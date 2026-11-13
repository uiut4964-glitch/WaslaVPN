# وصلة VPN — مشروع iOS تجريبي

واجهة عربية بسيطة للاتصال بخادم SOCKS5 يعمل على هاتف Android، مع محاولة تمرير اتصالات TCP وUDP من خلال نفق VPN على مستوى النظام. المشروع موجّه للاختبار والتطوير؛ لم يتم توقيعه أو تشغيله على جهاز iPhone فعلي ضمن بيئة إعداد هذا الأرشيف.

## ما الذي يفعله التطبيق؟

- يحفظ عنوان خادم Android ومنفذ SOCKS5.
- يختبر مصافحة SOCKS5 الأساسية عبر TCP.
- ينشئ إعداد `NEPacketTunnelProvider` لتمرير حركة الجهاز عبر نفق VPN.
- يستخدم Tun2SocksKit / HevSocks5Tunnel بوضع UDP، مع استثناء عنوان خادم Android من مسار النفق لتجنب حلقة توجيه.
- لا يحتاج إلى ضبط HTTP Proxy يدويًا في إعدادات Wi‑Fi.

## إعداد الاتصال

1. شغّل مشاركة VPN/Proxy على هاتف Android واترك خادم SOCKS5 يعمل.
2. وصّل الآيفون بنقطة اتصال Android نفسها.
3. في التطبيق أدخل عنوان واجهة نقطة الاتصال للهاتف (العنوان الذي يستطيع الآيفون الوصول إليه، وغالبًا يظهر بجوار `ap0` أو `swlan0`) والمنفذ `8080` أو المنفذ الذي اخترته.
4. اضغط «اختبار خادم SOCKS5». الاختبار الحالي يتحقق من مصافحة SOCKS5 عبر TCP فقط، ولا يثبت أن UDP ASSOCIATE يعمل.
5. اضغط «تشغيل VPN» ووافق على إضافة إعداد VPN في iOS.
6. اختبر لعبة تستخدم UDP. إذا فشل UDP رغم نجاح TCP، فتحقق من أن تطبيق Android ينفذ SOCKS5 UDP ASSOCIATE ويرسل بيانات UDP فعليًا؛ لا يستطيع تطبيق iOS تعويض غياب دعم UDP في الخادم.

## مهم جدًا: صلاحية Apple والتوقيع

هذا ليس تطبيقًا عاديًا يعتمد على إعداد Proxy داخل Wi‑Fi. التقاط حركة كل التطبيقات يتطلب امتداد `Packet Tunnel` وصلاحية Apple المسماة `com.apple.developer.networking.networkextension` مع قيمة `packet-tunnel-provider`.

- البناء غير الموقّع في GitHub Actions يجهّز ملف IPA من ناحية الملفات فقط.
- تثبيت IPA بتوقيع Apple ID مجاني لا يمنح تلقائيًا صلاحية Packet Tunnel. يجب توقيع التطبيق والامتداد بملف Provisioning Profile صالح يتضمن هذه الصلاحية؛ وعمليًا يلزم حساب Apple Developer مؤهل وتفعيل القدرة على App ID.
- لا ترفع شهادة التوقيع أو ملف provisioning profile أو كلمة مرور Apple إلى مستودع عام.

مرجع Apple: https://developer.apple.com/documentation/networkextension/packet-tunnel-provider

## البناء من Windows عبر GitHub Actions

لا تحتاج إلى تثبيت Xcode على Windows لإنشاء بناء غير موقّع:

1. أنشئ مستودع GitHub خاصًا جديدًا.
2. ارفع محتويات هذا المجلد إلى المستودع، مع مجلد `.github`.
3. قبل البناء، غيّر `com.example.waslavpn` و`com.example.waslavpn.PacketTunnel` في `project.yml`، وغيّر `providerBundleIdentifier` في `App/TunnelController.swift` إلى نفس معرّف الامتداد الجديد.
4. من تبويب **Actions** شغّل **Build WaslaVPN iOS**.
5. عند اكتمال البناء، نزّل artifact باسم `WaslaVPN-iOS-unsigned`.

يمكن أيضًا فتح `project.yml` باستخدام XcodeGen على جهاز Mac ثم فتح `WaslaVPN.xcodeproj` في Xcode.

## الاعتماديات

- Tun2SocksKit: https://github.com/EbrahimTahernejad/Tun2SocksKit — MIT.
- محرك HevSocks5Tunnel: https://github.com/heiher/hev-socks5-tunnel — MIT.

يتم جلب الاعتمادية من Swift Package Manager عند البناء. لا توجد ملفات framework ثنائية مضمّنة في هذا الأرشيف.

## ملاحظة حول قواعد Apple

تنص ملاحظة Apple التقنية TN3120 على أن Packet Tunnel ليس واجهة عامة لتحويل كل حركة الجهاز إلى بروكسي على واجهة أخرى؛ لذلك فهذا النموذج مناسب للتجربة الشخصية/التطوير، ولا ينبغي اعتباره تصميمًا مضمون القبول في App Store. راجع: https://developer.apple.com/documentation/technotes/tn3120-expected-use-cases-for-network-extension-packet-tunnel-providers

## حدود النسخة الحالية

- النسخة الأولية تقبل عنوان IPv4 فقط لخادم Android.
- لا تتضمن مصادقة اسم مستخدم/كلمة مرور لخادم SOCKS5.
- اختبار SOCKS5 الحالي لا يختبر UDP ASSOCIATE.
- لم يتم اختبار توافق UDP بين هذا المحرك وإصدار تطبيق Android الظاهر في صورة المستخدم؛ يجب اختباره فعليًا قبل اعتباره حلًا نهائيًا لـPUBG.
- قد تتطلب إعدادات الشبكة تعديلًا حسب عنوان نقطة اتصال Android الفعلي. تم وضع مسار استثناء لعنوان الخادم لتجنب إرسال اتصال الخادم إلى النفق نفسه.
- امتدادات Packet Tunnel على iOS لها حدود ذاكرة وتشغيل يفرضها النظام؛ يلزم اختبار على الجهاز الحقيقي.

## ملفات المشروع

- `App/` — الواجهة العربية وإدارة إعداد VPN.
- `PacketTunnel/` — امتداد Packet Tunnel وتشغيل محرك SOCKS5 tun2socks.
- `project.yml` — تعريف أهداف XcodeGen والاعتماديات.
- `.github/workflows/build-ios.yml` — بناء IPA غير موقّع على macOS runner.
