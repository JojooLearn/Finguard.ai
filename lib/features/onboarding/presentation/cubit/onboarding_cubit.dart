import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/initial_setup_entity.dart';
import '../../domain/repositories/onboarding_repository.dart';
import 'onboarding_state.dart';

class OnboardingCubit extends Cubit<OnboardingState> {
  final OnboardingRepository onboardingRepository;

  OnboardingCubit({required this.onboardingRepository})
      : super(const OnboardingInitial());

  Future<void> submitInitialSetup(InitialSetupEntity data) async {
    emit(const OnboardingSubmitting());
    final result = await onboardingRepository.completeOnboarding(data);
    result.fold(
      (_) => emit(const OnboardingSuccess()),
      (failure) => emit(OnboardingError(failure.message)),
    );
  }

  void reset() {
    emit(const OnboardingInitial());
  }
}

