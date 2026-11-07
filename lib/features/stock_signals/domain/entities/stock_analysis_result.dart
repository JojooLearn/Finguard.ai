import 'package:equatable/equatable.dart';

class ExecutiveSummary extends Equatable {
  final String verdict;
  final int buyPercentage;
  final int holdPercentage;
  final int sellPercentage;
  final String targetPrice;
  final String stopLoss;
  final String executiveRationale;

  const ExecutiveSummary({
    required this.verdict,
    required this.buyPercentage,
    required this.holdPercentage,
    required this.sellPercentage,
    required this.targetPrice,
    required this.stopLoss,
    required this.executiveRationale,
  });

  factory ExecutiveSummary.fromJson(Map<String, dynamic> json) {
    return ExecutiveSummary(
      verdict: json['verdict']?.toString() ?? 'WAIT & SEE',
      buyPercentage: (json['buy_percentage'] as num?)?.toInt() ?? 50,
      holdPercentage: (json['hold_percentage'] as num?)?.toInt() ?? 25,
      sellPercentage: (json['sell_percentage'] as num?)?.toInt() ?? 25,
      targetPrice: json['target_price']?.toString() ?? '-',
      stopLoss: json['stop_loss']?.toString() ?? '-',
      executiveRationale: json['executive_rationale']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [
        verdict,
        buyPercentage,
        holdPercentage,
        sellPercentage,
        targetPrice,
        stopLoss,
        executiveRationale,
      ];
}

class FinancialContextSummary extends Equatable {
  final double availableCash;
  final double monthlyFreeCash;
  final double emergencyFund;
  final double lotPrice;
  final int affordableLotsFreeCash;
  final int affordableLotsLiquid;
  final String walletSyncAdvice;

  const FinancialContextSummary({
    required this.availableCash,
    required this.monthlyFreeCash,
    required this.emergencyFund,
    required this.lotPrice,
    required this.affordableLotsFreeCash,
    required this.affordableLotsLiquid,
    required this.walletSyncAdvice,
  });

  factory FinancialContextSummary.fromJson(Map<String, dynamic> json) {
    return FinancialContextSummary(
      availableCash: (json['available_cash'] as num?)?.toDouble() ?? 0.0,
      monthlyFreeCash: (json['monthly_free_cash'] as num?)?.toDouble() ?? 0.0,
      emergencyFund: (json['emergency_fund'] as num?)?.toDouble() ?? 0.0,
      lotPrice: (json['lot_price'] as num?)?.toDouble() ?? 0.0,
      affordableLotsFreeCash:
          (json['affordable_lots_free_cash'] as num?)?.toInt() ?? 0,
      affordableLotsLiquid:
          (json['affordable_lots_liquid'] as num?)?.toInt() ?? 0,
      walletSyncAdvice: json['wallet_sync_advice']?.toString() ?? '',
    );
  }

  @override
  List<Object?> get props => [
        availableCash,
        monthlyFreeCash,
        emergencyFund,
        lotPrice,
        affordableLotsFreeCash,
        affordableLotsLiquid,
        walletSyncAdvice,
      ];
}

class TechnicalDataSummary extends Equatable {
  final double? rsi;
  final String? rsiStatus;
  final double? sma50;
  final String? ma50Status;
  final dynamic peRatio;
  final dynamic pbv;

  const TechnicalDataSummary({
    this.rsi,
    this.rsiStatus,
    this.sma50,
    this.ma50Status,
    this.peRatio,
    this.pbv,
  });

  factory TechnicalDataSummary.fromJson(Map<String, dynamic> json) {
    return TechnicalDataSummary(
      rsi: (json['rsi'] as num?)?.toDouble(),
      rsiStatus: json['rsi_status']?.toString(),
      sma50: (json['sma50'] as num?)?.toDouble(),
      ma50Status: json['ma50_status']?.toString(),
      peRatio: json['pe_ratio'],
      pbv: json['pbv'],
    );
  }

  @override
  List<Object?> get props => [
        rsi,
        rsiStatus,
        sma50,
        ma50Status,
        peRatio,
        pbv,
      ];
}

class BandarmologyDataSummary extends Equatable {
  final int totalBidLots;
  final int totalOfferLots;
  final String? orderBookSummary;
  final String? brokerSummary;

  const BandarmologyDataSummary({
    required this.totalBidLots,
    required this.totalOfferLots,
    this.orderBookSummary,
    this.brokerSummary,
  });

  factory BandarmologyDataSummary.fromJson(Map<String, dynamic> json) {
    return BandarmologyDataSummary(
      totalBidLots: (json['total_bid_lots'] as num?)?.toInt() ?? 0,
      totalOfferLots: (json['total_offer_lots'] as num?)?.toInt() ?? 0,
      orderBookSummary: json['order_book_summary']?.toString(),
      brokerSummary: json['broker_summary']?.toString(),
    );
  }

  @override
  List<Object?> get props => [
        totalBidLots,
        totalOfferLots,
        orderBookSummary,
        brokerSummary,
      ];
}

class StockAnalysisResult extends Equatable {
  final String ticker;
  final String companyName;
  final double price;
  final String currency;
  final String lastTradeDate;
  final double changePercent;
  final double previousClose;
  final int volumeLots;
  final double turnoverIdr;
  final double vwapPrice;
  final bool isIpo;
  final ExecutiveSummary executiveSummary;
  final FinancialContextSummary financialContext;
  final TechnicalDataSummary technicalData;
  final BandarmologyDataSummary bandarmologyData;
  final List<String> newsHeadlines;
  final String markdownAnalysis;
  final DateTime timestamp;

  const StockAnalysisResult({
    required this.ticker,
    required this.companyName,
    required this.price,
    required this.currency,
    required this.lastTradeDate,
    required this.changePercent,
    required this.previousClose,
    required this.volumeLots,
    required this.turnoverIdr,
    required this.vwapPrice,
    required this.isIpo,
    required this.executiveSummary,
    required this.financialContext,
    required this.technicalData,
    required this.bandarmologyData,
    required this.newsHeadlines,
    required this.markdownAnalysis,
    required this.timestamp,
  });

  factory StockAnalysisResult.fromJson(Map<String, dynamic> json) {
    return StockAnalysisResult(
      ticker: json['ticker']?.toString() ?? '',
      companyName: json['company_name']?.toString() ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency']?.toString() ?? 'IDR',
      lastTradeDate: json['last_trade_date']?.toString() ?? '',
      changePercent: (json['change_percent'] as num?)?.toDouble() ?? 0.0,
      previousClose: (json['previous_close'] as num?)?.toDouble() ?? 0.0,
      volumeLots: (json['volume_lots'] as num?)?.toInt() ?? 0,
      turnoverIdr: (json['turnover_idr'] as num?)?.toDouble() ?? 0.0,
      vwapPrice: (json['vwap_price'] as num?)?.toDouble() ?? 0.0,
      isIpo: json['is_ipo'] == true,
      executiveSummary: ExecutiveSummary.fromJson(
        json['executive_summary'] is Map
            ? Map<String, dynamic>.from(json['executive_summary'] as Map)
            : {},
      ),
      financialContext: FinancialContextSummary.fromJson(
        json['financial_context'] is Map
            ? Map<String, dynamic>.from(json['financial_context'] as Map)
            : {},
      ),
      technicalData: TechnicalDataSummary.fromJson(
        json['technical_data'] is Map
            ? Map<String, dynamic>.from(json['technical_data'] as Map)
            : {},
      ),
      bandarmologyData: BandarmologyDataSummary.fromJson(
        (json['bandarmology_data'] ?? json['bandarmologi_data']) is Map
            ? Map<String, dynamic>.from(
                (json['bandarmology_data'] ?? json['bandarmologi_data']) as Map,
              )
            : {},
      ),
      newsHeadlines: (json['news_headlines'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      markdownAnalysis: json['markdown_analysis']?.toString() ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        ticker,
        companyName,
        price,
        currency,
        lastTradeDate,
        changePercent,
        previousClose,
        volumeLots,
        turnoverIdr,
        vwapPrice,
        isIpo,
        executiveSummary,
        financialContext,
        technicalData,
        bandarmologyData,
        newsHeadlines,
        markdownAnalysis,
        timestamp,
      ];
}
