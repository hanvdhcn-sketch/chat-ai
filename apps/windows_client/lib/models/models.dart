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

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.status = 'complete',
    this.model,
  });

  final String id;
  final String role;
  String content;
  String status;
  String? model;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: json['role'] as String,
      content: json['content'] as String? ?? '',
      status: json['status'] as String? ?? 'complete',
      model: json['model'] as String?,
    );
  }
}

class UsageSnapshot {
  UsageSnapshot({
    required this.messagesCount,
    required this.messagesLimit,
    required this.planTier,
    this.imagesCount = 0,
    this.imagesLimit = 20,
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
    return UsageSnapshot(
      messagesCount: json['messagesCount'] as int? ?? 0,
      messagesLimit: json['messagesLimit'] as int? ?? 100,
      imagesCount: json['imagesCount'] as int? ?? 0,
      imagesLimit: json['imagesLimit'] as int? ?? 20,
      planTier: json['planTier'] as String? ?? 'free',
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
      maxImageBytes: json?['maxImageBytes'] as int? ?? (8 * 1024 * 1024),
      maxImagesPerDay: json?['maxImagesPerDay'] as int? ?? 20,
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
