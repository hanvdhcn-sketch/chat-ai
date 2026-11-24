import 'dart:typed_data';

class ChatUser {
  ChatUser({
    required this.id,
    required this.email,
    required this.planTier,
    this.name,
    this.locale = 'en',
  });

  final String id;
  final String email;
  final String? name;
  final String planTier; // free | pro
  final String locale;

  bool get isPro => planTier == 'pro';
  bool get showPoweredBy => !isPro;

  factory ChatUser.fromJson(Map<String, dynamic> json) {
    return ChatUser(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String?,
      planTier: json['planTier'] as String? ?? 'free',
      locale: json['locale'] as String? ?? 'en',
    );
  }
}

class Conversation {
  Conversation({
    required this.id,
    required this.title,
    required this.modelDefault,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final String modelDefault;
  final String updatedAt;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Chat',
      modelDefault: json['modelDefault'] as String? ?? 'grok',
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// Image shown in a user chat bubble (bytes for just-sent; name-only for history).
class MessageImageThumb {
  MessageImageThumb({
    required this.name,
    this.bytes,
    this.path,
    this.mimeType,
  });

  final String name;
  final Uint8List? bytes;
  final String? path;
  final String? mimeType;

  bool get hasPreview =>
      (bytes != null && bytes!.isNotEmpty) ||
      (path != null && path!.isNotEmpty);
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.status = 'complete',
    this.model,
    this.images = const [],
  });

  final String id;
  final String role;
  String content;
  String status;
  String? model;

  /// Image attachments rendered as thumbnails in the user bubble.
  List<MessageImageThumb> images;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final raw = json['content'] as String? ?? '';
    final parsed = splitAttachedImagePlaceholders(raw);
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: parsed.text,
      status: json['status'] as String? ?? 'complete',
      model: json['model'] as String?,
      images: parsed.images,
    );
  }
}

final _attachedImageLine = RegExp(r'^\[Attached image:\s*(.+?)\]\s*$');

({String text, List<MessageImageThumb> images}) splitAttachedImagePlaceholders(
  String content,
) {
  if (!content.contains('[Attached image:')) {
    return (text: content, images: const []);
  }

  final images = <MessageImageThumb>[];
  final kept = <String>[];
  for (final line in content.split('\n')) {
    final match = _attachedImageLine.firstMatch(line.trim());
    if (match != null) {
      images.add(MessageImageThumb(name: match.group(1)!.trim()));
      continue;
    }
    kept.add(line);
  }

  final text = kept
      .join('\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
  return (text: text, images: images);
}

class UsageSnapshot {
  UsageSnapshot({
    required this.messagesCount,
    required this.messagesLimit,
    required this.planTier,
    this.imagesCount = 0,
    this.imagesLimit = 8,
  });

  final int messagesCount;
  final int messagesLimit;
  final int imagesCount;
  final int imagesLimit;
  final String planTier;

  int get remaining =>
      (messagesLimit - messagesCount).clamp(0, messagesLimit);

  int get imagesRemaining =>
      (imagesLimit - imagesCount).clamp(0, imagesLimit);

  factory UsageSnapshot.fromJson(Map<String, dynamic> json) {
    final plan = json['planTier'] as String? ?? 'free';
    return UsageSnapshot(
      messagesCount: json['messagesCount'] as int? ?? 0,
      messagesLimit: json['messagesLimit'] as int? ?? 60,
      imagesCount: json['imagesCount'] as int? ?? 0,
      imagesLimit:
          json['imagesLimit'] as int? ?? (plan == 'pro' ? 20 : 8),
      planTier: plan,
    );
  }
}

class ImageLimits {
  ImageLimits({
    required this.maxImagesPerMessage,
    required this.maxImageBytes,
    required this.maxImagesPerDay,
  });

  final int maxImagesPerMessage;
  final int maxImageBytes;
  final int maxImagesPerDay;

  factory ImageLimits.fromJson(Map<String, dynamic>? json, {bool isPro = false}) {
    return ImageLimits(
      maxImagesPerMessage:
          json?['maxImagesPerMessage'] as int? ?? (isPro ? 8 : 3),
      maxImageBytes: json?['maxImageBytes'] as int? ??
          (isPro ? 8 * 1024 * 1024 : 5 * 1024 * 1024),
      maxImagesPerDay:
          json?['maxImagesPerDay'] as int? ?? (isPro ? 20 : 8),
    );
  }
}

class MonthlyImageSoftCap {
  MonthlyImageSoftCap({
    required this.active,
    required this.resetsAt,
    this.monthImagesCount = 0,
    this.softCap = 200,
  });

  final bool active;
  final String resetsAt;
  final int monthImagesCount;
  final int softCap;

  factory MonthlyImageSoftCap.fromJson(Map<String, dynamic>? json) {
    return MonthlyImageSoftCap(
      active: json?['active'] as bool? ?? false,
      resetsAt: json?['resetsAt'] as String? ?? '',
      monthImagesCount: json?['monthImagesCount'] as int? ?? 0,
      softCap: json?['softCap'] as int? ?? 200,
    );
  }
}

class UsageResponse {
  UsageResponse({
    required this.usage,
    required this.imageLimits,
    this.resetsAt,
    this.monthlyImageSoftCap,
  });

  final UsageSnapshot usage;
  final ImageLimits imageLimits;
  final String? resetsAt;
  /// Present only when Pro monthly soft-cap is already active.
  final MonthlyImageSoftCap? monthlyImageSoftCap;
}

class StoreProduct {
  StoreProduct({
    required this.storeProductId,
    required this.priceUsd,
    required this.trialDays,
    this.title,
  });

  final String storeProductId;
  final double priceUsd;
  final int trialDays;
  final String? title;

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    return StoreProduct(
      storeProductId: json['storeProductId'] as String? ?? 'pro_monthly',
      priceUsd: (json['priceUsd'] as num?)?.toDouble() ?? 9.99,
      trialDays: json['trialDays'] as int? ?? 7,
      title: json['title'] as String?,
    );
  }
}

class StoreVerifyResult {
  StoreVerifyResult({
    required this.planTier,
    required this.verified,
    required this.stub,
    this.reason,
  });

  final String planTier;
  final bool verified;
  final bool stub;
  final String? reason;

  factory StoreVerifyResult.fromJson(Map<String, dynamic> json) {
    return StoreVerifyResult(
      planTier: json['planTier'] as String? ?? 'free',
      verified: json['verified'] as bool? ?? false,
      stub: json['stub'] as bool? ?? false,
      reason: json['reason'] as String?,
    );
  }
}
