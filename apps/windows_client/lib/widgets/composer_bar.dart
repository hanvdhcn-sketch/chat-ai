import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  });

  final TextEditingController controller;
  final bool streaming;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final String hint;
  final VoidCallback? onAttach;

  @override
  State<ComposerBar> createState() => _ComposerBarState();
}

class _ComposerBarState extends State<ComposerBar> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _onComposerKeyEvent);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
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

    // Enter sends (same as Send button); skip empty / whitespace-only.
    if (!widget.streaming && widget.controller.text.trim().isNotEmpty) {
      widget.onSend();
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Container(
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
              onPressed: widget.onAttach,
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
            IconButton(
              tooltip: 'Web',
              onPressed: () {},
              icon: Icon(
                Icons.public_rounded,
                color: AppTheme.inkMuted.withValues(alpha: 0.85),
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppTheme.inkMuted.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 4),
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
                onPressed: () {
                  if (widget.controller.text.trim().isNotEmpty) {
                    widget.onSend();
                  }
                },
                style: IconButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  fixedSize: const Size(44, 44),
                ),
                icon: const Icon(Icons.send_rounded, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}
