import 'package:equatable/equatable.dart';

class ProfileEntity extends Equatable {
  final String id;
  final String displayName;
  final String email;
  final String currencyCode;
  final String timezone;
  final double monthlyIncome;
  final double essentialExpenses;
  final double monthlyDebt;
  final int strictnessLevel;
  final DateTime? onboardingCompletedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const ProfileEntity({
    required this.id,
    required this.displayName,
    required this.email,
    this.currencyCode = 'IDR',
    this.timezone = 'Asia/Jakarta',
    this.monthlyIncome = 0.0,
    this.essentialExpenses = 0.0,
    this.monthlyDebt = 0.0,
    this.strictnessLevel = 3,
    this.onboardingCompletedAt,
    this.createdAt,
    this.updatedAt,
  });

  ProfileEntity copyWith({
    String? id,
    String? displayName,
    String? email,
    String? currencyCode,
    String? timezone,
    double? monthlyIncome,
    double? essentialExpenses,
    double? monthlyDebt,
    int? strictnessLevel,
    DateTime? onboardingCompletedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProfileEntity(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      currencyCode: currencyCode ?? this.currencyCode,
      timezone: timezone ?? this.timezone,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      essentialExpenses: essentialExpenses ?? this.essentialExpenses,
      monthlyDebt: monthlyDebt ?? this.monthlyDebt,
      strictnessLevel: strictnessLevel ?? this.strictnessLevel,
      onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        displayName,
        email,
        currencyCode,
        timezone,
        monthlyIncome,
        essentialExpenses,
        monthlyDebt,
        strictnessLevel,
        onboardingCompletedAt,
        createdAt,
        updatedAt,
      ];
}

