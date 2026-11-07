import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:finguard/features/notifications/domain/notification_helper.dart';
import 'package:finguard/features/budgets/presentation/cubit/budget_state.dart';
import 'package:finguard/features/budgets/domain/entities/budget_entity.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('NotificationHelper', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    final now = DateTime.now();

    test('generates budget alert notification when spent exceeds limit', () {
      final budget = BudgetEntity(
        id: 'b1',
        userId: 'u1',
        categoryId: 'c1',
        categoryName: 'Makan & Minum',
        limitAmount: 50000,
        spentAmount: 60000,
        periodStart: now,
        periodEnd: now,
        createdAt: now,
        updatedAt: now,
      );

      final notifs = NotificationHelper.buildNotifications(
        budgetState: BudgetLoaded(
          budgets: [budget],
          periodStart: now,
          periodEnd: now,
        ),
      );

      expect(notifs.length, 1);
      expect(notifs.first.id, 'budget_over_b1');
      expect(notifs.first.title, contains('Jebol'));
      expect(notifs.first.message, contains('batas belanja'));
      expect(notifs.first.message.contains('pagu'), isFalse);
    });

    test('hasUnread accurately identifies read and unread status', () async {
      final budget = BudgetEntity(
        id: 'b1',
        userId: 'u1',
        categoryId: 'c1',
        categoryName: 'Makan & Minum',
        limitAmount: 50000,
        spentAmount: 60000,
        periodStart: now,
        periodEnd: now,
        createdAt: now,
        updatedAt: now,
      );

      // Initially unread
      bool unread = await NotificationHelper.hasUnread(
        budgetState: BudgetLoaded(
          budgets: [budget],
          periodStart: now,
          periodEnd: now,
        ),
      );
      expect(unread, isTrue);

      // Mark as read in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('read_notification_ids', ['budget_over_b1']);

      // Now should be false
      unread = await NotificationHelper.hasUnread(
        budgetState: BudgetLoaded(
          budgets: [budget],
          periodStart: now,
          periodEnd: now,
        ),
      );
      expect(unread, isFalse);
    });
  });
}
