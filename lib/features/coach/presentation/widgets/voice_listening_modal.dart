import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/services/voice_io_service.dart';

/// Modal bottom sheet popup that visually represents real-time listening
/// with the reactive Lottie voice animation and live transcription.
class VoiceListeningModal extends StatefulWidget {
  final VoiceIoService voiceIoService;
  final ValueChanged<String> onSend;
  final VoidCallback? onCancel;

  const VoiceListeningModal({
    super.key,
    required this.voiceIoService,
    required this.onSend,
    this.onCancel,
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

class _VoiceListeningModalState extends State<VoiceListeningModal> {
  final TextEditingController _textEditingController = TextEditingController();
  double _soundLevel = 0.0;
  bool _isListening = false;
  String? _statusMessage;

  @override
  void initState() {
    super.initState();
    _textEditingController.addListener(() {
      if (mounted) setState(() {});
    });

    // Start listening gently after bottom-sheet slide animation settles
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _startListeningSession();
        }
      });
    });
  }

  @override
  void dispose() {
    _textEditingController.dispose();
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
          _textEditingController.text = recognizedWords;
          _textEditingController.selection = TextSelection.fromPosition(
            TextPosition(offset: recognizedWords.length),
          );
        });
      },
      onSoundLevelChange: (level) {
        if (!mounted) return;
        setState(() {
          // Normalize sound level: quiet (< 0.05) vs active speech (0.1 - 1.0)
          _soundLevel = math.max(0.0, math.min(1.0, (level + 2.0) / 10.0));
        });
      },
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'notListening' || status == 'done') {
          setState(() {
            _isListening = false;
            _soundLevel = 0.0;
            if (_textEditingController.text.trim().isEmpty) {
              _statusMessage =
                  'Sesi dengar selesai. Ketuk mikrofon atau tombol di bawah untuk mulai lagi.';
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
          _soundLevel = 0.0;
          _statusMessage =
              errMsg.contains('no_match') || errMsg.contains('timeout')
              ? 'Suara belum terdeteksi. Bicara lebih dekat ke mikrofon ya!'
              : 'Status suara: $errMsg';
        });
      },
    );

    if (!started && mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
        _statusMessage =
            'Gagal memulai rekaman. Ketuk mikrofon untuk coba lagi.';
      });
    }
  }

  Future<void> _stopListeningSession() async {
    await widget.voiceIoService.stopListening();
    if (mounted) {
      setState(() {
        _isListening = false;
        _soundLevel = 0.0;
      });
    }
  }

  void _handleSend() {
    final textToSend = _textEditingController.text.trim();
    if (textToSend.isEmpty) return;

    widget.voiceIoService.stopListening();
    Navigator.of(context).pop();
    widget.onSend(textToSend);
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
            // Drag handle pill (swipe down or tap outside barrier to close)
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

            // Header Status Pill (redundant close 'X' removed — tap outside or drag down to dismiss)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
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
                              color: const Color(
                                0xFF10B981,
                              ).withValues(alpha: 0.6),
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
                      : (hasWords ? 'Siap Dikirim' : 'Mode Suara FinGuard'),
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
            const SizedBox(height: 16),

            // Sound-Reactive Lottie Voice Animation (assets/animations/voice_listening.json)
            Column(
              children: [
                GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopListeningSession();
                    } else {
                      _startListeningSession();
                    }
                  },
                  child: AnimatedScale(
                    scale: _isListening ? (1.0 + (_soundLevel * 0.16)) : 0.92,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOut,
                    child: AnimatedOpacity(
                      opacity: _isListening ? 1.0 : 0.58,
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        width: 148,
                        height: 148,
                        child: Lottie.asset(
                          'assets/animations/voice_listening.json',
                          animate: _isListening,
                          repeat: true,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _isListening
                      ? 'Mendengarkan... Ketuk animasi untuk jeda'
                      : (hasWords
                            ? 'Selesai bicara. Ketuk animasi untuk lanjut bicara'
                            : 'Ketuk animasi mikrofon untuk mulai bicara'),
                  style: GoogleFonts.urbanist(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isListening
                        ? AppColors.primary
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Live Dynamic Transcription Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 96),
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            hasWords
                                ? PhosphorIcons.chatCircleDots(
                                    PhosphorIconsStyle.fill,
                                  )
                                : (_isListening
                                      ? PhosphorIcons.waveform(
                                          PhosphorIconsStyle.bold,
                                        )
                                      : PhosphorIcons.info(
                                          PhosphorIconsStyle.bold,
                                        )),
                            size: 16,
                            color: hasWords || _isListening
                                ? AppColors.primary
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hasWords
                                ? 'Teks Terdeteksi (bisa diedit):'
                                : (_isListening
                                      ? 'Mendengarkan...'
                                      : 'Petunjuk:'),
                            style: GoogleFonts.urbanist(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: hasWords || _isListening
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      if (_isListening && hasWords)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF10B981,
                            ).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Aktif mencatat',
                                style: GoogleFonts.urbanist(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (hasWords) ...[
                    TextField(
                      controller: _textEditingController,
                      maxLines: 4,
                      minLines: 2,
                      style: GoogleFonts.urbanist(
                        fontSize: 16,
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
                  ] else ...[
                    Text(
                      _isListening
                          ? 'Silakan bicara sekarang... Ucapanmu akan langsung tertulis di sini.'
                          : (_statusMessage ??
                                'Ketuk tombol "Mulai Bicara" untuk merekam ucapanmu.'),
                      style: GoogleFonts.urbanist(
                        fontSize: 13.5,
                        color: _isListening
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Primary Action CTA (redundant 'Batal' button removed — tap outside to dismiss)
            AppButton(
              label: hasWords
                  ? 'Kirim Pesan'
                  : (_isListening ? 'Selesai Bicara' : 'Mulai Bicara'),
              onPressed: hasWords
                  ? _handleSend
                  : (_isListening
                        ? _stopListeningSession
                        : _startListeningSession),
              icon: Icon(
                hasWords
                    ? Icons.arrow_upward_rounded
                    : (_isListening
                          ? PhosphorIcons.stop(PhosphorIconsStyle.bold)
                          : PhosphorIcons.microphone(
                              PhosphorIconsStyle.fill,
                            )),
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
