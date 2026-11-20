import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/attachment.dart';
import '../theme/app_theme.dart';

class ComposerBar extends StatefulWidget {
  const ComposerBar({
    super.key,
    required this.controller,
    required this.streaming,
    required this.onSend,
    required this.onStop,
    this.hint = 'Type a message...',
    this.onAttach,
    this.attachments = const [],
    this.onRemoveAttachment,
  });

  final TextEditingController controller;
  final bool streaming;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final String hint;
  final VoidCallback? onAttach;
  final List<PendingAttachment> attachments;
  final ValueChanged<String>? onRemoveAttachment;

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _onComposerKeyEvent);
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  bool get _canSend {
    if (widget.streaming) return false;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final hasReady = widget.attachments.any((a) => a.isSendable);
    return hasText || hasReady;
  }

  KeyEventResult _onComposerKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }

    final isEnter = event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter;
    if (!isEnter) {
      return KeyEventResult.ignored;
    }

    // Let IME finish composition (e.g. Vietnamese, Japanese) before sending.
    if (widget.controller.value.isComposingRangeValid) {
      return KeyEventResult.ignored;
    }

    // Shift+Enter inserts a newline via default TextField behavior.
    if (HardwareKeyboard.instance.isShiftPressed) {
      return KeyEventResult.ignored;
    }

    // Enter sends (same as Send button); skip empty / no attachments.
    if (_canSend) {
      widget.onSend();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.attachments.isNotEmpty) ...[
            _AttachmentChipRow(
              attachments: widget.attachments,
              onRemove: widget.onRemoveAttachment,
            ),
            const SizedBox(height: 8),
          ],
          Container(
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: AppTheme.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Attach',
                  onPressed: widget.streaming ? null : widget.onAttach,
                  icon: Icon(
                    Icons.attach_file_rounded,
                    color: AppTheme.inkMuted.withValues(alpha: 0.9),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    enabled: !widget.streaming,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 14.5, height: 1.4),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                if (widget.streaming)
                  IconButton.filled(
                    onPressed: widget.onStop,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.stop_rounded),
                  )
                else
                  IconButton.filled(
                    onPressed: _canSend ? widget.onSend : null,
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.accent,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppTheme.accent.withValues(alpha: 0.4),
                      fixedSize: const Size(44, 44),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 20),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentChipRow extends StatelessWidget {
  const _AttachmentChipRow({
    required this.attachments,
    this.onRemove,
  });

  final List<PendingAttachment> attachments;
  final ValueChanged<String>? onRemove;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final a in attachments) ...[
            _AttachmentChip(
              attachment: a,
              onRemove: onRemove == null ? null : () => onRemove!(a.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({
    required this.attachment,
    this.onRemove,
  });

  final PendingAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final a = attachment;
    final isBad = a.kind == AttachmentKind.unsupported;
    final border = isBad ? const Color(0xFFFECACA) : AppTheme.border;
    final bg = isBad ? const Color(0xFFFEF2F2) : AppTheme.mist;

    Widget leading;
    if (a.kind == AttachmentKind.image && a.imageBytes != null) {
      leading = ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.memory(
          a.imageBytes!,
          width: 36,
          height: 36,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 20),
        ),
      );
    } else if (a.kind == AttachmentKind.text) {
      leading = Icon(Icons.description_outlined, size: 20, color: AppTheme.inkMuted);
    } else {
      leading = const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFDC2626));
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  a.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (a.notice != null)
                  Text(
                    a.notice!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: isBad
                          ? const Color(0xFF991B1B)
                          : AppTheme.inkMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (onRemove != null)
            IconButton(
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onRemove,
              icon: Icon(Icons.close, size: 16, color: AppTheme.inkMuted),
            ),
        ],
      ),
    );
  }
}
