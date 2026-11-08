import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../app/di/injection.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/formatters/currency_formatter.dart';
import '../../domain/entities/stock_analysis_result.dart';
import '../cubit/stock_analysis_cubit.dart';
import '../cubit/stock_analysis_state.dart';

class StockAnalysisPage extends StatelessWidget {
  final String? initialTicker;

  const StockAnalysisPage({super.key, this.initialTicker});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StockAnalysisCubit>(
      create: (_) {
        final cubit = sl<StockAnalysisCubit>();
        if (initialTicker != null && initialTicker!.trim().isNotEmpty) {
          cubit.analyze(initialTicker!);
        }
        return cubit;
      },
      child: const _StockAnalysisView(),
    );
  }
}

class _StockAnalysisView extends StatefulWidget {
  const _StockAnalysisView();

  @override
  State<_StockAnalysisView> createState() => _StockAnalysisViewState();
}

class _StockAnalysisViewState extends State<_StockAnalysisView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  static const List<String> _popularTickers = [
    'BBCA',
    'BBRI',
    'BMRI',
    'TLKM',
    'ASII',
    'BBNI',
    'GOTO',
    'BREN',
    'DEWA',
    'ADRO',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearch(String ticker) {
    final clean = ticker.trim().toUpperCase();
    if (clean.isEmpty) return;
    _searchFocusNode.unfocus();
    _searchController.text = clean;
    context.read<StockAnalysisCubit>().analyze(clean);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          color: AppColors.textPrimary,
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Cek & Analisa Saham',
          style: AppTypography.pageHeader.copyWith(fontSize: 20),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar & Ticker Chips Header
            _buildSearchSection(),

            // Dynamic Content
            Expanded(
              child: BlocBuilder<StockAnalysisCubit, StockAnalysisState>(
                builder: (context, state) {
                  if (state is StockAnalysisLoading) {
                    return _buildLoadingState(state);
                  } else if (state is StockAnalysisLoaded) {
                    return _buildLoadedState(state.result);
                  } else if (state is StockAnalysisError) {
                    return _buildErrorState(state);
                  }
                  return _buildInitialState();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchSection() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontalMargin,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.04),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceFieldFill,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.magnifyingGlass(),
                        size: 20,
                        color: AppColors.textPlaceholder,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(6),
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                          ],
                          style: AppTypography.itemTitle.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Ketik kode saham (misal: BBCA, BBRI, DEWA)',
                            hintStyle: AppTypography.captionText.copyWith(
                              color: AppColors.textPlaceholder,
                              fontSize: 13,
                              letterSpacing: 0,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: _onSearch,
                        ),
                      ),
                      if (_searchController.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          child: const Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: AppColors.textPlaceholder,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _onSearch(_searchController.text),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'Analisa',
                    style: AppTypography.button.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Horizontal Popular Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                Text(
                  'Tren:',
                  style: AppTypography.captionText.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: AppColors.textPlaceholder,
                  ),
                ),
                const SizedBox(width: 8),
                ..._popularTickers.map((ticker) {
                  final isSelected =
                      _searchController.text.trim().toUpperCase() == ticker;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _onSearch(ticker),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surfaceFieldFill,
                          borderRadius:
                              BorderRadius.circular(AppSpacing.radiusPill),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          ticker,
                          style: AppTypography.captionText.copyWith(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInitialState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
                boxShadow: AppSpacing.softShadow,
              ),
              child: Center(
                child: Icon(
                  PhosphorIcons.chartLineUp(PhosphorIconsStyle.bold),
                  size: 38,
                  color: AppColors.primary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Deep Stock Analysis & Bandarmologi',
              textAlign: TextAlign.center,
              style: AppTypography.pageHeader.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'FinGuard mengorkestrasi 6 Engine sekaligus: data bursa real-time, indikator teknikal deterministik, antrean order book HAKA/HAKI, profil broker akumulasi/distribusi, prospektus e-IPO, hingga kalkulasi kapasitas uang dingin di akun Anda.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildFeatureTag(PhosphorIcons.cpu(), '6 Engine Terpadu'),
                _buildFeatureTag(PhosphorIcons.bank(), 'Bandarmologi BEI'),
                _buildFeatureTag(PhosphorIcons.wallet(), 'Sinkronisasi Saldo Kas'),
                _buildFeatureTag(PhosphorIcons.newspaper(), 'Berita & e-IPO'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureTag(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.captionText.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(StockAnalysisLoading state) {
    final progress = ((state.stepIndex + 1) / 5).clamp(0.1, 1.0);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 90,
                  height: 90,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 5,
                    backgroundColor: AppColors.primaryLight,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: Center(
                    child: Text(
                      state.ticker,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Menganalisis ${state.ticker}...',
              style: AppTypography.itemTitle.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                state.loadingStepMessage,
                key: ValueKey<String>(state.loadingStepMessage),
                textAlign: TextAlign.center,
                style: AppTypography.captionText.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
              child: SizedBox(
                width: 200,
                height: 6,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: AppColors.surfaceFieldFill,
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Langkah ${state.stepIndex + 1} dari 5 Engine',
              style: AppTypography.captionText.copyWith(
                color: AppColors.textPlaceholder,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(StockAnalysisError state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                color: AppColors.expenseRedBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  PhosphorIcons.warningCircle(PhosphorIconsStyle.fill),
                  size: 32,
                  color: AppColors.expenseRed,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Analisis Saham Gagal',
              style: AppTypography.itemTitle.copyWith(fontSize: 17),
            ),
            const SizedBox(height: 8),
            Text(
              state.message,
              textAlign: TextAlign.center,
              style: AppTypography.captionText.copyWith(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (state.ticker != null && state.ticker!.isNotEmpty) {
                  _onSearch(state.ticker!);
                }
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadedState(StockAnalysisResult res) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontalMargin,
        vertical: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Executive Decision Box (Top Priority Visual Anchor)
          _buildExecutiveDecisionBox(res),
          const SizedBox(height: 16),

          // 2. Financial Context Card (Kapasitas Saldo & Uang Dingin Pengguna)
          _buildFinancialContextCard(res),
          const SizedBox(height: 16),

          // 3. Key Metrics Bento Grid (Teknikal & Bandarmologi)
          _buildKeyMetricsBento(res),
          const SizedBox(height: 16),

          // 4. Order Book & Broker Summary Card
          _buildBandarmologiCard(res),
          const SizedBox(height: 16),

          // 5. Comprehensive AI Institutional Report
          _buildMarkdownReportCard(res),
          const SizedBox(height: 16),

          // 6. Disclaimer Footer
          _buildDisclaimerCard(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildExecutiveDecisionBox(StockAnalysisResult res) {
    final exec = res.executiveSummary;
    final isBuy = exec.verdict.toUpperCase().contains('BUY');
    final isAvoid = exec.verdict.toUpperCase().contains('AVOID') ||
        exec.verdict.toUpperCase().contains('SELL');

    final badgeColor = isBuy
        ? AppColors.incomeGreen
        : isAvoid
            ? AppColors.expenseRed
            : const Color(0xFFF59E0B);
    final badgeBg = isBuy
        ? AppColors.incomeGreenBg
        : isAvoid
            ? AppColors.expenseRedBg
            : const Color(0xFFFEF3C7);

    final changeSign = res.changePercent >= 0 ? '+' : '';
    final isPositive = res.changePercent >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSectionCard),
        boxShadow: AppSpacing.softShadow,
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Ticker, Name & Verdict Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          res.ticker,
                          style: AppTypography.pageHeader.copyWith(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (res.isIpo) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius:
                                  BorderRadius.circular(AppSpacing.radiusPill),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.rocket_launch_rounded,
                                  size: 11,
                                  color: AppColors.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'e-IPO',
                                  style: AppTypography.captionText.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      res.companyName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.captionText.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
                ),
                child: Text(
                  exec.verdict,
                  style: AppTypography.itemTitle.copyWith(
                    color: badgeColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Price & Change Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Rp ${CurrencyFormatter.formatWithoutSymbol(res.price)}',
                style: AppTypography.pageHeader.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$changeSign${res.changePercent}%',
                style: AppTypography.captionText.copyWith(
                  color: isPositive ? AppColors.incomeGreen : AppColors.expenseRed,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '1 Lot = Rp ${CurrencyFormatter.formatWithoutSymbol(res.price * 100)}',
                style: AppTypography.captionText.copyWith(
                  color: AppColors.textPlaceholder,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Recommendation Ratio Bar (BUY % vs HOLD % vs SELL %)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusPill),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (exec.buyPercentage > 0)
                    Expanded(
                      flex: exec.buyPercentage,
                      child: Container(color: AppColors.incomeGreen),
                    ),
                  if (exec.holdPercentage > 0)
                    Expanded(
                      flex: exec.holdPercentage,
                      child: Container(color: const Color(0xFFF59E0B)),
                    ),
                  if (exec.sellPercentage > 0)
                    Expanded(
                      flex: exec.sellPercentage,
                      child: Container(color: AppColors.expenseRed),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRatioLabel(
                'BUY',
                '${exec.buyPercentage}%',
                AppColors.incomeGreen,
              ),
              _buildRatioLabel(
                'HOLD',
                '${exec.holdPercentage}%',
                const Color(0xFFF59E0B),
              ),
              _buildRatioLabel(
                'SELL/AVOID',
                '${exec.sellPercentage}%',
                AppColors.expenseRed,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Target Price & Stop Loss Strip
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceFieldFill,
              borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Target Profit (Resistance):',
                        style: AppTypography.captionText.copyWith(
                          fontSize: 11,
                          color: AppColors.textPlaceholder,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exec.targetPrice,
                        style: AppTypography.itemTitle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.incomeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 28,
                  color: Colors.black.withValues(alpha: 0.08),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Batas Risiko (Cut Loss):',
                        style: AppTypography.captionText.copyWith(
                          fontSize: 11,
                          color: AppColors.textPlaceholder,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        exec.stopLoss,
                        style: AppTypography.itemTitle.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.expenseRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (exec.executiveRationale.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              exec.executiveRationale,
              style: AppTypography.captionText.copyWith(
                fontSize: 12.5,
                color: AppColors.textPrimary,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatioLabel(String label, String pct, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          '$label $pct',
          style: AppTypography.captionText.copyWith(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildFinancialContextCard(StockAnalysisResult res) {
    final fc = res.financialContext;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSectionCard),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Kapasitas Dompet & Uang Dingin',
                  style: AppTypography.itemTitle.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Total Kas Cair',
                  CurrencyFormatter.format(fc.availableCash),
                  subValue: 'Bisa beli ~${fc.affordableLotsLiquid} Lot',
                  subColor: AppColors.incomeGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'Uang Dingin / Bulan',
                  CurrencyFormatter.format(fc.monthlyFreeCash),
                  subValue: 'Bisa cicil ~${fc.affordableLotsFreeCash} Lot/bln',
                  subColor: AppColors.primary,
                ),
              ),
            ],
          ),
          if (fc.walletSyncAdvice.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.tips_and_updates_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      fc.walletSyncAdvice,
                      style: AppTypography.captionText.copyWith(
                        fontSize: 12,
                        color: AppColors.textPrimary,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyMetricsBento(StockAnalysisResult res) {
    final tech = res.technicalData;
    final rsi = tech.rsi != null ? tech.rsi!.toStringAsFixed(1) : 'N/A';
    final rsiStatus = tech.rsiStatus ?? 'Netral';
    final sma50 = tech.sma50 != null ? 'Rp ${CurrencyFormatter.formatWithoutSymbol(tech.sma50!)}' : 'N/A';
    final maStatus = tech.ma50Status ?? 'N/A';
    final vwap = res.vwapPrice > 0 ? 'Rp ${CurrencyFormatter.formatWithoutSymbol(res.vwapPrice)}' : 'N/A';
    final volume = '${res.volumeLots.toLocaleString()} Lot';
    final turnover = 'Rp ${(res.turnoverIdr / 1e9).toStringAsFixed(2)} M';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSectionCard),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Metrik Teknikal & Likuiditas Bursa',
            style: AppTypography.itemTitle.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'RSI (14 Hari)',
                  rsi,
                  subValue: rsiStatus,
                  subColor: rsiStatus == 'Oversold'
                      ? AppColors.incomeGreen
                      : rsiStatus == 'Overbought'
                          ? AppColors.expenseRed
                          : AppColors.textPlaceholder,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'Tren MA50',
                  maStatus,
                  subValue: sma50,
                  subColor: maStatus == 'Uptrend'
                      ? AppColors.incomeGreen
                      : AppColors.expenseRed,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile('Harga VWAP Bandar', vwap),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'Volume & Turnover',
                  volume,
                  subValue: turnover,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'P/E Ratio',
                  tech.peRatio != null ? '${tech.peRatio}x' : 'N/A',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  'PBV',
                  tech.pbv != null ? '${tech.pbv}x' : 'N/A',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBandarmologiCard(StockAnalysisResult res) {
    final b = res.bandarmologyData;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSectionCard),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceFieldFill,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.groups_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bandarmologi & Analisis Order Book',
                  style: AppTypography.itemTitle.copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.incomeGreenBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Antrean BID (HAKA)',
                        style: AppTypography.captionText.copyWith(
                          fontSize: 11,
                          color: AppColors.incomeGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${b.totalBidLots.toLocaleString()} Lot',
                        style: AppTypography.itemTitle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.incomeGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.expenseRedBg,
                    borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Antrean OFFER (HAKI)',
                        style: AppTypography.captionText.copyWith(
                          fontSize: 11,
                          color: AppColors.expenseRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${b.totalOfferLots.toLocaleString()} Lot',
                        style: AppTypography.itemTitle.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.expenseRed,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (b.brokerSummary != null && b.brokerSummary!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildStructuredBrokerSummary(b.brokerSummary!),
          ],
        ],
      ),
    );
  }

  Widget _buildStructuredBrokerSummary(String rawSummary) {
    final lines = rawSummary
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    String? statusBandar;
    String? topBuyers;
    String? topSellers;
    String? brokerChar;
    String? newsRef;

    for (final line in lines) {
      final lower = line.toLowerCase();
      if (lower.contains('status bandarmologi:')) {
        statusBandar = line.replaceFirst(
          RegExp(r'^[-*•·\s]*status bandarmologi:\s*', caseSensitive: false),
          '',
        );
      } else if (lower.contains('top 3 broker net buy')) {
        topBuyers = line.replaceFirst(
          RegExp(r'^[-*•·\s]*top 3 broker net buy.*:\s*', caseSensitive: false),
          '',
        );
      } else if (lower.contains('top 3 broker net sell')) {
        topSellers = line.replaceFirst(
          RegExp(r'^[-*•·\s]*top 3 broker net sell.*:\s*', caseSensitive: false),
          '',
        );
      } else if (lower.contains('karakteristik broker')) {
        brokerChar = line.replaceFirst(
          RegExp(r'^[-*•·\s]*karakteristik broker.*:\s*', caseSensitive: false),
          '',
        );
      } else if (lower.contains('referensi berita')) {
        newsRef = line.replaceFirst(
          RegExp(r'^[-*•·\s]*referensi berita.*:\s*', caseSensitive: false),
          '',
        );
      }
    }

    // Fallback if unstructured
    if (statusBandar == null && topBuyers == null && topSellers == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceFieldFill,
          borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
        ),
        child: _buildSpanText(rawSummary),
      );
    }

    final List<Widget> items = [];

    // 1. Status Bandarmologi Pill
    if (statusBandar != null) {
      final isAcc = statusBandar.toUpperCase().contains('AKUMULASI');
      final badgeColor = isAcc ? AppColors.incomeGreen : AppColors.expenseRed;
      final badgeBg = isAcc ? AppColors.incomeGreenBg : AppColors.expenseRedBg;

      items.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: badgeBg,
            borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
            border: Border.all(
              color: badgeColor.withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isAcc
                        ? PhosphorIcons.trendUp(PhosphorIconsStyle.bold)
                        : PhosphorIcons.trendDown(PhosphorIconsStyle.bold),
                    size: 16,
                    color: badgeColor,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    isAcc
                        ? 'Status: AKUMULASI TERUKUR'
                        : 'Status: TEKANAN DISTRIBUSI',
                    style: GoogleFonts.urbanist(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: badgeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                statusBandar,
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Top 3 Buyers & Sellers
    if (topBuyers != null || topSellers != null) {
      items.add(const SizedBox(height: 10));
      if (topBuyers != null) {
        items.add(
          _buildBrokerRowCard(
            title: 'Top 3 Net Buy (Akumulasi)',
            content: topBuyers,
            icon: PhosphorIcons.arrowCircleUp(PhosphorIconsStyle.fill),
            color: AppColors.incomeGreen,
            bgColor: AppColors.incomeGreenBg.withValues(alpha: 0.6),
          ),
        );
      }
      if (topSellers != null) {
        items.add(const SizedBox(height: 8));
        items.add(
          _buildBrokerRowCard(
            title: 'Top 3 Net Sell (Distribusi)',
            content: topSellers,
            icon: PhosphorIcons.arrowCircleDown(PhosphorIconsStyle.fill),
            color: AppColors.expenseRed,
            bgColor: AppColors.expenseRedBg.withValues(alpha: 0.6),
          ),
        );
      }
    }

    // 3. Karakteristik Broker & Pasar
    if (brokerChar != null && brokerChar.isNotEmpty) {
      items.add(const SizedBox(height: 10));
      items.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surfaceFieldFill,
            borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    PhosphorIcons.usersFour(PhosphorIconsStyle.bold),
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Karakteristik Broker & Pasar',
                    style: GoogleFonts.urbanist(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                brokerChar,
                style: GoogleFonts.urbanist(
                  fontSize: 12,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Referensi Berita Aliran Dana Terkini (Dibersihkan dari teks gantung/terpotong)
    if (newsRef != null && newsRef.isNotEmpty) {
      String cleanedNews = newsRef.replaceAll('"', '').trim();
      cleanedNews = cleanedNews.replaceAll(RegExp(r'\s+[a-zA-Z]\s*\.\.\.$'), '...');
      cleanedNews = cleanedNews.replaceAll(RegExp(r'\.\.\.+$'), '...');
      if (!cleanedNews.endsWith('.')) cleanedNews += '...';

      items.add(const SizedBox(height: 10));
      items.add(
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
            border: Border.all(color: AppColors.neutral200, width: 0.8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  PhosphorIcons.newspaper(PhosphorIconsStyle.fill),
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sentimen Berita Terkait',
                      style: GoogleFonts.urbanist(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      cleanedNews,
                      style: GoogleFonts.urbanist(
                        fontSize: 11.5,
                        fontStyle: FontStyle.italic,
                        color: AppColors.textSecondary,
                        height: 1.38,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items,
    );
  }

  Widget _buildBrokerRowCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.urbanist(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            content,
            style: GoogleFonts.urbanist(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkdownReportCard(StockAnalysisResult res) {
    // Hilangkan redudansi disclaimer jika terdapat di akhir markdown
    String cleanMarkdown = res.markdownAnalysis;
    cleanMarkdown = cleanMarkdown
        .replaceAll(
          RegExp(
            r'((\r?\n)*)#{0,4}\s*(6\.|[0-9]+\.)?\s*⚠️?\s*Disclaimer.*$',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusSectionCard),
        boxShadow: AppSpacing.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Laporan Riset Institusi FinGuard',
                  style: AppTypography.itemTitle.copyWith(fontSize: 15),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy_rounded, size: 18),
                color: AppColors.textPlaceholder,
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: cleanMarkdown));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Analisis disalin ke clipboard!'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
          const Divider(height: 20),
          _buildRichMarkdownText(cleanMarkdown),
        ],
      ),
    );
  }

  Widget _buildRichMarkdownText(String text) {
    final lines = text.split('\n');
    final List<Widget> widgets = [];

    bool inRadarBox = false;
    final List<Widget> radarBoxChildren = [];

    void flushRadarBox() {
      if (radarBoxChildren.isNotEmpty) {
        widgets.add(
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 6, bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.22),
                width: 1.2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.from(radarBoxChildren),
            ),
          ),
        );
        radarBoxChildren.clear();
      }
      inRadarBox = false;
    }

    for (int i = 0; i < lines.length; i++) {
      final trimmed = lines[i].trim();
      if (trimmed.isEmpty) {
        if (!inRadarBox) {
          widgets.add(const SizedBox(height: 6));
        }
        continue;
      }

      // Check dividers
      if (RegExp(r'^[-_—━*]{3,}$').hasMatch(trimmed)) {
        if (inRadarBox) {
          radarBoxChildren.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Divider(
                color: AppColors.neutral200.withValues(alpha: 0.8),
                height: 1,
              ),
            ),
          );
        } else {
          widgets.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Divider(
                color: AppColors.neutral200.withValues(alpha: 0.8),
                height: 1,
              ),
            ),
          );
        }
        continue;
      }

      // Check Radar Box starter
      if (trimmed.contains('🎯') ||
          trimmed.toUpperCase().contains('RANGKUMAN RADAR')) {
        flushRadarBox();
        inRadarBox = true;
        radarBoxChildren.add(
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryLight.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _buildSpanText(
              trimmed,
              baseStyle: GoogleFonts.urbanist(
                color: AppColors.primaryDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        );
        continue;
      }

      // Check numbered section headers: e.g. "1. 📊 Valuasi..." or "2. 📈 Analisis..."
      final numHeaderMatch = RegExp(r'^(\d+\.)\s+(.*)$').firstMatch(trimmed);
      if (numHeaderMatch != null &&
          (trimmed.contains(RegExp(r'[📊📈🏦📰💼⚠️🚀]')) ||
              numHeaderMatch.group(2)!.length > 5)) {
        flushRadarBox();
        final numPrefix = numHeaderMatch.group(1)!;
        final title = numHeaderMatch.group(2)!;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    numPrefix.replaceAll('.', ''),
                    style: GoogleFonts.urbanist(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSpanText(
                    title,
                    baseStyle: GoogleFonts.urbanist(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Check standard markdown headers: "# ", "## ", "### "
      if (trimmed.startsWith('# ') ||
          trimmed.startsWith('## ') ||
          trimmed.startsWith('### ')) {
        flushRadarBox();
        final cleanHeader = trimmed.replaceAll(RegExp(r'^#+\s*'), '');
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 14, bottom: 6),
            child: Text(
              cleanHeader,
              style: GoogleFonts.urbanist(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        );
        continue;
      }

      // Check bullet items (matches "• ", "- ", "* ", "· ", "– ")
      final bulletMatch =
          RegExp(r'^[-*•·–\u00B7]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)!;
        final targetList = inRadarBox ? radarBoxChildren : widgets;
        targetList.add(
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '•',
                    style: GoogleFonts.urbanist(
                      color: inRadarBox
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildSpanText(
                    content,
                    baseStyle: GoogleFonts.urbanist(
                      color: AppColors.textPrimary,
                      fontSize: 13,
                      height: 1.48,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
        continue;
      }

      // Normal paragraph
      final targetList = inRadarBox ? radarBoxChildren : widgets;
      targetList.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: _buildSpanText(
            trimmed,
            baseStyle: GoogleFonts.urbanist(
              color: AppColors.textPrimary,
              fontSize: 13,
              height: 1.48,
              letterSpacing: 0.1,
            ),
          ),
        ),
      );
    }

    flushRadarBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  Widget _buildSpanText(String raw, {TextStyle? baseStyle}) {
    final style = baseStyle ??
        GoogleFonts.urbanist(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.48,
        );

    if (!raw.contains('**')) {
      return Text(raw, style: style);
    }

    final List<TextSpan> spans = [];
    final parts = raw.split('**');
    for (int i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      final isBold = i % 2 == 1;

      Color? tagColor;
      if (isBold) {
        final upper = parts[i].toUpperCase();
        if (upper.contains('BUY') ||
            upper.contains('ARA') ||
            upper.contains('AKUMULASI') ||
            upper.contains('UNTUNG')) {
          tagColor = const Color(0xFF16A34A);
        } else if (upper.contains('HIGH RISK') ||
            upper.contains('SELL') ||
            upper.contains('ARB') ||
            upper.contains('AVOID') ||
            upper.contains('CUT LOSS')) {
          tagColor = const Color(0xFFDC2626);
        } else if (upper.contains('WAIT') ||
            upper.contains('HOLD') ||
            upper.contains('MEDIUM RISK') ||
            upper.contains('KONSOLIDASI')) {
          tagColor = const Color(0xFFD97706);
        }
      }

      spans.add(
        TextSpan(
          text: parts[i],
          style: isBold
              ? style.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tagColor ?? AppColors.textPrimary,
                )
              : style.copyWith(
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }

  Widget _buildMetricTile(String label, String value, {String? subValue, Color? subColor}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceFieldFill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.captionText.copyWith(
              fontSize: 11,
              color: AppColors.textPlaceholder,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: AppTypography.itemTitle.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (subValue != null && subValue.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              subValue,
              style: AppTypography.captionText.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: subColor ?? AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDisclaimerCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceFieldFill,
        borderRadius: BorderRadius.circular(AppSpacing.radiusInnerElement),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: AppColors.textPlaceholder,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Disclaimer FinGuard: Analisis di atas merupakan sintesis data bursa publik, indikator teknikal deterministik, dan estimasi bandarmologi. Bukan jaminan keuntungan pasti. Seluruh keputusan investasi adalah tanggung jawab pribadi Anda.',
              style: AppTypography.captionText.copyWith(
                fontSize: 11,
                color: AppColors.textPlaceholder,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _NumberFormatExtension on int {
  String toLocaleString() {
    return CurrencyFormatter.formatWithoutSymbol(toDouble());
  }
}
