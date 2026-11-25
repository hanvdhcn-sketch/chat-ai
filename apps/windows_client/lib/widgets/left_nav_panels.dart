import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/attachment.dart';
import '../models/models.dart';
import '../services/config.dart';
import '../theme/app_theme.dart';
import 'right_panel.dart';

/// Shared Orbita dialog chrome for left-nav destinations.
Future<T?> showOrbitaPanel<T>({
  required BuildContext context,
  required String title,
  required Widget child,
  double width = 520,
  double maxHeightFactor = 0.82,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * maxHeightFactor;
      return Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: width, maxHeight: maxH),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                      color: AppTheme.inkMuted,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(child: child),
            ],
          ),
        ),
      );
    },
  );
}

// ── Search Chats ────────────────────────────────────────────────────────────

Future<void> showSearchChatsPanel({
  required BuildContext context,
  required List<Conversation> conversations,
  required Map<String, String> snippets,
  required ValueChanged<Conversation> onSelect,
}) {
  return showOrbitaPanel(
    context: context,
    title: 'Search Chats',
    child: _SearchChatsBody(
      conversations: conversations,
      snippets: snippets,
      onSelect: (c) {
        Navigator.of(context).pop();
        onSelect(c);
      },
    ),
  );
}

class _SearchChatsBody extends StatefulWidget {
  const _SearchChatsBody({
    required this.conversations,
    required this.snippets,
    required this.onSelect,
  });

  final List<Conversation> conversations;
  final Map<String, String> snippets;
  final ValueChanged<Conversation> onSelect;

  @override
  State<_SearchChatsBody> createState() => _SearchChatsBodyState();
}

class _SearchChatsBodyState extends State<_SearchChatsBody> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<Conversation> get _filtered {
    final q = _query.text.trim().toLowerCase();
    if (q.isEmpty) return widget.conversations;
    return widget.conversations.where((c) {
      final snippet = (widget.snippets[c.id] ?? '').toLowerCase();
      return c.title.toLowerCase().contains(q) || snippet.contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _query,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Search by title or snippet…',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _query.clear();
                        setState(() {});
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    _query.text.trim().isEmpty
                        ? 'No chats yet'
                        : 'No matches for “${_query.text.trim()}”',
                    style: TextStyle(
                      color: AppTheme.inkMuted.withValues(alpha: 0.9),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, i) {
                    final c = items[i];
                    final snippet = widget.snippets[c.id];
                    return ListTile(
                      leading: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: AppTheme.accent,
                      ),
                      title: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        (snippet != null && snippet.isNotEmpty)
                            ? snippet
                            : _formatUpdated(c.updatedAt),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => widget.onSelect(c),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ── Library ─────────────────────────────────────────────────────────────────

Future<void> showLibraryPanel({
  required BuildContext context,
  required List<Conversation> conversations,
  required Map<String, String> snippets,
  required List<PendingAttachment> pendingAttachments,
  required ValueChanged<Conversation> onSelectChat,
  required ValueChanged<String> onApplyPrompt,
}) {
  return showOrbitaPanel(
    context: context,
    title: 'Library',
    width: 560,
    child: _LibraryBody(
      conversations: conversations,
      snippets: snippets,
      pendingAttachments: pendingAttachments,
      onSelectChat: (c) {
        Navigator.of(context).pop();
        onSelectChat(c);
      },
      onApplyPrompt: (p) {
        Navigator.of(context).pop();
        onApplyPrompt(p);
      },
    ),
  );
}

class _LibraryBody extends StatelessWidget {
  const _LibraryBody({
    required this.conversations,
    required this.snippets,
    required this.pendingAttachments,
    required this.onSelectChat,
    required this.onApplyPrompt,
  });

  final List<Conversation> conversations;
  final Map<String, String> snippets;
  final List<PendingAttachment> pendingAttachments;
  final ValueChanged<Conversation> onSelectChat;
  final ValueChanged<String> onApplyPrompt;

  @override
  Widget build(BuildContext context) {
    final prompts = RightPanel.tools
        .where((t) => t.$3.isNotEmpty)
        .toList(growable: false);

    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(
            labelColor: AppTheme.accent,
            unselectedLabelColor: AppTheme.inkMuted,
            indicatorColor: AppTheme.accent,
            tabs: [
              Tab(text: 'Chats'),
              Tab(text: 'Prompts'),
              Tab(text: 'Attachments'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _LibraryChatsTab(
                  conversations: conversations,
                  snippets: snippets,
                  onSelect: onSelectChat,
                ),
                ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: prompts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 6),
                  itemBuilder: (context, i) {
                    final t = prompts[i];
                    return ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      leading: Icon(t.$1, color: AppTheme.accent),
                      title: Text(
                        t.$2,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        t.$3.trim(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.north_east_rounded, size: 16),
                      onTap: () => onApplyPrompt(t.$3),
                    );
                  },
                ),
                _LibraryAttachmentsTab(attachments: pendingAttachments),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LibraryChatsTab extends StatelessWidget {
  const _LibraryChatsTab({
    required this.conversations,
    required this.snippets,
    required this.onSelect,
  });

  final List<Conversation> conversations;
  final Map<String, String> snippets;
  final ValueChanged<Conversation> onSelect;

  @override
  Widget build(BuildContext context) {
    if (conversations.isEmpty) {
      return Center(
        child: Text(
          'No saved chats yet',
          style: TextStyle(color: AppTheme.inkMuted.withValues(alpha: 0.9)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final c = conversations[i];
        final snippet = snippets[c.id];
        return ListTile(
          leading: const Icon(Icons.folder_outlined, color: AppTheme.accent),
          title: Text(
            c.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            (snippet != null && snippet.isNotEmpty)
                ? snippet
                : _formatUpdated(c.updatedAt),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => onSelect(c),
        );
      },
    );
  }
}

class _LibraryAttachmentsTab extends StatelessWidget {
  const _LibraryAttachmentsTab({required this.attachments});

  final List<PendingAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Text(
          'No pending attachments in the composer.\n'
          'Drop or pick files while chatting — they stay local to this session '
          '(no cloud library sync yet).',
          style: TextStyle(
            color: AppTheme.inkMuted.withValues(alpha: 0.95),
            height: 1.4,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: attachments.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) {
        final a = attachments[i];
        final isImage = a.kind == AttachmentKind.image;
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            side: const BorderSide(color: AppTheme.border),
          ),
          leading: Icon(
            isImage ? Icons.image_outlined : Icons.insert_drive_file_outlined,
            color: AppTheme.accent,
          ),
          title: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            isImage ? 'Image · pending send' : 'File · pending send',
          ),
        );
      },
    );
  }
}

// ── Tools ───────────────────────────────────────────────────────────────────

Future<void> showToolsPanel({
  required BuildContext context,
  required ValueChanged<String> onQuickTool,
}) {
  return showOrbitaPanel(
    context: context,
    title: 'Quick Tools',
    width: 480,
    child: _ToolsBody(
      onQuickTool: (prompt) {
        Navigator.of(context).pop();
        onQuickTool(prompt);
      },
    ),
  );
}

class _ToolsBody extends StatelessWidget {
  const _ToolsBody({required this.onQuickTool});

  final ValueChanged<String> onQuickTool;

  @override
  Widget build(BuildContext context) {
    final tools =
        RightPanel.tools.where((t) => t.$3.isNotEmpty).toList(growable: false);
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.55,
      ),
      itemCount: tools.length,
      itemBuilder: (context, i) {
        final t = tools[i];
        return Material(
          color: AppTheme.mist,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: InkWell(
            onTap: () => onQuickTool(t.$3),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(t.$1, color: AppTheme.accent, size: 22),
                  const Spacer(),
                  Text(
                    t.$2,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Insert into composer',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppTheme.inkMuted.withValues(alpha: 0.95),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Settings ────────────────────────────────────────────────────────────────

class SettingsPanelArgs {
  const SettingsPanelArgs({
    required this.localeCode,
    required this.onToggleLocale,
    required this.onClearLocalData,
    required this.onOpenAbout,
    required this.showUpgrade,
    required this.billingBusy,
    required this.onUpgrade,
    required this.onRestorePurchases,
    required this.apiBaseUrl,
  });

  final String localeCode;
  final VoidCallback onToggleLocale;
  final Future<void> Function() onClearLocalData;
  final VoidCallback onOpenAbout;
  final bool showUpgrade;
  final bool billingBusy;
  final VoidCallback onUpgrade;
  final Future<void> Function() onRestorePurchases;
  final String apiBaseUrl;
}

Future<void> showSettingsPanel({
  required BuildContext context,
  required SettingsPanelArgs args,
}) {
  return showOrbitaPanel(
    context: context,
    title: AppLocalizations.of(context).settings,
    width: 520,
    child: _SettingsBody(args: args),
  );
}

class _SettingsBody extends StatefulWidget {
  const _SettingsBody({required this.args});

  final SettingsPanelArgs args;

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  bool _clearing = false;
  bool _restoring = false;
  late String _localeCode;

  @override
  void initState() {
    super.initState();
    _localeCode = widget.args.localeCode;
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final args = widget.args;
    final isVi = _localeCode == 'vi';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      children: [
        _SettingsSection(
          title: 'API',
          child: _SettingsTile(
            icon: Icons.link_rounded,
            title: 'API base URL',
            subtitle: args.apiBaseUrl,
            trailing: IconButton(
              tooltip: 'Copy',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: args.apiBaseUrl));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('API URL copied'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              icon: const Icon(Icons.copy_rounded, size: 18),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 8, bottom: 12),
          child: Text(
            'Set at build time via --dart-define=API_BASE_URL=… '
            '(default ${AppConfig.apiBaseUrl}). Restart required to change.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.inkMuted.withValues(alpha: 0.95),
              height: 1.35,
            ),
          ),
        ),
        _SettingsSection(
          title: loc.language,
          child: _SettingsTile(
            icon: Icons.language_rounded,
            title: isVi ? 'Tiếng Việt' : 'English',
            subtitle: isVi
                ? 'Đổi sang English'
                : 'Switch to Tiếng Việt',
            trailing: FilledButton.tonal(
              onPressed: () {
                args.onToggleLocale();
                setState(() {
                  _localeCode = _localeCode == 'en' ? 'vi' : 'en';
                });
              },
              child: Text(isVi ? 'EN' : 'VI'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        const _SettingsSection(
          title: 'Theme',
          child: _SettingsTile(
            icon: Icons.light_mode_outlined,
            title: 'Light',
            subtitle: 'Orbita Windows uses the light Fluent theme for now.',
          ),
        ),
        const SizedBox(height: 14),
        _SettingsSection(
          title: 'Billing',
          child: Column(
            children: [
              if (args.showUpgrade)
                _SettingsTile(
                  icon: Icons.workspace_premium_rounded,
                  title: loc.upgradePro,
                  subtitle: loc.storePurchaseHint,
                  trailing: FilledButton(
                    onPressed: args.billingBusy ? null : args.onUpgrade,
                    child: Text(args.billingBusy ? '…' : 'Go Pro'),
                  ),
                ),
              _SettingsTile(
                icon: Icons.restore_rounded,
                title: loc.restorePurchases,
                subtitle: 'Re-check Microsoft Store Pro license',
                trailing: TextButton(
                  onPressed: _restoring
                      ? null
                      : () async {
                          setState(() => _restoring = true);
                          try {
                            await args.onRestorePurchases();
                          } finally {
                            if (mounted) setState(() => _restoring = false);
                          }
                        },
                  child: Text(_restoring ? '…' : 'Restore'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        _SettingsSection(
          title: 'Data',
          child: _SettingsTile(
            icon: Icons.delete_outline_rounded,
            title: 'Clear local data',
            subtitle:
                'Reset stored auth token and local chat list on this device. '
                'Server chats (if any) are not deleted.',
            trailing: TextButton(
              onPressed: _clearing
                  ? null
                  : () async {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear local data?'),
                          content: const Text(
                            'This resets the local auth token and clears the '
                            'in-memory chat list. Continue?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Clear'),
                            ),
                          ],
                        ),
                      );
                      if (ok != true || !mounted) return;
                      setState(() => _clearing = true);
                      try {
                        await args.onClearLocalData();
                        if (!context.mounted) return;
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Local data cleared'),
                          ),
                        );
                      } finally {
                        if (mounted) setState(() => _clearing = false);
                      }
                    },
              child: Text(
                _clearing ? '…' : 'Clear',
                style: const TextStyle(color: Color(0xFFDC2626)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _SettingsSection(
          title: 'About',
          child: _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: AppTheme.brandName,
            subtitle: 'Version 0.1.0 · Powered by xAI Grok',
            trailing: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                args.onOpenAbout();
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsSection extends StatelessWidget {
  const _SettingsSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: AppTheme.inkMuted.withValues(alpha: 0.9),
            ),
          ),
        ),
        Material(
          color: AppTheme.mist,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppTheme.accent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle),
      trailing: trailing,
    );
  }
}

// ── About ───────────────────────────────────────────────────────────────────

Future<void> showAboutPanel(BuildContext context) {
  return showOrbitaPanel(
    context: context,
    title: 'About',
    width: 440,
    maxHeightFactor: 0.7,
    child: const _AboutBody(),
  );
}

class _AboutBody extends StatelessWidget {
  const _AboutBody();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      Color(0xFF60A5FA),
                      Color(0xFF2563EB),
                      Color(0xFF1E3A8A),
                    ],
                    center: Alignment(-0.2, -0.3),
                    radius: 0.95,
                  ),
                ),
                child: const Icon(
                  Icons.smart_toy_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppTheme.brandName,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.ink,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Version 0.1.0',
                      style: TextStyle(
                        color: AppTheme.inkMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Orbita is your AI assistant on Windows — chat with xAI Grok, '
            'attach files and images, and upgrade via Microsoft Store IAP. '
            'Free uses a lighter/cheaper Grok model; Pro uses the current '
            'strongest stable Grok (not permanently fixed to one version) '
            'plus higher quotas.',
            style: TextStyle(
              color: AppTheme.ink.withValues(alpha: 0.88),
              height: 1.45,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Powered by xAI Grok · Microsoft Store billing for Pro.',
            style: TextStyle(
              color: AppTheme.inkMuted.withValues(alpha: 0.95),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatUpdated(String iso) {
  if (iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return iso;
  final local = dt.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return 'Updated $y-$m-$d $hh:$mm';
}
