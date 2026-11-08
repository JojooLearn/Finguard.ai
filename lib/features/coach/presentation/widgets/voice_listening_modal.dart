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
  final TextEditingController _textEditingController = TextEditingController();
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

    _textEditingController.addListener(() {
      if (mounted) setState(() {});
    });

    _startListeningSession();
  }

  @override
  void dispose() {
    _autoSendTimer?.cancel();
    _waveController.dispose();
    _textEditingController.dispose();
    widget.voiceIoService.stopListening();
    super.dispose();
  }

  Future<void> _startListeningSession() async {
    _autoSendTimer?.cancel();
    _isAutoSending = false;

    setState(() {
      _isListening = true;
      _statusMessage = 'Mendengarkan ucapanmu...';
    });

    final started = await widget.voiceIoService.startListening(
      onResult: (recognizedWords, isFinalResult) {
        if (!mounted) return;
        setState(() {
          _textEditingController.text = recognizedWords;
          _textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: recognizedWords.length),
          );
        });

        // Auto-send when final result is reached and not empty
        if (isFinalResult && recognizedWords.trim().isNotEmpty && !_isAutoSending) {
          _isAutoSending = true;
          _autoSendTimer?.cancel();
          _autoSendTimer = Timer(const Duration(milliseconds: 800), () {
            if (mounted) {
              _handleSend();
            }
          });
        }
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() {
          // Normalize sound level
          _soundLevel = math.max(0.0, math.min(1.0, (level + 2.0) / 10.0));
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() {
            _isListening = false;
            if (_textEditingController.text.trim().isEmpty) {
              _statusMessage = 'Sesi dengar selesai. Ketuk mikrofon untuk mulai lagi.';
            }
          });
        } else if (status == 'listening') {
          setState(() {
            _isListening = true;
            _statusMessage = 'Mendengarkan ucapanmu...';
          });
        }
      },
      onError: (errMsg) {
        if (!mounted) return;
        if (_textEditingController.text.trim().isNotEmpty) {
          return;
        }
        setState(() {
          _isListening = false;
          _statusMessage = errMsg.contains('no_match') || errMsg.contains('timeout')
              ? 'Suara belum terdeteksi. Ketuk mikrofon dan bicara lebih dekat ya!'
              : 'Status suara: $errMsg';
        });
      },
    );

    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _statusMessage = 'Gagal memulai rekaman. Ketuk mikrofon untuk coba lagi.';
      });
    }
  }

  Future<void> _stopListeningSession() async {
    await widget.voiceIoService.stopListening();
    if (mounted) {
      setState(() => _isListening = false);
    }
  }

  void _handleSend() {
    final textToSend = _textEditingController.text.trim();
    if (textToSend.isEmpty) return;

    _autoSendTimer?.cancel();
    widget.voiceIoService.stopListening();
    Navigator.of(context).pop();
    widget.onSend(textToSend);
  }

  void _handleCancel() {
    _autoSendTimer?.cancel();
    widget.voiceIoService.cancelListening();
    widget.onCancel();
  }

  @override
  Widget build(BuildContext context) {
    final hasWords = _textEditingController.text.trim().isNotEmpty;

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
                          : (_textEditingController.text.isNotEmpty
                              ? 'Siap Dikirim'
                              : 'Ketuk Mic untuk Bicara'),
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
                    ? 1.0 + (math.sin(wavePhase) * 0.05) + (_soundLevel * 0.12)
                    : 1.0;

                return Column(
                  children: [
                    // Mic Orb (tappable to start/stop listening)
                    GestureDetector(
                      onTap: () {
                        if (_isListening) {
                          _stopListeningSession();
                        } else {
                          _startListeningSession();
                        }
                      },
                      child: Transform.scale(
                        scale: pulseScale,
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _isListening
                                ? AppColors.aiAccentGradient
                                : const LinearGradient(
                                    colors: [Color(0xFF94A3B8), Color(0xFF64748B)],
                                  ),
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening
                                        ? AppColors.primary
                                        : const Color(0xFF64748B))
                                    .withValues(
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
                                  : PhosphorIcons.microphone(PhosphorIconsStyle.bold),
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isListening
                          ? 'Ketuk untuk jeda'
                          : 'Ketuk mikrofon untuk bicara',
                      style: GoogleFonts.urbanist(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Dynamic Waveform Bars
                    _buildWaveformBars(wavePhase),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // Live Transcription & Editable Text Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              constraints: const BoxConstraints(minHeight: 84),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: hasWords
                      ? AppColors.primary.withValues(alpha: 0.35)
                      : AppColors.neutral200.withValues(alpha: 0.8),
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
                        hasWords ? 'Suara Terdeteksi (bisa diedit):' : 'Petunjuk:',
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
                    TextField(
                      controller: _textEditingController,
                      maxLines: 3,
                      minLines: 1,
                      style: GoogleFonts.urbanist(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                        height: 1.4,
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
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
                    label: hasWords
                        ? 'Kirim Sekarang'
                        : (_isListening ? 'Mendengarkan...' : 'Mulai Bicara'),
                    onPressed: hasWords
                        ? _handleSend
                        : (_isListening ? null : _startListeningSession),
                    icon: Icon(
                      hasWords
                          ? Icons.arrow_upward_rounded
                          : (_isListening
                              ? PhosphorIcons.waveform(PhosphorIconsStyle.bold)
                              : PhosphorIcons.microphone(PhosphorIconsStyle.fill)),
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
            : 0.1;
        final dynamicBoost = _soundLevel * 30.0;
        final barHeight = math.max(
          6.0,
          (baseHeights[index] * 0.35) + (sineVal * baseHeights[index] * 0.65) + dynamicBoost,
        );

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3.5),
          width: 5,
          height: barHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: _isListening
                  ? const [
                      Color(0xFF8B5CF6),
                      Color(0xFF6366F1),
                    ]
                  : [
                      const Color(0xFFCBD5E1),
                      const Color(0xFF94A3B8),
                    ],
            ),
          ),
        );
      }),
    );
  }
}
