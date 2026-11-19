import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ComposerBar extends StatelessWidget {
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
              onPressed: onAttach,
              icon: Icon(
                Icons.attach_file_rounded,
                color: AppTheme.inkMuted.withValues(alpha: 0.9),
              ),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 5,
                enabled: !streaming,
                onSubmitted: (_) {
                  if (!streaming) onSend();
                },
                style: const TextStyle(fontSize: 14.5, height: 1.4),
                decoration: InputDecoration(
                  hintText: hint,
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
            if (streaming)
              IconButton.filled(
                onPressed: onStop,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.stop_rounded),
              )
            else
              IconButton.filled(
                onPressed: onSend,
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
