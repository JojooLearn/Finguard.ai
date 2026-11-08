import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/services/voice_io_service.dart';

/// Modal bottom sheet popup that visually represents real-time listening
/// with animated sound waves, mic pulsing orb, and live transcription.
class VoiceListeningModal extends StatefulWidget {
  final VoiceIoService voiceIoService;
  final ValueChanged<String> onSend;
  final VoidCallback onCancel;

  const VoiceListeningModal({
    super.key,
    required this.voiceIoService,
    required this.onSend,
    required this.onCancel,
  });

  static Future<void> show({
    required BuildContext context,
    required VoiceIoService voiceIoService,
    required ValueChanged<String> onSend,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => VoiceListeningModal(
        voiceIoService: voiceIoService,
        onSend: onSend,
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  State<VoiceListeningModal> createState() => _VoiceListeningModalState();
}

class _VoiceListeningModalState extends State<VoiceListeningModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  String _recognizedWords = '';
  double _soundLevel = 0.0;
  bool _isListening = false;
  bool _isAutoSending = false;
  String? _statusMessage;
  Timer? _autoSendTimer;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _startListeningSession();
  }

  @override
  void dispose() {
    _autoSendTimer?.cancel();
    _waveController.dispose();
    widget.voiceIoService.stopListening();
    super.dispose();
  }

  Future<void> _startListeningSession() async {
    setState(() {
      _isListening = true;
      _statusMessage = 'Mendengarkan ucapanmu...';
    });

    final started = await widget.voiceIoService.startListening(
      onResult: (recognizedWords, isFinalResult) {
        if (!mounted) return;
        setState(() {
          _recognizedWords = recognizedWords;
        });

        // If the speech engine gives a final result with non-empty text, trigger auto-send after a brief pause
        if (isFinalResult && recognizedWords.trim().isNotEmpty && !_isAutoSending) {
          _isAutoSending = true;
          _autoSendTimer?.cancel();
          _autoSendTimer = Timer(const Duration(milliseconds: 750), () {
            if (mounted) {
              _handleSend();
            }
          });
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() {
          // Normalize level (typically -2 to 10 on Android)
          _soundLevel = math.max(0.0, math.min(1.0, (level + 2.0) / 10.0));
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() => _isListening = false);
        }
      },
      onError: (errMsg) {
        if (!mounted) return;
        if (_recognizedWords.trim().isNotEmpty) {
          // If we already have recognized text, ignore trailing timeout errors
          return;
        }
        setState(() {
          _isListening = false;
          _statusMessage = errMsg.contains('no_match') || errMsg.contains('timeout')
              ? 'Suara belum terdeteksi. Coba bicara lebih dekat ya!'
              : 'Mikrofon: $errMsg';
        });
      },
    );

    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = 'Gagal mengakses mikrofon. Pastikan izin sudah aktif.';
      });
    }
  }

  void _handleSend() {
    final textToSend = _recognizedWords.trim();
    if (textToSend.isEmpty) return;

    _autoSendTimer?.cancel();
    widget.voiceIoService.stopListening();
    Navigator.of(context).pop();
    widget.onSend(textToSend);
  }

  void _handleCancel() {
    _autoSendTimer?.cancel();
    widget.voiceIoService.stopListening();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final hasWords = _recognizedWords.trim().isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: AppSpacing.glowShadow,
      ),
      padding: EdgeInsets.only(
        top: 14,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle pill
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.neutral200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _isListening
                            ? const Color(0xFF10B981)
                            : AppColors.textSecondary,
                        shape: BoxShape.circle,
                        boxShadow: _isListening
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                  blurRadius: 6,
                                  spreadRadius: 2,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isListening
                          ? 'Mendengarkan Suara...'
                          : 'Pengenalan Suara Selesai',
                      style: GoogleFonts.urbanist(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isListening
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: _handleCancel,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.neutral100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Pulsing Mic Orb & Waveform Visualization
            AnimatedBuilder(
              animation: _waveController,
              builder: (context, child) {
                final wavePhase = _waveController.value * 2 * math.pi;
                final pulseScale = _isListening
                    ? 1.0 + (math.sin(wavePhase) * 0.06) + (_soundLevel * 0.12)
                    : 1.0;

                return Column(
                  children: [
                    // Mic Orb with ripple circles
                    Transform.scale(
                      scale: pulseScale,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.aiAccentGradient,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(
                                alpha: _isListening ? 0.35 : 0.15,
                              ),
                              blurRadius: 24,
                              spreadRadius: _isListening ? 4 : 1,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            _isListening
                                ? PhosphorIcons.microphone(PhosphorIconsStyle.fill)
                                : PhosphorIcons.microphoneSlash(PhosphorIconsStyle.fill),
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Dynamic Waveform Bars
                    _buildWaveformBars(wavePhase),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Live Transcription Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 84),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: hasWords
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : AppColors.neutral200.withValues(alpha: 0.7),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        hasWords
                            ? PhosphorIcons.chatCircleDots(PhosphorIconsStyle.fill)
                            : PhosphorIcons.info(PhosphorIconsStyle.bold),
                        size: 15,
                        color: hasWords ? AppColors.primary : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        hasWords ? 'Suara Terdeteksi:' : 'Petunjuk:',
                        style: GoogleFonts.urbanist(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: hasWords ? AppColors.primary : AppColors.textSecondary,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (hasWords) ...[
                    Text(
                      '"$_recognizedWords"',
                      style: GoogleFonts.urbanist(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                    if (_isAutoSending) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Mengirim otomatis...',
                        style: GoogleFonts.urbanist(
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ] else ...[
                    Text(
                      _statusMessage ?? 'Bicara sekarang, misalnya:\n"Catat makan siang 35 ribu" atau "Analisa saham BBCA"',
                      style: GoogleFonts.urbanist(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons Row
            Row(
              children: [
                TextButton(
                  onPressed: _handleCancel,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                  child: Text(
                    'Batal',
                    style: GoogleFonts.urbanist(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    label: hasWords ? 'Kirim Sekarang' : 'Mendengarkan...',
                    onPressed: hasWords ? _handleSend : null,
                    icon: const Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 7 animated audio bars that fluctuate smoothly with sine math and sound level
  Widget _buildWaveformBars(double phase) {
    const barCount = 7;
    const baseHeights = [10.0, 20.0, 32.0, 24.0, 36.0, 22.0, 12.0];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(barCount, (index) {
        final offset = index * 0.6;
        final sineVal = _isListening
            ? (math.sin(phase + offset) + 1.0) / 2.0
            : 0.2;
        final dynamicBoost = _soundLevel * 22.0;
        final barHeight = math.max(
          6.0,
          (baseHeights[index] * 0.45) + (sineVal * baseHeights[index] * 0.55) + dynamicBoost,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: 5,
          height: barHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF8B5CF6),
                Color(0xFF6366F1),
              ],
            ),
          ),
        );
      }),
    );
  }
}

