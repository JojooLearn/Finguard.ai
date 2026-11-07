import 'package:equatable/equatable.dart';

abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

class OnboardingSubmitting extends OnboardingState {
  const OnboardingSubmitting();
}

class OnboardingSuccess extends OnboardingState {
  const OnboardingSuccess();
}

class OnboardingError extends OnboardingState {
  final String message;

  const OnboardingError(this.message);

  @override
  List<Object?> get props => [message];
}

