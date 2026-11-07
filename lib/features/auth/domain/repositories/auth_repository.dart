import '../../../../core/result/result.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Result<UserEntity>> signUp({
    required String email,
    required String password,
    required String fullName,
  });

  Future<Result<UserEntity>> signIn({
    required String email,
    required String password,
  });

  Future<Result<void>> signOut();

  UserEntity? getCurrentUser();

  Stream<UserEntity?> get authStateChanges;

  /// Cached answer, valid after [loadOnboardingStatus] has run for this user.
  bool hasCompletedOnboarding();

  /// Reads profiles.onboarding_completed_at from the database (source of truth).
  Future<bool> loadOnboardingStatus();

  void setOnboardingCompleted(bool completed);

  void updateCurrentUserDisplayName(String name);
}

