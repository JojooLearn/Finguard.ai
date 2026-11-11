import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Custom in-memory StreamAudioSource for `just_audio`.
/// Decodes Base64 audio into memory (`Uint8List`) and streams directly to the player
/// WITHOUT writing any physical `.mp3` or `.wav` files to local storage.
class InMemoryWavAudioSource extends StreamAudioSource {
  final Uint8List audioBytes;
  final String contentType;

  InMemoryWavAudioSource._({
    required this.audioBytes,
    required this.contentType,
    super.tag,
  });

  /// Creates an [InMemoryWavAudioSource] from a Base64-encoded audio string.
  /// Automatically strips data URL prefixes and wraps raw PCM16 in a 44-byte RIFF WAV header if needed.
  factory InMemoryWavAudioSource.fromBase64(String base64Audio, {dynamic tag}) {
    final cleaned = base64Audio
        .replaceFirst(RegExp(r'^data:audio\/[a-zA-Z0-9.+-]+;base64,'), '')
        .trim();
    final decoded = base64Decode(cleaned);
    final playableBytes = VoiceIoService.ensurePlayableWavBytes(decoded);
    final isMp3 = playableBytes.length >= 3 &&
        ((playableBytes[0] == 0x49 &&
                playableBytes[1] == 0x44 &&
                playableBytes[2] == 0x33) || // "ID3"
            (playableBytes[0] == 0xFF && (playableBytes[1] & 0xE0) == 0xE0));
    return InMemoryWavAudioSource._(
      audioBytes: playableBytes,
      contentType: isMp3 ? 'audio/mpeg' : 'audio/wav',
      tag: tag,
    );
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final effectiveStart = start ?? 0;
    final effectiveEnd = end ?? audioBytes.length;
    return StreamAudioResponse(
      sourceLength: audioBytes.length,
      contentLength: effectiveEnd - effectiveStart,
      offset: effectiveStart,
      stream: Stream.value(audioBytes.sublist(effectiveStart, effectiveEnd)),
      contentType: contentType,
    );
  }
}

/// Service handling On-Device Speech-to-Text (Voice-In) and On-Device Text-to-Speech (`flutter_tts` Voice-Out).
class VoiceIoService {
  final SpeechToText _speechToText;
  final FlutterTts _flutterTts;
  bool _isInitialized = false;
  bool _isTtsConfigured = false;
  bool _isSpeaking = false;

  VoidCallback? onTtsStateChanged;

  VoiceIoService({
    SpeechToText? speechToText,
    FlutterTts? flutterTts,
  })  : _speechToText = speechToText ?? SpeechToText(),
        _flutterTts = flutterTts ?? FlutterTts();

  bool get isListening => _speechToText.isListening;
  bool get isSpeaking => _isSpeaking;

  /// Configures on-device Indonesian Text-to-Speech (`id-ID`) with natural pitch and pace.
  Future<void> ensureTtsConfigured() async {
    if (_isTtsConfigured) return;
    try {
      await _flutterTts.setLanguage('id-ID');
      await _flutterTts.setPitch(1.0);
      // Note: FlutterTts scales Android rate * 2.0f internally (0.48 * 2.0 = 0.96x natural pace).
      await _flutterTts.setSpeechRate(0.48);
      await _flutterTts.setVolume(1.0);

      _flutterTts.setStartHandler(() {
        _isSpeaking = true;
        onTtsStateChanged?.call();
      });
      _flutterTts.setCompletionHandler(() {
        _isSpeaking = false;
        onTtsStateChanged?.call();
      });
      _flutterTts.setCancelHandler(() {
        _isSpeaking = false;
        onTtsStateChanged?.call();
      });
      _flutterTts.setPauseHandler(() {
        _isSpeaking = false;
        onTtsStateChanged?.call();
      });
      _flutterTts.setErrorHandler((_) {
        _isSpeaking = false;
        onTtsStateChanged?.call();
      });

      _isTtsConfigured = true;
    } catch (e) {
      debugPrint('VoiceIoService TTS init failed: $e');
    }
  }

  /// Cleans markdown formatting, box lines, and symbols before speaking aloud via `flutter_tts`.
  static String sanitizeTextForSpeech(String rawText) {
    var clean = rawText
        .replaceAll(RegExp(r'https?:\/\/\S+'), '')
        .replaceAll(RegExp(r'[━─═_]{3,}'), ', ')
        .replaceAll(RegExp(r'[*#`~>|]'), '')
        .replaceAllMapped(
          RegExp(r'(^|\n)\s*[•\-]\s+'),
          (m) => m.group(1) ?? '',
        )
        .replaceAllMapped(
          RegExp(r'Rp\.?\s*(\d[\d.]*)'),
          (m) => '${m.group(1)} rupiah',
        )
        .replaceAll(RegExp(r'\n+'), '. ')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    // Strip stray emoji / pictograph characters so TTS doesn't stall reading unicode descriptions
    clean = clean
        .replaceAll(
          RegExp(
            r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
            unicode: true,
          ),
          '',
        )
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
    return clean;
  }

  /// Speaks [text] aloud natively on-device using `flutter_tts` in Indonesian (`id-ID`).
  Future<void> speak(String text) async {
    final cleanText = sanitizeTextForSpeech(text);
    if (cleanText.isEmpty) return;

    await stopSpeaking();
    await ensureTtsConfigured();

    try {
      _isSpeaking = true;
      onTtsStateChanged?.call();
      await _flutterTts.speak(cleanText);
    } catch (e) {
      _isSpeaking = false;
      onTtsStateChanged?.call();
      debugPrint('VoiceIoService TTS speak failed: $e');
    }
  }

  /// Immediately stops any ongoing `flutter_tts` utterance.
  Future<void> stopSpeaking() async {
    try {
      await _flutterTts.stop();
    } catch (_) {
    } finally {
      if (_isSpeaking) {
        _isSpeaking = false;
        onTtsStateChanged?.call();
      } else {
        _isSpeaking = false;
      }
    }
  }

  /// Requests microphone permission and initializes on-device STT.
  Future<bool> ensurePermissionsAndInitialize({
    void Function(String status)? onStatus,
    void Function(String errorMsg)? onError,
  }) async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        onError?.call('Izin mikrofon diperlukan untuk fitur input suara.');
        return false;
      }
    } catch (_) {
      // On desktop/test environments where permission_handler is unavailable, proceed to SpeechToText init
    }

    try {
      if (!_isInitialized) {
        _isInitialized = await _speechToText.initialize(
          onStatus: onStatus,
          onError: (err) => onError?.call(err.errorMsg),
          options: [
            SpeechToText.androidNoBluetooth,
          ],
        );
      }
      _speechToText.statusListener = onStatus;
      if (onError != null) {
        _speechToText.errorListener = (err) => onError(err.errorMsg);
      }
      return _isInitialized;
    } catch (e) {
      onError?.call('Gagal menginisialisasi pengenalan suara: $e');
      return false;
    }
  }

  /// Starts on-device Speech-to-Text listening in Indonesian (`id_ID`) or device system locale.
  Future<bool> startListening({
    required void Function(String recognizedWords, bool isFinalResult) onResult,
    void Function(String status)? onStatus,
    void Function(String errorMsg)? onError,
    void Function(double soundLevel)? onSoundLevelChange,
    String? localeId,
  }) async {
    final ready = await ensurePermissionsAndInitialize(
      onStatus: onStatus,
      onError: (errMsg) {
        // Filter out benign pauses/silence timeouts so they do not crash or show red errors
        if (errMsg == 'error_no_match' || errMsg == 'error_speech_timeout') {
          return;
        }
        onError?.call(errMsg);
      },
    );
    if (!ready) return false;

    // Reset any previously active listening session cleanly
    try {
      if (_speechToText.isListening) {
        await _speechToText.cancel();
      }
    } catch (_) {}

    // Fast-resolve preferred locale without hanging broadcast queries
    String? effectiveLocale = localeId;
    if (effectiveLocale == null) {
      try {
        final sys = await _speechToText
            .systemLocale()
            .timeout(const Duration(milliseconds: 300), onTimeout: () => null);
        if (sys != null && sys.localeId.isNotEmpty) {
          effectiveLocale = sys.localeId;
        }
      } catch (_) {}
    }

    await _speechToText.listen(
      onResult: (SpeechRecognitionResult result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      onSoundLevelChange: onSoundLevelChange,
      listenOptions: SpeechListenOptions(
        localeId: effectiveLocale ?? 'id_ID',
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: false,
        pauseFor: const Duration(seconds: 8),
        listenFor: const Duration(seconds: 45),
      ),
    );
    return true;
  }

  /// Stops active STT recording.
  Future<void> stopListening() async {
    try {
      if (_speechToText.isListening) {
        await _speechToText.stop();
      }
    } catch (_) {}
  }

  /// Cancels active STT recording immediately.
  Future<void> cancelListening() async {
    try {
      await _speechToText.cancel();
    } catch (_) {}
  }

  /// Ensures raw audio bytes have a valid container header (RIFF WAV or MP3).
  /// If raw 16-bit 24kHz mono PCM bytes are received from Gemini, prepends a 44-byte RIFF WAV header.
  static Uint8List ensurePlayableWavBytes(
    Uint8List rawBytes, {
    int sampleRate = 24000,
    int numChannels = 1,
    int bitsPerSample = 16,
  }) {
    if (rawBytes.length >= 4) {
      // Check "RIFF" (WAV)
      final isRiff = rawBytes[0] == 0x52 &&
          rawBytes[1] == 0x49 &&
          rawBytes[2] == 0x46 &&
          rawBytes[3] == 0x46;
      // Check "ID3" or MP3 frame sync
      final isMp3 = (rawBytes[0] == 0x49 &&
              rawBytes[1] == 0x44 &&
              rawBytes[2] == 0x33) ||
          (rawBytes[0] == 0xFF && (rawBytes[1] & 0xE0) == 0xE0);
      if (isRiff || isMp3) {
        return rawBytes;
      }
    }

    final byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final blockAlign = numChannels * (bitsPerSample ~/ 8);
    final dataSize = rawBytes.length;
    final wavBuffer = ByteData(44 + dataSize);

    // "RIFF"
    wavBuffer.setUint8(0, 0x52);
    wavBuffer.setUint8(1, 0x49);
    wavBuffer.setUint8(2, 0x46);
    wavBuffer.setUint8(3, 0x46);
    wavBuffer.setUint32(4, 36 + dataSize, Endian.little);
    // "WAVE"
    wavBuffer.setUint8(8, 0x57);
    wavBuffer.setUint8(9, 0x41);
    wavBuffer.setUint8(10, 0x56);
    wavBuffer.setUint8(11, 0x45);
    // "fmt "
    wavBuffer.setUint8(12, 0x66);
    wavBuffer.setUint8(13, 0x6D);
    wavBuffer.setUint8(14, 0x74);
    wavBuffer.setUint8(15, 0x20);
    wavBuffer.setUint32(16, 16, Endian.little); // PCM chunk size
    wavBuffer.setUint16(20, 1, Endian.little); // AudioFormat 1 = PCM
    wavBuffer.setUint16(22, numChannels, Endian.little);
    wavBuffer.setUint32(24, sampleRate, Endian.little);
    wavBuffer.setUint32(28, byteRate, Endian.little);
    wavBuffer.setUint16(32, blockAlign, Endian.little);
    wavBuffer.setUint16(34, bitsPerSample, Endian.little);
    // "data"
    wavBuffer.setUint8(36, 0x64);
    wavBuffer.setUint8(37, 0x61);
    wavBuffer.setUint8(38, 0x74);
    wavBuffer.setUint8(39, 0x61);
    wavBuffer.setUint32(40, dataSize, Endian.little);

    final out = wavBuffer.buffer.asUint8List();
    out.setRange(44, 44 + dataSize, rawBytes);
    return out;
  }

  /// Generates a valid, playable in-memory 24kHz 16-bit mono WAV Base64 audio stream
  /// when running in offline/local fallback mode with `requestAudio == true`.
  static String generateSynthesizedCoachVoiceWavBase64(String replyText) {
    const sampleRate = 24000;
    // Scale duration gently by text length (0.45s to 0.9s) for responsive feedback
    final durationSeconds =
        (0.45 + (replyText.length.clamp(10, 180) / 400.0)).clamp(0.45, 0.9);
    final totalSamples = (sampleRate * durationSeconds).round();
    final pcmData = ByteData(totalSamples * 2);

    for (int i = 0; i < totalSamples; i++) {
      final t = i / sampleRate;
      final progress = i / totalSamples;
      // Pleasant two-note chime envelope (523.25 Hz C5 -> 659.25 Hz E5)
      final freq = progress < 0.45 ? 523.25 : 659.25;
      final envelope = math.sin(progress * math.pi);
      final sampleValue =
          (math.sin(2 * math.pi * freq * t) * 8000 * envelope).round();
      pcmData.setInt16(i * 2, sampleValue.clamp(-32768, 32767), Endian.little);
    }

    final wavBytes = ensurePlayableWavBytes(
      pcmData.buffer.asUint8List(),
      sampleRate: sampleRate,
    );
    return base64Encode(wavBytes);
  }
}
