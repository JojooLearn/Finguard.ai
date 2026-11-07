import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/utils/financial_calculator.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/explanation_sheet.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../goals/domain/entities/goal_entity.dart';
import '../../../goals/presentation/cubit/goal_cubit.dart';
import '../../../goals/presentation/cubit/goal_state.dart';
import '../../../profile/presentation/cubit/profile_cubit.dart';
import '../../../profile/presentation/cubit/profile_state.dart';

class CalculatorsPage extends StatefulWidget {
  const CalculatorsPage({super.key});

  @override
  State<CalculatorsPage> createState() => _CalculatorsPageState();
}

class _CalculatorsPageState extends State<CalculatorsPage> {
  int _tabIndex = 0; // 0: Emergency Fund, 1: Compound Growth, 2: Debt Ratio
  bool _dataInitialized = false;

  // Emergency Fund
  final _expenseController = TextEditingController();
  int _selectedMonths = 3;
  final _currentFundController = TextEditingController();
  final _contributionController = TextEditingController();
  Map<String, dynamic>? _emergencyResult;

  // Compound Growth
  final _principalController = TextEditingController();
  final _monthlyContribController = TextEditingController();
  final _rateController = TextEditingController(text: '7');
  final _yearsController = TextEditingController(text: '5');
  double? _compoundResult;

  // Debt Ratio
  final _debtIncomeController = TextEditingController();
  final _debtPaymentController = TextEditingController();
  double? _debtRatioResult;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _populateFromUserContext();
  }

  void _populateFromUserContext() {
    if (_dataInitialized) return;

    final profileState = context.read<ProfileCubit>().state;
    final goalState = context.read<GoalCubit>().state;

    double income = 1000000;
    double essential = 500000;
    double debt = 0;
    double currentEmergency = 0;

    if (profileState is ProfileLoaded) {
      final p = profileState.profile;
      if (p.monthlyIncome > 0) {
        income = p.monthlyIncome;
        essential =
            p.essentialExpenses > 0 ? p.essentialExpenses : (income * 0.50);
        debt = p.monthlyDebt;
      }
    }

    if (goalState is GoalLoaded) {
      final emGoal = goalState.goals
          .where((g) =>
              g.goalType == GoalType.emergencyFund ||
              g.name.toLowerCase().contains('darurat'))
          .firstOrNull;
      if (emGoal != null) {
        currentEmergency = emGoal.currentAmount;
      }
    }

    final savingsAlloc = (income * 0.20).roundToDouble();

    _expenseController.text = CurrencyInputFormatter.format(essential);
    _contributionController.text = CurrencyInputFormatter.format(savingsAlloc);
    _currentFundController.text =
        CurrencyInputFormatter.format(currentEmergency);

    _debtIncomeController.text = CurrencyInputFormatter.format(income);
    _debtPaymentController.text = CurrencyInputFormatter.format(debt);

    _monthlyContribController.text =
        CurrencyInputFormatter.format(savingsAlloc);
    _principalController.text = CurrencyInputFormatter.format(
        currentEmergency > 0 ? currentEmergency : savingsAlloc * 2);

    _calcEmergency();
    _calcCompound();
    _calcDebt();

    _dataInitialized = true;
  }

  @override
  void dispose() {
    _expenseController.dispose();
    _currentFundController.dispose();
    _contributionController.dispose();
    _principalController.dispose();
    _monthlyContribController.dispose();
    _rateController.dispose();
    _yearsController.dispose();
    _debtIncomeController.dispose();
    _debtPaymentController.dispose();
    super.dispose();
  }

  double _parseNum(String text) {
    return CurrencyInputFormatter.parse(text);
  }

  void _calcEmergency() {
    final exp = _parseNum(_expenseController.text);
    final current = _parseNum(_currentFundController.text);
    final contrib = _parseNum(_contributionController.text);

    setState(() {
      _emergencyResult = FinancialCalculator.calculateEmergencyFund(
        essentialMonthlyExpenses: exp,
        targetMonths: _selectedMonths,
        currentFund: current,
        monthlyContribution: contrib,
      );
    });
  }

  void _calcCompound() {
    final principal = _parseNum(_principalController.text);
    final contrib = _parseNum(_monthlyContribController.text);
    final rate = (_parseNum(_rateController.text)) / 100 / 12;
    final periods = (_parseNum(_yearsController.text).toInt()) * 12;

    setState(() {
      _compoundResult = FinancialCalculator.calculateCompoundGrowth(
        initialPrincipal: principal,
        periodicContribution: contrib,
        periodicRate: rate,
        totalPeriods: periods,
      );
    });
  }

  void _calcDebt() {
    final income = _parseNum(_debtIncomeController.text);
    final debt = _parseNum(_debtPaymentController.text);

    setState(() {
      _debtRatioResult = FinancialCalculator.calculateDebtRatio(
        monthlyDebtPayments: debt,
        monthlyIncome: income,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.screenBackground,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header (Standardized consistent style)
                Row(
                  children: [
                    AppIconButton(
                      icon: PhosphorIcons.arrowLeft(),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      'Kalkulator Cuan & Cicilan',
                      style: AppTypography.pageHeader,
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Contextual Auto-fill Reassurance Pill (Tonal Flat Surface)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius:
                        BorderRadius.circular(AppSpacing.radiusInnerElement),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Angka di bawah otomatis diselaraskan dari profil & peta alokasi 50/30/20 kamu. Silakan ubah jika ingin simulasi bebas.',
                          style: AppTypography.captionText.copyWith(
                            color: AppColors.primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Calculator Type Tabs (Single unified pill segmented control)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFieldFill,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildTabBtn('Dana Darurat', 0)),
                      Expanded(child: _buildTabBtn('Nabung Rutin', 1)),
                      Expanded(child: _buildTabBtn('Cek Cicilan', 2)),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                if (_tabIndex == 0) _buildEmergencyView(),
                if (_tabIndex == 1) _buildCompoundView(),
                if (_tabIndex == 2) _buildDebtRatioView(),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabBtn(String label, int index) {
    final isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _tabIndex = index);
        if (index == 0) _calcEmergency();
        if (index == 1) _calcCompound();
        if (index == 2) _calcDebt();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyView() {
    return Column(
      children: [
        // Form Card (Zero Shadows)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputRow(
                'Kebutuhan pokok per bulan',
                _expenseController,
                prefix: 'Rp ',
                isCurrency: true,
              ),
              const SizedBox(height: 14),
              Text(
                'Target jangka waktu aman',
                style: AppTypography.sectionLabel.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [3, 6, 12].map((m) {
                  final selected = _selectedMonths == m;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedMonths = m);
                        _calcEmergency();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : AppColors.surfaceFieldFill,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '$m bln',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              _buildInputRow(
                'Dana darurat saat ini',
                _currentFundController,
                prefix: 'Rp ',
                isCurrency: true,
              ),
              const SizedBox(height: 14),
              _buildInputRow(
                'Alokasi tabungan per bulan',
                _contributionController,
                prefix: 'Rp ',
                isCurrency: true,
              ),
              const SizedBox(height: 18),
              AppButton(label: 'Hitung Target', onPressed: _calcEmergency),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_emergencyResult != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Proyeksi Target Dana Darurat',
                          style: AppTypography.itemTitle.copyWith(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () {
                            final rawExp = double.tryParse(
                                  _expenseController.text
                                      .replaceAll('.', '')
                                      .replaceAll(',', ''),
                                ) ??
                                0.0;
                            final targetVal =
                                _emergencyResult!['target'] as double;
                            ExplanationSheet.show(
                              context,
                              title: 'Perhitungan Target Dana Darurat',
                              metricValue: CurrencyFormatter.format(targetVal),
                              formula:
                                  '${CurrencyFormatter.format(rawExp)} x $_selectedMonths Bulan = ${CurrencyFormatter.format(targetVal)}',
                              explanation:
                                  'Target dana darurat sebesar ${CurrencyFormatter.format(targetVal)} dihitung dari estimasi pengeluaran bulananmu (${CurrencyFormatter.format(rawExp)}) dikali durasi proteksi selama $_selectedMonths bulan yang kamu pilih.',
                              tip:
                                  'Simpan di rekening terpisah tanpa kartu debit agar tidak tergoda untuk dipakai belanja konsumtif.',
                              icon: PhosphorIcons.shieldCheck(
                                PhosphorIconsStyle.fill,
                              ),
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight,
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusPill),
                      ),
                      child: Text(
                        '$_selectedMonths Bulan Proteksi',
                        style: AppTypography.captionText.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  CurrencyFormatter.format(
                      _emergencyResult!['target'] as double),
                  style: AppTypography.bigNumber.copyWith(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFieldFill,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Kekurangan Saldo',
                        style: AppTypography.captionText.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        CurrencyFormatter.format(
                            _emergencyResult!['remaining'] as double),
                        style: AppTypography.captionText.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_emergencyResult!['estimatedMonths'] != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.incomeGreenBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          PhosphorIcons.clockClockwise(PhosphorIconsStyle.bold),
                          size: 16,
                          color: AppColors.incomeGreen,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Estimasi tercapai dalam ${_emergencyResult!['estimatedMonths']} bulan lagi (nabung ${_contributionController.text}/bln).',
                            style: AppTypography.captionText.copyWith(
                              color: AppColors.incomeGreen,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Center(
                  child: Text(
                    'Simulasi proyeksi matematis ini tidak mengubah data celengan asli.',
                    style: AppTypography.smallCaption.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCompoundView() {
    return Column(
      children: [
        // Form Card (Zero Shadows)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputRow(
                'Modal awal',
                _principalController,
                prefix: 'Rp ',
                isCurrency: true,
              ),
              const SizedBox(height: 12),
              _buildInputRow(
                'Setoran per bulan',
                _monthlyContribController,
                prefix: 'Rp ',
                isCurrency: true,
              ),
              const SizedBox(height: 12),
              _buildInputRow(
                'Perkiraan imbal hasil per tahun (%)',
                _rateController,
                isCurrency: false,
              ),
              const SizedBox(height: 12),
              _buildInputRow(
                'Durasi menabung (tahun)',
                _yearsController,
                isCurrency: false,
              ),
              const SizedBox(height: 18),
              AppButton(label: 'Hitung Simulasi', onPressed: _calcCompound),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_compoundResult != null)
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: AppColors.limeCardGradient,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Estimasi Akumulasi Tabungan',
                      style: TextStyle(
                        color: AppColors.primaryDark.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        final p = double.tryParse(
                              _principalController.text
                                  .replaceAll('.', '')
                                  .replaceAll(',', ''),
                            ) ??
                            0.0;
                        final pmt = double.tryParse(
                              _monthlyContribController.text
                                  .replaceAll('.', '')
                                  .replaceAll(',', ''),
                            ) ??
                            0.0;
                        final r = double.tryParse(
                              _rateController.text.replaceAll(',', '.'),
                            ) ??
                            0.0;
                        final t = int.tryParse(_yearsController.text) ?? 0;
                        final totalPrincipal = p + (pmt * 12 * t);
                        final totalInterest =
                            (_compoundResult! - totalPrincipal).clamp(
                              0.0,
                              double.infinity,
                            );

                        ExplanationSheet.show(
                          context,
                          title: 'Simulasi Bunga Majemuk',
                          metricValue:
                              CurrencyFormatter.format(_compoundResult!),
                          formula:
                              'Modal ${CurrencyFormatter.format(totalPrincipal)} + Cuan ${CurrencyFormatter.format(totalInterest)} = ${CurrencyFormatter.format(_compoundResult!)}',
                          explanation:
                              'Dengan modal awal ${CurrencyFormatter.format(p)} dan setoran rutin ${CurrencyFormatter.format(pmt)}/bulan selama $t tahun (total setoran modal ${CurrencyFormatter.format(totalPrincipal)}), asumsi return tahunan $r% menghasilkan akumulasi keuntungan bunga majemuk sebesar ${CurrencyFormatter.format(totalInterest)}.',
                          tip:
                              'Semakin panjang durasi dan konsisten setoran bulananmu, efek pelipatgandaan keuntungan majemuk akan semakin dahsyat!',
                          icon: PhosphorIcons.chartLineUp(
                            PhosphorIconsStyle.fill,
                          ),
                        );
                      },
                      child: Icon(
                        PhosphorIcons.info(PhosphorIconsStyle.bold),
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  CurrencyFormatter.format(_compoundResult!),
                  style: AppTypography.bigNumber,
                ),
                const SizedBox(height: 8),
                Text(
                  'Proyeksi pertumbuhan dengan formula bunga majemuk (${_yearsController.text} tahun, bunga ${_rateController.text}%/thn).',
                  style: AppTypography.smallCaption.copyWith(
                    color: AppColors.primaryDark.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDebtRatioView() {
    return Column(
      children: [
        // Form Card (Zero Shadows)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInputRow(
                'Pemasukan bersih sebulan',
                _debtIncomeController,
                prefix: 'Rp ',
                isCurrency: true,
              ),
              const SizedBox(height: 12),
              _buildInputRow(
                'Total cicilan atau utang bulanan',
                _debtPaymentController,
                prefix: 'Rp ',
                isCurrency: true,
              ),
              const SizedBox(height: 18),
              AppButton(label: 'Cek Beban Cicilan', onPressed: _calcDebt),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_debtRatioResult != null)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard,
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Porsi Cicilan dari Pemasukan',
                        style: AppTypography.caption),
                    _debtRatioResult! > 30
                        ? StatusChip.melebihi('Beban Tinggi')
                        : StatusChip.aman('Porsi Ideal'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${_debtRatioResult!.toStringAsFixed(1)}%',
                  style: AppTypography.bigNumber.copyWith(
                    color: _debtRatioResult! > 30
                        ? AppColors.danger
                        : AppColors.success,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _debtRatioResult! > 30
                      ? 'Rasio cicilan melebihi 30% dari pemasukan. Batasi komitmen cicilan baru agar arus kas tetap sehat.'
                      : 'Kondisi sehat. Total beban cicilan bulananmu masih berada dalam batas aman di bawah 30%.',
                  style: AppTypography.body,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildInputRow(
    String label,
    TextEditingController controller, {
    String? prefix,
    bool isCurrency = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.sectionLabel.copyWith(fontSize: 13)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          inputFormatters: isCurrency ? [CurrencyInputFormatter()] : null,
          style: AppTypography.body.copyWith(fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            prefixText: prefix,
            prefixStyle: prefix != null
                ? AppTypography.body.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  )
                : null,
            filled: true,
            fillColor: AppColors.surfaceFieldFill,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
