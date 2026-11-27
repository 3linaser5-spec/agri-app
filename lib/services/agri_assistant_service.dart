import '../models/agri_assistant_models.dart';
import '../models/encyclopedia_model.dart';
import 'encyclopedia_service.dart';

/// مساعد زراعي يجاوب من محتوى موسوعة التطبيق نفسه (بحث بالكلمات المفتاحية).
///
/// لا يشخّص أمراضًا ولا يوصف علاجًا: أي سؤال عن مرض أو إصابة أو مبيد يُوجَّه
/// إلى ميزة فحص الآفات بالذكاء الاصطناعي.
class AgriAssistantService {
  AgriAssistantService._();

  static List<EncyclopediaItem>? _items;
  static Map<String, String> _sectionNames = const {};

  static const List<String> defaultQuestions = [
    'امتى أزرع الطماطم؟',
    'إزاي أحسب احتياج الري؟',
    'مواعيد التسميد',
    'تجهيز الأرض للزراعة',
  ];

  static const Set<String> _stopWords = {
    'من', 'في', 'على', 'عن', 'الى', 'إلى', 'مع', 'ايه', 'إيه', 'ما', 'ماذا',
    'كيف', 'ازاي', 'إزاي', 'امتى', 'متى', 'هل', 'هو', 'هي', 'ليه', 'لماذا',
    'افضل', 'أفضل', 'وقت', 'اوقات', 'أوقات', 'ممكن', 'عايز', 'عاوز', 'اريد',
    'أريد', 'عندي', 'عندى', 'انا', 'أنا', 'ازرع', 'أزرع', 'طريقة', 'طريقه',
    'اللي', 'التي', 'الذي', 'ولا', 'او', 'أو', 'يا',
  };

  static const List<String> _diagnosisKeywords = [
    'مرض', 'امراض', 'أمراض', 'علاج', 'مبيد', 'مبيدات', 'حشره', 'حشرة',
    'حشرات', 'افه', 'آفة', 'آفات', 'اصابه', 'إصابة', 'تعفن', 'ذبول', 'بقعه',
    'بقع', 'فطر', 'فطري', 'نيماتودا', 'اكاروس', 'أكاروس', 'اصفرار',
  ];

  static Future<void> ensureLoaded() async {
    if (_items != null) return;
    final sections = await EncyclopediaService.getSections();
    final names = <String, String>{};
    final items = <EncyclopediaItem>[];
    for (final section in sections) {
      names[section.id] = section.name;
      items.addAll(await EncyclopediaService.getItems(section.id));
    }
    _sectionNames = names;
    _items = items;
  }

  static Future<AgriAssistantReply> ask(String question) async {
    final text = question.trim();
    if (text.isEmpty) {
      return const AgriAssistantReply(
        text: 'اكتب سؤالك الأول عن الزراعة أو الري أو التسميد.',
        isNotice: true,
      );
    }
    if (_mentionsDiagnosis(text)) {
      return const AgriAssistantReply(
        text:
            'تشخيص الأمراض ووصف العلاج مسؤولية ميزة فحص الآفات بالذكاء الاصطناعي: '
            'صوّر النبات من هناك وهتاخد الاحتمالات وخطة العلاج المقترحة.\n'
            'أنا هنا للأسئلة الزراعية العامة: مواعيد الزراعة، الري، التسميد، '
            'تجهيز الأرض، التقليم، الحصاد والتخزين.',
        isNotice: true,
      );
    }

    await ensureLoaded();
    final items = _items ?? const <EncyclopediaItem>[];
    if (items.isEmpty) {
      return const AgriAssistantReply(
        text:
            'الموسوعة مش متاحة دلوقتي. اتأكد من الإنترنت وافتح شاشة الموسوعة مرة، '
            'وبعدها اسألني تاني.',
        isNotice: true,
      );
    }

    final tokens = _tokens(text);
    if (tokens.isEmpty) {
      return const AgriAssistantReply(
        text: 'وضّح سؤالك أكتر، مثلاً: مواعيد زراعة الطماطم أو احتياج الري.',
        suggestions: defaultQuestions,
        isNotice: true,
      );
    }

    final scored = <(EncyclopediaItem, int)>[];
    for (final item in items) {
      final score = _score(item, tokens);
      if (score > 0) scored.add((item, score));
    }
    scored.sort((a, b) => b.$2.compareTo(a.$2));

    if (scored.isEmpty) {
      return const AgriAssistantReply(
        text: 'مفيش موضوع مطابق في الموسوعة لكلامك. جرّب تسأل بكلمات أبسط:',
        suggestions: defaultQuestions,
        isNotice: true,
      );
    }

    final top = scored.take(3).toList(growable: false);
    final best = top.first.$1;
    final heading =
        best.subtitle.isEmpty ? best.title : '${best.title} — ${best.subtitle}';

    return AgriAssistantReply(
      text: '$heading\n\n${_summary(best)}',
      matches: [
        for (final entry in top)
          AgriAssistantMatch(
            title: entry.$1.title,
            subtitle: entry.$1.subtitle,
            content: entry.$1.content,
            sectionName: _sectionNames[entry.$1.sectionId] ?? '',
            sections: entry.$1.sections,
          ),
      ],
    );
  }

  static bool _mentionsDiagnosis(String text) {
    final normalized = _normalize(text);
    return _diagnosisKeywords
        .any((keyword) => normalized.contains(_normalize(keyword)));
  }

  static int _score(EncyclopediaItem item, List<String> tokens) {
    final title = _normalize(item.title);
    final subtitle = _normalize(item.subtitle);
    final body = _normalize([
      item.content,
      for (final section in item.sections)
        '${section['title'] ?? ''} ${section['content'] ?? ''}',
    ].join(' '));
    var score = 0;
    for (final token in tokens) {
      if (title.contains(token)) score += 6;
      if (subtitle.contains(token)) score += 3;
      if (body.contains(token)) score += 1;
    }
    return score;
  }

  static String _summary(EncyclopediaItem item) {
    final paragraphs = item.content
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .take(2)
        .join('\n');
    if (paragraphs.isEmpty) {
      return item.subtitle.isEmpty
          ? 'تفاصيل الموضوع متاحة في الموسوعة.'
          : item.subtitle;
    }
    if (paragraphs.length <= 480) return paragraphs;
    return '${paragraphs.substring(0, 480)}…';
  }

  static List<String> _tokens(String text) {
    final normalized = _normalize(text);
    final parts = normalized
        .split(RegExp(r'[^\u0621-\u064Aa-z0-9]+'))
        .map((part) => part.trim())
        .where((part) => part.length >= 2 && !_stopWords.contains(part))
        .toList(growable: false);
    return parts.toSet().toList(growable: false);
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp(r'[\u0623\u0625\u0622\u0671]'), 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .trim();
}
