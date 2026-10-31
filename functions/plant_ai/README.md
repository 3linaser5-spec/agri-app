# مصنف الأمراض على خادم Firebase

هذا codebase يشغّل ملف `plant_disease_classifier.tflite` على خادم Firebase Cloud Functions باستخدام Python 3.11 وLiteRT. التطبيق يرفع صورة ورقة عبر Callable Function اسمها `classifyPlantDisease`؛ لا يوجد تشغيل محلي للنموذج. ترجع الدالة أعلى ثلاثة احتمالات من 38 فئة PlantVillage، وتبحث عن سجل علاج مطابق بدقة في `treatments.json`.

الدالة تفرض Firebase Auth وApp Check، وتضع حدًا أقصاه 10 صور يوميًا لكل حساب. عداد الاستخدام خادمي، وصور التشخيص لا تُحفظ في Firestore أو Storage. حجم الصورة الأقصى 5 MiB، والصيغ المدعومة JPG وPNG وWebP. وضعت الدالة حدًا أقصى للتوسّع حتى لا ترتفع الكلفة بلا حدود.

## قاعدة العلاج وسلامة التوصيات

قاعدة `treatments.json` هي الملف المرفق في سياق المشروع، ويذكر مصدره وزارة الزراعة واستصلاح الأراضي — لجنة مبيدات الآفات الزراعية 2026. الملف نفسه يضع `source_status` على أنه غير متحقق بصورة مستقلة، وينص على عدم عرض مبيد قبل مراجعة مرجع رسمي موضعي لكل سجل. كذلك حقول `approved_pesticides` فارغة في السجلات الحالية. لذلك تعرض الدالة الأعراض وتوقيت المكافحة المذكورين في السجل المطابق، لكنها لا تعرض اسم مبيد أو جرعة أو فترة أمان. أي منتج لن يظهر إلا بعد توثيق المصدر والسجل واعتماد بياناته.

إذا لم توجد مطابقة مباشرة بين فئة النموذج وسجل القاعدة، لا تُخمن الدالة علاجًا؛ تعرض أن سجلًا مطابقًا غير متوفر. ومخرجات الصورة احتمالات أولية من صور PlantVillage، وليست تشخيصًا حقليًا مؤكدًا.

## متطلبات تهيئة App Check

ترفض الدالة أي طلب لا يحمل App Check صالحًا. قبل اختبارها من إصدار Android، سجّل التطبيق في Firebase App Check باستخدام Play Integrity وأضف بصمة SHA-256 لشهادة التوقيع الفعلية. تهيئة Play Integrity قد تتطلب ربط مشروع Firebase من Google Play Console؛ إعداد التوزيع خارج Google Play يحتاج ضبط إعدادات Play Integrity المناسبة. لا تستخدم Debug token مكشوفًا أو تضعه في APK أو workflow عام.

## النشر

يتطلب نشر Cloud Functions خطة Firebase Blaze وربط المشروع بحساب فوترة؛ الاستهلاك قد يولد رسومًا حسب الاستخدام. راجع الميزانية وأنشئ تنبيه فوترة قبل النشر. دعم Firebase Functions لـPython في وضع Preview حسب التوثيق الرسمي، لذا اختبر الكود قبل تعميمه.

بعد تسجيل Firebase CLI في الحساب الصحيح واختيار المشروع الصحيح، ينشر هذا codebase فقط من جذر المستودع:

```bash
firebase deploy --only functions:plant-ai --project agri-dahshory
```

قبل اختبار التطبيق، يجب أن تكون قيم Firebase في `lib/firebase_options.dart` مطابقة لإعداد Android الرسمي، كما يجب أن يكون سر GitHub `GOOGLE_SERVICES_JSON` المستخدم في CI مطابقًا للملف نفسه. لا تضف `google-services.json` إلى Git.

## مراجع رسمية

- [تنظيم Functions في codebases متعددة](https://firebase.google.com/docs/functions/organize-functions)
- [اختيار Python runtime وإدارة الدوال](https://firebase.google.com/docs/functions/manage-functions)
- [مرجع Python Callable Functions وApp Check](https://firebase.google.com/docs/reference/functions/2nd-gen/python/firebase_functions.https_fn)
- [فرض App Check على Cloud Functions](https://firebase.google.com/docs/app-check/cloud-functions)
- [إعداد Android مع Play Integrity](https://firebase.google.com/docs/app-check/android/play-integrity-provider)
- [تهيئة App Check في Flutter](https://firebase.google.com/docs/app-check/flutter/default-providers)
- [خطة Firebase والفوترة](https://firebase.google.com/docs/projects/billing/firebase-pricing-plans)
- [حزمة LiteRT المستخدمة لتشغيل TFLite](https://pypi.org/project/ai-edge-litert/)
- [بيانات PlantVillage المستخدمة في التدريب](https://huggingface.co/datasets/mohanty/PlantVillage)
