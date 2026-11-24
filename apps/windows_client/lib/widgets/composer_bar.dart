import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/attachment.dart';
import '../services/dictation_service.dart';
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
    this.localeCode = 'en',
    this.onDictationError,
  });

  final TextEditingController controller;
  final bool streaming;
  final VoidCallback onSend;
  final VoidCallback onStop;
  final String hint;
  final VoidCallback? onAttach;
  final List<PendingAttachment> attachments;
  final ValueChanged<String>? onRemoveAttachment;

  /// BCP-47 language hint for STT (`en`, `vi`).
  final String localeCode;

  /// Optional host callback for mic / STT failures (SnackBar, etc.).
  final ValueChanged<String>? onDictationError;

  @override
  State<ComposerBar> createState() => ComposerBarState();
}

class ComposerBarState extends State<ComposerBar> {
  late final FocusNode _focusNode;
  late final DictationService _dictation;
  bool _dictating = false;

  /// Text present before the current dictation session (partials replace after this).
  String _dictationPrefix = '';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(onKeyEvent: _onComposerKeyEvent);
    _dictation = DictationService();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void didUpdateWidget(ComposerBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // After a reply finishes, put the caret back in the composer.
    if (oldWidget.streaming && !widget.streaming) {
      requestFocus();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _dictation.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (mounted) setState(() {});
  }

  /// Focus the composer and place the caret at the end of current text.
  void requestFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final text = widget.controller.text;
      widget.controller.selection =
          TextSelection.collapsed(offset: text.length);
      _focusNode.requestFocus();
    });
  }

  bool get _canSend {
    if (widget.streaming) return false;
    final hasText = widget.controller.text.trim().isNotEmpty;
    final hasReady = widget.attachments.any((a) => a.isSendable);
    return hasText || hasReady;
  }

  void _sendAndKeepFocus() {
    if (!_canSend) return;
    widget.onSend();
    // Field stays enabled while streaming so focus can stick / return.
    requestFocus();
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
      _sendAndKeepFocus();
    }
    return KeyEventResult.handled;
  }

  Future<void> _toggleDictation() async {
    if (widget.streaming) return;
    if (_dictating) {
      await _stopDictation();
      return;
    }

    final existing = widget.controller.text;
    _dictationPrefix = existing.trimRight();
    if (_dictationPrefix.isNotEmpty && !_dictationPrefix.endsWith(' ')) {
      // Keep a space between typed text and the spoken segment.
      _dictationPrefix = '$_dictationPrefix ';
    }

    setState(() => _dictating = true);
    requestFocus();

    try {
      await _dictation.start(
        localeHint: widget.localeCode,
        onText: (text, {required isFinal}) {
          if (!mounted) return;
          final next = '$_dictationPrefix${text.trim()}';
          widget.controller.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
          if (isFinal) {
            // Commit this utterance; further finals append after it.
            _dictationPrefix = next.trimRight();
            if (_dictationPrefix.isNotEmpty) {
              _dictationPrefix = '$_dictationPrefix ';
            }
          }
        },
        onError: (msg) {
          if (!mounted) return;
          widget.onDictationError?.call(msg);
          _stopDictation();
        },
        onStatus: (status) {
          // speech_to_text reports "done" / "notListening" when the OS ends a pass.
          if (status == 'done' || status == 'notListening') {
            if (_dictating && mounted) {
              // Keep UI recording until the user taps stop; plugin may auto-stop.
              // If plugin stopped listening, flip UI off.
              if (!_dictation.isListening) {
                setState(() => _dictating = false);
              }
            }
          }
        },
      );
      if (mounted && !_dictation.isListening) {
        setState(() => _dictating = false);
      }
    } catch (e) {
      if (!mounted) return;
      widget.onDictationError?.call(e.toString());
      setState(() => _dictating = false);
    }
  }

  Future<void> _stopDictation() async {
    await _dictation.stop();
    if (mounted) {
      setState(() => _dictating = false);
      requestFocus();
    }
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
              border: Border.all(
                color: _dictating
                    ? const Color(0xFFEF4444).withValues(alpha: 0.55)
                    : AppTheme.border,
              ),
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
                IconButton(
                  tooltip: _dictating ? 'Stop dictation' : 'Voice dictation',
                  onPressed: widget.streaming ? null : _toggleDictation,
                  icon: Icon(
                    _dictating ? Icons.stop_circle_outlined : Icons.mic_none_rounded,
                    color: _dictating
                        ? const Color(0xFFEF4444)
                        : AppTheme.inkMuted.withValues(alpha: 0.9),
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 5,
                    // Keep enabled during streaming so focus survives Enter/send
                    // and the user can draft the next message while Grok replies.
                    enabled: true,
                    readOnly: false,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    style: const TextStyle(fontSize: 14.5, height: 1.4),
                    decoration: InputDecoration(
                      hintText: _dictating ? 'Listening…' : widget.hint,
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
                    onPressed: _canSend ? _sendAndKeepFocus : null,
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
