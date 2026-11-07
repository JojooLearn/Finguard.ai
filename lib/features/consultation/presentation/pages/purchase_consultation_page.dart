import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/currency_input_formatter.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../domain/entities/consultation_result_entity.dart';
import '../cubit/consultation_cubit.dart';
import '../cubit/consultation_state.dart';

class PurchaseConsultationPage extends StatefulWidget {
  const PurchaseConsultationPage({super.key});

  @override
  State<PurchaseConsultationPage> createState() =>
      _PurchaseConsultationPageState();
}

class _PurchaseConsultationPageState extends State<PurchaseConsultationPage> {
  final _itemController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedCategory = 'Hiburan';

  static const List<String> _categories = [
    'Hiburan',
    'Gaya Hidup',
    'Belanja Harian',
    'Transportasi',
    'Kesehatan',
    'Lainnya',
  ];

  @override
  void dispose() {
    _itemController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  void _onAnalyze(BuildContext context) {
    final price = CurrencyInputFormatter.parse(_priceController.text);
    if (_itemController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nama barang yang ingin dibeli')),
      );
      return;
    }
    if (price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal harga barang terlebih dahulu')),
      );
      return;
    }
    context.read<ConsultationCubit>().consultPurchase(
      itemName: _itemController.text.trim(),
      estimatedPrice: price,
      categoryName: _selectedCategory,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ConsultationCubit>(
      create: (_) => sl<ConsultationCubit>(),
      child: Builder(
        builder: (context) {
          return Scaffold(
            body: Container(
              decoration: const BoxDecoration(
                gradient: AppColors.screenBackground,
              ),
              child: SafeArea(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header (Stitch Prompt 14)
                      Row(
                        children: [
                          AppIconButton(
                            icon: Icons.arrow_back_rounded,
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 14),
                          Text(
                            'Boleh Beli Gak?',
                            style: AppTypography.pageHeader,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Form input card (Flat Tonal Surface - Zero Shadows)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceCard,
                          borderRadius: BorderRadius.circular(
                            AppSpacing.cardRadius,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Barang yang mau dibeli',
                              style: AppTypography.sectionLabel.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _itemController,
                              style: AppTypography.body,
                              decoration: InputDecoration(
                                hintText: 'Misal: Sepatu baru, PS5, Laptop',
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
                            Text(
                              'Harganya berapa?',
                              style: AppTypography.sectionLabel.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _priceController,
                              keyboardType: TextInputType.number,
                              inputFormatters: [CurrencyInputFormatter()],
                              style: AppTypography.bigNumber.copyWith(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                              decoration: InputDecoration(
                                hintText: '2.500.000',
                                hintStyle: AppTypography.bigNumber.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPlaceholder,
                                ),
                                prefixText: 'Rp ',
                                prefixStyle: AppTypography.bigNumber.copyWith(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
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
                            Text(
                              'Kategori',
                              style: AppTypography.sectionLabel.copyWith(
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _categories.map((cat) {
                                final isSelected = _selectedCategory == cat;
                                return GestureDetector(
                                  onTap: () =>
                                      setState(() => _selectedCategory = cat),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 9,
                                    ),
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
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w600,
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                            BlocBuilder<ConsultationCubit, ConsultationState>(
                              builder: (context, state) {
                                final isLoading = state is ConsultationLoading;
                                return AppButton(
                                  label: 'Cek Kelayakan Beli',
                                  isLoading: isLoading,
                                  onPressed: isLoading
                                      ? null
                                      : () => _onAnalyze(context),
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Result state handling
                      BlocBuilder<ConsultationCubit, ConsultationState>(
                        builder: (context, state) {
                          if (state is ConsultationError) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.errorTint,
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.cardRadius,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    color: AppColors.error,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      state.message,
                                      style: const TextStyle(
                                        color: AppColors.error,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }

                          if (state is ConsultationSuccess) {
                            return _buildResultCard(context, state.result);
                          }

                          return const SizedBox.shrink();
                        },
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultCard(
    BuildContext context,
    ConsultationResultEntity result,
  ) {
    StatusChip verdictChip;

    switch (result.verdict) {
      case ConsultationVerdict.affordable:
        verdictChip = StatusChip.aman('Aman untuk Dibeli');
        break;
      case ConsultationVerdict.caution:
        verdictChip = StatusChip.hampirHabis('Perlu Pertimbangan');
        break;
      case ConsultationVerdict.notRecommended:
        verdictChip = StatusChip.melebihi('Sebaiknya Ditunda');
        break;
      case ConsultationVerdict.insufficientData:
        verdictChip = StatusChip.perhatian('Data Belum Lengkap');
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Verdict Chip
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Saran dari Coach',
                style: AppTypography.sectionLabel.copyWith(fontSize: 15),
              ),
              verdictChip,
            ],
          ),
          const SizedBox(height: 14),

          // "Bahaya Boncos" Illustration when verdict is notRecommended
          if (result.verdict == ConsultationVerdict.notRecommended) ...[
            Center(
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.dangerTint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.25),
                  ),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/danger_boncos.png',
                      width: 135,
                      height: 135,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Waspada! Dompetmu Terancam Boncos',
                      style: AppTypography.itemTitle.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.danger,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // AI Explanation
          Text(
            result.explanation,
            style: AppTypography.body.copyWith(height: 1.5),
          ),

          // Budget Warning Alert (if any)
          if (result.budgetWarning != null &&
              result.budgetWarning!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.dangerTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 16,
                    color: AppColors.danger,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      result.budgetWarning!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Opportunity Cost Banner (if any)
          if (result.opportunityCost != null &&
              result.opportunityCost!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceFieldFill,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.swap_horiz_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Dampak ke Target Tabungan',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          result.opportunityCost!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Deterministic Figures Breakdown
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceFieldFill,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Uang dingin bulan ini', style: AppTypography.caption),
                    Text(
                      CurrencyFormatter.format(result.freeCash),
                      style: AppTypography.sectionLabel.copyWith(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sisa uang setelah pembelian',
                      style: AppTypography.caption,
                    ),
                    Text(
                      CurrencyFormatter.formatSigned(
                        result.remainingCash,
                        isIncome: result.remainingCash >= 0,
                      ),
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: result.remainingCash >= 0
                            ? AppColors.success
                            : AppColors.danger,
                      ),
                    ),
                  ],
                ),
                if (result.priceRatioToFreeCash != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Porsi terhadap uang dingin',
                        style: AppTypography.caption,
                      ),
                      Text(
                        '${result.priceRatioToFreeCash!.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: result.priceRatioToFreeCash! > 50
                              ? AppColors.warning
                              : AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),
          Center(
            child: Text(
              'Tenang, ini cuma simulasi hitung-hitungan, belum dicatat sebagai pengeluaran.',
              style: AppTypography.smallCaption,
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Hitung Barang Lain',
            variant: AppButtonVariant.secondary,
            onPressed: () => context.read<ConsultationCubit>().reset(),
          ),
        ],
      ),
    );
  }
}
