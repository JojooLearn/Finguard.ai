import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../budgets/presentation/cubit/budget_cubit.dart';
import '../../../goals/presentation/cubit/goal_cubit.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';
import '../../../stock_signals/presentation/cubit/stock_signal_list_cubit.dart';
import '../../../stock_signals/presentation/cubit/stock_signal_list_state.dart';
import '../../../transactions/presentation/cubit/transaction_cubit.dart';
import '../../domain/notification_helper.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> {
  NotificationCategory _selectedCategory = NotificationCategory.all;
  final Set<String> _readIds = {};
  final Set<String> _dismissedIds = {};

  static const int _pageSize = 15;
  int _displayedLimit = _pageSize;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  String? get _currentUserId {
    try {
      final pState = context.read<ProfileCubit>().state;
      if (pState is ProfileLoaded) {
        return pState.profile.id;
      }
    } catch (_) {}
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadStoredPreferences();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final all = _buildNotifications();
      final filteredCount = all.where((n) {
        if (_selectedCategory == NotificationCategory.all) return true;
        return n.category == _selectedCategory;
      }).length;

      if (_displayedLimit < filteredCount) {
        setState(() => _isLoadingMore = true);
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted) {
            setState(() {
              _displayedLimit += _pageSize;
              _isLoadingMore = false;
            });
          }
        });
      }
    }
  }

  Future<void> _loadStoredPreferences() async {
    final userId = _currentUserId;
    final prefs = await SharedPreferences.getInstance();
    final readList = <String>[
      ...(prefs.getStringList(NotificationHelper.readPrefsKey) ?? const <String>[]),
      ...(prefs.getStringList(NotificationHelper.readKeyForUser(userId)) ?? const <String>[]),
    ];
    final dismissedList = <String>[
      ...(prefs.getStringList(NotificationHelper.dismissedPrefsKey) ?? const <String>[]),
      ...(prefs.getStringList(NotificationHelper.dismissedKeyForUser(userId)) ?? const <String>[]),
    ];
    if (mounted) {
      setState(() {
        _readIds.addAll(readList);
        _dismissedIds.addAll(dismissedList);
      });
    }
  }

  Future<void> _saveReadIds() async {
    final userId = _currentUserId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      NotificationHelper.readKeyForUser(userId),
      _readIds.toList(),
    );
  }

  Future<void> _saveDismissedIds() async {
    final userId = _currentUserId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      NotificationHelper.dismissedKeyForUser(userId),
      _dismissedIds.toList(),
    );
  }

  String _formatNotificationTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);

    if (diff.isNegative) {
      return DateFormat('d MMM, HH:mm').format(local);
    }
    if (diff.inMinutes < 1) {
      return 'Baru saja';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes} mnt lalu';
    }
    if (diff.inHours < 24 &&
        local.day == now.day &&
        local.month == now.month &&
        local.year == now.year) {
      return 'Hari ini, ${DateFormat('HH:mm').format(local)}';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (local.year == yesterday.year &&
        local.month == yesterday.month &&
        local.day == yesterday.day) {
      return 'Kemarin, ${DateFormat('HH:mm').format(local)}';
    }
    if (local.year == now.year) {
      return DateFormat('d MMM, HH:mm').format(local);
    }
    return DateFormat('d MMM yyyy, HH:mm').format(local);
  }

  List<NotificationItemModel> _buildNotifications() {
    StockSignalListState? stockState;
    try {
      stockState = context.read<StockSignalListCubit>().state;
    } catch (_) {}

    final list = NotificationHelper.buildNotifications(
      budgetState: context.read<BudgetCubit>().state,
      goalState: context.read<GoalCubit>().state,
      profileState: context.read<ProfileCubit>().state,
      transactionState: context.read<TransactionCubit>().state,
      stockSignalState: stockState,
    );

    // Filter out dismissed items
    final activeList = list.where((item) => !_dismissedIds.contains(item.id)).toList();

    // Mark read states
    for (final item in activeList) {
      if (_readIds.contains(item.id)) {
        item.isRead = true;
      }
    }

    // Sort descending by timestamp: newest on top
    activeList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return activeList;
  }

  @override
  Widget build(BuildContext context) {
    final allNotifications = _buildNotifications();

    final filtered = allNotifications.where((n) {
      if (_selectedCategory == NotificationCategory.all) return true;
      return n.category == _selectedCategory;
    }).toList();

    final unreadCount = filtered.where((n) => !n.isRead).length;

    return Scaffold(
      backgroundColor: AppColors.bgCanvasMain,
      appBar: AppBar(
        backgroundColor: AppColors.bgCanvasMain,
        elevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.arrowLeft(), color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Pusat Notifikasi',
          style: AppTypography.pageHeader,
        ),
        centerTitle: true,
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () {
                setState(() {
                  for (final item in filtered) {
                    _readIds.add(item.id);
                  }
                });
                _saveReadIds();
              },
              child: Text(
                'Tandai Dibaca',
                style: AppTypography.captionText.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  fontSize: 13,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // 1. Horizontal Categorization Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontalMargin,
              vertical: 8,
            ),
            child: Row(
              children: [
                _buildCategoryPill(
                  label: 'Semua',
                  category: NotificationCategory.all,
                  count: allNotifications.length,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  label: 'Peringatan',
                  category: NotificationCategory.warning,
                  count: allNotifications
                      .where((n) => n.category == NotificationCategory.warning)
                      .length,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  label: 'Sinyal Saham',
                  category: NotificationCategory.stockSignal,
                  count: allNotifications
                      .where((n) => n.category == NotificationCategory.stockSignal)
                      .length,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  label: 'Target Tabungan',
                  category: NotificationCategory.goalTarget,
                  count: allNotifications
                      .where((n) => n.category == NotificationCategory.goalTarget)
                      .length,
                ),
                const SizedBox(width: 8),
                _buildCategoryPill(
                  label: 'Info Sistem',
                  category: NotificationCategory.systemInfo,
                  count: allNotifications
                      .where((n) => n.category == NotificationCategory.systemInfo)
                      .length,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // 2. Notifications List View
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState(_selectedCategory)
                : Builder(
                    builder: (context) {
                      final visibleItems = filtered.take(_displayedLimit).toList();
                      final bool hasMore = _displayedLimit < filtered.length;

                      return ListView.separated(
                        controller: _scrollController,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.only(
                          left: AppSpacing.screenHorizontalMargin,
                          right: AppSpacing.screenHorizontalMargin,
                          top: 8,
                          bottom: 32,
                        ),
                        itemCount: visibleItems.length +
                            (filtered.length > _pageSize ? 1 : 0),
                        separatorBuilder: (_, index) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          if (index == visibleItems.length) {
                            if (hasMore) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Memuat notifikasi lainnya...',
                                        style: AppTypography.captionText.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: Text(
                                  'Semua ${filtered.length} notifikasi telah dimuat',
                                  style: AppTypography.captionText.copyWith(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            );
                          }

                          final item = visibleItems[index];
                          return Dismissible(
                            key: Key(item.id),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              decoration: BoxDecoration(
                                color: AppColors.expenseRed,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusBentoAndItem,
                                ),
                              ),
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: Icon(
                                PhosphorIcons.trash(),
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                            onDismissed: (_) {
                              setState(() {
                                _dismissedIds.add(item.id);
                              });
                              _saveDismissedIds();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notifikasi dihapus'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                            },
                            child: _buildNotificationCard(item),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill({
    required String label,
    required NotificationCategory category,
    required int count,
  }) {
    final isSelected = _selectedCategory == category;
    return GestureDetector(
      onTap: () {
        if (_selectedCategory != category) {
          setState(() {
            _selectedCategory = category;
            _displayedLimit = _pageSize;
          });
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(0);
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: AppTypography.captionText.copyWith(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontSize: 12,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.surfaceFieldFill,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItemModel item) {
    Color iconColor;
    Color iconBg;
    IconData icon;
    String categoryLabel;
    Color badgeBg;
    Color badgeText;

    switch (item.category) {
      case NotificationCategory.warning:
        iconColor = AppColors.expenseRed;
        iconBg = AppColors.expenseRedBg;
        icon = PhosphorIcons.warningCircle(PhosphorIconsStyle.fill);
        categoryLabel = 'PERINGATAN';
        badgeBg = AppColors.expenseRedBg;
        badgeText = AppColors.expenseRed;
        break;
      case NotificationCategory.stockSignal:
        iconColor = AppColors.primary;
        iconBg = AppColors.primaryLight;
        icon = PhosphorIcons.chartLineUp(PhosphorIconsStyle.fill);
        categoryLabel = 'SINYAL SAHAM';
        badgeBg = AppColors.primaryLight;
        badgeText = AppColors.primary;
        break;
      case NotificationCategory.goalTarget:
        iconColor = AppColors.incomeGreen;
        iconBg = AppColors.incomeGreenBg;
        icon = PhosphorIcons.piggyBank(PhosphorIconsStyle.fill);
        categoryLabel = 'TARGET';
        badgeBg = AppColors.incomeGreenBg;
        badgeText = AppColors.incomeGreen;
        break;
      case NotificationCategory.systemInfo:
      case NotificationCategory.all:
        iconColor = AppColors.primaryDark;
        iconBg = AppColors.surfaceFieldFill;
        icon = PhosphorIcons.info(PhosphorIconsStyle.fill);
        categoryLabel = 'INFO SISTEM';
        badgeBg = AppColors.surfaceFieldFill;
        badgeText = AppColors.primaryDark;
        break;
    }

    return GestureDetector(
      onTap: () {
        setState(() => _readIds.add(item.id));
        _saveReadIds();
        if (item.route.isNotEmpty) {
          context.push(item.route);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: item.isRead
              ? AppColors.surfaceCard
              : AppColors.primaryLight.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppSpacing.radiusBentoAndItem),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Category Pill Badge + Timestamp Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBg,
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              categoryLabel,
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: badgeText,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          if (item.badgeText != null &&
                              item.badgeText != categoryLabel) ...[
                            const SizedBox(width: 5),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceFieldFill,
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                item.badgeText!,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _formatNotificationTime(item.timestamp),
                        style: AppTypography.captionText.copyWith(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Title
                  Text(
                    item.title,
                    style: AppTypography.itemTitle.copyWith(
                      fontSize: 14.5,
                      fontWeight:
                          item.isRead ? FontWeight.w600 : FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Message body
                  Text(
                    item.message,
                    style: AppTypography.captionText.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (!item.isRead) ...[
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(NotificationCategory category) {
    String title = 'Tidak Ada Notifikasi';
    String description =
        'Semua kondisi keuangan dan targetmu terpantau aman terkendali.';

    switch (category) {
      case NotificationCategory.warning:
        title = 'Belum Ada Peringatan';
        description =
            'Bagus! Tidak ada pos belanja yang jebol atau cicilan yang berlebih saat ini.';
        break;
      case NotificationCategory.stockSignal:
        title = 'Belum Ada Sinyal Saham';
        description =
            'Radar sinyal teknikal TradingView belum menerima trigger baru untuk saham pilihanmu.';
        break;
      case NotificationCategory.goalTarget:
        title = 'Belum Ada Update Target';
        description =
            'Buat target celengan atau tabungan impian untuk memantau progres finansialmu.';
        break;
      case NotificationCategory.systemInfo:
        title = 'Info Sistem Kosong';
        description =
            'Belum ada pengumuman sistem atau pembagian alokasi baru.';
        break;
      case NotificationCategory.all:
        break;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  PhosphorIcons.bellSimpleSlash(),
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.itemTitle.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: AppTypography.captionText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
