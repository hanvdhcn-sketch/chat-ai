import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/app_theme.dart';

typedef QuickToolHandler = void Function(String prompt);

class RightPanel extends StatelessWidget {
  const RightPanel({
    super.key,
    required this.conversations,
    required this.activeId,
    required this.onSelect,
    required this.onQuickTool,
    required this.onSeeAll,
    this.onMoreTools,
  });

  final List<Conversation> conversations;
  final String? activeId;
  final ValueChanged<Conversation> onSelect;
  final QuickToolHandler onQuickTool;
  final VoidCallback onSeeAll;
  /// Opens the full tools panel (left-nav Tools). Defaults to [onSeeAll].
  final VoidCallback? onMoreTools;

  static const tools = <(IconData, String, String)>[
    (Icons.description_outlined, 'Summarize Text', 'Summarize the following text: '),
    (Icons.mail_outline_rounded, 'Write Email', 'Help me write a professional email about: '),
    (Icons.translate_rounded, 'Translate', 'Translate the following to English: '),
    (Icons.code_rounded, 'Explain Code', 'Explain this code step by step: '),
    (Icons.image_outlined, 'Create Image', 'Describe an image I can generate for: '),
    (Icons.flight_takeoff_rounded, 'Plan Trip', 'Help me plan a trip to: '),
    (Icons.school_outlined, 'Study Helper', 'Create a study plan for: '),
    (Icons.more_horiz_rounded, 'More Tools', ''),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      width: AppTheme.rightPanelWidth,
      color: AppTheme.mist,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  color: Color(0xFFFBBF24),
                  size: 20,
                ),
                const SizedBox(width: 6),
                Text(
                  'Quick Tools',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tools.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.35,
              ),
              itemBuilder: (context, i) {
                final t = tools[i];
                return _ToolCard(
                  icon: t.$1,
                  label: t.$2,
                  onTap: () {
                    if (t.$3.isEmpty) {
                      (onMoreTools ?? onSeeAll)();
                    } else {
                      onQuickTool(t.$3);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppTheme.ink.withValues(alpha: 0.55),
                ),
                const SizedBox(width: 6),
                Text(
                  'Recent Chats',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: onSeeAll,
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.accent,
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'See All >',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: conversations.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      'No chats yet',
                      style: TextStyle(color: AppTheme.inkMuted.withValues(alpha: 0.8)),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: conversations.length.clamp(0, 12),
                    itemBuilder: (context, i) {
                      final c = conversations[i];
                      final selected = c.id == activeId;
                      return _RecentTile(
                        title: c.title,
                        subtitle: _relativeTime(c.updatedAt),
                        selected: selected,
                        onTap: () => onSelect(c),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatefulWidget {
  const _ToolCard({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hover ? -1.5 : 0, 0),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hover ? 0.08 : 0.04),
              blurRadius: _hover ? 12 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(widget.icon, color: AppTheme.accent, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.ink,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? AppTheme.accentSoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 16,
                  color: selected ? AppTheme.accent : AppTheme.inkMuted,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: AppTheme.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.inkMuted.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _relativeTime(String iso) {
  if (iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final diff = DateTime.now().toUtc().difference(dt.toUtc());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.month}/${dt.day}';
}
