import 'package:equatable/equatable.dart';

enum ConsultationVerdict {
  affordable,
  caution,
  notRecommended,
  insufficientData;

  static ConsultationVerdict fromString(String? val) {
    switch (val?.toLowerCase()) {
      case 'caution':
        return ConsultationVerdict.caution;
      case 'not_recommended':
        return ConsultationVerdict.notRecommended;
      case 'insufficient_data':
        return ConsultationVerdict.insufficientData;
      case 'affordable':
      default:
        return ConsultationVerdict.affordable;
    }
  }

  String get displayName {
    switch (this) {
      case ConsultationVerdict.affordable:
        return 'Dapat Diterima';
      case ConsultationVerdict.caution:
        return 'Perhatian / Risiko Sedang';
      case ConsultationVerdict.notRecommended:
        return 'Tidak Direkomendasikan';
      case ConsultationVerdict.insufficientData:
        return 'Data Belum Lengkap';
    }
  }
}

class ConsultationResultEntity extends Equatable {
  final String itemName;
  final double estimatedPrice;
  final ConsultationVerdict verdict;
  final String explanation;
  final String? opportunityCost;
  final String? budgetWarning;
  final double freeCash;
  final double remainingCash;
  final double? priceRatioToFreeCash;
  final double availableCash;

  const ConsultationResultEntity({
    required this.itemName,
    required this.estimatedPrice,
    required this.verdict,
    required this.explanation,
    this.opportunityCost,
    this.budgetWarning,
    required this.freeCash,
    required this.remainingCash,
    this.priceRatioToFreeCash,
    this.availableCash = 0.0,
  });

  @override
  List<Object?> get props => [
    itemName,
    estimatedPrice,
    verdict,
    explanation,
    opportunityCost,
    budgetWarning,
    freeCash,
    remainingCash,
    priceRatioToFreeCash,
    availableCash,
  ];
}
