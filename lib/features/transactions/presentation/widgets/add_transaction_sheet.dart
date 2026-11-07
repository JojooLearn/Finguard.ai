import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../domain/entities/category_entity.dart';
import '../cubit/transaction_cubit.dart';
import '../cubit/transaction_state.dart';

class AddTransactionSheet extends StatelessWidget {
  final VoidCallback onSelectCoach;
  final VoidCallback onSelectManual;

  const AddTransactionSheet({
    super.key,
    required this.onSelectCoach,
    required this.onSelectManual,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onOpenCoachTab,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => AddTransactionSheet(
        onSelectCoach: () {
          Navigator.pop(ctx);
          if (onOpenCoachTab != null) {
            onOpenCoachTab();
          } else {
            context.push('/coach');
          }
        },
        onSelectManual: () {
          Navigator.pop(ctx);
          _showManualForm(context);
        },
      ),
    );
  }

  static void _showManualForm(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => const _ManualTransactionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 40),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Tambah transaksi',
            style: AppTypography.screenTitle.copyWith(fontSize: 20),
          ),
          const SizedBox(height: 18),
          _buildOptionTile(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'Ketik di Coach',
            subtitle: 'AI ekstrak nominal dan kategori otomatis',
            onTap: onSelectCoach,
          ),
          const SizedBox(height: 12),
          _buildOptionTile(
            icon: Icons.edit_note_rounded,
            title: 'Isi manual',
            subtitle: 'Masukkan nominal, kategori, dan catatan',
            onTap: onSelectManual,
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surfaceFieldFill,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.sectionLabel.copyWith(fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTypography.caption.copyWith(fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.primaryDark,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualTransactionSheet extends StatefulWidget {
  const _ManualTransactionSheet();

  @override
  State<_ManualTransactionSheet> createState() =>
      _ManualTransactionSheetState();
}

class _ManualTransactionSheetState extends State<_ManualTransactionSheet> {
  bool isIncome = false;
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  String selectedCategory = 'Makan & Minum';

  static const _expenseCategories = [
    'Makan & Minum',
    'Transportasi',
    'Hiburan',
    'Belanja Harian',
    'Tagihan & Utilitas',
    'Kesehatan',
  ];

  static const _incomeCategories = [
    'Gaji & Upah',
    'Bonus & Komisi',
    'Investasi',
    'Lainnya',
  ];

  @override
  void dispose() {
    amountController.dispose();
    noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = isIncome ? _incomeCategories : _expenseCategories;
    if (!categories.contains(selectedCategory)) {
      selectedCategory = categories.first;
    }

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Tambah transaksi',
              style: AppTypography.screenTitle.copyWith(fontSize: 20),
            ),
            const SizedBox(height: 16),

            // Segmented pill toggle: Pengeluaran / Pemasukan
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceFieldFill,
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        isIncome = false;
                        selectedCategory = _expenseCategories.first;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: !isIncome
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Pengeluaran',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: !isIncome
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() {
                        isIncome = true;
                        selectedCategory = _incomeCategories.first;
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isIncome
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          'Pemasukan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isIncome
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Large Rp Amount Input
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              inputFormatters: [CurrencyInputFormatter()],
              style: AppTypography.bigNumber.copyWith(fontSize: 32),
              decoration: InputDecoration(
                prefixText: 'Rp ',
                prefixStyle: AppTypography.bigNumber.copyWith(fontSize: 28),
                hintText: '0',
                filled: true,
                fillColor: AppColors.surfaceFieldFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Category Selection Chips
            Text(
              'Kategori',
              style: AppTypography.sectionLabel.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((cat) {
                final isSelected = selectedCategory == cat;
                return GestureDetector(
                  onTap: () => setState(() => selectedCategory = cat),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.surfaceFieldFill,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Note
            Text(
              'Catatan (opsional)',
              style: AppTypography.sectionLabel.copyWith(fontSize: 13),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: noteController,
              style: AppTypography.body,
              decoration: InputDecoration(
                hintText: 'Misal: Kopi susu, Makan siang',
                hintStyle: AppTypography.bodySecondary,
                filled: true,
                fillColor: AppColors.surfaceFieldFill,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 22),

            AppButton(
              label: 'Simpan',
              onPressed: () {
                final rawAmount = amountController.text
                    .replaceAll('.', '')
                    .replaceAll(',', '')
                    .trim();
                final amount = double.tryParse(rawAmount);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text(
                        'Isi nominalnya dulu, kocak! Masa 0 rupiah.',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      backgroundColor: AppColors.expenseRed,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  );
                  return;
                }

                final rawNote = noteController.text.trim();
                final noteText =
                    rawNote.isNotEmpty ? rawNote : selectedCategory;

                // Lookup Category and Account ID from Cubit state
                String? catId;
                String? accId;
                final cubitState = context.read<TransactionCubit>().state;
                if (cubitState is TransactionLoaded) {
                  final cat = cubitState.categories.where((c) =>
                      c.name.toLowerCase() == selectedCategory.toLowerCase()).firstOrNull;
                  catId = cat?.id;

                  final acc = cubitState.accounts.where((a) => a.isDefault).firstOrNull ??
                      cubitState.accounts.firstOrNull;
                  accId = acc?.id;
                }

                context.read<TransactionCubit>().addTransaction(
                      amount: amount,
                      type: isIncome
                          ? TransactionType.income
                          : TransactionType.expense,
                      transactionDate: DateTime.now(),
                      categoryId: catId,
                      accountId: accId,
                      note: noteText,
                    );

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text(
                      'Mantap! Transaksi berhasil dicatat.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: AppColors.incomeGreen,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
