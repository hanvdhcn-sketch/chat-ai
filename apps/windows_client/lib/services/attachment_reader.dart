import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/attachment.dart';

/// Reads dropped/picked files into chat-ready attachments.
class AttachmentReader {
  static const int maxTextChars = 80000;
  /** Pro / request-ceiling default; Free uses [freeMaxImageBytes]. */
  static const int maxImageBytes = 8 * 1024 * 1024;
  static const int freeMaxImageBytes = 5 * 1024 * 1024;
  static const int proMaxImageBytes = 8 * 1024 * 1024;
  /// Legacy total cap; prefer [maxImagesForPlan] for images.
  static const int maxAttachments = 5;
  static const int freeMaxImagesPerMessage = 3;
  static const int proMaxImagesPerMessage = 8;
  static const int freeMaxImagesPerDay = 8;
  static const int proMaxImagesPerDay = 20;

  static int maxImagesForPlan({required bool isPro}) =>
      isPro ? proMaxImagesPerMessage : freeMaxImagesPerMessage;

  static int maxImageBytesForPlan({required bool isPro}) =>
      isPro ? proMaxImageBytes : freeMaxImageBytes;

  static int maxImagesPerDayForPlan({required bool isPro}) =>
      isPro ? proMaxImagesPerDay : freeMaxImagesPerDay;

  static int maxAttachmentsForPlan({required bool isPro}) =>
      maxImagesForPlan(isPro: isPro);

  static const _textExts = {
    '.txt',
    '.md',
    '.markdown',
    '.json',
    '.csv',
    '.log',
    '.yaml',
    '.yml',
    '.xml',
    '.html',
    '.htm',
    '.css',
    '.js',
    '.ts',
    '.tsx',
    '.jsx',
    '.dart',
    '.py',
    '.rs',
    '.go',
    '.java',
    '.kt',
    '.c',
    '.h',
    '.cpp',
    '.hpp',
    '.cs',
    '.rb',
    '.php',
    '.sh',
    '.ps1',
    '.sql',
    '.toml',
    '.ini',
    '.env',
    '.gitignore',
  };

  static const _imageExts = {
    '.png',
    '.jpg',
    '.jpeg',
    '.webp',
    '.gif',
  };

  static Future<PendingAttachment> fromPath(
    String path, {
    int? maxImageBytes,
  }) async {
    final file = File(path);
    final name = file.uri.pathSegments.isNotEmpty
        ? file.uri.pathSegments.last
        : path;
    final ext = _ext(name);
    final id =
        '${DateTime.now().microsecondsSinceEpoch}_${name.hashCode.abs()}';
    final imageByteCap = maxImageBytes ?? AttachmentReader.maxImageBytes;

    if (ext == '.pdf') {
      return PendingAttachment(
        id: id,
        path: path,
        name: name,
        kind: AttachmentKind.unsupported,
        mimeType: 'application/pdf',
        notice: 'PDF text extraction is not supported yet on Windows.',
      );
    }

    if (_imageExts.contains(ext)) {
      return _readImage(
        id: id,
        path: path,
        name: name,
        ext: ext,
        maxImageBytes: imageByteCap,
      );
    }

    if (_textExts.contains(ext) || ext.isEmpty) {
      return _readText(id: id, path: path, name: name, ext: ext);
    }

    // Unknown binary — try UTF-8 text; otherwise unsupported.
    try {
      final raf = await file.open();
      try {
        final probe = await raf.read(512);
        final looksBinary = probe.any((b) => b == 0);
        if (!looksBinary) {
          return await _readText(id: id, path: path, name: name, ext: ext);
        }
      } finally {
        await raf.close();
      }
    } catch (_) {/* fall through */}

    return PendingAttachment(
      id: id,
      path: path,
      name: name,
      kind: AttachmentKind.unsupported,
      mimeType: 'application/octet-stream',
      notice: 'This file type is not supported for chat context.',
    );
  }

  static Future<PendingAttachment> _readText({
    required String id,
    required String path,
    required String name,
    required String ext,
  }) async {
    final file = File(path);
    String raw;
    try {
      raw = await file.readAsString();
    } catch (_) {
      return PendingAttachment(
        id: id,
        path: path,
        name: name,
        kind: AttachmentKind.unsupported,
        mimeType: 'text/plain',
        notice: 'Could not read this file as text.',
      );
    }

    String? notice;
    var text = raw;
    if (text.length > maxTextChars) {
      text = text.substring(0, maxTextChars);
      notice =
          'Truncated to $maxTextChars characters (file was ${raw.length}).';
    }

    return PendingAttachment(
      id: id,
      path: path,
      name: name,
      kind: AttachmentKind.text,
      mimeType: _textMime(ext),
      text: text,
      notice: notice,
    );
  }

  static Future<PendingAttachment> _readImage({
    required String id,
    required String path,
    required String name,
    required String ext,
    required int maxImageBytes,
  }) async {
    final file = File(path);
    final raw = await file.readAsBytes();
    if (raw.length > maxImageBytes) {
      return PendingAttachment(
        id: id,
        path: path,
        name: name,
        kind: AttachmentKind.unsupported,
        mimeType: _imageMime(ext),
        notice:
            'Image too large (max ${maxImageBytes ~/ (1024 * 1024)} MB).',
      );
    }

    // xAI vision accepts JPEG/PNG; re-encode webp/gif to PNG.
    if (ext == '.png' || ext == '.jpg' || ext == '.jpeg') {
      return PendingAttachment(
        id: id,
        path: path,
        name: name,
        kind: AttachmentKind.image,
        mimeType: _imageMime(ext),
        imageBytes: raw,
      );
    }

    try {
      final png = await _reencodePng(raw);
      return PendingAttachment(
        id: id,
        path: path,
        name: name,
        kind: AttachmentKind.image,
        mimeType: 'image/png',
        imageBytes: png,
        notice: ext == '.gif' || ext == '.webp'
            ? 'Converted $ext → PNG for Grok vision.'
            : null,
      );
    } catch (_) {
      return PendingAttachment(
        id: id,
        path: path,
        name: name,
        kind: AttachmentKind.unsupported,
        mimeType: _imageMime(ext),
        notice: 'Could not decode this image for Grok vision.',
      );
    }
  }

  static Future<Uint8List> _reencodePng(Uint8List bytes) async {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final bd = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (bd == null) {
      throw StateError('png encode failed');
    }
    return bd.buffer.asUint8List();
  }

  static String _ext(String name) {
    final i = name.lastIndexOf('.');
    if (i < 0) return '';
    return name.substring(i).toLowerCase();
  }

  static String _textMime(String ext) {
    switch (ext) {
      case '.json':
        return 'application/json';
      case '.md':
      case '.markdown':
        return 'text/markdown';
      case '.csv':
        return 'text/csv';
      case '.html':
      case '.htm':
        return 'text/html';
      default:
        return 'text/plain';
    }
  }

  static String _imageMime(String ext) {
    switch (ext) {
      case '.png':
        return 'image/png';
      case '.jpg':
      case '.jpeg':
        return 'image/jpeg';
      case '.webp':
        return 'image/webp';
      case '.gif':
        return 'image/gif';
      default:
        return 'application/octet-stream';
    }
  }
}
