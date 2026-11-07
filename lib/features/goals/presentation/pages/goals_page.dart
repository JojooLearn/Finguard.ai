import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:lottie/lottie.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/explanation_sheet.dart';
import '../../domain/entities/goal_entity.dart';
import '../cubit/goal_cubit.dart';
import '../cubit/goal_state.dart';

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final Map<String, double> _localContributions = {};
  final List<_LocalGoalItem> _localCreatedGoals = [];

  void _showAddGoalDialog(BuildContext context, {bool hasEmergencyFund = false}) {
    final nameCtrl = TextEditingController();
    final targetCtrl = TextEditingController();
    final availableTypes = GoalType.values.where((t) {
      if (hasEmergencyFund && t == GoalType.emergencyFund) return false;
      return true;
    }).toList();
    GoalType selectedType = availableTypes.first;
    int selectedPriority = 3;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          String namePlaceholder = 'Misal: Beli Laptop, Liburan';
          if (selectedType == GoalType.emergencyFund) {
            namePlaceholder = 'Misal: Dana Darurat 6 Bulan';
          } else if (selectedType == GoalType.debtRepayment) {
            namePlaceholder = 'Misal: Lunasi Cicilan Laptop';
          } else if (selectedType == GoalType.other) {
            namePlaceholder = 'Misal: Modal Usaha Sampingan';
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
                    'Target Tabungan Baru',
                    style: AppTypography.screenTitle.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 16),

                  // Goal Type Chips
                  Text(
                    'Jenis Tabungan',
                    style: AppTypography.sectionLabel.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableTypes.map((t) {
                      final isSelected = selectedType == t;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedType = t),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.surfaceFieldFill,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            t.displayName,
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

                  // Name field
                  Text(
                    'Nama Target',
                    style: AppTypography.sectionLabel.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: nameCtrl,
                    style: AppTypography.body,
                    decoration: InputDecoration(
                      hintText: namePlaceholder,
                      hintStyle: AppTypography.bodySecondary,
                      filled: true,
                      fillColor: AppColors.surfaceFieldFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Target Amount
                  Text(
                    'Target Nominal',
                    style: AppTypography.sectionLabel.copyWith(fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: targetCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    style: AppTypography.bigNumber.copyWith(fontSize: 24),
                    decoration: InputDecoration(
                      prefixText: 'Rp ',
                      prefixStyle: AppTypography.bigNumber.copyWith(
                        fontSize: 22,
                      ),
                      hintText: '1.000.000',
                      filled: true,
                      fillColor: AppColors.surfaceFieldFill,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Priority selector (1-5 levels with clear meaning & explanation)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'Skala Prioritas',
                                style: AppTypography.sectionLabel.copyWith(
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(width: 5),
                              GestureDetector(
                                onTap: () {
                                  ExplanationSheet.show(
                                    context,
                                    title: 'Fungsi Skala Prioritas Target',
                                    metricValue: 'Level 1 s/d 5',
                                    formula: 'Level 5 = Paling Utama, Level 1 = Fleksibel',
                                    explanation:
                                        'Skala prioritas menentukan urutan target di beranda aplikasi dan menjadi acuan utama bagi AI Financial Coach dalam memandu alokasi uang dingin bulananmu.\n\n• Level 5 (Sangat Mendesak): Wajib diselesaikan pertama (seperti Dana Darurat & Utang Berbunga).\n• Level 4 (Tinggi): Target penting berikutnya.\n• Level 3 (Sedang): Rencana tabungan reguler standar.\n• Level 1-2 (Fleksibel): Target opsional / belanja gaya hidup di masa depan.',
                                    tip:
                                        'Disiplin memprioritaskan target Level 5 & 4 akan menjauhkanmu dari jebakan utang dan risiko finansial mendadak.',
                                    icon: PhosphorIcons.star(PhosphorIconsStyle.fill),
                                  );
                                },
                                child: Icon(
                                  PhosphorIcons.info(PhosphorIconsStyle.bold),
                                  size: 14,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: List.generate(5, (index) {
                              final level = index + 1;
                              final isSelected = level == selectedPriority;
                              return GestureDetector(
                                onTap: () =>
                                    setModalState(() => selectedPriority = level),
                                child: Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(left: 6),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.surfaceFieldFill,
                                    borderRadius: BorderRadius.circular(10),
                                    border: isSelected
                                        ? Border.all(
                                            color: AppColors.primaryDark,
                                            width: 1.5,
                                          )
                                        : null,
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '$level',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: selectedPriority >= 4
                              ? AppColors.expenseRedBg
                              : AppColors.primaryLight.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selectedPriority >= 4
                                  ? PhosphorIcons.fire(PhosphorIconsStyle.fill)
                                  : selectedPriority == 3
                                      ? PhosphorIcons.clockCountdown(PhosphorIconsStyle.fill)
                                      : PhosphorIcons.leaf(PhosphorIconsStyle.fill),
                              size: 14,
                              color: selectedPriority >= 4
                                  ? AppColors.danger
                                  : AppColors.primaryDark,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                selectedPriority == 5
                                    ? 'Level 5: Sangat Mendesak / Fokus Utama (Didahulukan)'
                                    : selectedPriority == 4
                                        ? 'Level 4: Prioritas Tinggi (Segera Diselesaikan)'
                                        : selectedPriority == 3
                                            ? 'Level 3: Prioritas Sedang (Rencana Reguler)'
                                            : selectedPriority == 2
                                                ? 'Level 2: Prioritas Rendah (Bisa Ditunda)'
                                                : 'Level 1: Prioritas Fleksibel / Opsional',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: selectedPriority >= 4
                                      ? AppColors.danger
                                      : AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  AppButton(
                    label: 'Simpan Target Tabungan',
                    onPressed: () {
                      final goalName = nameCtrl.text.trim();
                      if (goalName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Nama target tabungan wajib diisi.',
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

                      final rawTarget = targetCtrl.text
                          .replaceAll('.', '')
                          .replaceAll(',', '')
                          .trim();
                      final target = double.tryParse(rawTarget);
                      if (target == null || target <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Target nominal tabungan harus lebih dari Rp0.',
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

                      setState(() {
                        _localCreatedGoals.add(
                          _LocalGoalItem(
                            id: 'local_${DateTime.now().millisecondsSinceEpoch}',
                            title: goalName,
                            targetDate: 'Des 2027',
                            current: 0,
                            target: target,
                            type: selectedType,
                            priority: selectedPriority,
                          ),
                        );
                      });

                      context.read<GoalCubit>().createGoal(
                        name: goalName,
                        type: selectedType,
                        targetAmount: target,
                        priority: selectedPriority,
                      );
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Mantap! Celengan baru berhasil dibuat dan siap diisi.',
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
        },
      ),
    );
  }

  void _showCelebrationDialog(BuildContext context, String goalTitle) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 170,
              height: 170,
              child: Lottie.asset(
                'assets/animations/scr08_goal_piggy_celebration.json',
                repeat: true,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Target Tercapai! 🎉',
              style: AppTypography.screenTitle.copyWith(
                fontSize: 20,
                color: AppColors.primaryDark,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Selamat! Celengan "$goalTitle" kamu sudah tembus target 100%. Pertahankan disiplin finansial ini, Boss!',
              style: AppTypography.body.copyWith(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            AppButton(
              label: 'Mantap, Lanjutkan!',
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      ),
    );
  }

  void _showContributionSheet(
    BuildContext context, {
    required String goalId,
    required String title,
    double currentAmount = 0,
    double targetAmount = 0,
  }) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 28,
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
                'Tambah Tabungan',
                style: AppTypography.screenTitle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 4),
              Text(title, style: AppTypography.caption),
              const SizedBox(height: 16),
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [CurrencyInputFormatter()],
                style: AppTypography.bigNumber.copyWith(fontSize: 28),
                decoration: InputDecoration(
                  prefixText: 'Rp ',
                  prefixStyle: AppTypography.bigNumber.copyWith(fontSize: 24),
                  hintText: '500.000',
                  filled: true,
                  fillColor: AppColors.surfaceFieldFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Catatan (opsional)',
                style: AppTypography.sectionLabel.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: noteCtrl,
                style: AppTypography.body,
                decoration: InputDecoration(
                  hintText: 'Setoran tabungan bulanan',
                  hintStyle: AppTypography.bodySecondary,
                  filled: true,
                  fillColor: AppColors.surfaceFieldFill,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
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
                  final amount = double.tryParse(
                    amountCtrl.text
                        .replaceAll('.', '')
                        .replaceAll(',', '')
                        .trim(),
                  );
                  if (amount == null || amount <= 0) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Masukin nominal nabungnya dulu, kocak!',
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

                  setState(() {
                    _localContributions[goalId] =
                        (_localContributions[goalId] ?? 0) + amount;
                  });

                  context.read<GoalCubit>().addContribution(
                    goalId: goalId,
                    amount: amount,
                    date: DateTime.now(),
                    note: noteCtrl.text.trim().isNotEmpty
                        ? noteCtrl.text.trim()
                        : null,
                  );

                  Navigator.pop(ctx);
                  final isTargetReached = targetAmount > 0 &&
                      (currentAmount + amount) >= targetAmount;

                  if (isTargetReached) {
                    Future.delayed(const Duration(milliseconds: 300), () {
                      if (mounted) _showCelebrationDialog(this.context, title);
                    });
                  } else {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Cakep! Setoran ${CurrencyFormatter.format(amount)} masuk ke $title.',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: AppColors.incomeGreen,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GoalCubit, GoalState>(
      builder: (context, state) {
        final List<_LocalGoalItem> displayGoals = [];

        if (state is GoalLoaded) {
          for (final g in state.goals) {
            displayGoals.add(
              _LocalGoalItem(
                id: g.id,
                title: g.name,
                targetDate: g.targetDate != null
                    ? 'Des ${g.targetDate!.year}'
                    : 'Des 2027',
                current: g.currentAmount + (_localContributions[g.id] ?? 0),
                target: g.targetAmount,
                type: g.goalType,
                priority: g.priority,
              ),
            );
          }
        }
        for (final g in _localCreatedGoals) {
          if (!displayGoals.any((d) => d.id == g.id || d.title == g.title)) {
            displayGoals.add(
              _LocalGoalItem(
                id: g.id,
                title: g.title,
                targetDate: g.targetDate,
                current: g.current + (_localContributions[g.id] ?? 0),
                target: g.target,
                type: g.type,
                priority: g.priority,
              ),
            );
          }
        }

        // Sort: Emergency Fund first (pinned hero card), then by priority descending (5 to 1)
        displayGoals.sort((a, b) {
          if (a.type == GoalType.emergencyFund && b.type != GoalType.emergencyFund) return -1;
          if (b.type == GoalType.emergencyFund && a.type != GoalType.emergencyFund) return 1;
          return b.priority.compareTo(a.priority);
        });

        final hasEmergencyFund = displayGoals.any((g) => g.type == GoalType.emergencyFund);

        return Scaffold(
          backgroundColor: AppColors.background,
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surfaceCard,
              onRefresh: () => context.read<GoalCubit>().loadGoals(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.only(
                  left: AppSpacing.sideMargin,
                  right: AppSpacing.sideMargin,
                  top: 12,
                  bottom: 120,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Standardized consistent header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            AppIconButton(
                              icon: PhosphorIcons.arrowLeft(),
                              onPressed: () => Navigator.pop(context),
                            ),
                            const SizedBox(width: 14),
                            Text(
                              'Target Tabungan',
                              style: AppTypography.pageHeader,
                            ),
                          ],
                        ),
                        AppIconButton(
                          icon: PhosphorIcons.plus(),
                          onPressed: () => _showAddGoalDialog(
                            context,
                            hasEmergencyFund: hasEmergencyFund,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    if (displayGoals.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          vertical: 40,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.cardRadius,
                          ),
                        ),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/images/empty_goals.png',
                              width: 160,
                              height: 160,
                              fit: BoxFit.contain,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Belum Ada Target Tabungan',
                              style: AppTypography.screenTitle.copyWith(
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Mulai buat target tabungan seperti Dana Darurat atau rencana belanja impian.',
                              style: AppTypography.caption,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            AppButton(
                              label: 'Tambah Target Baru',
                              onPressed: () => _showAddGoalDialog(
                                context,
                                hasEmergencyFund: hasEmergencyFund,
                              ),
                            ),
                          ],
                        ),
                      ),

                    for (int i = 0; i < displayGoals.length; i++) ...[
                      if (i == 0)
                        _buildFeaturedDarkGoalCard(
                          context: context,
                          goal: displayGoals[i],
                        )
                      else
                        _buildSecondaryGoalCard(
                          context: context,
                          goal: displayGoals[i],
                        ),
                      const SizedBox(height: 16),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _confirmDeleteGoal(BuildContext context, _LocalGoalItem goal) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Hapus Target Tabungan?',
          style: AppTypography.itemTitle.copyWith(fontSize: 18),
        ),
        content: Text(
          'Target "${goal.title}" akan dihapus dari daftar celenganmu. Saldo di buku kasmu tetap aman.',
          style: AppTypography.body.copyWith(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _localCreatedGoals.removeWhere(
                  (g) => g.id == goal.id || g.title == goal.title,
                );
              });
              context.read<GoalCubit>().deleteGoal(goal.id);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Target "${goal.title}" berhasil dihapus.'),
                  backgroundColor: AppColors.primaryDark,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            child: const Text(
              'Hapus',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Featured Primary Goal Card (Zero Shadows, Clean Bento)
  Widget _buildFeaturedDarkGoalCard({
    required BuildContext context,
    required _LocalGoalItem goal,
  }) {
    final progress = goal.target > 0 ? (goal.current / goal.target) : 0.0;
    final percent = (progress * 100).toInt();
    final isEmergency = goal.type == GoalType.emergencyFund;
    final remaining = (goal.target - goal.current).clamp(0.0, double.infinity);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppColors.darkCardGradient,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Left Icon + Metadata Column, Right Actions
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    isEmergency
                        ? PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)
                        : PhosphorIcons.target(PhosphorIconsStyle.fill),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge Row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isEmergency
                                    ? PhosphorIcons.shieldCheck(
                                        PhosphorIconsStyle.fill,
                                      )
                                    : PhosphorIcons.star(PhosphorIconsStyle.fill),
                                size: 10,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isEmergency
                                    ? 'Fokus Utama'
                                    : 'Prioritas ${goal.priority}/5',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            goal.targetDate,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Title + Info Trigger (Spacious & Clean)
                    GestureDetector(
                      onTap: () {
                        final essentialMonthly =
                            goal.target > 0 ? (goal.target / 3) : 0.0;
                        if (isEmergency) {
                          ExplanationSheet.show(
                            context,
                            title: goal.title,
                            metricValue: CurrencyFormatter.format(goal.target),
                            formula:
                                '3 Bulan x ${CurrencyFormatter.format(essentialMonthly)} = ${CurrencyFormatter.format(goal.target)}',
                            explanation:
                                'Target celengan Dana Darurat sebesar ${CurrencyFormatter.format(goal.target)} dihitung dari 3 kali kebutuhan pokok bulananmu (${CurrencyFormatter.format(essentialMonthly)} per bulan).\n\nSaat ini telah terkumpul ${CurrencyFormatter.format(goal.current)} ($percent%). Sisa kekurangan yang perlu kamu kumpulkan adalah ${CurrencyFormatter.format(remaining)}.',
                            tip:
                                'Simpan dana darurat di tabungan terpisah yang mudah dicairkan tapi tidak terhubung ke kartu debit belanja harian.',
                            icon: PhosphorIcons.shieldCheck(
                              PhosphorIconsStyle.fill,
                            ),
                          );
                        } else {
                          ExplanationSheet.show(
                            context,
                            title: goal.title,
                            metricValue: CurrencyFormatter.format(goal.target),
                            formula:
                                'Terkumpul ${CurrencyFormatter.format(goal.current)} / Target ${CurrencyFormatter.format(goal.target)} ($percent%)',
                            explanation:
                                'Target tabungan untuk "${goal.title}". Dari total target sebesar ${CurrencyFormatter.format(goal.target)}, kamu sudah mengumpulkan ${CurrencyFormatter.format(goal.current)} ($percent%). Sisa dana yang dibutuhkan adalah ${CurrencyFormatter.format(remaining)}.',
                            tip:
                                'Sisihkan di awal bulan secara konsisten setiap menerima penghasilan agar target tercapai sesuai jadwal.',
                            icon: PhosphorIcons.piggyBank(
                              PhosphorIconsStyle.fill,
                            ),
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              goal.title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            PhosphorIcons.info(PhosphorIconsStyle.bold),
                            size: 15,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEmergency)
                GestureDetector(
                  onTap: () => _confirmDeleteGoal(context, goal),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        PhosphorIcons.trash(),
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Balance Showcase Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TERKUMPUL SAAT INI',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: Colors.white.withValues(alpha: 0.65),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    CurrencyFormatter.format(goal.current),
                    style: AppTypography.bigNumberLight.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            remaining > 0
                ? 'Target ${CurrencyFormatter.format(goal.target)} • Kurang ${CurrencyFormatter.format(remaining)}'
                : 'Target ${CurrencyFormatter.format(goal.target)} • Sudah Terpenuhi 🎉',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 14),

          // Sleek Progress Track
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.18),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 20),

          // Sleek Action Button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _showContributionSheet(
                context,
                goalId: goal.id,
                title: goal.title,
                currentAmount: goal.current,
                targetAmount: goal.target,
              ),
              borderRadius: BorderRadius.circular(100),
              child: Container(
                width: double.infinity,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      PhosphorIcons.plusCircle(PhosphorIconsStyle.fill),
                      size: 18,
                      color: AppColors.primaryDark,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Masukin Tabungan',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Secondary Goal Card (Zero Shadows)
  Widget _buildSecondaryGoalCard({
    required BuildContext context,
    required _LocalGoalItem goal,
  }) {
    final progress = goal.target > 0 ? (goal.current / goal.target) : 0.0;
    final percent = (progress * 100).toInt();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(
                    goal.type == GoalType.savings
                        ? PhosphorIcons.piggyBank(PhosphorIconsStyle.fill)
                        : PhosphorIcons.target(PhosphorIconsStyle.fill),
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    final remaining = (goal.target - goal.current).clamp(
                      0.0,
                      double.infinity,
                    );
                    ExplanationSheet.show(
                      context,
                      title: goal.title,
                      metricValue: CurrencyFormatter.format(goal.target),
                      formula:
                          'Terkumpul ${CurrencyFormatter.format(goal.current)} / Target ${CurrencyFormatter.format(goal.target)} ($percent%)',
                      explanation:
                          'Target tabungan "${goal.title}". Dari total rencana ${CurrencyFormatter.format(goal.target)}, sudah terkumpul sebesar ${CurrencyFormatter.format(goal.current)} ($percent%). Sisa dana yang dibutuhkan adalah ${CurrencyFormatter.format(remaining)}.',
                      tip:
                          'Sisihkan secara konsisten di awal bulan setiap gajian agar target tercapai pada ${goal.targetDate}.',
                      icon: goal.type == GoalType.savings
                          ? PhosphorIcons.piggyBank(PhosphorIconsStyle.fill)
                          : PhosphorIcons.target(PhosphorIconsStyle.fill),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              goal.title,
                              style: AppTypography.sectionLabel.copyWith(
                                fontSize: 16,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            PhosphorIcons.info(PhosphorIconsStyle.bold),
                            size: 13,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: goal.priority >= 4
                                  ? AppColors.expenseRedBg
                                  : AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              goal.priority == 5
                                  ? 'P5 • Utama'
                                  : goal.priority == 4
                                      ? 'P4 • Tinggi'
                                      : goal.priority == 3
                                          ? 'P3 • Sedang'
                                          : 'P${goal.priority} • Santai',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: goal.priority >= 4
                                    ? AppColors.danger
                                    : AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(goal.targetDate, style: AppTypography.caption),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceFieldFill,
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  '$percent%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _confirmDeleteGoal(context, goal),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFieldFill,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      PhosphorIcons.trash(),
                      size: 14,
                      color: AppColors.expenseRed,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                CurrencyFormatter.format(goal.current),
                style: AppTypography.sectionLabel.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                'dari ${CurrencyFormatter.format(goal.target)}',
                style: AppTypography.caption,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.black.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AppButton(
            label: 'Masukin Tabungan',
            variant: AppButtonVariant.secondary,
            onPressed: () => _showContributionSheet(
              context,
              goalId: goal.id,
              title: goal.title,
              currentAmount: goal.current,
              targetAmount: goal.target,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocalGoalItem {
  final String id;
  final String title;
  final String targetDate;
  final double current;
  final double target;
  final GoalType type;
  final int priority;

  const _LocalGoalItem({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.current,
    required this.target,
    required this.type,
    this.priority = 3,
  });
}
