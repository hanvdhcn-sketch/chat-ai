import 'dart:async';
import 'dart:io';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/attachment.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/attachment_reader.dart';
import '../services/auth_service.dart';
import '../services/config.dart';
import '../services/startup_clock.dart';
import '../services/store_billing.dart';
import '../theme/app_theme.dart';
import '../widgets/composer_bar.dart';
import '../widgets/left_nav.dart';
import '../widgets/left_nav_panels.dart';
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
  final _composerKey = GlobalKey<ComposerBarState>();

  late final ApiClient _api;
  late final StoreBillingService _storeBilling;
  List<Conversation> _conversations = [];
  Conversation? _active;
  List<ChatMessage> _messages = [];
  UsageSnapshot? _usage;
  ImageLimits? _imageLimits;
  String? _resetsAt;
  MonthlyImageSoftCap? _monthlyImageSoftCap;
  bool _monthlySoftCapNotified = false;
  bool _busy = false;
  bool _streaming = false;
  bool _billingBusy = false;
  bool _showSample = true;
  bool _dragging = false;
  String? _error;
  Locale _localeOverride = const Locale('en');
  final List<PendingAttachment> _attachments = [];
  /// Local title/snippet index for Search + Library (no cloud sync).
  final Map<String, String> _snippets = {};

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
    // Optimistic shell: composer + sample chat before any network round-trip.
    final demos = _demoConversations();
    _conversations = demos;
    _active = demos.first;
    _showSample = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      StartupClock.mark('chatFirstFrame');
      unawaited(StartupClock.markReady());
      unawaited(_bootstrap());
    });
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
    StartupClock.mark('chatBootstrapStart');
    try {
      // Parallel shell fetches — never serialize on the critical path.
      final results = await Future.wait<Object?>([
        _api.listConversations(),
        _api.getUsage(),
      ]);
      final convos = results[0]! as List<Conversation>;
      final usageRes = results[1]! as UsageResponse;
      if (!mounted) return;
      setState(() {
        _conversations = convos.isEmpty ? _demoConversations() : convos;
        _usage = usageRes.usage;
        _imageLimits = usageRes.imageLimits;
        _resetsAt = usageRes.resetsAt;
        _monthlyImageSoftCap = usageRes.monthlyImageSoftCap;
        _error = null;
        if (convos.isEmpty) {
          _active = _conversations.first;
          _showSample = true;
          _messages = [];
        }
      });
      _maybeNotifyMonthlyImageSoftCap(usageRes.monthlyImageSoftCap);
      StartupClock.mark('chatBootstrapShell');
      // Defer message hydrate so composer stays interactive immediately.
      if (convos.isNotEmpty) {
        unawaited(_openConversation(convos.first));
      }
    } catch (e) {
      // Offline / API down — keep optimistic demo shell already painted.
      if (!mounted) return;
      setState(() {
        if (_conversations.isEmpty) {
          _conversations = _demoConversations();
          _active = _conversations.first;
          _showSample = true;
          _messages = [];
        }
        _error = null;
      });
      StartupClock.mark('chatBootstrapOffline');
    }
  }

  List<Conversation> _demoConversations() {
    final now = DateTime.now().toUtc();
    final list = [
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
    _snippets
      ..['demo_1'] = _sampleUser
      ..['demo_2'] = 'Polish left nav, Quick Tools, and Fluent surfaces…'
      ..['demo_3'] = 'Verify Store IAP products, restore, and Pro entitlements…'
      ..['demo_4'] = 'Soạn email xin nghỉ phép ngắn gọn, lịch sự…';
    return list;
  }

  void _cacheSnippet(String conversationId, List<ChatMessage> msgs) {
    if (conversationId.isEmpty || msgs.isEmpty) return;
    ChatMessage? firstUser;
    for (final m in msgs) {
      if (m.role == 'user' && m.content.trim().isNotEmpty) {
        firstUser = m;
        break;
      }
    }
    final source = firstUser ?? msgs.first;
    final text = source.content.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (text.isEmpty) return;
    _snippets[conversationId] =
        text.length <= 140 ? text : '${text.substring(0, 137)}…';
  }

  void _toggleLocale() {
    setState(() {
      _localeOverride = _localeOverride.languageCode == 'en'
          ? const Locale('vi')
          : const Locale('en');
    });
  }

  Future<void> _clearLocalData() async {
    if (_streaming) await _stop();
    if (!mounted) return;
    final auth = context.read<AuthService>();
    await auth.signOut();
    await auth.bootstrap();
    if (!mounted) return;
    setState(() {
      _snippets.clear();
      _attachments.clear();
      _input.clear();
      _messages = [];
      _active = null;
      _error = null;
      _showSample = true;
      _conversations = _demoConversations();
      _active = _conversations.first;
    });
    await _bootstrap();
  }

  Future<void> _restorePurchasesAction() async {
    final auth = context.read<AuthService>();
    try {
      final result = await _storeBilling.restorePurchases();
      await auth.refreshMe();
      await _bootstrap();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ??
                (result.ok ? 'Purchases restored' : result.status),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    }
  }

  void _openAbout() {
    showAboutPanel(context);
  }

  void _handleNavTap(String label) {
    switch (label) {
      case 'Search Chats':
        showSearchChatsPanel(
          context: context,
          conversations: _conversations,
          snippets: Map<String, String>.from(_snippets),
          onSelect: _openConversation,
        );
        return;
      case 'Library':
        showLibraryPanel(
          context: context,
          conversations: _conversations,
          snippets: Map<String, String>.from(_snippets),
          pendingAttachments: List<PendingAttachment>.from(_attachments),
          onSelectChat: _openConversation,
          onApplyPrompt: _applyQuickTool,
        );
        return;
      case 'Tools':
        showToolsPanel(
          context: context,
          onQuickTool: _applyQuickTool,
        );
        return;
      case 'Settings':
        final auth = context.read<AuthService>();
        showSettingsPanel(
          context: context,
          args: SettingsPanelArgs(
            localeCode: _localeOverride.languageCode,
            onToggleLocale: _toggleLocale,
            onClearLocalData: _clearLocalData,
            onOpenAbout: _openAbout,
            showUpgrade: !(auth.user?.isPro ?? false),
            billingBusy: _billingBusy,
            onUpgrade: _upgradePro,
            onRestorePurchases: _restorePurchasesAction,
            apiBaseUrl: AppConfig.apiBaseUrl,
          ),
        );
        return;
      case 'About':
        _openAbout();
        return;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label — coming soon'),
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  Future<void> _openConversation(Conversation c) async {
    if (c.id.startsWith('demo_')) {
      setState(() {
        _active = c;
        _messages = [];
        _showSample = c.id == 'demo_1';
        _busy = false;
        if (c.id == 'demo_1') {
          _snippets[c.id] = _sampleUser;
        }
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
        _cacheSnippet(c.id, msgs);
      });
      _scrollToEnd();
    } catch (e) {
      final stale = e is ApiException && e.isNotFound;
      setState(() {
        _error = _friendlyError(e);
        _busy = false;
        if (stale) {
          _conversations =
              _conversations.where((x) => x.id != c.id).toList();
          _active = null;
          _messages = [];
          _showSample = false;
        }
      });
      if (stale) {
        await _newChat();
      }
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

  /// Text shown in the bubble (images render as thumbnails, not placeholders).
  String _composeDisplayContent(
    String text,
    List<PendingAttachment> attachments,
  ) {
    final parts = <String>[];
    if (text.trim().isNotEmpty) parts.add(text.trim());
    for (final a in attachments) {
      if (a.kind == AttachmentKind.image) {
        // Thumbnails carry the image; keep only an optional size/notice note.
        if (a.notice != null) parts.add('(${a.notice})');
      } else if (a.kind == AttachmentKind.text && a.text != null) {
        parts.add('--- Attached file: ${a.name} ---');
        if (a.notice != null) parts.add('(${a.notice})');
        parts.add(a.text!);
        parts.add('--- End of ${a.name} ---');
      } else if (a.kind == AttachmentKind.unsupported) {
        parts.add(
          '[Unsupported: ${a.name}${a.notice != null ? ' — ${a.notice}' : ''}]',
        );
      }
    }
    return parts.join('\n\n').trim();
  }

  List<MessageImageThumb> _thumbsFromAttachments(
    List<PendingAttachment> attachments,
  ) {
    return attachments
        .where((a) => a.kind == AttachmentKind.image)
        .map(
          (a) => MessageImageThumb(
            name: a.name,
            bytes: a.imageBytes,
            path: a.path,
            mimeType: a.mimeType,
          ),
        )
        .toList(growable: false);
  }

  bool get _isPro =>
      context.read<AuthService>().user?.isPro ??
      (_usage?.planTier == 'pro');

  int get _maxImagesPerMessage =>
      _imageLimits?.maxImagesPerMessage ??
      AttachmentReader.maxImagesForPlan(isPro: _isPro);

  Future<void> _addPaths(Iterable<String> paths) async {
    final maxPerMessage = _maxImagesPerMessage;
    final currentImages =
        _attachments.where((a) => a.kind == AttachmentKind.image).length;
    final slotsLeft = maxPerMessage - _attachments.length;
    if (slotsLeft <= 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Max $maxPerMessage attachments per message on your plan',
          ),
        ),
      );
      return;
    }

    final usedToday = _usage?.imagesCount ?? 0;
    final limitToday = _usage?.imagesLimit ??
        (_imageLimits?.maxImagesPerDay ??
            AttachmentReader.maxImagesPerDayForPlan(isPro: _isPro));
    final imageByteCap = _imageLimits?.maxImageBytes ??
        AttachmentReader.maxImageBytesForPlan(isPro: _isPro);
    final toLoad = paths.take(slotsLeft).toList();
    final loaded = <PendingAttachment>[];
    var imagesAdded = 0;
    for (final path in toLoad) {
      try {
        final att = await AttachmentReader.fromPath(
          path,
          maxImageBytes: imageByteCap,
        );
        if (att.kind == AttachmentKind.image) {
          if (currentImages + imagesAdded >= maxPerMessage) {
            loaded.add(
              PendingAttachment(
                id: 'lim_${DateTime.now().microsecondsSinceEpoch}',
                path: path,
                name: att.name,
                kind: AttachmentKind.unsupported,
                mimeType: att.mimeType,
                notice:
                    'Max $maxPerMessage images per message on your plan.',
              ),
            );
            continue;
          }
          if (usedToday + currentImages + imagesAdded >= limitToday) {
            loaded.add(
              PendingAttachment(
                id: 'day_${DateTime.now().microsecondsSinceEpoch}',
                path: path,
                name: att.name,
                kind: AttachmentKind.unsupported,
                mimeType: att.mimeType,
                notice: _imageQuotaReachedNotice(),
              ),
            );
            continue;
          }
          imagesAdded += 1;
        }
        loaded.add(att);
      } catch (e) {
        loaded.add(
          PendingAttachment(
            id: 'err_${DateTime.now().microsecondsSinceEpoch}',
            path: path,
            name: path.split(RegExp(r'[\\/]')).last,
            kind: AttachmentKind.unsupported,
            mimeType: 'application/octet-stream',
            notice: 'Could not read file.',
          ),
        );
      }
    }
    if (!mounted) return;
    setState(() => _attachments.addAll(loaded));

    final unsupported =
        loaded.where((a) => a.kind == AttachmentKind.unsupported).toList();
    if (unsupported.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            unsupported.length == 1
                ? unsupported.first.notice ??
                    '${unsupported.first.name} is unsupported'
                : '${unsupported.length} files are unsupported',
          ),
        ),
      );
    }
  }

  Future<String> _writeTempBytes(String name, List<int> bytes) async {
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final dir = Directory.systemTemp;
    final file = File(
      '${dir.path}${Platform.pathSeparator}orbita_drop_${DateTime.now().microsecondsSinceEpoch}_$safe',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _pickAttachments() async {
    if (_streaming) return;
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null) return;
    final paths = result.files
        .map((f) => f.path)
        .whereType<String>()
        .where((p) => p.isNotEmpty);
    await _addPaths(paths);
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    final pending = List<PendingAttachment>.from(_attachments);
    final sendable = pending.where((a) => a.isSendable).toList();
    if (_streaming) return;
    if (text.isEmpty && sendable.isEmpty) return;

    final remaining = _usage?.remaining;
    if (remaining != null && remaining <= 0) {
      final notice = _messageQuotaReachedNotice();
      setState(() => _error = notice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice)),
        );
      }
      return;
    }

    final imageCount =
        sendable.where((a) => a.kind == AttachmentKind.image).length;
    final imagesRemaining = _usage?.imagesRemaining;
    if (imageCount > 0 &&
        imagesRemaining != null &&
        imageCount > imagesRemaining) {
      final notice = _imageQuotaReachedNotice();
      setState(() => _error = notice);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(notice)),
        );
      }
      return;
    }

    final displayContent = _composeDisplayContent(text, pending);
    final displayImages = _thumbsFromAttachments(sendable);
    final attachmentPayload =
        sendable.map((a) => a.toApiJson()).toList(growable: false);

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
            ChatMessage(
              id: 'local_user',
              role: 'user',
              content: displayContent,
              images: displayImages,
            ),
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
          _attachments.clear();
          final idx =
              _conversations.indexWhere((c) => c.id == localConvo.id);
          if (idx >= 0) {
            final titleSrc = text.isNotEmpty
                ? text
                : (pending.isNotEmpty ? pending.first.name : 'Chat');
            _conversations[idx] = Conversation(
              id: localConvo.id,
              title: titleSrc.length > 42
                  ? '${titleSrc.substring(0, 42)}…'
                  : titleSrc,
              modelDefault: localConvo.modelDefault,
              updatedAt: DateTime.now().toUtc().toIso8601String(),
            );
            _cacheSnippet(localConvo.id, _messages);
          }
        });
        _scrollToEnd();
        return;
      }
    }

    final activeConvo = conversation;
    if (activeConvo == null) return;

    setState(() {
      _busy = true;
      _streaming = true;
      _showSample = false;
      _error = null;
      _messages = [
        ..._messages,
        ChatMessage(
          id: 'local_user',
          role: 'user',
          content: displayContent,
          images: displayImages,
        ),
        ChatMessage(
          id: 'local_assistant',
          role: 'assistant',
          content: '',
          status: 'streaming',
        ),
      ];
      _input.clear();
      _attachments.clear();
      _cacheSnippet(activeConvo.id, _messages);
    });
    _scrollToEnd();

    final stream = _api.streamMessage(
      conversationId: activeConvo.id,
      content: text,
      locale: _localeOverride.languageCode,
      attachments: attachmentPayload,
    );
    _cancelStream = stream.cancel;

    var staleConversation = false;
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
                  content: displayContent,
                  images: displayImages,
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
            final errCode = event['error'] as String? ?? 'stream error';
            final friendly = _friendlyErrorCode(errCode);
            setState(() {
              _messages.last.status = 'error';
              if (_messages.last.content.isEmpty) {
                _messages.last.content = friendly;
              }
              _error = friendly;
            });
          }
        },
        onError: (Object e) {
          if (e is ApiException && e.isNotFound) {
            staleConversation = true;
          }
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

      if (staleConversation) {
        final staleId = conversation.id;
        setState(() {
          _conversations =
              _conversations.where((c) => c.id != staleId).toList();
          // Drop the failed optimistic turn; user can resend on a fresh chat.
          if (_messages.length >= 2 &&
              _messages[_messages.length - 1].role == 'assistant' &&
              _messages[_messages.length - 2].role == 'user') {
            _messages = _messages.sublist(0, _messages.length - 2);
          }
          _input.text = text;
          for (final a in pending) {
            if (!_attachments.any((x) => x.path == a.path)) {
              _attachments.add(a);
            }
          }
        });
        await _newChat();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_friendlyErrorCode('not_found'))),
          );
        }
        return;
      }

      try {
        final usageRes = await _api.getUsage();
        final convos = await _api.listConversations();
        setState(() {
          _usage = usageRes.usage;
          _imageLimits = usageRes.imageLimits;
          _resetsAt = usageRes.resetsAt;
          _monthlyImageSoftCap = usageRes.monthlyImageSoftCap;
          _conversations = convos;
        });
        _maybeNotifyMonthlyImageSoftCap(usageRes.monthlyImageSoftCap);
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
    // Keep caret after a trailing space so the user can type immediately.
    final text = prompt.endsWith(' ') ? prompt : '$prompt ';
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _composerKey.currentState?.requestFocus();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Prompt inserted into composer'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  String _formatResetsAt([String? iso]) {
    final raw = iso ?? _resetsAt;
    var when = raw != null ? DateTime.tryParse(raw)?.toUtc() : null;
    if (when == null) {
      final now = DateTime.now().toUtc();
      when = DateTime.utc(now.year, now.month, now.day + 1);
    }
    final y = when.year.toString().padLeft(4, '0');
    final m = when.month.toString().padLeft(2, '0');
    final d = when.day.toString().padLeft(2, '0');
    final hh = when.hour.toString().padLeft(2, '0');
    final mm = when.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm UTC';
  }

  void _maybeNotifyMonthlyImageSoftCap(MonthlyImageSoftCap? softCap) {
    if (softCap == null || !softCap.active) {
      _monthlySoftCapNotified = false;
      return;
    }
    if (_monthlySoftCapNotified || !mounted) return;
    _monthlySoftCapNotified = true;
    final notice = AppLocalizations.of(context).monthlyImageAllowanceReached(
      _formatResetsAt(softCap.resetsAt),
    );
    setState(() => _error = notice);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(notice), duration: const Duration(seconds: 8)),
    );
  }

  String _messageQuotaReachedNotice() {
    if (!mounted) {
      return 'Daily message limit reached. Wait until the next day reset '
          '(${_formatResetsAt()}) to continue.';
    }
    return AppLocalizations.of(context).messageQuotaReached(_formatResetsAt());
  }

  String _imageQuotaReachedNotice() {
    if (!mounted) {
      return 'Daily image upload limit reached. Wait until the next day reset '
          '(${_formatResetsAt()}) to upload more.';
    }
    return AppLocalizations.of(context).imageQuotaReached(_formatResetsAt());
  }

  String _friendlyErrorCode(String? code) {
    switch (code) {
      case 'not_found':
        return 'This chat is no longer on the server (API may have restarted). '
            'A new chat is ready — send again.';
      case 'invalid_body':
        return 'Could not send that message. Check your text or attachments.';
      case 'aborted':
        return 'Stopped.';
      case 'stream_failed':
        return 'The reply stream failed. Try again.';
      default:
        return code ?? 'Something went wrong.';
    }
  }

  String _friendlyError(Object e) {
    if (e is ApiException) {
      if (e.isNotFound) {
        return _friendlyErrorCode('not_found');
      }
      if (e.isQuota) {
        switch (e.code) {
          case 'token_soft_cap_exceeded':
            return _messageQuotaReachedNotice();
          case 'image_quota_exceeded':
            return _imageQuotaReachedNotice();
          case 'too_many_images_per_message':
            return 'Too many images in one message for your plan '
                '(max $_maxImagesPerMessage).';
          case 'message_quota_exceeded':
          default:
            return _messageQuotaReachedNotice();
        }
      }
      if (e.isRateLimit) {
        return 'Too many requests — wait a moment and try again.';
      }
      switch (e.code) {
        case 'invalid_body':
        case 'aborted':
        case 'stream_failed':
        case 'not_found':
          return _friendlyErrorCode(e.code);
        default:
          return e.code ?? e.toString();
      }
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
                  onNavTap: _handleNavTap,
                ),
                Expanded(child: _buildCenter(auth)),
                RightPanel(
                  conversations: _conversations,
                  activeId: _active?.id,
                  onSelect: _openConversation,
                  onQuickTool: _applyQuickTool,
                  onSeeAll: () => _handleNavTap('Library'),
                  onMoreTools: () => _handleNavTap('Tools'),
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
    return DropTarget(
      acceptedKinds: const {DropItemKind.file},
      onEnter: (_) => setState(() => _dragging = true),
      onLeave: () => setState(() => _dragging = false),
      onDrop: (detail) async {
        setState(() => _dragging = false);
        if (_streaming) return;
        final paths = <String>[];
        for (final item in detail.items) {
          if (item is DropFileItem) {
            final path = item.localPath;
            if (path != null && path.isNotEmpty) {
              paths.add(path);
            } else {
              // Provider-backed file without a path — write to temp then read.
              try {
                final bytes = await item.file.readAsBytes();
                final tmp = await _writeTempBytes(item.name, bytes);
                paths.add(tmp);
              } catch (_) {/* skip unreadable */}
            }
          }
        }
        await _addPaths(paths);
      },
      child: Stack(
        children: [
          ColoredBox(
            color: AppTheme.surface,
            child: Column(
              children: [
                _ChatHeader(
                  model: _selectedModel,
                  streaming: _streaming,
                  usage: _usage,
                  onToggleLocale: _toggleLocale,
                  localeCode: _localeOverride.languageCode,
                  onRestore: () {
                    _restorePurchasesAction();
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
                  key: _composerKey,
                  controller: _input,
                  streaming: _streaming,
                  onSend: _send,
                  onStop: _stop,
                  localeCode: _localeOverride.languageCode,
                  attachments: _attachments,
                  onRemoveAttachment: (id) {
                    setState(
                      () => _attachments.removeWhere((a) => a.id == id),
                    );
                  },
                  onAttach: _pickAttachments,
                  onDictationError: (msg) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(msg),
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (_dragging)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.10),
                    border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.55),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surface.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.file_download_outlined,
                            size: 36,
                            color: AppTheme.accent,
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Drop files to attach',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Images → Grok vision · Text files → chat context',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
