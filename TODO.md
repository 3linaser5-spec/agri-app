# الأعمال المطلوبة

- [x] توحيد صلاحيات تنبيهات اللاندسكيب والأقمار عبر `hasMapAlertAccess`، مع إبقاء حفظ حقول الأقمار مرتبطًا بـ `satellite_monitoring`.
- [x] منع حفظ حقول الأقمار دون entitlement صحيح، مع التحقق من الاسم والمحصول والتاريخ والمساحة قبل الكتابة.
- [x] تثبيت ملكية مشروع اللاندسكيب على المستند الأب في `versions` و`satelliteLinks` باستخدام `get()`.
- [x] إضافة اختبارات Firebase Emulator دائمة إلى `rules-tests/` وتشغيلها في CI.
- [x] تغطية اختبارات القواعد: عزل المستخدمين، ملكية المشروع، منع child writes، صلاحية الأدمن، entitlement اللاندسكيب، الرفض بدون entitlement، والتنبيهات وملاحظات الفحص.
- [x] إظهار «اللاندسكيب والري» كبطاقة رئيسية بجانب الحاسبات ومزرعتي ورصد الأقمار، وإضافته إلى قائمة كل الخدمات.
- [x] إصلاح مسار keystore في Build APK وإضافة فحوص آمنة لوجود أسرار التوقيع وملف Firebase.
- [x] تشغيل `npm test` داخل Functions: 25 اختبارًا ناجحًا.
- [x] تشغيل `npm audit --omit=dev --audit-level=moderate` داخل Functions: 0 vulnerabilities.
- [ ] تشغيل Flutter analyze/test وبناء APK عبر GitHub Actions بعد دفع commit؛ Flutter غير مثبت في Sandbox الحالي.
- [ ] نشر قواعد Firestore إلى Firebase بعد مراجعة مالك المشروع؛ هذا التنفيذ لا ينشر تلقائيًا قواعد الإنتاج.
