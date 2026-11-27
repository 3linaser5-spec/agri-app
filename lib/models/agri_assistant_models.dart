/// نماذج شاشة المساعد الزراعي (محادثة + نتائج من الموسوعة).
library;

/// رسالة داخل المحادثة.
class AgriAssistantMessage {
  const AgriAssistantMessage({
    required this.text,
    required this.isUser,
    this.matches = const [],
    this.suggestions = const [],
    this.isNotice = false,
  });

  final String text;
  final bool isUser;
  final List<AgriAssistantMatch> matches;
  final List<String> suggestions;

  /// رد تنبيهي (توجيه لفحص الآفات أو لا توجد نتيجة).
  final bool isNotice;
}

/// موضوع من الموسوعة مطابق للسؤال.
class AgriAssistantMatch {
  const AgriAssistantMatch({
    required this.title,
    required this.subtitle,
    required this.content,
    required this.sectionName,
    this.sections = const [],
  });

  final String title;
  final String subtitle;
  final String content;
  final String sectionName;
  final List<Map<String, String>> sections;
}

/// رد المساعد على سؤال واحد.
class AgriAssistantReply {
  const AgriAssistantReply({
    required this.text,
    this.matches = const [],
    this.suggestions = const [],
    this.isNotice = false,
  });

  final String text;
  final List<AgriAssistantMatch> matches;
  final List<String> suggestions;
  final bool isNotice;
}
