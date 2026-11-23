import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Speech-to-text for the composer.
///
/// Primary: [speech_to_text] (Windows UWP / Store-friendly).
/// Fallback on Windows unpackaged builds: .NET [System.Speech] via PowerShell
/// (works without MSIX package identity; uses installed speech language packs).
class DictationService {
  DictationService();

  final SpeechToText _speech = SpeechToText();
  bool _pluginReady = false;
  bool _pluginFailed = false;
  bool _listening = false;
  Process? _psProcess;
  StreamSubscription<String>? _psOutSub;
  StreamSubscription<String>? _psErrSub;

  bool get isListening => _listening;

  Future<bool> _ensurePlugin({
    required void Function(String msg) onStatus,
    required void Function(String msg) onError,
  }) async {
    if (_pluginReady) return true;
    if (_pluginFailed) return false;
    try {
      final ok = await _speech.initialize(
        onStatus: onStatus,
        onError: (e) => onError(e.errorMsg),
        debugLogging: kDebugMode,
      );
      _pluginReady = ok;
      if (!ok) _pluginFailed = true;
      return ok;
    } catch (e) {
      _pluginFailed = true;
      onError(e.toString());
      return false;
    }
  }

  /// Prefer [localeHint] (e.g. `vi` / `en`), then `vi-VN`, then device default.
  Future<String?> _resolveLocaleId(String? localeHint) async {
    if (!_pluginReady) return null;
    final locales = await _speech.locales();
    if (locales.isEmpty) return null;
    final hint = (localeHint ?? '').toLowerCase();
    if (hint.isNotEmpty) {
      final exact = locales.where(
        (l) => l.localeId.toLowerCase() == hint ||
            l.localeId.toLowerCase().startsWith('$hint-') ||
            l.localeId.toLowerCase().startsWith('${hint}_'),
      );
      if (exact.isNotEmpty) return exact.first.localeId;
    }
    for (final prefer in ['vi-VN', 'vi_VN', 'en-US', 'en_US']) {
      final match = locales.where(
        (l) => l.localeId.toLowerCase() == prefer.toLowerCase(),
      );
      if (match.isNotEmpty) return match.first.localeId;
    }
    return locales.first.localeId;
  }

  Future<void> start({
    String? localeHint,
    required void Function(String text, {required bool isFinal}) onText,
    required void Function(String message) onError,
    void Function(String status)? onStatus,
  }) async {
    if (_listening) return;

    final statusCb = onStatus ?? (_) {};
    final pluginOk = await _ensurePlugin(
      onStatus: statusCb,
      onError: onError,
    );

    if (pluginOk) {
      final localeId = await _resolveLocaleId(localeHint);
      _listening = true;
      try {
        await _speech.listen(
          onResult: (result) {
            final text = result.recognizedWords.trim();
            if (text.isEmpty) return;
            onText(text, isFinal: result.finalResult);
          },
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.dictation,
            partialResults: true,
            cancelOnError: true,
            autoPunctuation: true,
            localeId: localeId,
          ),
        );
        return;
      } catch (e) {
        _listening = false;
        // Fall through to Windows System.Speech when plugin listen fails.
        if (!Platform.isWindows) {
          onError(e.toString());
          return;
        }
      }
    }

    if (!Platform.isWindows) {
      onError(
        'Speech recognition is unavailable. Check microphone permission.',
      );
      return;
    }

    await _startSystemSpeechFallback(
      localeHint: localeHint,
      onText: onText,
      onError: onError,
    );
  }

  Future<void> _startSystemSpeechFallback({
    String? localeHint,
    required void Function(String text, {required bool isFinal}) onText,
    required void Function(String message) onError,
  }) async {
    final cultures = <String>[];
    final hint = (localeHint ?? '').trim();
    if (hint.toLowerCase().startsWith('vi')) {
      cultures.addAll(['vi-VN', 'en-US']);
    } else if (hint.toLowerCase().startsWith('en')) {
      cultures.addAll(['en-US', 'vi-VN']);
    } else {
      cultures.addAll(['vi-VN', 'en-US']);
    }

    // One-shot recognitions in a loop; Dart kills the process on stop.
    final script = '''
\$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Speech
\$cultures = @(${cultures.map((c) => "'$c'").join(',')})
\$eng = \$null
\$used = \$null
foreach (\$c in \$cultures) {
  try {
    \$eng = New-Object System.Speech.Recognition.SpeechRecognitionEngine ([System.Globalization.CultureInfo]::new(\$c))
    \$used = \$c
    break
  } catch {}
}
if (-not \$eng) {
  [Console]::Error.WriteLine('No speech engine for: ' + (\$cultures -join ', '))
  exit 2
}
\$eng.LoadGrammar((New-Object System.Speech.Recognition.DictationGrammar))
try {
  \$eng.SetInputToDefaultAudioDevice()
} catch {
  [Console]::Error.WriteLine('Microphone unavailable: ' + \$_.Exception.Message)
  exit 3
}
\$eng.InitialSilenceTimeout = [TimeSpan]::FromSeconds(12)
\$eng.BabbleTimeout = [TimeSpan]::FromSeconds(0)
\$eng.EndSilenceTimeout = [TimeSpan]::FromSeconds(1.2)
[Console]::Out.WriteLine('READY:' + \$used)
[Console]::Out.Flush()
while (\$true) {
  try {
    \$result = \$eng.Recognize()
    if (\$null -ne \$result -and \$result.Text) {
      [Console]::Out.WriteLine('RESULT:' + \$result.Text)
      [Console]::Out.Flush()
    }
  } catch {
    Start-Sleep -Milliseconds 200
  }
}
''';

    try {
      final proc = await Process.start(
        'powershell.exe',
        [
          '-NoProfile',
          '-NonInteractive',
          '-ExecutionPolicy',
          'Bypass',
          '-Command',
          script,
        ],
        mode: ProcessStartMode.normal,
      );
      _psProcess = proc;
      _listening = true;

      _psOutSub = proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.startsWith('RESULT:')) {
          final text = line.substring(7).trim();
          if (text.isNotEmpty) {
            onText(text, isFinal: true);
          }
        }
      });

      _psErrSub = proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((line) {
        if (line.trim().isEmpty) return;
        onError(line.trim());
      });

      proc.exitCode.then((code) async {
        if (!_listening) return;
        _listening = false;
        if (code != 0) {
          onError(
            'Windows speech failed (exit $code). Install a Speech language '
            'pack (Vietnamese or English) in Windows Settings → Time & language '
            '→ Speech, and allow microphone access.',
          );
        }
      });
    } catch (e) {
      _listening = false;
      onError(e.toString());
    }
  }

  Future<void> stop() async {
    _listening = false;
    try {
      if (_pluginReady && _speech.isListening) {
        await _speech.stop();
      }
    } catch (_) {/* ignore */}
    await _killFallback();
  }

  Future<void> cancel() async {
    _listening = false;
    try {
      if (_pluginReady) {
        await _speech.cancel();
      }
    } catch (_) {/* ignore */}
    await _killFallback();
  }

  Future<void> _killFallback() async {
    await _psOutSub?.cancel();
    await _psErrSub?.cancel();
    _psOutSub = null;
    _psErrSub = null;
    final p = _psProcess;
    _psProcess = null;
    if (p != null) {
      try {
        p.kill(ProcessSignal.sigterm);
      } catch (_) {
        try {
          p.kill();
        } catch (_) {/* ignore */}
      }
    }
  }

  Future<void> dispose() async {
    await cancel();
  }
}
