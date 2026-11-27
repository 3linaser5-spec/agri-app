import 'package:material_ui/material_ui.dart';

import '../../models/agri_assistant_models.dart';
import '../../services/agri_assistant_service.dart';

/// محادثة المساعد الزراعي: أسئلة عامة تُجاب من موسوعة التطبيق.
class AgriAssistantScreen extends StatefulWidget {
  const AgriAssistantScreen({super.key});

  @override
  State<AgriAssistantScreen> createState() => _AgriAssistantScreenState();
}

class _AgriAssistantScreenState extends State<AgriAssistantScreen> {
  static const Color _green = Color(0xFF047857);

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<AgriAssistantMessage> _messages = [
    const AgriAssistantMessage(
      text:
          'أهلًا بيك 👋 أنا المساعد الزراعي.\n'
          'اسألني عن الزراعة والري والتسميد وتجهيز الأرض والحصاد، وأنا أجاوبك من موسوعة التطبيق.\n'
          'تشخيص الأمراض ووصف العلاج في ميزة فحص الآفات بالذكاء الاصطناعي.',
      isUser: false,
    ),
  ];
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send(String question) async {
    final text = question.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _messages.add(AgriAssistantMessage(text: text, isUser: true));
      _busy = true;
    });
    _controller.clear();
    _scrollToEnd();
    try {
      final reply = await AgriAssistantService.ask(text);
      if (!mounted) return;
      setState(() {
        _messages.add(AgriAssistantMessage(
          text: reply.text,
          isUser: false,
          matches: reply.matches,
          suggestions: reply.suggestions,
          isNotice: reply.isNotice,
        ));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _messages.add(const AgriAssistantMessage(
          text: 'تعذر الوصول للموسوعة الآن. اتأكد من الإنترنت وحاول تاني.',
          isUser: false,
          isNotice: true,
        ));
      });
    } finally {
      if (mounted) setState(() => _busy = false);
      _scrollToEnd();
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('المساعد الزراعي',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: _messages.length + (_busy ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _messages.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return _buildMessage(_messages[index], isDark);
                },
              ),
            ),
            _buildSuggestions(),
            _buildInput(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage(AgriAssistantMessage message, bool isDark) {
    final isUser = message.isUser;
    final bubbleColor =
        isUser ? _green : (isDark ? const Color(0xFF1F2937) : Colors.white);
    final textColor = isUser
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF111827));
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: const BoxConstraints(maxWidth: 330),
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(14),
                border: isUser
                    ? null
                    : Border.all(color: _green.withValues(alpha: 0.18)),
              ),
              child: Text(
                message.text,
                style: TextStyle(fontSize: 13, height: 1.5, color: textColor),
              ),
            ),
            for (final match in message.matches)
              _buildMatchCard(match, isDark),
            if (message.suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final suggestion in message.suggestions)
                      ActionChip(
                        label: Text(suggestion,
                            style: const TextStyle(fontSize: 11)),
                        onPressed: () => _send(suggestion),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchCard(AgriAssistantMatch match, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showMatchDetails(match),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _green.withValues(alpha: 0.22)),
          ),
          child: Row(
            children: [
              const Icon(Icons.menu_book, size: 16, color: _green),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      match.title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF064E3B),
                      ),
                    ),
                    if (match.sectionName.isNotEmpty)
                      Text(
                        match.sectionName,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white60 : Colors.black54,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, size: 16, color: _green),
            ],
          ),
        ),
      ),
    );
  }

  void _showMatchDetails(AgriAssistantMatch match) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(match.title, style: const TextStyle(fontSize: 15)),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: [
                  if (match.subtitle.isNotEmpty)
                    Text(
                      match.subtitle,
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  if (match.content.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      match.content,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                  for (final section in match.sections) ...[
                    const SizedBox(height: 10),
                    Text(
                      section['title'] ?? '',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      section['content'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSuggestions() {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: AgriAssistantService.defaultQuestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final question = AgriAssistantService.defaultQuestions[index];
          return ActionChip(
            label: Text(question, style: const TextStyle(fontSize: 11)),
            onPressed: _busy ? null : () => _send(question),
          );
        },
      ),
    );
  }

  Widget _buildInput(bool isDark) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          border: Border(
            top: BorderSide(color: _green.withValues(alpha: 0.15)),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.send,
                onSubmitted: _send,
                decoration: const InputDecoration(
                  hintText: 'اكتب سؤالك الزراعي...',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _busy ? null : () => _send(_controller.text),
              style: IconButton.styleFrom(backgroundColor: _green),
              icon: const Icon(Icons.send, color: Colors.white, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}
