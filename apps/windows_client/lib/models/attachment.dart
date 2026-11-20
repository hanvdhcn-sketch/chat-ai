import 'dart:convert';
import 'dart:typed_data';

/// Pending composer attachment (image vision, text context, or unsupported).
enum AttachmentKind { image, text, unsupported }

class PendingAttachment {
  PendingAttachment({
    required this.id,
    required this.path,
    required this.name,
    required this.kind,
    required this.mimeType,
    this.text,
    this.imageBytes,
    this.notice,
  });

  final String id;
  final String path;
  final String name;
  final AttachmentKind kind;
  final String mimeType;

  /// Extracted / truncated text for text-like files.
  final String? text;

  /// PNG/JPEG bytes for vision (webp/gif may be re-encoded to PNG).
  final Uint8List? imageBytes;

  /// User-visible note (truncation, PDF unsupported, etc.).
  final String? notice;

  bool get isSendable =>
      kind == AttachmentKind.image || kind == AttachmentKind.text;

  Map<String, dynamic> toApiJson() {
    return {
      'name': name,
      'mimeType': mimeType,
      'kind': kind.name,
      if (text != null) 'text': text,
      if (imageBytes != null) 'dataBase64': base64Encode(imageBytes!),
      if (notice != null) 'notice': notice,
    };
  }
}
