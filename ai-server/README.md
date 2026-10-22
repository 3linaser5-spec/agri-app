# خادم تشخيص النباتات المحلي (Docker)

نموذج رؤية مفتوح المصدر بيشتغل على جهازك/سيرفرك أنت، من غير Gemini ولا أي
خدمة ذكاء اصطناعي خارجية. التطبيق بيبعت صورة، والخادم يرجّع: اسم النبات،
التشخيص، الأعراض، الأسباب، العلاج (عضوي ثم كيماوي)، والوقاية — بالعربي وبصيغة JSON.

## المكوّنات

| الخدمة | الدور |
|---|---|
| `ollama` | يشغّل نموذج الرؤية (`qwen2.5vl:7b` افتراضيًا) |
| `model-pull` | يسحب النموذج أول مرة بس |
| `gateway` | API صغير: مفتاح سري، فحص الصورة وتصغيرها، تنظيم الرد، حد للطلبات المتزامنة |

## التشغيل

```bash
cd ai-server
cp .env.example .env
# حط في .env قيمة API_KEY (مثلاً: openssl rand -hex 24)
docker compose up -d --build              # CPU (بطيء)
# أو مع كرت NVIDIA:
docker compose -f docker-compose.yml -f docker-compose.gpu.yml up -d --build
```

أول تشغيل بيسحب النموذج (عدة جيجا). تابع بـ `docker compose logs -f model-pull`.

اختبار:

```bash
curl http://127.0.0.1:8080/health
curl -X POST http://127.0.0.1:8080/v1/diagnose \
  -H "X-API-Key: <API_KEY>" -F "image=@leaf.jpg" -F "crop=طماطم"
```

## الرد

`is_plant`, `plant_name_ar`, `plant_name_scientific`, `health_status`
(`healthy|diseased|pest|deficiency|unclear`), `diagnosis_ar`, `diagnosis_en`,
`confidence` (0–1), `severity`, `symptoms`, `causes`, `treatment_organic`,
`treatment_chemical`, `prevention`, `needs_expert`, `notes`, `disclaimer`, `model`.

الخادم بيفرض بنفسه: لو الثقة أقل من 0.5 أو الحالة `unclear` يبقى `needs_expert=true`،
والعلاج الكيماوي بدون جرعات رقمية (المادة الفعالة فقط) مع تنبيه لقراءة النشرة.

## المتطلبات الفعلية

- **كرت شاشة NVIDIA بذاكرة 8GB+** لنموذج 7B (الرد في ثواني). بدون كرت الرد ممكن ياخد دقائق؛ جرّب `qwen2.5vl:3b`.
- مساحة 15GB+ ورام 16GB+.
- لازم الجهاز يفضل شغال. Firebase **مش** هيشغّل ده، هو بس ممكن يخزّن النتائج.

## إتاحته للتطبيق على النت

المنفذ مربوط على `127.0.0.1` عمدًا. للوصول من الموبايل حط قدامه proxy بـ HTTPS
(Caddy أو Cloudflare Tunnel) ولا تفتح 8080 مباشرة. المفتاح `API_KEY` لو اتسرّب
غيّره في `.env` وأعد تشغيل `gateway`.

⚠️ لا تحط `API_KEY` داخل تطبيق Flutter كما هو (أي حد يفك الـ APK يلاقيه). الأمان
الحقيقي: خلّي التطبيق يكلم Cloud Function صغيرة (بعد التحقق من تسجيل الدخول)
وهي اللي تكلم الخادم بالمفتاح المخزّن في Secret Manager. أقدر أبنيها كخطوة لاحقة.

## حدود لازم تعرفها

- ده نموذج رؤية عام، **مش** مدرّب خصيصًا على كل أمراض النباتات. هو أقرب لـ Gemini من
  نموذج تصنيف جاهز، لكن دقته بتتفاوت وممكن يغلط أو يتخيل علاج.
- لو عايز دقة أعلى لمحاصيل معينة، الطريق: تجمع صور مصنّفة (PlantVillage / PlantDoc /
  صور مزارعك)، تضبط النموذج (fine-tune)، ثم تضيف طبقة تصنيف قبل الوصف. ده شغل تدريب
  منفصل محتاج GPU.
- التشخيص من صورة واحدة استرشادي. القرار النهائي ومبيدات الآفات لمهندس زراعي.

## اختبار الكود

```bash
cd gateway
python -I -m unittest discover -s tests -p "test_*.py"   # بدون أي مكتبات
pip install -r requirements.txt && python tests/e2e_fake_ollama.py
```
