import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import '../services/store_billing.dart';
import '../theme/app_theme.dart';
import '../widgets/composer_bar.dart';
import '../widgets/left_nav.dart';
import '../widgets/message_bubble.dart';
import '../widgets/model_catalog.dart';
import '../widgets/right_panel.dart';

/// Sample conversation shown when the API has no messages (visual match to mockup).
const _sampleUser =
    'Hãy lập kế hoạch học tập để trở thành SysAdmin chuyên nghiệp trong 6 tháng';

const _sampleAssistant = '''
Dưới đây là **lộ trình 6 tháng** để trở thành SysAdmin chuyên nghiệp:

1. **Nền tảng (Tháng 1–2)**
- Linux cơ bản, shell, networking
- Virtualization & containers (Docker)

2. **Hạ tầng (Tháng 3–4)**
- Windows Server, Active Directory
- Monitoring, backup, security cơ bản

3. **Automation (Tháng 5)**
- Bash/PowerShell scripting
- Ansible / CI cơ bản

4. **Thực chiến (Tháng 6)**
- Lab home + dự án portfolio
- Review kiến thức & interview prep

Bạn muốn mình chi tiết hóa tuần đầu tiên không?
''';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  late final ApiClient _api;
  late final StoreBillingService _storeBilling;
  List<Conversation> _conversations = [];
  Conversation? _active;
  List<ChatMessage> _messages = [];
  UsageSnapshot? _usage;
  bool _busy = false;
  bool _streaming = false;
  bool _billingBusy = false;
  bool _showSample = true;
  String? _error;
  Locale _localeOverride = const Locale('en');

  Future<void> Function()? _cancelStream;
  StreamSubscription<Map<String, dynamic>>? _streamSub;

  UiModel get _selectedModel => kGrokModel;

  List<ChatMessage> get _displayMessages {
    if (_messages.isNotEmpty) return _messages;
    if (_showSample) {
      return [
        ChatMessage(id: 'sample_u', role: 'user', content: _sampleUser),
        ChatMessage(
          id: 'sample_a',
          role: 'assistant',
          content: _sampleAssistant,
          model: _selectedModel.runtimeHint,
        ),
      ];
    }
    return const [];
  }

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthService>();
    _api = ApiClient(getToken: () async => auth.accessToken);
    _storeBilling = StoreBillingService(api: _api);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _upgradePro() async {
    if (_billingBusy) return;
    setState(() {
      _billingBusy = true;
      _error = null;
    });
    try {
      final result = await _storeBilling.purchasePro();
      final auth = context.read<AuthService>();
      await auth.refreshMe();
      await _bootstrap();
      if (!mounted) return;
      final loc = AppLocalizations.of(context);
      final msg = result.ok
          ? (result.stub
              ? loc.storeStubHint
              : 'Pro (${result.planTier}) — ${result.status}')
          : (result.message ?? result.status);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      if (!result.ok && result.status != 'cancelled') {
        setState(() => _error = result.message ?? result.status);
      }
    } catch (e) {
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _billingBusy = false);
    }
  }

  Future<void> _bootstrap() async {
    try {
      final convos = await _api.listConversations();
      final usage = await _api.getUsage();
      setState(() {
        _conversations = convos.isEmpty ? _demoConversations() : convos;
        _usage = usage;
        _error = null;
      });
      if (convos.isNotEmpty) {
        await _openConversation(convos.first);
      } else if (_conversations.isNotEmpty) {
        setState(() {
          _active = _conversations.first;
          _showSample = true;
          _messages = [];
        });
      }
    } catch (e) {
      // Offline / API down — still show mockup UI with sample content.
      setState(() {
        _conversations = _demoConversations();
        _active = _conversations.first;
        _showSample = true;
        _messages = [];
        _error = null;
      });
    }
  }

  List<Conversation> _demoConversations() {
    final now = DateTime.now().toUtc();
    return [
      Conversation(
        id: 'demo_1',
        title: 'Kế hoạch học tập SysAdmin',
        modelDefault: 'grok',
        updatedAt: now.subtract(const Duration(minutes: 2)).toIso8601String(),
      ),
      Conversation(
        id: 'demo_2',
        title: 'Refactor Flutter Windows UI',
        modelDefault: 'grok',
        updatedAt: now.subtract(const Duration(hours: 1)).toIso8601String(),
      ),
      Conversation(
        id: 'demo_3',
        title: 'Microsoft Store IAP checklist',
        modelDefault: 'grok',
        updatedAt: now.subtract(const Duration(hours: 5)).toIso8601String(),
      ),
      Conversation(
        id: 'demo_4',
        title: 'Viết email xin nghỉ phép',
        modelDefault: 'grok',
        updatedAt: now.subtract(const Duration(days: 1)).toIso8601String(),
      ),
    ];
  }

  Future<void> _openConversation(Conversation c) async {
    if (c.id.startsWith('demo_')) {
      setState(() {
        _active = c;
        _messages = [];
        _showSample = c.id == 'demo_1';
        _busy = false;
      });
      return;
    }
    if (_streaming) await _stop();
    setState(() {
      _active = c;
      _busy = true;
      _showSample = false;
    });
    try {
      final msgs = await _api.listMessages(c.id);
      setState(() {
        _messages = msgs;
        _busy = false;
        _showSample = msgs.isEmpty;
      });
      _scrollToEnd();
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _busy = false;
      });
    }
  }

  Future<void> _newChat() async {
    if (_streaming) await _stop();
    setState(() => _busy = true);
    try {
      final c = await _api.createConversation();
      setState(() {
        _conversations = [
          c,
          ..._conversations.where((x) => !x.id.startsWith('demo_')),
        ];
        _active = c;
        _messages = [];
        _showSample = false;
        _busy = false;
      });
    } catch (e) {
      final local = Conversation(
        id: 'demo_${DateTime.now().millisecondsSinceEpoch}',
        title: 'New chat',
        modelDefault: _selectedModel.runtimeHint,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );
      setState(() {
        _conversations = [local, ..._conversations];
        _active = local;
        _messages = [];
        _showSample = false;
        _busy = false;
        _error = null;
      });
    }
  }

  Future<void> _stop() async {
    await _streamSub?.cancel();
    _streamSub = null;
    final cancel = _cancelStream;
    _cancelStream = null;
    await cancel?.call();
    if (!mounted) return;
    setState(() {
      _streaming = false;
      _busy = false;
      if (_messages.isNotEmpty &&
          _messages.last.role == 'assistant' &&
          _messages.last.status == 'streaming') {
        _messages.last.status =
            _messages.last.content.isEmpty ? 'error' : 'complete';
        if (_messages.last.content.isEmpty) {
          _messages.last.content = 'Stopped';
        }
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _streaming) return;

    var conversation = _active;
    if (conversation == null || conversation.id.startsWith('demo_')) {
      await _newChat();
      conversation = _active;
      if (conversation == null) return;
      // If still demo (API offline), keep local-only UX.
      if (conversation.id.startsWith('demo_')) {
        final localConvo = conversation;
        setState(() {
          _showSample = false;
          _messages = [
            ChatMessage(id: 'local_user', role: 'user', content: text),
            ChatMessage(
              id: 'local_assistant',
              role: 'assistant',
              content:
                  'API chưa kết nối. UI đã sẵn sàng — chạy API local rồi gửi lại '
                  '(runtime: xAI Grok).',
              status: 'complete',
              model: _selectedModel.runtimeHint,
            ),
          ];
          _input.clear();
          final idx =
              _conversations.indexWhere((c) => c.id == localConvo.id);
          if (idx >= 0) {
            _conversations[idx] = Conversation(
              id: localConvo.id,
              title: text.length > 42 ? '${text.substring(0, 42)}…' : text,
              modelDefault: localConvo.modelDefault,
              updatedAt: DateTime.now().toUtc().toIso8601String(),
            );
          }
        });
        _scrollToEnd();
        return;
      }
    }

    setState(() {
      _busy = true;
      _streaming = true;
      _showSample = false;
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

    final stream = _api.streamMessage(
      conversationId: conversation.id,
      content: text,
    );
    _cancelStream = stream.cancel;

    try {
      final done = Completer<void>();
      _streamSub = stream.events.listen(
        (event) {
          final type = event['type'] as String?;
          if (type == 'meta') {
            final aid = event['assistantMessageId'] as String?;
            final uid = event['userMessageId'] as String?;
            setState(() {
              if (uid != null && _messages.length >= 2) {
                _messages[_messages.length - 2] = ChatMessage(
                  id: uid,
                  role: 'user',
                  content: text,
                );
              }
              if (aid != null && _messages.isNotEmpty) {
                final prev = _messages.last;
                _messages[_messages.length - 1] = ChatMessage(
                  id: aid,
                  role: 'assistant',
                  content: prev.content,
                  status: 'streaming',
                  model: event['model'] as String? ?? prev.model,
                );
              }
            });
          } else if (type == 'delta') {
            final delta = event['text'] as String? ?? '';
            setState(() {
              final last = _messages.last;
              last.content = '${last.content}$delta';
              last.model = event['model'] as String? ?? last.model;
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
              if (_messages.last.content.isEmpty) {
                _messages.last.content =
                    event['error'] as String? ?? 'stream error';
              }
              _error = event['error'] as String? ?? _error;
            });
          }
        },
        onError: (Object e) {
          setState(() {
            _error = _friendlyError(e);
            if (_messages.isNotEmpty && _messages.last.role == 'assistant') {
              _messages.last.status = 'error';
              if (_messages.last.content.isEmpty) {
                _messages.last.content = _error!;
              }
            }
          });
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: true,
      );

      await done.future;
      if (!mounted) return;
      try {
        final usage = await _api.getUsage();
        final convos = await _api.listConversations();
        setState(() {
          _usage = usage;
          _conversations = convos;
        });
      } catch (_) {/* ignore refresh errors after stream */}
    } finally {
      await _streamSub?.cancel();
      _streamSub = null;
      _cancelStream = null;
      if (mounted) {
        setState(() {
          _streaming = false;
          _busy = false;
        });
      }
    }
  }

  void _applyQuickTool(String prompt) {
    _input.text = prompt;
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
  }

  String _friendlyError(Object e) {
    if (e is ApiException) {
      if (e.isQuota) {
        return e.code == 'token_soft_cap_exceeded'
            ? 'Token soft-cap reached for today. Upgrade or try tomorrow.'
            : 'Daily message quota reached. Upgrade to Pro for more.';
      }
      if (e.isRateLimit) {
        return 'Too many requests — wait a moment and try again.';
      }
      return e.code ?? e.toString();
    }
    return e.toString();
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
    _streamSub?.cancel();
    _cancelStream?.call();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final showUpgrade = !(auth.user?.isPro ?? false);

    return Localizations.override(
      context: context,
      locale: _localeOverride,
      child: Builder(
        builder: (context) {
          return Scaffold(
            backgroundColor: AppTheme.surface,
            body: Row(
              children: [
                LeftNav(
                  onNewChat: _newChat,
                  onUpgrade: _upgradePro,
                  billingBusy: _billingBusy,
                  showUpgrade: showUpgrade,
                  onNavTap: (label) {
                    if (label == 'About') {
                      showAboutDialog(
                        context: context,
                        applicationName: AppTheme.brandName,
                        applicationVersion: '0.1.0',
                        applicationLegalese:
                            'Powered by xAI Grok. Microsoft Store IAP for Pro.',
                      );
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$label — coming soon'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                Expanded(child: _buildCenter(auth)),
                RightPanel(
                  conversations: _conversations,
                  activeId: _active?.id,
                  onSelect: _openConversation,
                  onQuickTool: _applyQuickTool,
                  onSeeAll: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Library — coming soon'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCenter(AuthService auth) {
    final msgs = _displayMessages;
    return ColoredBox(
      color: AppTheme.surface,
      child: Column(
        children: [
          _ChatHeader(
            model: _selectedModel,
            streaming: _streaming,
            usage: _usage,
            onToggleLocale: () {
              setState(() {
                _localeOverride = _localeOverride.languageCode == 'en'
                    ? const Locale('vi')
                    : const Locale('en');
              });
            },
            localeCode: _localeOverride.languageCode,
            onRestore: () async {
              try {
                final result = await _storeBilling.restorePurchases();
                await auth.refreshMe();
                await _bootstrap();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      result.message ??
                          '${result.status} → ${result.planTier ?? 'free'}',
                    ),
                  ),
                );
              } catch (e) {
                setState(() => _error = _friendlyError(e));
              }
            },
            onSwitchTier: (tier) async {
              await auth.switchStubTier(tier);
              await _bootstrap();
            },
          ),
          if (_error != null)
            Material(
              color: const Color(0xFFFEE2E2),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFF991B1B)),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () => setState(() => _error = null),
                      icon: const Icon(Icons.close, size: 18),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: _busy && msgs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
                    itemCount: msgs.length,
                    itemBuilder: (context, i) => MessageBubble(
                      message: msgs[i],
                      modelLabel: _selectedModel.label,
                    ),
                  ),
          ),
          ComposerBar(
            controller: _input,
            streaming: _streaming,
            onSend: _send,
            onStop: _stop,
            onAttach: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Attachments — coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.model,
    required this.streaming,
    required this.usage,
    required this.onToggleLocale,
    required this.localeCode,
    required this.onRestore,
    required this.onSwitchTier,
  });

  final UiModel model;
  final bool streaming;
  final UsageSnapshot? usage;
  final VoidCallback onToggleLocale;
  final String localeCode;
  final VoidCallback onRestore;
  final ValueChanged<String> onSwitchTier;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 16, 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.mist,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(model.icon, size: 16, color: model.color),
                const SizedBox(width: 8),
                Text(
                  model.label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          if (streaming) ...[
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
          ],
          if (usage != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${usage!.remaining} left',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.inkMuted.withValues(alpha: 0.9),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Chat history',
            onPressed: () {},
            icon: Icon(Icons.history_rounded, color: AppTheme.inkMuted),
          ),
          IconButton(
            tooltip: 'Share',
            onPressed: () {},
            icon: Icon(Icons.ios_share_rounded, color: AppTheme.inkMuted),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (v) {
              if (v == 'locale') onToggleLocale();
              if (v == 'restore') onRestore();
              if (v == 'free' || v == 'pro') onSwitchTier(v);
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'locale',
                child: Text('Language: ${localeCode.toUpperCase()}'),
              ),
              const PopupMenuItem(
                value: 'restore',
                child: Text('Restore purchases'),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'free', child: Text('Stub Free')),
              const PopupMenuItem(value: 'pro', child: Text('Stub Pro')),
            ],
            icon: Icon(Icons.more_horiz, color: AppTheme.inkMuted),
          ),
        ],
      ),
    );
  }
}
