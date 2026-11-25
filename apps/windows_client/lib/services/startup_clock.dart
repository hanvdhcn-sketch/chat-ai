import 'dart:io';

import 'package:flutter/foundation.dart';

/// Process-local cold-start timing for Orbita Windows.
///
/// Writes milestones to `%TEMP%/orbita_startup.json` so release launches
/// can be timed without attaching DevTools.
class StartupClock {
  StartupClock._();

  static final Stopwatch _sw = Stopwatch();
  static final Map<String, int> _marks = <String, int>{};
  static bool _readyWritten = false;

  static void start() {
    if (_sw.isRunning) return;
    _sw.start();
    mark('main');
  }

  static int get elapsedMs => _sw.elapsedMilliseconds;

  static void mark(String name) {
    if (!_sw.isRunning) start();
    _marks[name] = _sw.elapsedMilliseconds;
    debugPrint('[startup] $name @ ${_marks[name]}ms');
  }

  /// First interactive shell: window content painted and composer in tree.
  static Future<void> markReady() async {
    if (_readyWritten) return;
    _readyWritten = true;
    mark('ready');
    try {
      final path = '${Directory.systemTemp.path}\\orbita_startup.json';
      final payload = StringBuffer('{\n');
      payload.writeln('  "readyMs": ${_marks['ready']},');
      payload.writeln('  "marks": {');
      final entries = _marks.entries.toList();
      for (var i = 0; i < entries.length; i++) {
        final e = entries[i];
        final comma = i == entries.length - 1 ? '' : ',';
        payload.writeln('    "${e.key}": ${e.value}$comma');
      }
      payload.writeln('  }');
      payload.writeln('}');
      await File(path).writeAsString(payload.toString(), flush: true);
    } catch (_) {
      // Timing must never break startup.
    }
  }
}
