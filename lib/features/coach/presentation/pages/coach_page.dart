import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
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
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../cubit/coach_cubit.dart';
import '../cubit/coach_state.dart';

class CoachPage extends StatefulWidget {
  final bool? isKeyboardOpen;

  const CoachPage({super.key, this.isKeyboardOpen});

  @override
  State<CoachPage> createState() => _CoachPageState();
}

class _CoachPageState extends State<CoachPage> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ReceiptScannerService _scannerService = ReceiptScannerService();

  Uint8List? _selectedReceiptBytes;
  String? _selectedReceiptName;
  bool _isProcessingImage = false;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<CoachCubit>();
    if (cubit.state is CoachInitial) {
      cubit.loadChatHistory();
    }
  }

  @override
  void didUpdateWidget(covariant CoachPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isKeyboardOpen == true && oldWidget.isKeyboardOpen != true) {
      _scrollToBottom();
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
                                  color: AppColors.primaryLight.withValues(alpha: 0.5),
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
                                  color: AppColors.primaryLight.withValues(alpha: 0.5),
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

  Future<void> _sendMessage([String? presetText]) async {
    final text = presetText ?? _textController.text.trim();
    final hasReceipt = _selectedReceiptBytes != null;

    if (text.isEmpty && !hasReceipt) return;

    if (presetText == null) {
      _textController.clear();
    }

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
          .uploadReceiptToStorage(
            bytes: receiptBytes,
            userId: userId,
          )
          .catchError((_) => storagePath);

      if (!mounted) return;
      context.read<CoachCubit>().sendReceiptScan(
        receiptPath: storagePath,
        receiptBase64: receiptBase64,
        caption: text.isNotEmpty ? text : null,
      );
    } else {
      context.read<CoachCubit>().sendMessage(text);
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

  @override
  void dispose() {
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

    return Column(
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
                        style: AppTypography.screenTitle.copyWith(fontSize: 18),
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
                    onPressed: () =>
                        context.read<CoachCubit>().startNewConversation(),
                  ),
                  const SizedBox(width: 10),
                  AppIconButton(
                    icon: PhosphorIcons.clockCounterClockwise(),
                    onPressed: () => context.push('/coach/history'),
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
              if (state is CoachLoaded) {
                _scrollToBottom();
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
              }

              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.only(
                  left: AppSpacing.sideMargin,
                  right: AppSpacing.sideMargin,
                  top: 8,
                  bottom: 12,
                ),
                physics: const BouncingScrollPhysics(),
                itemCount: messages.length + (isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == messages.length && isSending) {
                    return _buildTypingIndicator(
                      isScanningReceipt: isScanningReceipt,
                    );
                  }
                  final msg = messages[index];

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
            final keyboardOpen = widget.isKeyboardOpen ??
                (View.of(context).viewInsets.bottom > 0 ||
                    MediaQuery.of(context).viewInsets.bottom > 0);
            final safeBottom = MediaQuery.of(context).padding.bottom;
            // Inside MainScaffold (extendBody: true), safeBottom already includes
            // FloatingNavBar height (>= 80px). Avoid double-adding 96px!
            final bottomPadding = keyboardOpen
                ? 8.0
                : (safeBottom >= 80.0 ? (safeBottom + 8.0) : (safeBottom + 96.0));

            return Container(
              padding: EdgeInsets.only(
                bottom: bottomPadding,
                top: 6,
              ),
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
                        _buildSuggestionChip('Sisa jatah jajan makan berapa?'),
                        const SizedBox(width: 8),
                        _buildSuggestionChip('Duit gue sekarang ada berapa?'),
                        const SizedBox(width: 8),
                        _buildSuggestionChip('Pengeluaran bulan ini udah berapa?'),
                        const SizedBox(width: 8),
                        _buildSuggestionChip('Boleh beli HP 3 juta gak?'),
                        const SizedBox(width: 8),
                        _buildSuggestionChip('Progres celengan darurat aman gak?'),
                        const SizedBox(width: 8),
                        _buildSuggestionChip('Kasih masukan dong buat dompet gue'),
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
                                      hintStyle: AppTypography.bodySecondary.copyWith(
                                        fontSize: 13,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(
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
                                    padding: EdgeInsets.only(right: 8, bottom: 12),
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
                                    key: const Key('scan_receipt_action_button'),
                                    onTap: () => _showScanSourceSheet(context),
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight.withValues(alpha: 0.45),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        PhosphorIcons.cameraPlus(PhosphorIconsStyle.bold),
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
                        GestureDetector(
                          onTap: () => _sendMessage(),
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: AppColors.aiAccentGradient,
                              shape: BoxShape.circle,
                              boxShadow: AppSpacing.glowShadow,
                            ),
                            child: Center(
                              child: Icon(
                                PhosphorIcons.arrowUp(PhosphorIconsStyle.bold),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
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
              maxWidth: MediaQuery.of(context).size.width * (isUser ? 0.78 : 0.83),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMessageContent(message.content, isUser),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 10,
                      color: isUser
                          ? Colors.white.withValues(alpha: 0.7)
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

  /// Formatter untuk pesan chat dengan spacing paragraf rapi dan dukungan bullet/list & bold
  Widget _buildMessageContent(String content, bool isUser) {
    if (isUser) {
      return Text(
        content,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
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

      final lines = paragraph.split('\n');
      final isListBlock = lines.any((l) =>
          l.trim().startsWith('- ') ||
          l.trim().startsWith('* ') ||
          l.trim().startsWith('• ') ||
          RegExp(r'^\d+\.\s+').hasMatch(l.trim()));

      if (isListBlock) {
        for (int l = 0; l < lines.length; l++) {
          final line = lines[l].trim();
          if (line.isEmpty) continue;

          final isBullet = line.startsWith('- ') ||
              line.startsWith('* ') ||
              line.startsWith('• ');
          final isNumbered = RegExp(r'^\d+\.\s+').hasMatch(line);

          if (isBullet || isNumbered) {
            children.add(_buildListItem(line, isNumbered: isNumbered));
          } else {
            children.add(_buildParagraphItem(line));
          }

          if (l < lines.length - 1) {
            children.add(const SizedBox(height: 5));
          }
        }
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
        style: const TextStyle(
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

  Widget _buildParagraphItem(String text) {
    final headerMatch = RegExp(r'^#{1,4}\s+(.*)$').firstMatch(text.trim());
    final cleanedText =
        headerMatch != null ? headerMatch.group(1)!.trim() : text;
    final isHeader = headerMatch != null;

    return _buildRichFormattedText(
      cleanedText,
      baseStyle: TextStyle(
        color: AppColors.textPrimary,
        fontSize: 14,
        fontWeight: isHeader ? FontWeight.w700 : FontWeight.w400,
        height: 1.52,
        letterSpacing: 0.1,
      ),
    );
  }

  Widget _buildListItem(String text, {required bool isNumbered}) {
    String prefix;
    String body;
    if (isNumbered) {
      final match = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(text);
      prefix = match?.group(1) ?? '•';
      body = match?.group(2) ?? text;
    } else {
      prefix = '•';
      body = text.replaceFirst(RegExp(r'^[-*•]\s+'), '');
    }

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isNumbered ? prefix : '•',
            style: TextStyle(
              color: isNumbered ? AppColors.primary : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildRichFormattedText(
              body,
              baseStyle: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.5,
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
      spans.add(
        TextSpan(
          text: parts[i],
          style: isBold
              ? baseStyle.copyWith(
                  fontWeight: FontWeight.w700,
                )
              : baseStyle,
        ),
      );
    }

    return RichText(
      text: TextSpan(children: spans),
    );
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

    final sizeKb =
        (_selectedReceiptBytes!.lengthInBytes / 1024).toStringAsFixed(1);

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppSpacing.softShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 36,
              height: 22,
              child: Lottie.asset(
                'assets/animations/scr04_ai_coach_typing.json',
                repeat: true,
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
    final isIncome = payload['type'] == 'income';
    final note = payload['note']?.toString() ?? 'Transaksi Coach';
    final category =
        payload['category_suggestion']?.toString() ??
        (isIncome ? 'Pemasukan' : 'Makan & Minum');
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
              _buildExtractRow('Jenis', isIncome ? 'Pemasukan' : 'Pengeluaran'),
              const SizedBox(height: 6),
              _buildExtractRow(
                'Nominal',
                CurrencyFormatter.format(amount),
                isBold: true,
              ),
              const SizedBox(height: 6),
              _buildExtractRow('Kategori', category),
              const SizedBox(height: 6),
              _buildExtractRow('Catatan', note),

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
                  child: const Text(
                    'Transaksi berhasil disimpan ke pos anggaran.',
                    style: TextStyle(
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
                            : () => context
                                  .read<CoachCubit>()
                                  .confirmExtractedTransaction(message),
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
}
