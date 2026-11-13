import Foundation
import NetworkExtension
import Tun2SocksKit

final class PacketTunnelProvider: NEPacketTunnelProvider {
    override func startTunnel(
        options: [String: NSObject]?,
        completionHandler: @escaping (Error?) -> Void
    ) {
        guard
            let tunnelProtocol = protocolConfiguration as? NETunnelProviderProtocol,
            let configuration = tunnelProtocol.providerConfiguration,
            let host = configuration["host"] as? String,
            let port = configuration["port"] as? Int,
            (1...65535).contains(port)
        else {
            completionHandler(TunnelError.invalidConfiguration)
            return
        }

        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.2")
        settings.mtu = NSNumber(value: 1400)

        let ipv4 = NEIPv4Settings(
            addresses: ["198.18.0.1"],
            subnetMasks: ["255.255.255.0"]
        )
        ipv4.includedRoutes = [NEIPv4Route.default()]
        // Keep the Android SOCKS5 endpoint outside the VPN route to avoid a tunnel loop.
        ipv4.excludedRoutes = [
            NEIPv4Route(destinationAddress: host, subnetMask: "255.255.255.255")
        ]
        settings.ipv4Settings = ipv4

        let ipv6 = NEIPv6Settings(
            addresses: ["fd00:198:18::1"],
            networkPrefixLengths: [64]
        )
        ipv6.includedRoutes = [NEIPv6Route.default()]
        settings.ipv6Settings = ipv6

        let dns = NEDNSSettings(servers: ["1.1.1.1", "8.8.8.8"])
        dns.matchDomains = [""]
        settings.dnsSettings = dns

        setTunnelNetworkSettings(settings) { error in
            if let error {
                NSLog("WaslaVPN: Could not apply packet tunnel settings: %@", error.localizedDescription)
                completionHandler(error)
                return
            }

            let engineConfiguration = Self.makeHevConfiguration(host: host, port: port)
            NSLog("WaslaVPN: Starting SOCKS5 tun2socks engine for %@:%d", host, port)

            DispatchQueue.global(qos: .userInitiated).async {
                Socks5Tunnel.run(withConfig: .string(content: engineConfiguration)) { code in
                    NSLog("WaslaVPN: tun2socks engine exited with code %d", code)
                    if code != 0 {
                        self.cancelTunnelWithError(TunnelError.engineStopped(code))
                    }
                }
            }

            completionHandler(nil)
        }
    }

    override func stopTunnel(
        with reason: NEProviderStopReason,
        completionHandler: @escaping () -> Void
    ) {
        Socks5Tunnel.quit()
        completionHandler()
    }

    private static func makeHevConfiguration(host: String, port: Int) -> String {
        // host is restricted to IPv4 in the app UI, so it is safe to place in this YAML.
        return """
        tunnel:
          mtu: 1400
        socks5:
          address: \(host)
          port: \(port)
          udp: 'udp'
        misc:
          task-stack-size: 24576
          tcp-buffer-size: 4096
          max-session-count: 512
          connect-timeout: 5000
          read-write-timeout: 60000
          log-file: stderr
          log-level: error
        """
    }
}

private enum TunnelError: LocalizedError {
    case invalidConfiguration
    case engineStopped(Int32)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "إعدادات خادم SOCKS5 غير صالحة."
        case .engineStopped(let code):
            return "توقف محرك النفق برمز الخطأ \(code)."
        }
    }
}
