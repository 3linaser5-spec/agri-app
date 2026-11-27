# الأمان — الإجراءات المطلوبة قبل النشر

آخر تحديث: 2026-11-26

الملف ده بيجمّع الإجراءات الأمنية: اللي اتعمل في الكود، واللي لازم يتعمل من Firebase Console أو إعدادات المستودع.

## 1. قواعد Firestore وStorage (أولوية قصوى)

- ملفات `firebase/firestore.rules` و`firebase/storage.rules` مكتوب عليها إنها قوالب مقترحة ولم تُنشر.
- افتح Firebase Console ← Firestore ← Rules وقارن القواعد المنشورة فعليًا بالملفات في المستودع.
- أنشئ مستند `admins/{uid}` للأدمن قبل النشر، وإلا لوحة الإدارة مش هتفتح.
- اختبر قبل النشر: `cd rules-tests && npm test` على Firebase Emulator.
- النشر من الطرفية: `firebase deploy --only firestore:rules,firestore:indexes,storage` بمشروع `agri-dahshory`.

## 2. مفتاح Firebase وApp Check

- قيّد مفتاح الـ API من Google Cloud Console ← APIs & Services ← Credentials: تطبيقات Android فقط، ببصمة SHA-1 للإصدار، مع حدود للـ APIs المسموحة.
- فعّل App Check بمزوّد Play Integrity من Firebase Console ← App Check، وسجّل التطبيق.
- بعد ما تتأكد إن كل الترافيك بيمر بـ App Check، فعّل Enforce على Firestore وStorage وCloud Functions.
- تحذير: تفعيل Enforce قبل تسجيل التطبيق بيقفل التطبيق للمستخدمين.

## 3. التحقق من ملكية رقم الموبايل (issue #43)

- الوضع الحالي: الدخول بإيميل اصطناعي `phone@agri-app.local`، وده لا يثبت ملكية الرقم.
- الخطة المقترحة: خطوة تحقق واحدة برسالة SMS عند التسجيل (Firebase Phone Auth)، ثم ربط الجلسة بالحساب.
- المتطلبات: تفعيل Phone provider، إضافة بصمات SHA-1/SHA-256، ومراجعة تكلفة الرسائل قبل الإطلاق.
- لحد التنفيذ: اعتبر رقم الموبايل معرّف عرض وليس وسيلة تحقق من الهوية.

## 4. سياسة كلمة المرور

- الكود بقى يفرض 10 أحرف على الأقل مع حروف وأرقام عند إنشاء الحساب، بدون كسر دخول الحسابات القديمة.
- فعّل نفس السياسة على الخادم: Firebase Console ← Authentication ← Settings ← Password policy.

## 5. رقم التواصل (issue #50)

- الرقم اتشال من الكود وبقى بيتقرأ وقت البناء من GitHub Secrets: `ENGINEER_PHONE` (صيغة دولية بدون +) و`ENGINEER_PHONE_LOCAL` (صيغة محلية للعرض في PDF).
- **مهم:** لو السرين مش مضافين، أزرار واتساب هتختفي من التطبيق وبناء الـ APK هيكمّل بشكل طبيعي.
- الرقم القديم لسه موجود في تاريخ الكوميتات وفي الإصدارات القديمة. لو مش عايزه ظاهر: غيّره لرقم مخصص للعمل، أو حوّل المستودع لخاص.

## 6. إصدار APK

- لتشويش كود Dart وتقسيم معلومات التصحيح، أضف الفلاجين التاليين لخطوة بناء الـ release في workflow البناء: `--obfuscate --split-debug-info=build/debug-info`، وارفع مجلد `build/debug-info` كـ artifact (معلومات التصحيح دي بتحتاجها عشان تفك الـ stack trace بعد التشويش).
- تعديل ملفات `.github/workflows/` محتاج صلاحية `workflow` على ربط GitHub، ولو مش متاحة: عدّلها من واجهة GitHub أو من نسخة محلية للمستودع.
- تصغير الموارد (R8) مقفول عن قصد لحد ما يتجرّب على جهاز حقيقي.

## 7. أسرار وإعدادات المستودع المطلوبة

| الاسم | النوع | الاستخدام |
| --- | --- | --- |
| `ENGINEER_PHONE` | Secret | رقم واتساب بصيغة دولية بدون + |
| `ENGINEER_PHONE_LOCAL` | Secret | نفس الرقم بصيغة محلية للعرض في PDF |
| `FIREBASE_SERVICE_ACCOUNT` | Secret | نشر قواعد Firestore وStorage |
| `FIREBASE_PROJECT_ID` | Variable | معرّف مشروع Firebase |

## 8. مراجع

- `docs/security-audit-2026-11-25.md` — ملاحظات التدقيق الأولى.
- `plan.md` — خطة الإصلاح الكاملة.
