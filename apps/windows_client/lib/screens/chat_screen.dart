import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/free_badge.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late final ApiClient _api;
  List<Conversation> _conversations = [];
  Conversation? _active;
  List<ChatMessage> _messages = [];
  UsageSnapshot? _usage;
  bool _busy = false;
  String? _error;
  Locale _localeOverride = const Locale('en');

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _api = ApiClient(getToken: () async => auth.accessToken);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    try {
      final convos = await _api.listConversations();
      final usage = await _api.getUsage();
      setState(() {
        _conversations = convos;
        _usage = usage;
        _error = null;
      });
      if (convos.isNotEmpty) {
        await _openConversation(convos.first);
      }
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _openConversation(Conversation c) async {
    setState(() {
      _active = c;
      _busy = true;
    });
    try {
      final msgs = await _api.listMessages(c.id);
      setState(() {
        _messages = msgs;
        _busy = false;
      });
      _scrollToEnd();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _newChat() async {
    setState(() => _busy = true);
    try {
      final c = await _api.createConversation();
      setState(() {
        _conversations = [c, ..._conversations];
        _active = c;
        _messages = [];
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _busy) return;

    var conversation = _active;
    if (conversation == null) {
      await _newChat();
      conversation = _active;
      if (conversation == null) return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _messages = [
        ..._messages,
        ChatMessage(id: 'local_user', role: 'user', content: text),
        ChatMessage(
          id: 'local_assistant',
          role: 'assistant',
          content: '',
          status: 'streaming',
        ),
      ];
      _input.clear();
    });
    _scrollToEnd();

    try {
      await for (final event in _api.streamMessage(
        conversationId: conversation.id,
        content: text,
      )) {
        final type = event['type'] as String?;
        if (type == 'delta') {
          final delta = event['text'] as String? ?? '';
          setState(() {
            final last = _messages.last;
            last.content = '${last.content}$delta';
          });
          _scrollToEnd();
        } else if (type == 'done') {
          setState(() {
            _messages.last.status = 'complete';
            _messages.last.model = event['model'] as String?;
          });
        } else if (type == 'error') {
          setState(() {
            _messages.last.status = 'error';
            _messages.last.content =
                event['error'] as String? ?? 'stream error';
          });
        }
      }
      final usage = await _api.getUsage();
      final convos = await _api.listConversations();
      setState(() {
        _usage = usage;
        _conversations = convos;
        _busy = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _busy = false;
        if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
          _messages.last.status = 'error';
          _messages.last.content = e.toString();
        }
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final showBadge = auth.user?.showPoweredBy ?? true;

    return Localizations.override(
      context: context,
      locale: _localeOverride,
      child: Builder(
        builder: (context) {
          final loc = AppLocalizations.of(context);
          return Scaffold(
            body: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFECFEFF),
                    Color(0xFFF1F5F9),
                    Color(0xFFE2E8F0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  _Sidebar(
                    conversations: _conversations,
                    activeId: _active?.id,
                    onNew: _newChat,
                    onSelect: _openConversation,
                    usage: _usage,
                    showBadge: showBadge,
                    onToggleLocale: () {
                      setState(() {
                        _localeOverride = _localeOverride.languageCode == 'en'
                            ? const Locale('vi')
                            : const Locale('en');
                      });
                    },
                    onSwitchTier: (tier) async {
                      await auth.switchStubTier(tier);
                      await _bootstrap();
                    },
                    localeCode: _localeOverride.languageCode,
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        _Header(
                          title: _active?.title ?? loc.appTitle,
                          plan: auth.user?.planTier ?? 'free',
                          showBadge: showBadge,
                        ),
                        if (_error != null)
                          Material(
                            color: const Color(0xFFFEE2E2),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                _error!,
                                style: const TextStyle(color: Color(0xFF991B1B)),
                              ),
                            ),
                          ),
                        Expanded(
                          child: _messages.isEmpty
                              ? Center(
                                  child: Text(
                                    loc.emptyChat,
                                    style: TextStyle(
                                      color: AppTheme.ink.withValues(alpha: 0.45),
                                      fontSize: 16,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  controller: _scroll,
                                  padding: const EdgeInsets.fromLTRB(
                                    28,
                                    16,
                                    28,
                                    16,
                                  ),
                                  itemCount: _messages.length,
                                  itemBuilder: (context, i) =>
                                      MessageBubble(message: _messages[i]),
                                ),
                        ),
                        _Composer(
                          controller: _input,
                          busy: _busy,
                          onSend: _send,
                          hint: loc.messageHint,
                          sendLabel: loc.send,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.plan,
    required this.showBadge,
  });

  final String title;
  final String plan;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 8),
      child: Row(
        children: [
          Text(
            AppTheme.brandName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.ink.withValues(alpha: 0.55),
              ),
            ),
          ),
          FreeBadge(visible: showBadge),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: plan == 'pro'
                  ? AppTheme.teal.withValues(alpha: 0.15)
                  : AppTheme.ink.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              plan == 'pro' ? l10n.proPlan : l10n.freePlan,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.conversations,
    required this.activeId,
    required this.onNew,
    required this.onSelect,
    required this.usage,
    required this.showBadge,
    required this.onToggleLocale,
    required this.onSwitchTier,
    required this.localeCode,
  });

  final List<Conversation> conversations;
  final String? activeId;
  final VoidCallback onNew;
  final ValueChanged<Conversation> onSelect;
  final UsageSnapshot? usage;
  final bool showBadge;
  final VoidCallback onToggleLocale;
  final ValueChanged<String> onSwitchTier;
  final String localeCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Container(
      width: 280,
      decoration: const BoxDecoration(
        color: Color(0xCCFFFFFF),
        border: Border(right: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: FilledButton.icon(
              onPressed: onNew,
              icon: const Icon(Icons.add, size: 18),
              label: Text(l10n.newChat),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              l10n.conversations,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.ink.withValues(alpha: 0.5),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: conversations.length,
              itemBuilder: (context, i) {
                final c = conversations[i];
                final selected = c.id == activeId;
                return ListTile(
                  dense: true,
                  selected: selected,
                  selectedTileColor: AppTheme.teal.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  title: Text(
                    c.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => onSelect(c),
                );
              },
            ),
          ),
          if (usage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(
                l10n.usageRemaining(usage!.remaining),
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
          if (showBadge)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: OutlinedButton(
                onPressed: () {
                  // Open Stripe Checkout via system browser (API /v1/billing/checkout).
                },
                child: Text(l10n.upgradePro),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Row(
              children: [
                TextButton(
                  onPressed: onToggleLocale,
                  child: Text('${l10n.language}: ${localeCode.toUpperCase()}'),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  tooltip: 'Stub tier',
                  onSelected: onSwitchTier,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'free', child: Text('Stub Free')),
                    PopupMenuItem(value: 'pro', child: Text('Stub Pro')),
                  ],
                  child: const Icon(Icons.manage_accounts_outlined, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
    required this.hint,
    required this.sendLabel,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onSend;
  final String hint;
  final String sendLabel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              enabled: !busy,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(hintText: hint),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton(
            onPressed: busy ? null : onSend,
            child: Text(sendLabel),
          ),
        ],
      ),
    );
  }
}
