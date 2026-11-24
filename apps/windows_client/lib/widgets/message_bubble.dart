import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';
import 'model_catalog.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    this.modelLabel = 'Grok',
  });

  final ChatMessage message;
  final String modelLabel;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == 'user';
    if (isUser) {
      return _UserBubble(
        content: message.content,
        images: message.images,
      );
    }
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
  const _UserBubble({
    required this.content,
    this.images = const [],
  });

  final String content;
  final List<MessageImageThumb> images;

  @override
  Widget build(BuildContext context) {
    final hasText = content.trim().isNotEmpty;
    final hasImages = images.isNotEmpty;

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
                padding: EdgeInsets.symmetric(
                  horizontal: hasImages && !hasText ? 10 : 16,
                  vertical: hasImages && !hasText ? 10 : 12,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.userBubble,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (hasImages)
                      _ImageThumbRow(images: images),
                    if (hasImages && hasText) const SizedBox(height: 8),
                    if (hasText)
                      SelectableText(
                        content,
                        style: const TextStyle(
                          color: AppTheme.ink,
                          height: 1.45,
                          fontSize: 14.5,
                        ),
                      ),
                  ],
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

class _ImageThumbRow extends StatelessWidget {
  const _ImageThumbRow({required this.images});

  final List<MessageImageThumb> images;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final image in images) _ImageThumb(image: image),
      ],
    );
  }
}

class _ImageThumb extends StatelessWidget {
  const _ImageThumb({required this.image});

  final MessageImageThumb image;

  void _openFullView(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.72),
      builder: (ctx) => _ImageFullViewDialog(image: image),
    );
  }

  @override
  Widget build(BuildContext context) {
    final preview = _buildPreview();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _openFullView(context),
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: preview,
        ),
      ),
    );
  }

  Widget _buildPreview() {
    if (image.bytes != null && image.bytes!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          image.bytes!,
          width: 168,
          height: 126,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _FallbackThumb(name: image.name),
        ),
      );
    }

    final path = image.path;
    if (path != null && path.isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            file,
            width: 168,
            height: 126,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _FallbackThumb(name: image.name),
          ),
        );
      }
    }

    return _FallbackThumb(name: image.name);
  }
}

class _FallbackThumb extends StatelessWidget {
  const _FallbackThumb({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 168,
      height: 126,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 28,
              color: AppTheme.inkMuted.withValues(alpha: 0.9),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.inkMuted,
                height: 1.25,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageFullViewDialog extends StatelessWidget {
  const _ImageFullViewDialog({required this.image});

  final MessageImageThumb image;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900, maxHeight: 700),
        child: Material(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 8, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        image.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Center(child: _fullImage()),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fullImage() {
    if (image.bytes != null && image.bytes!.isNotEmpty) {
      return Image.memory(
        image.bytes!,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _missing(),
      );
    }
    final path = image.path;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return Image.file(
        File(path),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _missing(),
      );
    }
    return _missing();
  }

  Widget _missing() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, size: 40, color: AppTheme.inkMuted),
          const SizedBox(height: 12),
          Text(
            'Preview unavailable for ${image.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.inkMuted),
          ),
        ],
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
