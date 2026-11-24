# نباتي — المستشار الزراعي الذكي (agri-app)

تطبيق Flutter عربي للاستشارات الزراعية: تشخيص أمراض النبات بالصور، حاسبات
زراعية، برامج مزرعة، خرائط وتنبيهات أقمار صناعية، ومخطّط تنفيذ شبكات الري
مع تحليل تغطية هيدروليكي وتقارير PDF/DXF.

## المتطلبات

- Flutter 3.44.x (أحدث إصدار مستقر يعمل عليه CI) و Dart 3.10+
- Node.js 20+ لوظائف Firebase (`functions/`)
- Python 3.11 لوظيفة تشخيص النبات `functions/plant_ai` (اختياري محليًا)

## التشغيل

```bash
flutter pub get
flutter analyze
flutter test
flutter run            # يحتاج جهازًا/محاكيًا عبر adb
```

`android/` غير مُلتزَم في المستودع: CI يولّده بـ `flutter create` ثم يحقن
الصلاحيات و`MainActivity.kt` و`build.gradle` (راجع
`.github/workflows/build_apk.yml`). وبالتالي لا يمكن بناء APK محليًا قبل توليد
المجلد أو تشغيل الـ workflow.

### الوظائف السحابية

```bash
cd functions && npm ci && npm test && npm run build
firebase deploy --only functions,firestore:rules,firestore:indexes,storage
```

`firebase/firestore.rules` و`firebase/storage.rules` قالبان لم يُنشرا بعد؛
راجعهما في Rules Playground قبل النشر، وأنشئ مستند `admins/{uid}` للأدمن.

## الأسرار المطلوبة (Firebase Functions config / env)

| المفتاح | الاستخدام | الحالة |
| --- | --- | --- |
| `NASA_EARTHDATA_USERNAME` / `_PASSWORD` | تحميل صور الأقمار (AppEEARS) | غير مضبوط |
| `CDSE_OAUTH_CLIENT_ID` / `_SECRET` | Sentinel Hub / Copernicus | غير مضبوط |

بدونها تعمل بقية الميزات، وتُعيد مسارات الأقمار خطأ إعداد واضحًا بدل نتيجة
مزيفة. راجع `docs/SATELLITE_MONITORING_SETUP_AR.md`.

## البنية

| المسار | المحتوى |
| --- | --- |
| `lib/main.dart` | نقطة الدخول فقط (`main`) |
| `lib/app/` | `AgriConsultantApp`، `ThemeController`، وتهيئة Firebase المشتركة |
| `lib/screens/root/` | شاشات الجذر: البداية، الدخول، التنقّل، الرئيسية، الماسح، السجل، الحساب، الموسوعة، الإحصاءات |
| `lib/screens/` | شاشات مقسّمة حسب النطاق (admin, calculators, farm, irrigation, satellite) |
| `lib/services/` | خدمات Firebase والشبكة والتحليل |
| `lib/engines/` | محركات الري والهيدروليكا والتغطية (pure Dart، مغطاة باختبارات) |
| `lib/models/` | موديلات Firestore/JSON |
| `firebase/` | قواعد Firestore وStorage والفهارس |
| `functions/` | Cloud Functions (TypeScript) + `plant_ai` (Python) |
| `docs/` | أدلة الإعداد والتشغيل |

## الاختبارات و CI

- `flutter test` يشغّل كل ملفات `test/` (لا تُوضع اختبارات داخل `lib/`).
- `cd functions && npm test` لاختبارات Cloud Functions.
- `.github/workflows/analyze.yml` يشغّل الاثنين مع `flutter analyze` على Flutter 3.50.1.
- `scripts/check_coverage.py` يفرض حدًا أدنى لتغطية الأسطر (73%) من `coverage/lcov.info`.
- `.github/workflows/build_apk.yml` يبني APK ويحدّث `version.json`
  (الإصدار + بصمة SHA-256) الذي يقرأه التحديث الذاتي في التطبيق.

## تحديث التطبيق ذاتيًا

`VersionService` يجلب `version.json` من
`raw.githubusercontent.com/3linaser5-spec/agri-app/main/version.json`، يقارن
الإصدار، ينزّل APK من نطاقات GitHub المسموحة، يتحقق من SHA-256 ثم يفتح المثبّت.
أي تغيير في مكان النشر يتطلب تحديث قائمة النطاقات المسموحة في
`lib/services/version_service.dart` و`scripts/update_release_checksum.py`.
