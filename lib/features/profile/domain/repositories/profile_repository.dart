import '../../../../core/result/result.dart';
import '../entities/profile_entity.dart';

abstract class ProfileRepository {
  Future<Result<ProfileEntity>> getProfile();

  Future<Result<ProfileEntity>> updateProfile({
    String? displayName,
    double? monthlyIncome,
    double? essentialExpenses,
    double? monthlyDebt,
    int? strictnessLevel,
  });

  Future<Result<void>> recalculateBlueprintFromIncome({
    required double monthlyIncome,
    int? strictnessLevel,
  });

  void clearCache();
}

