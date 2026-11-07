import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../../../core/formatters/date_formatter.dart';
import '../../domain/entities/stock_signal.dart';
import '../cubit/stock_signal_list_cubit.dart';
import '../cubit/stock_signal_list_state.dart';

class StockSignalDashboardCard extends StatelessWidget {
  const StockSignalDashboardCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header (Flush with screen side margins)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Radar Sinyal Saham',
                  style: AppTypography.sectionLabel.copyWith(fontSize: 16),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold),
                        size: 11,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Trade',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    context.read<StockSignalListCubit>().refresh();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Menyinkronkan radar tren pasar terkini...',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        backgroundColor: AppColors.primary,
                        duration: const Duration(seconds: 1),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIcons.arrowsClockwise(PhosphorIconsStyle.bold),
                          size: 11,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Update Pasar',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _showInfoDisclaimerSheet(context),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 18,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Horizontal Card Carousel / States
        BlocBuilder<StockSignalListCubit, StockSignalListState>(
          builder: (context, state) {
            if (state is StockSignalLoading) {
              return _buildLoadingSkeleton(context);
            }

            if (state is StockSignalError) {
              return _buildErrorState(context, state.message);
            }

            if (state is StockSignalLoaded) {
              final signals = state.signals;
              if (signals.isEmpty) {
                return _buildEmptyState();
              }

              // Smooth full-bleed horizontal carousel aligned flush with side margins
              // Uses OverflowBox instead of negative Container margin to prevent Flutter assertion errors
              final screenWidth = MediaQuery.of(context).size.width;
              return SizedBox(
                height: 118,
                child: OverflowBox(
                  minWidth: 0.0,
                  maxWidth: screenWidth,
                  child: SizedBox(
                    width: screenWidth,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sideMargin,
                      ),
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: signals.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final item = signals[index];
                        return _buildSignalItemCard(context, item);
                      },
                    ),
                  ),
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    return SizedBox(
      height: 118,
      child: OverflowBox(
        minWidth: 0.0,
        maxWidth: screenWidth,
        child: SizedBox(
          width: screenWidth,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sideMargin),
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 2,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, _) => Container(
              width: 172,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.surfaceFieldFill, width: 1.2),
                boxShadow: AppSpacing.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 55,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFieldFill,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Container(
                        width: 38,
                        height: 16,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFieldFill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 85,
                    height: 14,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceFieldFill,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    height: 26,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceFieldFill,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  Container(
                    width: 120,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceFieldFill,
                      borderRadius: BorderRadius.circular(4),
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceFieldFill, width: 1.2),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.surfaceFieldFill,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.radar_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Belum Ada Sinyal Aktif',
                  style: AppTypography.sectionLabel.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  'Sistem terus memantau 5 saham unggulan.',
                  style: AppTypography.caption.copyWith(fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.surfaceFieldFill, width: 1.2),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(fontSize: 11),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => context.read<StockSignalListCubit>().refresh(),
            child: const Text(
              'Coba lagi',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignalItemCard(BuildContext context, StockSignal item) {
    final (badgeBg, badgeTextColor) = _getSignalColors(item.signalType);

    return GestureDetector(
      onTap: () => _showSignalDetailSheet(context, item),
      child: Container(
        width: 172,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.surfaceFieldFill, width: 1.2),
          boxShadow: AppSpacing.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 1. Top Row: IDX Tag + Ticker & Signal Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1.5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'IDX',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      item.ticker,
                      style: const TextStyle(
                        fontFamily: 'Urbanist',
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: badgeBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.signalType.displayName,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: badgeTextColor,
                    ),
                  ),
                ),
              ],
            ),

            // 2. Price, Timeframe & Live TV Dot
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          CurrencyFormatter.format(item.priceAtSignal),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Urbanist',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFieldFill,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.timeframe,
                          style: AppTypography.caption.copyWith(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: badgeTextColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 3),
                    Text(
                      'Live TV',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        color: badgeTextColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 3. Native 60FPS Sparkline Chart
            SizedBox(
              width: double.infinity,
              height: 26,
              child: StockSparklineChart(
                ticker: item.ticker,
                signalType: item.signalType,
                lineColor: badgeTextColor,
              ),
            ),

            // 4. Notes / Indicator Summary
            Text(
              item.analysisNotes?.isNotEmpty == true
                  ? item.analysisNotes!
                  : 'Sinyal teknikal TradingView',
              style: AppTypography.caption.copyWith(
                fontSize: 9.5,
                color: AppColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  (Color bg, Color text) _getSignalColors(StockSignalType type) {
    switch (type) {
      case StockSignalType.buy:
      case StockSignalType.strongBuy:
        return (AppColors.successTint, AppColors.success);
      case StockSignalType.sell:
      case StockSignalType.strongSell:
        return (AppColors.dangerTint, AppColors.danger);
      case StockSignalType.hold:
        return (AppColors.warningOrangeBg, const Color(0xFFD97706));
    }
  }

  Future<void> _openTradingViewChart(String ticker) async {
    final cleanTicker = ticker.trim().toUpperCase();
    final uri = Uri.parse('https://id.tradingview.com/chart/?symbol=IDX:$cleanTicker');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  void _showSignalDetailSheet(BuildContext context, StockSignal item) {
    final (badgeBg, badgeTextColor) = _getSignalColors(item.signalType);
    final pivotPrice = item.priceAtSignal;
    final supportPrice = (pivotPrice * 0.96).roundToDouble();
    final resistancePrice = (pivotPrice * 1.05).roundToDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 28,
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
              const SizedBox(height: 16),

              // Ticker & Sinyal Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'IDX',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item.ticker,
                        style: AppTypography.screenTitle.copyWith(fontSize: 22),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceFieldFill,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Timeframe ${item.timeframe}',
                          style: AppTypography.caption.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.signalType.displayName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Price Big Display + 1 Lot Info
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    CurrencyFormatter.format(item.priceAtSignal),
                    style: AppTypography.bigNumber.copyWith(fontSize: 26),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '/lembar (1 Lot = ${CurrencyFormatter.format(item.priceAtSignal * 100)})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // High-Resolution Technical Sparkline Card with Support / Pivot / Resistance (Clean Light Palette)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.primaryLight.withValues(alpha: 0.45),
                      const Color(0xFFF8FAFC),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: badgeTextColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  'Trajektori Momentum IDX:${item.ticker} (${item.timeframe})',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.itemTitle.copyWith(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _openTradingViewChart(item.ticker),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3.5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'TradingView',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  PhosphorIcons.arrowsOutSimple(
                                    PhosphorIconsStyle.bold,
                                  ),
                                  size: 13,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 92,
                      child: StockSparklineChart(
                        ticker: item.ticker,
                        signalType: item.signalType,
                        lineColor: badgeTextColor,
                        showGrid: true,
                        gridColor: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildPriceLevelBadge(
                          label: 'Support',
                          price: CurrencyFormatter.format(supportPrice),
                          color: const Color(0xFF059669),
                        ),
                        _buildPriceLevelBadge(
                          label: 'Pivot Sinyal',
                          price: CurrencyFormatter.format(pivotPrice),
                          color: AppColors.primary,
                        ),
                        _buildPriceLevelBadge(
                          label: 'Resistance',
                          price: CurrencyFormatter.format(resistancePrice),
                          color: const Color(0xFFD97706),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Technical details card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceFieldFill,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  children: [
                    _buildDetailRow(
                      'Waktu Sinyal Masuk',
                      DateFormatter.formatRelativeDateTime(item.createdAt),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      'Berlaku Sampai',
                      DateFormatter.formatRelativeDateTime(item.validUntil),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow('Sumber Sinyal', 'TradingView Strategy'),
                    if (item.analysisNotes?.isNotEmpty == true) ...[
                      const SizedBox(height: 8),
                      _buildDetailRow('Analisis Teknikal', item.analysisNotes!),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Mandatory Risk Disclaimer
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: AppColors.warningTint,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: AppColors.warning,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Disclaimer: Sinyal teknikal ini murni indikator dari TradingView & bukan jaminan pasti cuan.',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textPrimary.withValues(alpha: 0.8),
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Action: Tanya Coach Finansial
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/coach');
                },
                child: Container(
                  width: double.infinity,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        PhosphorIcons.sparkle(PhosphorIconsStyle.fill),
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Tanya Analisa ke AI Coach',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceLevelBadge({
    required String label,
    required String price,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          price,
          style: TextStyle(
            fontFamily: 'Urbanist',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.caption),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: AppTypography.sectionLabel.copyWith(fontSize: 12.5),
          ),
        ),
      ],
    );
  }

  void _showInfoDisclaimerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 32,
        ),
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
            const SizedBox(height: 18),
            Text(
              'Tentang Radar Sinyal Saham',
              style: AppTypography.screenTitle.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 10),
            Text(
              'Fitur ini menyajikan sinyal teknikal (BUY, HOLD, SELL) yang dikirimkan secara otomatis dari webhook TradingView Strategy. Data ini berfungsi sebagai referensi pembantu untuk memantau momentum saham.',
              style: AppTypography.body.copyWith(
                fontSize: 13,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                width: double.infinity,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.surfaceFieldFill,
                  borderRadius: BorderRadius.circular(100),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'Mengerti',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Native 60/120 FPS CustomPainter Sparkline Chart for Stock Momentum Trajectory.
class StockSparklineChart extends StatelessWidget {
  final String ticker;
  final StockSignalType signalType;
  final Color lineColor;
  final bool showGrid;
  final Color? gridColor;

  const StockSparklineChart({
    super.key,
    required this.ticker,
    required this.signalType,
    required this.lineColor,
    this.showGrid = false,
    this.gridColor,
  });

  List<double> _generateTrajectoryPoints() {
    final seed = ticker.codeUnits.fold<int>(0, (acc, c) => acc + c);
    final List<double> base;
    switch (signalType) {
      case StockSignalType.buy:
      case StockSignalType.strongBuy:
        base = [0.22, 0.28, 0.25, 0.38, 0.34, 0.52, 0.48, 0.68, 0.64, 0.86, 0.92];
        break;
      case StockSignalType.sell:
      case StockSignalType.strongSell:
        base = [0.88, 0.82, 0.85, 0.68, 0.72, 0.54, 0.58, 0.36, 0.40, 0.22, 0.14];
        break;
      case StockSignalType.hold:
        base = [0.46, 0.54, 0.42, 0.58, 0.48, 0.55, 0.45, 0.53, 0.49, 0.52, 0.50];
        break;
    }

    return List<double>.generate(base.length, (i) {
      final wave = math.sin((seed + i * 3) * 0.7) * 0.04;
      return (base[i] + wave).clamp(0.08, 0.94);
    });
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _StockSparklinePainter(
        points: _generateTrajectoryPoints(),
        lineColor: lineColor,
        showGrid: showGrid,
        gridColor: gridColor,
      ),
    );
  }
}

class _StockSparklinePainter extends CustomPainter {
  final List<double> points;
  final Color lineColor;
  final bool showGrid;
  final Color? gridColor;

  _StockSparklinePainter({
    required this.points,
    required this.lineColor,
    required this.showGrid,
    this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2 || size.width <= 0 || size.height <= 0) return;

    if (showGrid) {
      final gridPaint = Paint()
        ..color = gridColor ?? Colors.white.withValues(alpha: 0.10)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke;

      for (final r in [0.2, 0.5, 0.8]) {
        final y = size.height * r;
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }

    final stepX = (size.width - 6) / (points.length - 1);
    final offsets = <Offset>[];
    for (int i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = size.height - (points[i] * (size.height - 6)) - 3;
      offsets.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 0; i < offsets.length - 1; i++) {
      final p0 = offsets[i];
      final p1 = offsets[i + 1];
      final controlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(controlX, p0.dy, controlX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(offsets.last.dx, size.height)
      ..lineTo(offsets.first.dx, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: showGrid ? 0.35 : 0.24),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = lineColor
      ..strokeWidth = showGrid ? 2.4 : 1.9
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawPath(linePath, strokePaint);

    // Live pulsing dot at the latest point
    final lastPt = offsets.last;
    final haloPaint = Paint()
      ..color = lineColor.withValues(alpha: 0.28)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPt, showGrid ? 6.0 : 4.5, haloPaint);

    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lastPt, showGrid ? 3.2 : 2.4, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _StockSparklinePainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
        oldDelegate.showGrid != showGrid ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.points != points;
  }
}
