import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/chat_message_entity.dart';
import '../../domain/services/receipt_scanner_service.dart';
import '../../domain/services/voice_io_service.dart';
import '../../../budgets/presentation/cubit/budget_cubit.dart';
import '../../../goals/presentation/cubit/goal_cubit.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../../../transactions/presentation/cubit/transaction_cubit.dart';
import '../cubit/coach_cubit.dart';
import '../cubit/coach_state.dart';
import '../widgets/voice_listening_modal.dart';

class CoachPage extends StatefulWidget {
  final bool? isKeyboardOpen;
  final bool isActive;
  final VoiceIoService? voiceIoService;

  const CoachPage({
    super.key,
    this.isKeyboardOpen,
    this.isActive = true,
    this.voiceIoService,
  });

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> with WidgetsBindingObserver {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ReceiptScannerService _scannerService = ReceiptScannerService();
  late final VoiceIoService _voiceIoService;

  static const int _messageBatchSize = 20;
  int _visibleMessageCount = _messageBatchSize;
  int _currentTotalMessages = 0;
  bool _isLoadingOlderMessages = false;
  String? _lastTrackedConversationId;

  AudioPlayer? _audioPlayer;
  StreamSubscription<PlayerState>? _playerStateSub;
  String? _activePlayingMessageId;
  bool _isAudioPlaying = false;
  bool _isTtsSpeaking = false;
  String? _lastAutoPlayedMessageId;

  bool _hasInputText = false;
  bool _initializedConfirmedSnapshot = false;
  final Set<String> _knownConfirmedTxIds = {};
  Timer? _txPopupTimer;
  bool _isListeningVoice = false;
  bool _isVoiceOrigin = false;
  bool _isUpdatingTextFromStt = false;

  Uint8List? _selectedReceiptBytes;
  String? _selectedReceiptName;
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voiceIoService = widget.voiceIoService ?? VoiceIoService();
    _voiceIoService.onTtsStateChanged = () {
      if (!mounted) return;
      setState(() {
        _isTtsSpeaking = _voiceIoService.isSpeaking;
      });
    };
    _scrollController.addListener(_onChatScroll);
    _textController.addListener(_onTextChanged);
    final cubit = context.read<CoachCubit>();
    if (cubit.state is CoachLoaded) {
      final loaded = cubit.state as CoachLoaded;
      _knownConfirmedTxIds.addAll(
        loaded.messages.where((m) => m.isConfirmed).map((m) => m.id),
      );
      _initializedConfirmedSnapshot = true;
    }
    if (cubit.state is CoachInitial) {
      cubit.loadChatHistory();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _stopActiveVoiceOut();
    }
  }

  void _onTextChanged() {
    final nonEmpty = _textController.text.trim().isNotEmpty;
    if (!_isUpdatingTextFromStt) {
      if (!nonEmpty) {
        _isVoiceOrigin = false;
      } else if (!_isListeningVoice) {
        // User typed manually via keyboard
        _isVoiceOrigin = false;
      }
    }
    if (nonEmpty != _hasInputText && mounted) {
      setState(() {
        _hasInputText = nonEmpty;
      });
    }
  }

  AudioPlayer _getOrCreateAudioPlayer() {
    if (_audioPlayer != null) return _audioPlayer!;
    final player = AudioPlayer();
    _audioPlayer = player;
    _playerStateSub = player.playerStateStream.listen((playerState) {
      if (!mounted) return;
      final completed =
          playerState.processingState == ProcessingState.completed;
      if (completed) {
        player.seek(Duration.zero);
        player.pause();
        setState(() {
          _isAudioPlaying = false;
        });
      } else {
        final playing = playerState.playing;
        if (playing != _isAudioPlaying) {
          setState(() {
            _isAudioPlaying = playing;
          });
        }
      }
    });
    return player;
  }

  Future<void> _stopActiveVoiceOut() async {
    await _voiceIoService.stopSpeaking();
    try {
      await _audioPlayer?.stop();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _isAudioPlaying = false;
        _isTtsSpeaking = false;
      });
    }
  }

  int? _resolveActiveStrictnessLevel() {
    try {
      final profileState = context.read<ProfileCubit>().state;
      if (profileState is ProfileLoaded) {
        return profileState.profile.strictnessLevel;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _togglePlayMessageAudio(ChatMessageEntity message) async {
    final isCurrentTtsPlaying =
        _activePlayingMessageId == message.id && _isTtsSpeaking;
    final isCurrentWavPlaying =
        _activePlayingMessageId == message.id && _isAudioPlaying;

    if (isCurrentTtsPlaying || isCurrentWavPlaying) {
      await _stopActiveVoiceOut();
      return;
    }

    await _stopActiveVoiceOut();
    if (mounted) {
      setState(() {
        _activePlayingMessageId = message.id;
      });
    }

    final strictnessLevel = _resolveActiveStrictnessLevel();

    // Primary: Gemini Native HD Voice-Out WAV (`audio_base64` returned from Edge Function)
    final base64Str = message.effectiveAudioBase64;
    if (base64Str != null && base64Str.isNotEmpty) {
      try {
        final player = _getOrCreateAudioPlayer();
        if (mounted) setState(() => _isAudioPlaying = true);

        final source = InMemoryWavAudioSource.fromBase64(
          base64Str,
          tag: message.id,
        );
        await player.setAudioSource(source);
        await player.play();
        return;
      } catch (e) {
        debugPrint(
          'Gemini HD audio playback error (falling back to local TTS): $e',
        );
        if (mounted) {
          setState(() {
            _isAudioPlaying = false;
          });
        }
      }
    }

    // Fallback: On-Device TTS (`flutter_tts`) tuned per active Coach character
    await _voiceIoService.speak(
      message.content,
      strictnessLevel: strictnessLevel,
    );
  }

  void _toggleVoiceInput() {
    _stopActiveVoiceOut();
    VoiceListeningModal.show(
      context: context,
      voiceIoService: _voiceIoService,
      onSend: (spokenText) {
        _sendMessage(spokenText, true);
      },
    );
  }

  @override
  void didUpdateWidget(covariant CoachPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isKeyboardOpen == true && oldWidget.isKeyboardOpen != true) {
      _scrollToBottom();
    }
    if (oldWidget.isActive && !widget.isActive) {
      _stopActiveVoiceOut();
    }
  }

  void _showScanSourceSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Scan Nota / Lampirkan Struk',
                  style: AppTypography.screenTitle.copyWith(fontSize: 17),
                ),
                const SizedBox(height: 4),
                Text(
                  'Pilih sumber foto struk belanja untuk dicatat otomatis oleh AI Coach.',
                  style: AppTypography.bodySecondary.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _pickImage(ImageSource.camera);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceFieldFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIcons.camera(PhosphorIconsStyle.bold),
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Kamera',
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Foto struk langsung',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _pickImage(ImageSource.gallery);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceFieldFill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.15),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryLight.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  PhosphorIcons.image(PhosphorIconsStyle.bold),
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Galeri',
                                style: AppTypography.body.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Pilih foto tersimpan',
                                style: AppTypography.caption.copyWith(
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() => _isProcessingImage = true);
      final picked = await _scannerService.pickReceiptImage(source);
      if (picked == null) {
        setState(() => _isProcessingImage = false);
        return;
      }

      final rawBytes = await picked.readAsBytes();
      final compressed = await _scannerService.compressImageBytes(rawBytes);
      final validationError = ReceiptScannerService.validateReceiptImage(
        fileName: picked.name,
        bytes: compressed,
      );
      if (validationError != null) {
        setState(() => _isProcessingImage = false);
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: Text(validationError),
              backgroundColor: AppColors.danger,
            ),
          );
        return;
      }

      setState(() {
        _selectedReceiptBytes = compressed;
        _selectedReceiptName = picked.name;
        _isProcessingImage = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isProcessingImage = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            content: Text('Gagal memilih nota: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
    }
  }

  Future<void> _sendMessage([
    String? presetText,
    bool? forceRequestAudio,
  ]) async {
    final text = presetText ?? _textController.text.trim();
    final hasReceipt = _selectedReceiptBytes != null;

    if (text.isEmpty && !hasReceipt) return;

    final shouldRequestAudio =
        forceRequestAudio ?? (presetText == null && _isVoiceOrigin);

    _stopActiveVoiceOut();

    if (_isListeningVoice) {
      await _voiceIoService.stopListening();
    }

    if (presetText == null) {
      _isUpdatingTextFromStt = true;
      _textController.clear();
      _isUpdatingTextFromStt = false;
    }

    if (!mounted) return;
    setState(() {
      _isListeningVoice = false;
      _isVoiceOrigin = false;
      _hasInputText = _textController.text.trim().isNotEmpty;
    });

    if (hasReceipt) {
      final receiptBytes = _selectedReceiptBytes!;
      setState(() {
        _selectedReceiptBytes = null;
        _selectedReceiptName = null;
      });

      final receiptBase64 = base64Encode(receiptBytes);
      final userId =
          Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
      final storagePath =
          '$userId/${DateTime.now().millisecondsSinceEpoch}_receipt.jpg';

      // Non-blocking background upload to Supabase Storage while AI OCR runs immediately via inline base64
      _scannerService
          .uploadReceiptToStorage(bytes: receiptBytes, userId: userId)
          .catchError((_) => storagePath);

      if (!mounted) return;
      context.read<CoachCubit>().sendReceiptScan(
        receiptPath: storagePath,
        receiptBase64: receiptBase64,
        caption: text.isNotEmpty ? text : null,
      );
    } else {
      if (!mounted) return;
      int? currentStrictness;
      try {
        final profileState = context.read<ProfileCubit>().state;
        if (profileState is ProfileLoaded) {
          currentStrictness = profileState.profile.strictnessLevel;
        }
      } catch (_) {}

      context.read<CoachCubit>().sendMessage(
        text,
        requestAudio: shouldRequestAudio,
        strictnessLevel: currentStrictness,
      );
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 150), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _onChatScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <= 30 && !_isLoadingOlderMessages) {
      if (_visibleMessageCount < _currentTotalMessages) {
        _isLoadingOlderMessages = true;
        final oldMaxScroll = _scrollController.position.maxScrollExtent;
        final oldOffset = _scrollController.position.pixels;
        setState(() {
          _visibleMessageCount = (_visibleMessageCount + _messageBatchSize)
              .clamp(_messageBatchSize, _currentTotalMessages);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            final newMaxScroll = _scrollController.position.maxScrollExtent;
            final delta = newMaxScroll - oldMaxScroll;
            if (delta > 0) {
              _scrollController.jumpTo(oldOffset + delta);
            }
          }
          _isLoadingOlderMessages = false;
        });
      }
    }
  }

  @override
  void deactivate() {
    _stopActiveVoiceOut();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _txPopupTimer?.cancel();
    _voiceIoService.onTtsStateChanged = null;
    _voiceIoService.stopSpeaking();
    _textController.removeListener(_onTextChanged);
    _scrollController.removeListener(_onChatScroll);
    _playerStateSub?.cancel();
    _audioPlayer?.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String coachAvatarAsset = 'assets/icons/coach_mode_pro.png';
    try {
      final profileState = context.watch<ProfileCubit>().state;
      if (profileState is ProfileLoaded) {
        final level = profileState.profile.strictnessLevel;
        if (level >= 4) {
          coachAvatarAsset = 'assets/icons/coach_mode_roast.png';
        } else if (level <= 2) {
          coachAvatarAsset = 'assets/icons/coach_mode_supportive.png';
        }
      }
    } catch (_) {}

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        _stopActiveVoiceOut();
      },
      child: Column(
        children: [
          // Top Header (finguard_desig.md 7.4)
          Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.sideMargin,
              right: AppSpacing.sideMargin,
              top: 12,
              bottom: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        gradient: AppColors.aiAccentGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppSpacing.glowShadow,
                      ),
                      child: Image.asset(
                        coachAvatarAsset,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: Icon(
                            PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Financial Coach',
                          style: AppTypography.screenTitle.copyWith(
                            fontSize: 18,
                          ),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.income,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Database Terhubung',
                              style: AppTypography.caption.copyWith(
                                fontSize: 11,
                                color: AppColors.income,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    AppIconButton(
                      icon: PhosphorIcons.plus(),
                      onPressed: () {
                        _stopActiveVoiceOut();
                        context.read<CoachCubit>().startNewConversation();
                      },
                    ),
                    const SizedBox(width: 10),
                    AppIconButton(
                      icon: PhosphorIcons.clockCounterClockwise(),
                      onPressed: () {
                        _stopActiveVoiceOut();
                        context.push('/coach/history');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Chat Message Area
          Expanded(
            child: BlocConsumer<CoachCubit, CoachState>(
              listener: (context, state) {
                if (state is CoachLoading) {
                  _initializedConfirmedSnapshot = false;
                  _knownConfirmedTxIds.clear();
                  return;
                }
                if (state is CoachLoaded) {
                  if (!_initializedConfirmedSnapshot) {
                    _knownConfirmedTxIds.addAll(
                      state.messages
                          .where((m) => m.isConfirmed)
                          .map((m) => m.id),
                    );
                    _initializedConfirmedSnapshot = true;
                  } else {
                    ChatMessageEntity? newestConfirmedTx;
                    for (final m in state.messages) {
                      if (m.isConfirmed &&
                          !_knownConfirmedTxIds.contains(m.id)) {
                        _knownConfirmedTxIds.add(m.id);
                        if (m.structuredPayload != null &&
                            m.structuredPayload!['amount'] != null) {
                          newestConfirmedTx = m;
                        }
                      }
                    }
                    if (newestConfirmedTx != null) {
                      final payload = newestConfirmedTx.structuredPayload!;
                      final isEmergencyDeposit =
                          payload['funding_source'] ==
                              'emergency_fund_deposit' ||
                          payload['type'] == 'goal_deposit';
                      final isIncome =
                          !isEmergencyDeposit && payload['type'] == 'income';
                      final amount =
                          (payload['amount'] as num?)?.toDouble() ?? 0.0;
                      if (!isEmergencyDeposit && amount > 0) {
                        _showTransactionLottiePopup(
                          isIncome: isIncome,
                          amount: amount,
                          note: payload['note']?.toString(),
                        );
                      }
                    }
                  }

                  if (state.confirmFeedbackMessage != null &&
                      state.confirmFeedbackMessage!.isNotEmpty) {
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(
                          content: Text(state.confirmFeedbackMessage!),
                          backgroundColor: AppColors.expenseRed,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    context.read<CoachCubit>().clearConfirmFeedback();
                  }
                  _scrollToBottom();
                  if (!state.isSending && state.messages.isNotEmpty) {
                    final latest = state.messages.last;
                    final shouldAutoSpeak =
                        !latest.isUser &&
                        widget.isActive &&
                        (latest.autoSpeak || latest.hasAudio) &&
                        _lastAutoPlayedMessageId != latest.id;
                    if (shouldAutoSpeak) {
                      _lastAutoPlayedMessageId = latest.id;
                      _togglePlayMessageAudio(latest);
                    }
                  }
                }
              },
              builder: (context, state) {
                if (state is CoachLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                List<ChatMessageEntity> messages = [];
                bool isSending = false;
                bool isScanningReceipt = false;

                if (state is CoachLoaded) {
                  messages = state.messages;
                  isSending = state.isSending;
                  isScanningReceipt = state.isScanningReceipt;

                  final currentConvId = messages.isNotEmpty
                      ? messages.first.conversationId
                      : null;
                  if (_lastTrackedConversationId != null &&
                      _lastTrackedConversationId != currentConvId) {
                    _visibleMessageCount = _messageBatchSize;
                  }
                  _lastTrackedConversationId = currentConvId;
                }

                _currentTotalMessages = messages.length;
                final bool hasOlderMessages =
                    messages.length > _visibleMessageCount;
                final List<ChatMessageEntity> visibleMessages = hasOlderMessages
                    ? messages.sublist(messages.length - _visibleMessageCount)
                    : messages;
                final int olderHeaderCount = hasOlderMessages ? 1 : 0;
                final int typingCount = isSending ? 1 : 0;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    left: AppSpacing.sideMargin,
                    right: AppSpacing.sideMargin,
                    top: 8,
                    bottom: 12,
                  ),
                  physics: const BouncingScrollPhysics(),
                  itemCount:
                      olderHeaderCount + visibleMessages.length + typingCount,
                  itemBuilder: (context, index) {
                    if (hasOlderMessages && index == 0) {
                      return _buildLoadOlderMessagesHeader(
                        remainingCount: messages.length - _visibleMessageCount,
                        onTap: () {
                          setState(() {
                            _visibleMessageCount =
                                (_visibleMessageCount + _messageBatchSize)
                                    .clamp(_messageBatchSize, messages.length);
                          });
                        },
                      );
                    }

                    final adjustedIndex =
                        hasOlderMessages ? index - 1 : index;

                    if (adjustedIndex == visibleMessages.length && isSending) {
                      return _buildTypingIndicator(
                        isScanningReceipt: isScanningReceipt,
                      );
                    }
                    final msg = visibleMessages[adjustedIndex];

                    if (msg.isRetryable) {
                      return _buildErrorBubble(msg);
                    }

                    if (msg.needsClarification) {
                      return _buildClarificationBubble(msg);
                    }

                    return _buildMessageBubble(msg);
                  },
                );
              },
            ),
          ),

          // Bottom Section: Quick Suggestions (nempel tepat di atas field input) + Input Bar
          Builder(
            builder: (context) {
              final keyboardOpen =
                  widget.isKeyboardOpen ??
                  (View.of(context).viewInsets.bottom > 0 ||
                      MediaQuery.of(context).viewInsets.bottom > 0);
              final safeBottom = MediaQuery.of(context).padding.bottom;
              // Inside MainScaffold (extendBody: true), safeBottom already includes
              // FloatingNavBar height (>= 80px). Avoid double-adding 96px!
              final bottomPadding = keyboardOpen
                  ? 8.0
                  : (safeBottom >= 80.0
                        ? (safeBottom + 8.0)
                        : (safeBottom + 96.0));

              return Container(
                padding: EdgeInsets.only(bottom: bottomPadding, top: 6),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Receipt Image Preview
                    if (_selectedReceiptBytes != null)
                      _buildSelectedReceiptPreview(),

                    // Quick Suggestions (nempel tepat di atas field input pesan)
                    SizedBox(
                      height: 36,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sideMargin,
                        ),
                        physics: const BouncingScrollPhysics(),
                        children: [
                          _buildSuggestionChip('Catat: Nasi padang 25rb'),
                          const SizedBox(width: 8),
                          _buildSuggestionChip(
                            'Sisa jatah jajan makan berapa?',
                          ),
                          const SizedBox(width: 8),
                          _buildSuggestionChip('Duit gue sekarang ada berapa?'),
                          const SizedBox(width: 8),
                          _buildSuggestionChip(
                            'Pengeluaran bulan ini udah berapa?',
                          ),
                          const SizedBox(width: 8),
                          _buildSuggestionChip('Boleh beli HP 3 juta gak?'),
                          const SizedBox(width: 8),
                          _buildSuggestionChip(
                            'Progres celengan darurat aman gak?',
                          ),
                          const SizedBox(width: 8),
                          _buildSuggestionChip(
                            'Kasih masukan dong buat dompet gue',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Input Bar
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sideMargin,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Container(
                              constraints: const BoxConstraints(
                                minHeight: 48,
                                maxHeight: 120,
                              ),
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 8,
                                top: 2,
                                bottom: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceCard,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: AppSpacing.softShadow,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _textController,
                                      minLines: 1,
                                      maxLines: 4,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.newline,
                                      onSubmitted: (_) => _sendMessage(),
                                      style: AppTypography.body,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        hintText: _selectedReceiptBytes != null
                                            ? 'Catatan nota (opsional)...'
                                            : 'Tulis transaksi atau tanya...',
                                        hintStyle: AppTypography.bodySecondary
                                            .copyWith(fontSize: 13),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 11,
                                            ),
                                        border: InputBorder.none,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  if (_isProcessingImage)
                                    const Padding(
                                      padding: EdgeInsets.only(
                                        right: 8,
                                        bottom: 12,
                                      ),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    )
                                  else
                                    GestureDetector(
                                      key: const Key(
                                        'scan_receipt_action_button',
                                      ),
                                      onTap: () =>
                                          _showScanSourceSheet(context),
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 4,
                                        ),
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryLight
                                              .withValues(alpha: 0.45),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          PhosphorIcons.cameraPlus(
                                            PhosphorIconsStyle.bold,
                                          ),
                                          size: 19,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Builder(
                            builder: (context) {
                              final showSendIcon =
                                  _hasInputText ||
                                  _selectedReceiptBytes != null;
                              return GestureDetector(
                                key: const Key('voice_or_send_action_button'),
                                onTap: () {
                                  if (showSendIcon) {
                                    _sendMessage();
                                  } else {
                                    _toggleVoiceInput();
                                  }
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 48,
                                  height: 48,
                                  decoration: const BoxDecoration(
                                    gradient: AppColors.aiAccentGradient,
                                    shape: BoxShape.circle,
                                    boxShadow: AppSpacing.glowShadow,
                                  ),
                                  child: Center(
                                    child: Icon(
                                      showSendIcon
                                          ? PhosphorIcons.arrowUp(
                                              PhosphorIconsStyle.bold,
                                            )
                                          : PhosphorIcons.microphone(
                                              PhosphorIconsStyle.bold,
                                            ),
                                      color: Colors.white,
                                      size: 20,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionChip(String text, {VoidCallback? onTapOverride}) {
    return ActionChip(
      label: Text(text),
      labelStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      backgroundColor: AppColors.surfaceCard,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      onPressed: onTapOverride ?? () => _sendMessage(text),
    );
  }

  Widget _buildMessageBubble(ChatMessageEntity message) {
    final isUser = message.isUser;
    final timeStr = DateFormatter.formatTime(message.createdAt);

    final hasExtractedTx =
        !isUser &&
        message.structuredPayload != null &&
        message.structuredPayload!['amount'] != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth:
                  MediaQuery.of(context).size.width * (isUser ? 0.78 : 0.88),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isUser ? AppColors.primary : AppColors.surfaceCard,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(24),
                topRight: const Radius.circular(24),
                bottomLeft: Radius.circular(isUser ? 24 : 8),
                bottomRight: Radius.circular(isUser ? 8 : 24),
              ),
              boxShadow: AppSpacing.softShadow,
            ),
            child: Column(
              crossAxisAlignment: message.hasVoiceOutput
                  ? CrossAxisAlignment.stretch
                  : CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.hasVoiceOutput) ...[
                  _buildMiniAudioPlayer(message),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: AppColors.neutral200.withValues(alpha: 0.65),
                    ),
                  ),
                ],
                _buildMessageContent(message.content, isUser),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    timeStr,
                    style: GoogleFonts.urbanist(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasExtractedTx) ...[
            const SizedBox(height: 10),
            _buildExtractionConfirmCard(message),
          ],
        ],
      ),
    );
  }

  /// Mini Audio Player inside the AI Chat Bubble for Voice-Out responses
  Widget _buildMiniAudioPlayer(ChatMessageEntity message) {
    final isCurrentPlaying =
        _activePlayingMessageId == message.id &&
        (_isTtsSpeaking || _isAudioPlaying);

    return Material(
      key: Key('mini_audio_player_${message.id}'),
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _togglePlayMessageAudio(message),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primaryLight.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  gradient: AppColors.aiAccentGradient,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(
                    isCurrentPlaying
                        ? PhosphorIcons.pause(PhosphorIconsStyle.fill)
                        : PhosphorIcons.play(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isCurrentPlaying
                          ? 'Memutar suara Coach...'
                          : 'Putar suara Coach',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      isCurrentPlaying
                          ? 'Ketuk untuk jeda'
                          : (message.structuredPayload?['voice_character'] !=
                                    null
                                ? 'Suara ${message.structuredPayload!['voice_character']} • Ketuk untuk dengar'
                                : 'Ketuk untuk dengarkan balasan'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceCard.withValues(alpha: 0.75),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCurrentPlaying
                      ? PhosphorIcons.waveform(PhosphorIconsStyle.bold)
                      : PhosphorIcons.speakerHigh(PhosphorIconsStyle.bold),
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Formatter untuk pesan chat dengan spacing paragraf rapi dan dukungan bullet/list, bold & radar cards
  Widget _buildMessageContent(String content, bool isUser) {
    if (isUser) {
      return Text(
        content,
        style: GoogleFonts.urbanist(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
      );
    }

    final cleanContent = content.replaceAll('\r\n', '\n').trim();
    if (cleanContent.isEmpty) {
      return const SizedBox.shrink();
    }

    // Pisahkan paragraf berdasarkan dua kali baris baru (\n\n)
    final paragraphs = cleanContent.split(RegExp(r'\n{2,}'));
    final List<Widget> children = [];

    for (int p = 0; p < paragraphs.length; p++) {
      final paragraph = paragraphs[p].trim();
      if (paragraph.isEmpty) continue;

      // Cek apakah seluruh paragraf ini merupakan Divider markdown (misal: --- atau ━━━)
      if (RegExp(r'^[-_—━*]{3,}$').hasMatch(paragraph)) {
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Divider(
              color: AppColors.neutral200.withValues(alpha: 0.9),
              thickness: 1,
              height: 1,
            ),
          ),
        );
        continue;
      }

      final lines = paragraph.split('\n');

      // Cek apakah blok ini adalah Radar Ringkasan Saham/IPO
      final isRadarBlock =
          paragraph.contains('🎯') &&
          (paragraph.toUpperCase().contains('RADAR') ||
              paragraph.toUpperCase().contains('REKOMENDASI'));

      final isListBlock = lines.any(
        (l) =>
            l.trim().startsWith('- ') ||
            l.trim().startsWith('* ') ||
            l.trim().startsWith('• ') ||
            l.trim().startsWith('· ') ||
            l.trim().startsWith('– ') ||
            RegExp(r'^\d+\.\s+').hasMatch(l.trim()),
      );

      if (isRadarBlock) {
        children.add(_buildRadarSummaryCard(lines));
      } else if (isListBlock) {
        final List<Widget> listItems = [];
        for (int l = 0; l < lines.length; l++) {
          final line = lines[l].trim();
          if (line.isEmpty) continue;

          // Cek divider di dalam baris
          if (RegExp(r'^[-_—━*]{3,}$').hasMatch(line)) {
            listItems.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Divider(
                  color: AppColors.neutral200.withValues(alpha: 0.9),
                  thickness: 1,
                  height: 1,
                ),
              ),
            );
            continue;
          }

          final isBullet =
              line.startsWith('- ') ||
              line.startsWith('* ') ||
              line.startsWith('• ') ||
              line.startsWith('· ') ||
              line.startsWith('– ');
          final isNumbered = RegExp(r'^\d+\.\s+').hasMatch(line);

          if (isBullet || isNumbered) {
            listItems.add(_buildListItem(line, isNumbered: isNumbered));
          } else {
            listItems.add(_buildParagraphItem(line));
          }

          if (l < lines.length - 1) {
            listItems.add(const SizedBox(height: 5));
          }
        }

        children.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: listItems,
          ),
        );
      } else {
        children.add(_buildParagraphItem(paragraph));
      }

      if (p < paragraphs.length - 1) {
        children.add(const SizedBox(height: 8));
      }
    }

    if (children.isEmpty) {
      return Text(
        content,
        style: GoogleFonts.urbanist(
          color: AppColors.textPrimary,
          fontSize: 14,
          height: 1.5,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  /// Specialized card for Radar IPO / Stock Analysis summaries
  Widget _buildRadarSummaryCard(List<String> lines) {
    final List<Widget> cardItems = [];

    for (int i = 0; i < lines.length; i++) {
      final rawLine = lines[i].trim();
      if (rawLine.isEmpty) continue;

      if (RegExp(r'^[-_—━*]{3,}$').hasMatch(rawLine)) {
        cardItems.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Divider(
              color: AppColors.primary.withValues(alpha: 0.15),
              thickness: 1,
              height: 1,
            ),
          ),
        );
        continue;
      }

      final isBullet =
          rawLine.startsWith('- ') ||
          rawLine.startsWith('* ') ||
          rawLine.startsWith('• ') ||
          rawLine.startsWith('· ') ||
          rawLine.startsWith('– ');
      final isNumbered = RegExp(r'^\d+\.\s+').hasMatch(rawLine);

      if (isBullet || isNumbered) {
        cardItems.add(
          _buildListItem(rawLine, isNumbered: isNumbered, isRadarContext: true),
        );
      } else if (rawLine.contains('🎯')) {
        // Radar Header with pill styling
        cardItems.add(
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildRichFormattedText(
              rawLine,
              baseStyle: GoogleFonts.urbanist(
                color: AppColors.primaryDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
      } else {
        cardItems.add(_buildParagraphItem(rawLine));
      }

      if (i < lines.length - 1) {
        cardItems.add(const SizedBox(height: 5));
      }
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: cardItems,
      ),
    );
  }

  Widget _buildParagraphItem(String text) {
    if (RegExp(r'^[-_—━*]{3,}$').hasMatch(text.trim())) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Divider(
          color: AppColors.neutral200.withValues(alpha: 0.9),
          thickness: 1,
          height: 1,
        ),
      );
    }

    final headerMatch = RegExp(r'^#{1,4}\s+(.*)$').firstMatch(text.trim());
    final cleanedText = headerMatch != null
        ? headerMatch.group(1)!.trim()
        : text;
    final isHeader = headerMatch != null;

    return _buildRichFormattedText(
      cleanedText,
      baseStyle: GoogleFonts.urbanist(
        color: AppColors.textPrimary,
        fontSize: isHeader ? 15.5 : 14,
        fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
        height: 1.52,
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _buildListItem(
    String text, {
    required bool isNumbered,
    bool isRadarContext = false,
  }) {
    String prefix;
    String body;
    if (isNumbered) {
      final match = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(text);
      prefix = match?.group(1) ?? '•';
      body = match?.group(2) ?? text;
    } else {
      prefix = '•';
      body = text.replaceFirst(RegExp(r'^[-*•·–]\s+'), '');
    }

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              isNumbered ? prefix : '•',
              style: GoogleFonts.urbanist(
                color: isRadarContext
                    ? AppColors.primary
                    : (isNumbered
                          ? AppColors.primary
                          : AppColors.textSecondary),
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRichFormattedText(
              body,
              baseStyle: GoogleFonts.urbanist(
                color: AppColors.textPrimary,
                fontSize: 13.5,
                height: 1.48,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRichFormattedText(String text, {required TextStyle baseStyle}) {
    if (!text.contains('**')) {
      return Text(text, style: baseStyle);
    }

    final List<TextSpan> spans = [];
    final parts = text.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;

      Color? tagColor;
      if (isBold) {
        final upper = parts[i].toUpperCase();
        if (upper.contains('BUY') ||
            upper.contains('ARA') ||
            upper.contains('AKUMULASI') ||
            upper.contains('UNTUNG')) {
          tagColor = const Color(0xFF16A34A);
        } else if (upper.contains('HIGH RISK') ||
            upper.contains('SELL') ||
            upper.contains('ARB') ||
            upper.contains('AVOID')) {
          tagColor = const Color(0xFFDC2626);
        } else if (upper.contains('WAIT') ||
            upper.contains('HOLD') ||
            upper.contains('MEDIUM RISK')) {
          tagColor = const Color(0xFFD97706);
        }
      }

      spans.add(
        TextSpan(
          text: parts[i],
          style: isBold
              ? baseStyle.copyWith(
                  fontWeight: FontWeight.w700,
                  color: tagColor ?? baseStyle.color,
                )
              : baseStyle,
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  /// Error bubble with retry and dismiss actions
  Widget _buildErrorBubble(ChatMessageEntity message) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.errorTint,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppSpacing.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, size: 16, color: AppColors.error),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Gagal mengirim pesan',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message.content,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildActionChip(
                  icon: Icons.refresh,
                  label: 'Coba lagi',
                  color: AppColors.primary,
                  onTap: () => context.read<CoachCubit>().retryLastMessage(),
                ),
                const SizedBox(width: 8),
                _buildActionChip(
                  icon: Icons.close,
                  label: 'Abaikan',
                  color: AppColors.textSecondary,
                  onTap: () => context.read<CoachCubit>().dismissError(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Clarification bubble with visual indicator
  Widget _buildClarificationBubble(ChatMessageEntity message) {
    final timeStr = DateFormatter.formatTime(message.createdAt);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(8),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: AppSpacing.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warningTint,
                borderRadius: BorderRadius.circular(100),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.help_outline, size: 13, color: AppColors.warning),
                  SizedBox(width: 4),
                  Text(
                    'Kurang jelas nih 🤔',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
            ),
            _buildMessageContent(message.content, false),
            if (message.missingFields.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: message.missingFields.map((field) {
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.warningTint,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      _translateField(field),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.warning,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                timeStr,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedReceiptPreview() {
    if (_selectedReceiptBytes == null) return const SizedBox.shrink();

    final sizeKb = (_selectedReceiptBytes!.lengthInBytes / 1024)
        .toStringAsFixed(1);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sideMargin,
        vertical: 4,
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceFieldFill, width: 1.2),
          boxShadow: AppSpacing.softShadow,
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.memory(
                _selectedReceiptBytes!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedReceiptName ?? 'Nota Belanja',
                    style: const TextStyle(
                      fontFamily: 'Urbanist',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$sizeKb KB • Siap dipindai Coach',
                    style: AppTypography.caption.copyWith(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() {
                  _selectedReceiptBytes = null;
                  _selectedReceiptName = null;
                });
              },
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceFieldFill,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIcons.x(PhosphorIconsStyle.bold),
                  size: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadOlderMessagesHeader({
    required int remainingCount,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 12),
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(100),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.65),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIcons.clockCounterClockwise(PhosphorIconsStyle.bold),
                    size: 13,
                    color: AppColors.primaryDark,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Muat pesan sebelumnya ($remainingCount)',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator({bool isScanningReceipt = false}) {
    const scanSteps = [
      'Mengompresi gambar...',
      'Membaca rincian struk...',
      'Menyiapkan konfirmasi...',
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppSpacing.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 34,
              height: 34,
              child: Lottie.asset(
                'assets/animations/ai_coach_typing.json',
                repeat: true,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 8),
            if (isScanningReceipt)
              StreamBuilder<int>(
                stream: Stream.periodic(
                  const Duration(milliseconds: 900),
                  (i) => (i + 1).clamp(0, scanSteps.length - 1),
                ),
                initialData: 0,
                builder: (context, snapshot) {
                  final stepIdx = snapshot.data ?? 0;
                  return Text(
                    scanSteps[stepIdx],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  );
                },
              )
            else
              const Text(
                'Wait, Sabar Boss...',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Interactive card to confirm structured transaction extracted by AI (Stitch Prompt 7A & 7B)
  Widget _buildExtractionConfirmCard(ChatMessageEntity message) {
    final payload = message.structuredPayload!;
    final amount = (payload['amount'] as num?)?.toDouble() ?? 0.0;
    final isEmergencyDeposit =
        payload['funding_source'] == 'emergency_fund_deposit' ||
        payload['type'] == 'goal_deposit';
    final isIncome = !isEmergencyDeposit && payload['type'] == 'income';
    final note = payload['note']?.toString() ?? 'Transaksi Coach';
    final category = isEmergencyDeposit
        ? 'Dana Darurat'
        : (payload['category_suggestion']?.toString() ??
              (isIncome ? 'Pemasukan' : 'Makan & Minum'));
    final isEmergencyFunded =
        !isIncome &&
        !isEmergencyDeposit &&
        payload['funding_source'] == 'emergency_fund';
    final fallbackCatRaw =
        payload['fallback_category_suggestion']?.toString().trim() ?? '';
    final fallbackCategory = fallbackCatRaw.isNotEmpty
        ? fallbackCatRaw
        : (category.toLowerCase() == 'dana darurat' ? 'Lainnya' : category);
    final hasEmergencyToggle =
        !isIncome &&
        !isEmergencyDeposit &&
        (isEmergencyFunded || fallbackCatRaw.isNotEmpty);
    final isRejected =
        payload['rejected'] == true || payload['cancelled'] == true;

    return BlocBuilder<CoachCubit, CoachState>(
      builder: (context, state) {
        final isConfirming =
            state is CoachLoaded && state.confirmingMessageId == message.id;

        Color chipBg;
        Color chipFg;
        IconData chipIcon;
        String chipText;

        if (message.isConfirmed) {
          chipBg = AppColors.successTint;
          chipFg = AppColors.success;
          chipIcon = Icons.check_circle_rounded;
          chipText = 'Tercatat di Database';
        } else if (isRejected) {
          chipBg = AppColors.errorTint;
          chipFg = AppColors.error;
          chipIcon = Icons.cancel_rounded;
          chipText = 'Pencatatan Dibatalkan';
        } else {
          chipBg = AppColors.warningTint;
          chipFg = AppColors.warning;
          chipIcon = Icons.schedule_rounded;
          chipText = 'Menunggu Konfirmasi';
        }

        return Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppSpacing.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top status chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: chipBg,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(chipIcon, size: 14, color: chipFg),
                    const SizedBox(width: 5),
                    Text(
                      chipText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: chipFg,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Structured rows
              _buildExtractRow(
                'Jenis',
                isEmergencyDeposit
                    ? 'Setor Tabungan'
                    : (isIncome ? 'Pemasukan' : 'Pengeluaran'),
              ),
              const SizedBox(height: 6),
              _buildExtractRow(
                'Nominal',
                CurrencyFormatter.format(amount),
                isBold: true,
              ),
              const SizedBox(height: 6),
              _buildExtractRow('Kategori', category),
              const SizedBox(height: 6),
              _buildExtractRow(
                isEmergencyDeposit ? 'Tujuan Dana' : 'Sumber Dana',
                isEmergencyDeposit
                    ? 'Celengan Dana Darurat'
                    : (isIncome
                          ? 'Pemasukan'
                          : (isEmergencyFunded
                                ? 'Potong Dana Darurat'
                                : 'Pos $fallbackCategory')),
              ),
              const SizedBox(height: 6),
              _buildExtractRow('Catatan', note),

              if (hasEmergencyToggle &&
                  !isRejected &&
                  !message.isConfirmed) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: isConfirming
                            ? null
                            : () => context
                                  .read<CoachCubit>()
                                  .switchTransactionFundingSource(
                                    message,
                                    useEmergencyFund: true,
                                  ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isEmergencyFunded
                                ? AppColors.primaryLight
                                : AppColors.surfaceFieldFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isEmergencyFunded
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Potong Dana Darurat',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isEmergencyFunded
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: isConfirming
                            ? null
                            : () => context
                                  .read<CoachCubit>()
                                  .switchTransactionFundingSource(
                                    message,
                                    useEmergencyFund: false,
                                  ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: !isEmergencyFunded
                                ? AppColors.primaryLight
                                : AppColors.surfaceFieldFill,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: !isEmergencyFunded
                                  ? AppColors.primary
                                  : Colors.transparent,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Pos $fallbackCategory',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: !isEmergencyFunded
                                  ? AppColors.primaryDark
                                  : AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              if (isRejected) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFieldFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Transaksi ini dibatalkan dan tidak dicatat ke database.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ] else if (message.isConfirmed) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.successTint,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isEmergencyDeposit
                        ? 'Setoran berhasil ditambahkan ke Dana Darurat.'
                        : (isEmergencyFunded
                              ? 'Saldo Dana Darurat berhasil dipotong & transaksi dicatat.'
                              : 'Transaksi berhasil disimpan ke pos anggaran.'),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: isConfirming
                            ? null
                            : () async {
                                await context
                                    .read<CoachCubit>()
                                    .confirmExtractedTransaction(message);
                                if (!context.mounted) return;
                                try {
                                  context
                                      .read<TransactionCubit>()
                                      .loadTransactions();
                                } catch (_) {}
                                try {
                                  context.read<BudgetCubit>().loadBudgets();
                                } catch (_) {}
                                try {
                                  context.read<GoalCubit>().loadGoals();
                                } catch (_) {}
                              },
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          alignment: Alignment.center,
                          child: isConfirming
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.surfaceCard,
                                  ),
                                )
                              : const Text(
                                  'Simpan',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.surfaceCard,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: isConfirming
                            ? null
                            : () => context
                                  .read<CoachCubit>()
                                  .cancelExtractedTransaction(message),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceFieldFill,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExtractRow(String label, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }

  String _translateField(String field) {
    switch (field) {
      case 'amount':
        return 'Nominal';
      case 'date':
      case 'transaction_date':
        return 'Tanggal';
      case 'type':
        return 'Jenis (pemasukan/pengeluaran)';
      case 'category':
      case 'category_suggestion':
        return 'Kategori';
      case 'note':
        return 'Catatan';
      default:
        return field;
    }
  }

  /// Displays a brief animated Piggy Bank popup whenever Coach records an
  /// income (intact piggy) or expense (cracked/breaking piggy) transaction.
  void _showTransactionLottiePopup({
    required bool isIncome,
    required double amount,
    String? note,
  }) {
    if (!mounted) return;
    _txPopupTimer?.cancel();
    bool dialogDismissed = false;
    BuildContext? activeDialogCtx;

    showGeneralDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Tutup popup pencatatan transaksi',
      barrierColor: Colors.black.withValues(alpha: 0.34),
      transitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (dialogCtx, animation, secondaryAnimation) {
        activeDialogCtx = dialogCtx;
        return _buildTransactionLottiePopupCard(
          isIncome: isIncome,
          amount: amount,
          note: note,
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        );
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(scale: curved, child: child),
        );
      },
    ).whenComplete(() {
      dialogDismissed = true;
      activeDialogCtx = null;
      _txPopupTimer?.cancel();
    });

    _txPopupTimer = Timer(const Duration(milliseconds: 2200), () {
      if (dialogDismissed) return;
      final ctx = activeDialogCtx;
      if (ctx != null && ctx.mounted) {
        Navigator.of(ctx).maybePop();
      }
    });
  }

  Widget _buildTransactionLottiePopupCard({
    required bool isIncome,
    required double amount,
    String? note,
  }) {
    final lottieAsset = isIncome
        ? 'assets/animations/piggy_bank.json'
        : 'assets/animations/piggy_bank_broken.json';
    final badgeBg = isIncome ? AppColors.incomeGreenBg : AppColors.expenseRedBg;
    final badgeFg = isIncome ? AppColors.income : AppColors.expenseRed;
    final title = isIncome ? 'Pemasukan Tercatat!' : 'Pengeluaran Tercatat!';
    final subtitle = (note != null && note.trim().isNotEmpty)
        ? note.trim()
        : (isIncome
              ? 'Mantap, celenganmu makin tebal nih!'
              : 'Aduh, isi celenganmu pecah keluar!');
    final signedAmount = CurrencyFormatter.formatSigned(
      amount,
      isIncome: isIncome,
    );

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 284,
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: badgeBg, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 152,
                height: 152,
                decoration: BoxDecoration(
                  color: badgeBg.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                ),
                child: Lottie.asset(
                  lottieAsset,
                  repeat: false,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  title,
                  style: AppTypography.smallCaption.copyWith(
                    color: badgeFg,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  signedAmount,
                  style: AppTypography.bigNumber.copyWith(
                    fontSize: 24,
                    color: badgeFg,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
