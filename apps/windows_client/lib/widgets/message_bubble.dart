import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'model_catalog.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.modelLabel = 'GPT-6',
  });

  final ChatMessage message;
  final String modelLabel;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    if (isUser) return _UserBubble(content: message.content);
    return _AssistantBlock(
      content: message.content.isEmpty && message.status == 'streaming'
          ? '…'
          : message.content,
      modelLabel: modelLabel,
      streaming: message.status == 'streaming',
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.content});

  final String content;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 560),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.userBubble,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(
                  content,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    height: 1.45,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            const CircleAvatar(
              radius: 14,
              backgroundColor: Color(0xFF93C5FD),
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssistantBlock extends StatelessWidget {
  const _AssistantBlock({
    required this.content,
    required this.modelLabel,
    required this.streaming,
  });

  final String content;
  final String modelLabel;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final model = kUiModels.firstWhere(
      (m) => m.label == modelLabel,
      orElse: () => kUiModels.first,
    );

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: model.color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(model.icon, size: 16, color: model.color),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: _RichAssistantBody(content: content)),
                ],
              ),
              if (!streaming) ...[
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.only(left: 40),
                  child: Row(
                    children: [
                      _ActionIcon(
                        icon: Icons.thumb_up_alt_outlined,
                        onTap: () {},
                      ),
                      _ActionIcon(
                        icon: Icons.thumb_down_alt_outlined,
                        onTap: () {},
                      ),
                      _ActionIcon(
                        icon: Icons.copy_rounded,
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: content));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Copied'),
                              duration: Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                      _ActionIcon(icon: Icons.more_horiz, onTap: () {}),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      color: AppTheme.inkMuted,
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.all(6),
      constraints: const BoxConstraints(),
    );
  }
}

/// Lightweight rich renderer: **bold**, numbered stages, green checks.
class _RichAssistantBody extends StatelessWidget {
  const _RichAssistantBody({required this.content});

  final String content;

  static const _stageColors = <Color>[
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFF16A34A),
    Color(0xFFEA580C),
    Color(0xFF0891B2),
    Color(0xFFDB2777),
  ];

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n');
    final children = <Widget>[];

    for (final raw in lines) {
      final line = raw.trimRight();
      if (line.isEmpty) {
        children.add(const SizedBox(height: 6));
        continue;
      }

      final stage = RegExp(r'^(\d+)[\.\)]\s+(.+)$').firstMatch(line);
      if (stage != null) {
        final n = int.tryParse(stage.group(1)!) ?? 1;
        final color = _stageColors[(n - 1) % _stageColors.length];
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$n',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _InlineMarkdown(stage.group(2)!)),
              ],
            ),
          ),
        );
        continue;
      }

      if (line.startsWith('- ') || line.startsWith('• ')) {
        children.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2, bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: _InlineMarkdown(line.substring(2))),
              ],
            ),
          ),
        );
        continue;
      }

      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _InlineMarkdown(line),
        ),
      );
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _InlineMarkdown extends StatelessWidget {
  const _InlineMarkdown(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    var start = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > start) {
        spans.add(TextSpan(text: text.substring(start, m.start)));
      }
      spans.add(
        TextSpan(
          text: m.group(1),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      );
      start = m.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start)));
    }

    return Text.rich(
      TextSpan(
        style: const TextStyle(
          color: AppTheme.ink,
          height: 1.5,
          fontSize: 14.5,
        ),
        children: spans.isEmpty ? [TextSpan(text: text)] : spans,
      ),
    );
  }
}
