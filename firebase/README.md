# إعدادات Firebase (قواعد الأمان والفهارس)

الكود في التطبيق **بيخفي** أزرار الأدمن بس. اللي بيحمي البيانات فعلًا هو
**قواعد Firestore**. الملفات هنا قوالب جاهزة، ولازم تتراجع وتتنشر من عندك.

## 1) الفهارس (Indexes)
الاستعلامات `my_farm` (user_id + created_at) و`encyclopedia_items`
(section_id + order) محتاجة فهارس مركّبة، من غيرها الشاشة بتعرض خطأ.

    firebase deploy --only firestore:indexes

أو من الـ Console ← Firestore ← Indexes، أو اضغط على الرابط اللي بيظهر في رسالة
الخطأ (Flutter debug console) وهيفتح الفهرس جاهز للإنشاء.

## 2) القواعد (Rules)
1. شغّل التطبيق وسجّل دخول بحساب الأدمن مرة واحدة.
2. من Console ← Authentication انسخ الـ UID بتاعه.
3. أنشئ يدويًا مستند `admins/<UID>` (أي حقل، مثلًا `role: "admin"`).
4. جرّب `firestore.rules` في **Rules Playground** (قراءة/كتابة لكل collection).
5. انشر: `firebase deploy --only firestore:rules`

> لو في أي collection تاني بيستخدمه التطبيق ومش موجود في الملف، القاعدة الأخيرة
> `match /{document=**}` هتمنعه. راجع الـ Playground قبل النشر.

## 3) مفاتيح الـ API
- مفتاح Firebase في `lib/firebase_options.dart`: **قيّده** من Google Cloud Console
  (Credentials) بحيث يشتغل مع package name `com.dahshory.agri.agri_app`
  وبصمة SHA-1 بتاعة الـ keystore فقط. وتأكد إن الـ appId كامل
  (من `flutterfire configure`).
- مفتاح Gemini بيتمرر `--dart-define` وبيتحط جوه الـ APK، فأي حد يفك الـ APK
  يقدر يستخرجه. قيّده بالـ package وSHA-1 من Google Cloud، وحط حد استخدام يومي
  (quota)، أو انقل النداء لـ Cloud Function / Firebase AI Logic.

## 4) تحديث التطبيق
`version.json` يقدر يحتوي حقل `sha256` (SHA-256 للـ APK بحروف صغيرة).
لو موجود التطبيق بيتحقق منه قبل التثبيت. وروابط التحميل لازم تكون https على
GitHub فقط.
