import 'package:equatable/equatable.dart';
import '../../domain/entities/consultation_result_entity.dart';

abstract class ConsultationState extends Equatable {
  const ConsultationState();

  @override
  List<Object?> get props => [];
}

class ConsultationInitial extends ConsultationState {
  const ConsultationInitial();
}

class ConsultationLoading extends ConsultationState {
  const ConsultationLoading();
}

class ConsultationSuccess extends ConsultationState {
  final ConsultationResultEntity result;

  const ConsultationSuccess(this.result);

  @override
  List<Object?> get props => [result];
}

class ConsultationError extends ConsultationState {
  final String message;

  const ConsultationError(this.message);

  @override
  List<Object?> get props => [message];
}
