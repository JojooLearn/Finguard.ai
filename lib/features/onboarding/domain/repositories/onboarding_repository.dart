import '../../../../core/result/result.dart';
import '../entities/initial_setup_entity.dart';

abstract class OnboardingRepository {
  Future<bool> hasCompletedOnboarding(String userId);
  Future<Result<void>> completeOnboarding(InitialSetupEntity setupData);
}

