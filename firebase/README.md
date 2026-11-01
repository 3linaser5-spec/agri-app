# إعدادات Firebase (قواعد الأمان والفهارس)

الكود في التطبيق قد يخفي أزرار الأدمن، لكن الحماية الفعلية للبيانات هي **قواعد
Firestore**. هذه الملفات مهيأة لتُراجع وتُطبَّق من صاحب مشروع Firebase؛ لم يتم
نشر القواعد من هذه النسخة.

## الملفات وربط Firebase CLI

يوجد في جذر المشروع `firebase.json` يربط Firebase CLI بالملفات الموجودة هنا:

- `firebase/firestore.rules` لقواعد Firestore.
- `firebase/firestore.indexes.json` للفهارس المركّبة.

لا يوجد في المستودع `.firebaserc`، لذلك لا يُفترض مشروع Firebase بعينه. اختر
المشروع الصحيح صراحةً في Firebase Console أو عبر `firebase use` قبل أي نشر.

## 1) الفهارس (Indexes)

الاستعلامات `my_farm` (`user_id` + `created_at`) و`encyclopedia_items`
(`section_id` + `order`) تحتاج فهارس مركّبة. يمكن إنشاؤها من Console ←
Firestore Database ← Indexes، أو بعد مراجعة المشروع شغّل يدويًا:

```sh
firebase deploy --only firestore:indexes
```

يمكن أيضًا فتح رابط إنشاء الفهرس الذي يظهر في رسالة الخطأ في سجل Flutter.

## 2) قواعد Firestore وملف users

قواعد `users/{uid}` تسمح لصاحب الحساب بقراءة مستنده فقط. عند الإنشاء يجب أن
تكون الحقول التي يكتبها `AuthService` هي بالضبط:

- `uid`: نص يساوي UID الخاص بالمستخدم.
- `name`: نص غير فارغ، بحد أقصى 400 بايت في القاعدة؛ ويتحقق التسجيل في التطبيق
  من 3 إلى 100 حرف، بينما يظل محرر الاسم الحالي قادراً على حفظ اسم غير فارغ.
- `phone`: رقم مصري مطبّع إلى 11 رقمًا إنجليزيًا (`01[0125]xxxxxxxx`).
- `createdAt`: Timestamp صادر من `FieldValue.serverTimestamp()` ومساوٍ لوقت
  الطلب.

التحديث الذي يستخدمه التطبيق حاليًا هو `set(..., merge: true)` لتغيير `name`
فقط؛ لذلك تمنع القاعدة تغيير `uid` أو `phone` أو `createdAt` وتحظر الحذف.
الحقول الزائدة والأنواع غير الصحيحة مرفوضة. أما باقي المجموعات فتظل خاضعة
للصلاحيات المعرّفة في `firestore.rules`، والقاعدة النهائية تمنع أي مسار غير
معرّف.

## 3) حسابات الهاتف الحالية وملكية الرقم

التطبيق الحالي يحوّل الرقم إلى بريد إلكتروني **اصطناعي** من الشكل
`<normalized-phone>@agri-app.local` ويستخدم Email/Password. هذا الحساب الاصطناعي
لا يثبت أن المستخدم يملك رقم الهاتف، ولا يرسل OTP. لا تعتمد على تسجيل الدخول
الحالي لإثبات الملكية أو لاسترداد الرقم.

إذا كانت ملكية الرقم مطلوبة:

1. من Console ← Authentication ← Sign-in method فعّل **Phone**، واضبط متطلبات
   Android (اسم الحزمة وبصمة SHA-1/reCAPTCHA عند طلبها) وحدود الاستخدام.
2. غيّر تدفق التطبيق إلى Firebase Phone Auth: إرسال OTP، التحقق من الرمز، ثم
   إنشاء/ربط الحساب بالاعتماد الناتج. تفعيل المزود في Console وحده لا يحوّل
   التدفق الاصطناعي الحالي إلى OTP.
3. اختبر سيناريوهات إعادة الإرسال، الحدّ من المحاولات، وأرقام الاختبار من
   Console قبل الاعتماد على إثبات الملكية.

## 4) إعداد الأدمن وتطبيق القواعد

1. سجّل دخولًا بحساب الأدمن من التطبيق.
2. من Console ← Authentication انسخ UID الخاص به.
3. أنشئ يدويًا مستند `admins/<UID>` (مثلًا الحقل `role: "admin"`). الكتابة
   إلى مجموعة `admins` ممنوعة من التطبيق.
4. راجع `firestore.rules` في Rules Playground أو Firestore Emulator، خصوصًا
   إنشاء/تحديث `users/{uid}` وعمليات المجموعات المستخدمة فعلًا.
5. بعد اختيار المشروع الصحيح ومراجعة النتائج، انشر يدويًا عند الحاجة:

```sh
firebase deploy --only firestore:rules
```

هذه الخطوات توثيقية فقط ولم تُنفّذ هنا. إذا ظهرت مجموعة جديدة في التطبيق ولم
تُضف إلى القواعد، فستمنعها القاعدة النهائية `match /{document=**}`.

## 5) مفاتيح API

مفاتيح العميل مثل `apiKey` في `lib/firebase_options.dart` **ليست أسرارًا**؛
هي معرّفات/بيانات إعداد عامة للتطبيق ولا تحل محل قواعد Firestore أو التحقق من
الهوية. لا تغيّر `apiKey` من هذه النسخة لأن القيمة الفعلية غير متاحة. استخدم
Google Cloud Console لتقييد المفتاح باسم الحزمة
`com.dahshory.agri.agri_app` وبصمة SHA-1 الصحيحة، مع إبقاء الحماية الحقيقية في
قواعد Firebase.

تمت مطابقة `lib/firebase_options.dart` مع إعداد Android الرسمي للمشروع من Firebase
Console. ملف `google-services.json` لم يُضف إلى المستودع؛ يظل الـworkflow يعتمد على سر
GitHub `GOOGLE_SERVICES_JSON`، ويجب إبقاؤه مطابقًا لملف التطبيق نفسه.

### مصنف أمراض النباتات المخصص

أُضيف `functions/plant_ai` كـPython codebase منفصل عن دوال الطقس المكتوبة بـTypeScript.
الدالة `classifyPlantDisease` تشغّل ملف TFLite المخصص داخل Firebase Cloud Functions،
وتتطلب Firebase Auth وApp Check صالحًا، وتسمح بعشر صور يوميًا لكل حساب. لا تُحفظ الصور؛
وتُعاد أعلى ثلاثة تصنيفات أولية مع البحث عن سجل مطابق بدقة في قاعدة العلاج المرفقة.
يعرض التطبيق الأعراض وتوقيت المكافحة الواردين في السجل المطابق، ولا يعرض مبيدًا أو جرعة
ما دامت بيانات المنتج غير موثقة.

شاشة الفحص لم تعد تستدعي Gemini؛ تستخدم `cloud_functions` لاستدعاء المصنف. App Check
يستخدم Debug أثناء التطوير وPlay Integrity في إصدار Android الإنتاجي. قبل الإطلاق،
سجّل تطبيق Android في Firebase App Check باستخدام Play Integrity وأضف بصمة SHA-256
لشهادة التوقيع؛ يلزم أيضًا إعداد Play Integrity في Google Play Console إذا كان ذلك
مطلوبًا لقناة التوزيع. لا تفعّل فرض App Check على الدالة قبل اختبار نسخة التطبيق المسجلة.
لا تضع Debug token في إصدار منشور أو workflow عام.

نشر الدالة يتطلب مشروع Firebase على Blaze، كما أن Python Functions موصوفة في توثيق
Firebase الحالي كميزة تجريبية. راجع الميزانية وفعّل تنبيهات الفوترة قبل النشر. من جذر
المستودع وبعد اختيار مشروع Firebase الصحيح، ينشر codebase المصنف فقط بهذا الأمر:

```sh
firebase deploy --only functions:plant-ai
```

قواعد Firestore الحالية تمنع الوصول المباشر من العميل إلى مجموعة عداد الاستخدام
`_server_ai_usage`؛ الدالة تستخدم Admin SDK لحفظ العداد. ملف `treatments.json` يذكر
كتاب لجنة مبيدات الآفات الزراعية 2026، لكنه يصف مصدره بأنه غير متحقق بصورة مستقلة،
وسجلات التشغيل الحالية لا تحتوي مبيدات معتمدة مفعّلة؛ لذلك لا تُعرض أسماء منتجات أو جرعات.
النموذج لا يغطي إلا الفئات الثماني والثلاثين التي دُرّب عليها ولا يضمن دقة صور الحقول.

### بوابة صور التدريب للأدمن

أضيفت إلى لوحة الأدمن شاشة تجمع صورة النبات مع المحصول والمرض بعد تأكيد مراجعة
التصنيف. تُحفظ الصورة في `plant_training/{uid}/` داخل Cloud Storage، وتحفظ بياناتها
الوصفية في مجموعة `plant_training_samples` بحالة `pending_training`. لا تنشئ الشاشة
روابط تنزيل عامة، ولا تسمح بتعديل أو حذف العينات من التطبيق. تعتمد قواعد Firestore
وStorage على وجود مستند `admins/{uid}`؛ يجب إنشاء المستند للحساب الإداري ونشر القواعد
من Firebase Console أو CLI قبل نجاح الرفع. قواعد Storage تستخدم `firestore.exists`
للتحقق من دور الأدمن، ويُحتسب فحص المستند ضمن قراءات Firestore.

هذه البوابة تجمع الصور المصنفة فقط؛ **رفع صورة لا يغير أوزان النموذج العامل ولا ينشر
نسخة جديدة تلقائياً**. سكربت التدريب المتاح يبدأ من MobileNetV2 بأوزان ImageNet وينزّل
PlantVillage، ولا يستأنف من ملف TFLite المنشور. لم يُعثر ضمن الملفات المتاحة على
checkpoint قابل للتدريب بصيغة `.keras` أو `.h5` أو `.pt`؛ لذلك يلزم إعداد وتشغيل خدمة
تدريب منفصلة تجمع الصور القديمة والجديدة، وتقيّم النموذج، ثم تصدر نسخة جديدة قبل ربطها
بدالة التشخيص. لا تعرض البوابة زر تدريب يوحي بأن هذه الخطوة تنفذ بالفعل.

إعدادات الرفع متوافقة مع FlutterFire `firebase_storage` 13.x و`firebase_core` 4.x.
لرفع القواعد بعد اختيار المشروع الصحيح (لم ينفذ هذا التغيير أي نشر):

```sh
firebase deploy --only firestore:rules,storage
```

راجع [رفع الملفات من Flutter](https://firebase.google.com/docs/storage/flutter/upload-files)،
[صلاحيات Cloud Storage والتحقق من البيانات](https://firebase.google.com/docs/storage/security/rules-conditions)،
و[إصدار firebase_storage المتوافق](https://pub.dev/packages/firebase_storage/versions/13.0.0).

مراجع الإعداد الرسمية: [تنظيم codebases متعددة](https://firebase.google.com/docs/functions/organize-functions)،
[إصدارات Python runtime](https://firebase.google.com/docs/functions/manage-functions)،
[مرجع Callable Functions لـPython](https://firebase.google.com/docs/reference/functions/2nd-gen/python/firebase_functions.https_fn)،
[App Check مع Play Integrity على Android](https://firebase.google.com/docs/app-check/android/play-integrity-provider)،
[تهيئة App Check في Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers)،
[خطة Firebase Blaze والفوترة](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)،
[حزمة LiteRT المستخدمة](https://pypi.org/project/ai-edge-litert/).

## 6) تحديث التطبيق

يمكن أن يحتوي `version.json` على `sha256` (قيمة SHA-256 للـ APK بحروف صغيرة).
يفرض التطبيق الآن وجود قيمة سداسية عشرية من 64 خانة ويطابقها قبل التثبيت؛ لذلك
يجب بناء APK ثم حساب hash له وإضافة `sha256` إلى `version.json` قبل رفع/الإعلان
عن أي إصدار جديد. التحقق يكشف تلف الملف أثناء النقل لكنه لا يغني عن حماية حساب
GitHub أو توقيع Android. روابط التحميل يجب أن تكون HTTPS على GitHub فقط.
