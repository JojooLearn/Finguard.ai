import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/chat_conversation_entity.dart';
import '../cubit/coach_cubit.dart';
import '../cubit/coach_state.dart';

class ChatHistoryPage extends StatefulWidget {
  const ChatHistoryPage({super.key});

  @override
  State<ChatHistoryPage> createState() => _ChatHistoryPageState();
}

class _ChatHistoryPageState extends State<ChatHistoryPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CoachCubit>().loadConversations();
    });
  }

  String _formatTimestamp(DateTime dateTime) {
    return DateFormatter.formatRelativeDateTime(dateTime);
  }

  void _showDeleteConfirmation(
    BuildContext context,
    ChatConversationEntity conv,
  ) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                PhosphorIcons.trash(PhosphorIconsStyle.fill),
                color: AppColors.expense,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hapus Percakapan?',
                style: AppTypography.screenTitle.copyWith(fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          'Percakapan "${conv.title}" beserta seluruh riwayat pesannya akan dihapus permanen. Tindakan ini tidak dapat dibatalkan.',
          style: AppTypography.bodyText.copyWith(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Batal',
                    style: AppTypography.sectionLabel.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    context.read<CoachCubit>().deleteConversation(conv.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Percakapan berhasil dihapus.'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.expense,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'Hapus',
                    style: AppTypography.sectionLabel.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top App Bar
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sideMargin,
                vertical: 14,
              ),
              color: AppColors.background,
              child: Row(
                children: [
                  AppIconButton(
                    icon: PhosphorIcons.arrowLeft(),
                    onPressed: () => context.pop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Riwayat Percakapan',
                          style: AppTypography.screenTitle.copyWith(fontSize: 18),
                        ),
                        Text(
                          'Kelola semua sesi chat dengan Coach',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: PhosphorIcons.plus(),
                    onPressed: () async {
                      await context.read<CoachCubit>().startNewConversation();
                      if (context.mounted) {
                        context.pop();
                      }
                    },
                  ),
                ],
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // Body Content
            Expanded(
              child: BlocBuilder<CoachCubit, CoachState>(
                builder: (context, state) {
                  final isLoading = state is CoachLoaded &&
                      state.isLoadingConversations &&
                      state.conversations.isEmpty;

                  if (isLoading || state is CoachLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryDark,
                      ),
                    );
                  }

                  final conversations = state is CoachLoaded
                      ? state.conversations
                      : <ChatConversationEntity>[];
                  final activeId = state is CoachLoaded
                      ? state.activeConversationId
                      : null;

                  if (conversations.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.primaryLight,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                PhosphorIcons.chatsTeardrop(PhosphorIconsStyle.fill),
                                color: AppColors.primaryDark,
                                size: 36,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'Belum Ada Riwayat',
                              style: AppTypography.screenTitle.copyWith(
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Percakapanmu dengan Coach FinGuard akan tersimpan rapi di sini agar bisa kamu buka kembali kapan saja.',
                              textAlign: TextAlign.center,
                              style: AppTypography.bodyText.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 24),
                            AppButton(
                              label: 'Mulai Percakapan Baru',
                              icon: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 18,
                              ),
                              onPressed: () async {
                                await context
                                    .read<CoachCubit>()
                                    .startNewConversation();
                                if (context.mounted) {
                                  context.pop();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () =>
                        context.read<CoachCubit>().loadConversations(),
                    color: AppColors.primaryDark,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.sideMargin),
                      itemCount: conversations.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final conv = conversations[index];
                        final isActive = conv.id == activeId;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              context
                                  .read<CoachCubit>()
                                  .loadChatHistory(conversationId: conv.id);
                              context.pop();
                            },
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isActive
                                      ? AppColors.primary
                                      : const Color(0xFFE5E7EB),
                                  width: isActive ? 1.5 : 1,
                                ),
                                boxShadow: AppSpacing.softShadow,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Leading Icon
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: isActive
                                          ? AppColors.primaryLight
                                          : AppColors.surfaceFieldFill,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Center(
                                      child: Icon(
                                        PhosphorIcons.chatTeardropText(
                                          isActive
                                              ? PhosphorIconsStyle.fill
                                              : PhosphorIconsStyle.regular,
                                        ),
                                        color: isActive
                                            ? AppColors.primaryDark
                                            : AppColors.textSecondary,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Center Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                conv.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: AppTypography.sectionLabel
                                                    .copyWith(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                  color: AppColors.textPrimary,
                                                ),
                                              ),
                                            ),
                                            if (isActive) ...[
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.primaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  'Aktif',
                                                  style: AppTypography.caption
                                                      .copyWith(
                                                    color: AppColors.primaryDark,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        if (conv.lastMessage != null &&
                                            conv.lastMessage!.isNotEmpty)
                                          Text(
                                            conv.lastMessage!,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.caption.copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(
                                              PhosphorIcons.clock(
                                                PhosphorIconsStyle.regular,
                                              ),
                                              size: 12,
                                              color: AppColors.textDisabled,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              _formatTimestamp(conv.updatedAt),
                                              style: AppTypography.caption
                                                  .copyWith(
                                                color: AppColors.textDisabled,
                                                fontSize: 11,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  const SizedBox(width: 8),

                                  // Trailing Delete Action
                                  IconButton(
                                    icon: Icon(
                                      PhosphorIcons.trash(
                                        PhosphorIconsStyle.regular,
                                      ),
                                      color: AppColors.textDisabled,
                                      size: 18,
                                    ),
                                    tooltip: 'Hapus percakapan',
                                    onPressed: () => _showDeleteConfirmation(
                                      context,
                                      conv,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

