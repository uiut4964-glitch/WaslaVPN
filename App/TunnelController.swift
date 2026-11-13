import Foundation
import Combine
import Network
import NetworkExtension
import Darwin

@MainActor
final class TunnelController: ObservableObject {
    @Published var host: String = UserDefaults.standard.string(forKey: "proxyHost") ?? "10.68.137.72" {
        didSet { UserDefaults.standard.set(host, forKey: "proxyHost") }
    }
    @Published var port: String = UserDefaults.standard.string(forKey: "proxyPort") ?? "8080" {
        didSet { UserDefaults.standard.set(port, forKey: "proxyPort") }
    }
    @Published private(set) var statusText = "غير متصل"
    @Published private(set) var isConnected = false
    @Published private(set) var isBusy = false
    @Published private(set) var isTesting = false
    @Published private(set) var testMessage = ""
    @Published private(set) var testSucceeded = false
    @Published var errorMessage: String?

    private let providerBundleIdentifier = "com.example.waslavpn.PacketTunnel"
    private var manager: NETunnelProviderManager?
    private var probeConnection: NWConnection?
    private var statusObserver: NSObjectProtocol?

    init() {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshStatus() }
        }
        Task { await restoreManager() }
    }

    deinit {
        if let statusObserver {
            NotificationCenter.default.removeObserver(statusObserver)
        }
        probeConnection?.cancel()
    }

    func connect() {
        Task { await startTunnel() }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        refreshStatus()
    }

    func testSOCKS5() {
        errorMessage = nil
        testMessage = ""
        testSucceeded = false

        let cleanedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let portNumber = validPort(), isIPv4Address(cleanedHost) else {
            testMessage = "تحقق من عنوان IPv4 والمنفذ أولًا."
            return
        }

        isTesting = true
        testMessage = "جارٍ الاتصال بخادم SOCKS5…"

        let connection = NWConnection(
            host: NWEndpoint.Host(cleanedHost),
            port: NWEndpoint.Port(rawValue: portNumber)!,
            using: .tcp
        )
        probeConnection = connection

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                connection.send(content: Data([0x05, 0x01, 0x00]), completion: .contentProcessed { error in
                    if let error {
                        Task { @MainActor in
                            self?.finishProbe("تعذر إرسال طلب SOCKS5: \(error.localizedDescription)", success: false)
                        }
                        connection.cancel()
                        return
                    }

                    connection.receive(minimumIncompleteLength: 2, maximumLength: 2) { data, _, _, receiveError in
                        if let receiveError {
                            Task { @MainActor in
                                self?.finishProbe("لم يصل رد SOCKS5: \(receiveError.localizedDescription)", success: false)
                            }
                        } else if let data, Array(data) == [0x05, 0x00] {
                            Task { @MainActor in
                                self?.finishProbe("نجحت مصافحة SOCKS5. اختبار UDP لم يتم بعد.", success: true)
                            }
                        } else {
                            Task { @MainActor in
                                self?.finishProbe("الخادم ردّ، لكنه لم يقبل SOCKS5 دون مصادقة.", success: false)
                            }
                        }
                        connection.cancel()
                    }
                })
            case .failed(let error):
                Task { @MainActor in
                    self?.finishProbe("فشل الوصول إلى الخادم: \(error.localizedDescription)", success: false)
                }
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue.global(qos: .utility))
    }

    private func finishProbe(_ message: String, success: Bool) {
        testMessage = message
        testSucceeded = success
        isTesting = false
        probeConnection = nil
    }

    private func startTunnel() async {
        errorMessage = nil
        guard let portNumber = validPort() else {
            errorMessage = "المنفذ يجب أن يكون رقمًا بين 1 و65535."
            return
        }
        let cleanedHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isIPv4Address(cleanedHost) else {
            errorMessage = "أدخل عنوان IPv4 للهاتف على نقطة الاتصال، مثل 10.68.137.72."
            return
        }

        isBusy = true
        defer { isBusy = false }

        do {
            let vpnManager = try await loadOrCreateManager()
            let tunnelProtocol = NETunnelProviderProtocol()
            tunnelProtocol.providerBundleIdentifier = providerBundleIdentifier
            tunnelProtocol.serverAddress = "Android SOCKS5 · \(cleanedHost)"
            tunnelProtocol.providerConfiguration = [
                "host": cleanedHost,
                "port": Int(portNumber)
            ]

            vpnManager.protocolConfiguration = tunnelProtocol
            vpnManager.localizedDescription = "وصلة VPN"
            vpnManager.isEnabled = true
            vpnManager.isOnDemandEnabled = false

            try await savePreferences(vpnManager)
            try await reloadPreferences(vpnManager)
            manager = vpnManager
            try vpnManager.connection.startVPNTunnel()
            statusText = "جارٍ الاتصال…"
        } catch {
            errorMessage = "تعذر تشغيل VPN: \(error.localizedDescription)"
            statusText = "غير متصل"
            isConnected = false
        }
    }

    private func restoreManager() async {
        do {
            manager = try await loadOrCreateManager()
            refreshStatus()
        } catch {
            errorMessage = "تعذر قراءة إعداد VPN: \(error.localizedDescription)"
        }
    }

    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let managers: [NETunnelProviderManager] = try await withCheckedThrowingContinuation { continuation in
            NETunnelProviderManager.loadAllFromPreferences { managers, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: managers ?? [])
                }
            }
        }

        if let existing = managers.first(where: {
            ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == providerBundleIdentifier
        }) {
            return existing
        }
        return NETunnelProviderManager()
    }

    private func savePreferences(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.saveToPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func reloadPreferences(_ manager: NETunnelProviderManager) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            manager.loadFromPreferences { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }

    private func refreshStatus() {
        guard let manager else {
            statusText = "غير متصل"
            isConnected = false
            return
        }

        switch manager.connection.status {
        case .connected:
            statusText = "متصل — النفق يعمل"
            isConnected = true
        case .connecting, .reasserting:
            statusText = "جارٍ الاتصال…"
            isConnected = false
        case .disconnecting:
            statusText = "جارٍ قطع الاتصال…"
            isConnected = false
        case .disconnected, .invalid:
            statusText = "غير متصل"
            isConnected = false
        @unknown default:
            statusText = "حالة غير معروفة"
            isConnected = false
        }
    }

    private func validPort() -> UInt16? {
        guard let value = UInt16(port.trimmingCharacters(in: .whitespacesAndNewlines)), value > 0 else {
            return nil
        }
        return value
    }

    private func isIPv4Address(_ value: String) -> Bool {
        var address = in_addr()
        return value.withCString { inet_pton(AF_INET, $0, &address) } == 1
    }
}
