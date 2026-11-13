import SwiftUI

struct ContentView: View {
    @StateObject private var controller = TunnelController()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    header
                    serverCard
                    testCard
                    connectionCard
                    informationCard
                }
                .padding(18)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("وصلة VPN")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "network.badge.shield.half.filled")
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(.tint)
            Text("اتصال واحد لكل التطبيقات")
                .font(.title3.weight(.bold))
            Text("مرّر TCP وUDP من الآيفون عبر خادم SOCKS5 الموجود على هاتف Android.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("خادم Android", systemImage: "antenna.radiowaves.left.and.right")
                .font(.headline)

            VStack(alignment: .leading, spacing: 6) {
                Text("عنوان الهاتف على نقطة الاتصال (ap0)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("مثال: 10.68.137.72", text: $controller.host)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.numbersAndPunctuation)
                    .textFieldStyle(.roundedBorder)
                    .environment(\.layoutDirection, .leftToRight)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("منفذ SOCKS5")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("8080", text: $controller.port)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .environment(\.layoutDirection, .leftToRight)
            }

            Text("أدخل عنوان ap0 الظاهر في تطبيق Android. يجب أن يكون الآيفون متصلًا بنقطة اتصال ذلك الهاتف.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var testCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                controller.testSOCKS5()
            } label: {
                HStack {
                    if controller.isTesting {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "waveform.path.ecg")
                    }
                    Text(controller.isTesting ? "جارٍ اختبار الخادم…" : "اختبار خادم SOCKS5")
                    Spacer()
                }
                .font(.body.weight(.semibold))
                .foregroundStyle(.white)
                .padding(14)
                .background(Color.indigo)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(controller.isTesting || controller.isBusy)

            if !controller.testMessage.isEmpty {
                Text(controller.testMessage)
                    .font(.footnote)
                    .foregroundStyle(controller.testSucceeded ? .green : .secondary)
            }
            Text("هذا الاختبار يتحقق من مصافحة SOCKS5 عبر TCP فقط، ولا يثبت بعدُ أن مرحّل UDP يعمل.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var connectionCard: some View {
        VStack(spacing: 14) {
            HStack {
                Circle()
                    .fill(controller.isConnected ? Color.green : Color.secondary)
                    .frame(width: 10, height: 10)
                Text(controller.statusText)
                    .font(.headline)
                Spacer()
                if controller.isBusy {
                    ProgressView()
                }
            }

            Button {
                if controller.isConnected {
                    controller.disconnect()
                } else {
                    controller.connect()
                }
            } label: {
                HStack {
                    Image(systemName: controller.isConnected ? "stop.fill" : "power")
                    Text(controller.isConnected ? "إيقاف الاتصال" : "تشغيل VPN")
                }
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 17)
                .background(controller.isConnected ? Color.red : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(controller.isBusy || controller.isTesting)

            if let error = controller.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var informationCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label("ملاحظات مهمة", systemImage: "info.circle")
                .font(.headline)
            Text("• لا تحتاج إلى ضبط Proxy يدوي في إعدادات Wi‑Fi؛ التطبيق ينشئ اتصال VPN للنظام.")
            Text("• يجب أن يدعم خادم Android أمر SOCKS5 UDP ASSOCIATE فعليًا.")
            Text("• إذا نجح التصفح وفشلت PUBG، فقد تكون المشكلة في UDP لدى الخادم أو الشبكة، لا في واجهة الآيفون.")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
