import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/services/push_notification_service.dart';
import '../../budgets/presentation/cubit/budget_state.dart';
import '../../goals/presentation/cubit/goal_state.dart';
import '../../profile/presentation/cubit/profile_state.dart';
import '../../stock_signals/presentation/cubit/stock_signal_list_state.dart';
import '../../transactions/domain/entities/category_entity.dart';
import '../../transactions/presentation/cubit/transaction_state.dart';

enum NotificationType { alert, warning, success, info }

/// User-friendly, non-ambiguous notification business categories:
/// - warning: Peringatan batas belanja & cicilan utang
/// - stockSignal: Sinyal saham teknikal TradingView & rekomendasi AI Coach
/// - goalTarget: Pencapaian target tabungan & dana darurat
/// - systemInfo: Rapor bulanan, peta keuangan, dan info aktivitas sistem
enum NotificationCategory {
  all,
  warning,
  stockSignal,
  goalTarget,
  systemInfo,
}

class NotificationItemModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final NotificationCategory category;
  final String route;
  final String? badgeText;
  final Map<String, dynamic>? extraData;
  bool isRead;

  NotificationItemModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.category,
    required this.route,
    this.badgeText,
    this.extraData,
    this.isRead = false,
  });
}

class NotificationHelper {
  static const String readPrefsKey = 'read_notification_ids';
  static const String dismissedPrefsKey = 'dismissed_notification_ids';
  static const String pushedStatusBarPrefsKey = 'pushed_statusbar_notification_ids';

  static String readKeyForUser(String? userId) =>
      (userId != null && userId.isNotEmpty) ? '${readPrefsKey}_$userId' : readPrefsKey;

  static String dismissedKeyForUser(String? userId) =>
      (userId != null && userId.isNotEmpty)
          ? '${dismissedPrefsKey}_$userId'
          : dismissedPrefsKey;

  static String pushedKeyForUser(String? userId) =>
      (userId != null && userId.isNotEmpty)
          ? '${pushedStatusBarPrefsKey}_$userId'
          : pushedStatusBarPrefsKey;

  static List<NotificationItemModel> buildNotifications({
    BudgetState? budgetState,
    GoalState? goalState,
    ProfileState? profileState,
    TransactionState? transactionState,
    StockSignalListState? stockSignalState,
  }) {
    final List<NotificationItemModel> list = [];

    DateTime? userCreatedAt;
    if (profileState is ProfileLoaded) {
      final p = profileState.profile;
      userCreatedAt = p.onboardingCompletedAt ?? p.createdAt;
    }

    // 1. Peringatan Budget (Budget Alerts derived from real data)
    if (budgetState is BudgetLoaded) {
      for (final b in budgetState.budgets) {
        final catName = b.categoryName ?? 'Kategori';
        if (b.spentAmount > b.limitAmount && b.limitAmount > 0) {
          final over = b.spentAmount - b.limitAmount;
          list.add(NotificationItemModel(
            id: 'budget_over_${b.id}',
            title: 'Pos $catName Jebol Melebihi Batas!',
            message:
                'Pengeluaran ${CurrencyFormatter.format(b.spentAmount)} sudah melampaui batas belanja ${CurrencyFormatter.format(b.limitAmount)} (selisih ${CurrencyFormatter.format(over)}).',
            timestamp: b.updatedAt,
            type: NotificationType.alert,
            category: NotificationCategory.warning,
            badgeText: 'JEBOL',
            route: '/budget',
          ));
        } else if (b.usagePercentage >= 0.85 && b.limitAmount > 0) {
          list.add(NotificationItemModel(
            id: 'budget_warn_${b.id}',
            title: 'Pos $catName Mulai Menipis',
            message:
                'Sudah terpakai ${(b.usagePercentage * 100).toInt()}% dari batas belanja bulananmu. Tahan dulu belanja non-mendesak.',
            timestamp: b.updatedAt,
            type: NotificationType.warning,
            category: NotificationCategory.warning,
            badgeText: 'MENIPIS',
            route: '/budget',
          ));
        }
      }
    }

    // 2. Peringatan Cicilan Utang
    if (profileState is ProfileLoaded) {
      final p = profileState.profile;
      if (p.monthlyIncome > 0 && (p.monthlyDebt / p.monthlyIncome) > 0.30) {
        final ratio = ((p.monthlyDebt / p.monthlyIncome) * 100).toInt();
        list.add(NotificationItemModel(
          id: 'debt_warning_profile',
          title: 'Perhatian: Porsi Cicilan Melampaui 30%',
          message:
              'Total cicilanmu memakan $ratio% dari pemasukan bulanan. Waspada agar anggaran kebutuhan pokok tidak terhimpit.',
          timestamp: p.updatedAt ?? p.createdAt ?? DateTime.now(),
          type: NotificationType.alert,
          category: NotificationCategory.warning,
          badgeText: 'CICILAN',
          route: '/calculators',
        ));
      }
    }

    // 3. Sinyal Saham TradingView (Only signals emitted AFTER user registered)
    if (stockSignalState is StockSignalLoaded) {
      for (final s in stockSignalState.signals) {
        // Prevent spamming brand-new accounts with historical signals from before registration
        if (userCreatedAt != null && !s.createdAt.isAfter(userCreatedAt)) {
          continue;
        }
        final signalLabel = s.signalType.displayName;
        final isBuy = signalLabel.toUpperCase().contains('BUY');
        final isSell = signalLabel.toUpperCase().contains('SELL');
        list.add(NotificationItemModel(
          id: 'stock_signal_${s.id}',
          title: 'Sinyal Saham ${s.ticker} ($signalLabel)',
          message:
              'Terdeteksi di harga Rp${s.priceAtSignal.toStringAsFixed(0)}. ${s.analysisNotes ?? "Analisa teknikal TradingView telah tersedia di Coach Chat."}',
          timestamp: s.createdAt,
          type: isBuy
              ? NotificationType.success
              : (isSell ? NotificationType.alert : NotificationType.info),
          category: NotificationCategory.stockSignal,
          badgeText: signalLabel,
          route: '/coach',
          extraData: {
            'ticker': s.ticker,
            'signal_type': signalLabel,
          },
        ));
      }
    }

    // 4. Target Tabungan (Goal Achievements & Reminders)
    if (goalState is GoalLoaded) {
      for (final g in goalState.goals) {
        if (g.currentAmount >= g.targetAmount && g.targetAmount > 0) {
          list.add(NotificationItemModel(
            id: 'goal_success_${g.id}',
            title: 'Target "${g.name}" Telah Tercapai! 🎉',
            message:
                'Selamat! Dana sebesar ${CurrencyFormatter.format(g.targetAmount)} telah terkumpul 100%. Disiplin finansialmu membuahkan hasil!',
            timestamp: g.updatedAt,
            type: NotificationType.success,
            category: NotificationCategory.goalTarget,
            badgeText: 'TERCAPAI',
            route: '/goals',
          ));
        } else if (g.currentAmount > 0 && g.targetAmount > 0) {
          final pct = ((g.currentAmount / g.targetAmount) * 100).toInt();
          list.add(NotificationItemModel(
            id: 'goal_progress_${g.id}',
            title: 'Progres Tabungan "${g.name}" ($pct%)',
            message:
                'Terkumpul ${CurrencyFormatter.format(g.currentAmount)} dari target ${CurrencyFormatter.format(g.targetAmount)}. Sisihkan uang dingin lagi bulan ini!',
            timestamp: g.updatedAt,
            type: NotificationType.info,
            category: NotificationCategory.goalTarget,
            badgeText: 'CELENGAN',
            route: '/goals',
          ));
        }
      }
    }

    // Filter user-created transactions (exclude auto-seeded initial onboarding income)
    final userTransactions = (transactionState is TransactionLoaded)
        ? transactionState.transactions.where((tx) {
            final noteLower = (tx.note ?? '').toLowerCase();
            if (noteLower.contains('saldo awal') ||
                noteLower.contains('pemasukan awal') ||
                noteLower.contains('onboarding')) {
              return false;
            }
            if (userCreatedAt != null &&
                tx.createdAt.difference(userCreatedAt).inSeconds.abs() <= 10 &&
                tx.transactionType == TransactionType.income) {
              return false;
            }
            return true;
          }).toList()
        : const [];

    // 5. Info Sistem (Peta Keuangan & Rapor Bulanan)
    if (profileState is ProfileLoaded) {
      final p = profileState.profile;

      // Blueprint activation info (Welcome notification on account setup)
      list.add(NotificationItemModel(
        id: 'system_welcome_blueprint',
        title: 'Peta Keuangan 50/30/20 Aktif',
        message:
            'Formula 50/30/20 telah memetakan kebutuhan pokok, gaya hidup, dan alokasi tabungan bulananmu.',
        timestamp: p.onboardingCompletedAt ?? p.createdAt ?? DateTime.now(),
        type: NotificationType.info,
        category: NotificationCategory.systemInfo,
        badgeText: 'PETA 50/30/20',
        route: '/budget',
      ));

      // Monthly review reminder: only show if user has real transactions or account is >= 7 days old
      final accountAgeDays = userCreatedAt != null
          ? DateTime.now().difference(userCreatedAt).inDays
          : 0;
      if (userTransactions.length >= 3 || accountAgeDays >= 7) {
        list.add(NotificationItemModel(
          id: 'system_monthly_review_ready',
          title: 'Evaluasi Keuangan Bulanan',
          message:
              'Rapor performa keuangan dan rekomendasi AI Coach siap diexport ke PDF executive.',
          timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
          type: NotificationType.info,
          category: NotificationCategory.systemInfo,
          badgeText: 'RAPOR BULANAN',
          route: '/review',
        ));
      }
    }

    // 6. Transaksi Terbaru (Only user-recorded transactions)
    for (final tx in userTransactions.take(4)) {
      final isInc = tx.transactionType == TransactionType.income;
      list.add(NotificationItemModel(
        id: 'tx_notif_${tx.id}',
        title: isInc ? 'Pemasukan Tercatat' : 'Pengeluaran Tercatat',
        message:
            '${CurrencyFormatter.format(tx.amount)} · ${tx.note?.isNotEmpty == true ? tx.note! : (tx.category?.name ?? 'Transaksi')}',
        timestamp: tx.createdAt.toLocal(),
        type: isInc ? NotificationType.success : NotificationType.info,
        category: NotificationCategory.systemInfo,
        badgeText: isInc ? 'PEMASUKAN' : 'PENGELUARAN',
        route: '/transactions',
      ));
    }

    return list;
  }

  static Future<bool> hasUnread({
    BudgetState? budgetState,
    GoalState? goalState,
    ProfileState? profileState,
    TransactionState? transactionState,
    StockSignalListState? stockSignalState,
    bool triggerSystemStatusBar = true,
  }) async {
    final userId = (profileState is ProfileLoaded) ? profileState.profile.id : null;
    final prefs = await SharedPreferences.getInstance();
    final readIds = {
      ...(prefs.getStringList(readPrefsKey) ?? []),
      ...(prefs.getStringList(readKeyForUser(userId)) ?? []),
    };
    final dismissedIds = {
      ...(prefs.getStringList(dismissedPrefsKey) ?? []),
      ...(prefs.getStringList(dismissedKeyForUser(userId)) ?? []),
    };

    final notifs = buildNotifications(
      budgetState: budgetState,
      goalState: goalState,
      profileState: profileState,
      transactionState: transactionState,
      stockSignalState: stockSignalState,
    ).where((n) => !dismissedIds.contains(n.id)).toList();

    final unreadNotifs = notifs.where((n) => !readIds.contains(n.id)).toList();

    // Dispatch any newly generated unread notification to the Android Status Bar
    if (triggerSystemStatusBar && unreadNotifs.isNotEmpty && userId != null) {
      final pushedKey = pushedKeyForUser(userId);
      final pushedIds = (prefs.getStringList(pushedKey) ?? []).toSet();
      final unpushed = unreadNotifs.where((n) => !pushedIds.contains(n.id)).toList();
      if (unpushed.isNotEmpty) {
        // Sort newest first and post up to 2 most recent unpushed notifications to status bar
        unpushed.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        for (final item in unpushed.take(2)) {
          final shown = await PushNotificationService().showStatusBarNotification(
            id: item.id,
            title: item.title,
            body: item.message,
            route: item.route,
          );
          if (shown) {
            pushedIds.add(item.id);
          }
        }
        await prefs.setStringList(pushedKey, pushedIds.toList());
      }
    }

    return unreadNotifs.isNotEmpty;
  }
}
