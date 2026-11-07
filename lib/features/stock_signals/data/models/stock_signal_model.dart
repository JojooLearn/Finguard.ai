import '../../domain/entities/stock_signal.dart';

class StockSignalModel extends StockSignal {
  const StockSignalModel({
    required super.id,
    required super.ticker,
    required super.signalType,
    required super.priceAtSignal,
    super.timeframe = '1D',
    super.analysisNotes,
    required super.validUntil,
    required super.createdAt,
  });

  factory StockSignalModel.fromJson(Map<String, dynamic> json) {
    return StockSignalModel(
      id: json['id'] as String,
      ticker: (json['ticker'] as String? ?? '').toUpperCase(),
      signalType: StockSignalType.fromString(json['signal_type'] as String? ?? 'BUY'),
      priceAtSignal: (json['price_at_signal'] as num?)?.toDouble() ?? 0.0,
      timeframe: json['timeframe'] as String? ?? '1D',
      analysisNotes: json['analysis_notes'] as String?,
      validUntil: json['valid_until'] != null
          ? DateTime.parse(json['valid_until'] as String).toLocal()
          : DateTime.now().add(const Duration(days: 1)),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String).toLocal()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'ticker': ticker,
      'signal_type': signalType.toDbString(),
      'price_at_signal': priceAtSignal,
      'timeframe': timeframe,
      'analysis_notes': analysisNotes,
      'valid_until': validUntil.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

