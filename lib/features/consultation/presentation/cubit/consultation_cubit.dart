import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/consultation_repository.dart';
import 'consultation_state.dart';

class ConsultationCubit extends Cubit<ConsultationState> {
  final ConsultationRepository consultationRepository;

  ConsultationCubit({required this.consultationRepository})
      : super(const ConsultationInitial());

  Future<void> consultPurchase({
    required String itemName,
    required double estimatedPrice,
    String? categoryName,
  }) async {
    if (itemName.trim().isEmpty) {
      emit(const ConsultationError('Nama barang wajib diisi'));
      return;
    }
    if (estimatedPrice <= 0) {
      emit(const ConsultationError('Harga barang harus lebih dari 0'));
      return;
    }

    emit(const ConsultationLoading());

    final result = await consultationRepository.consultPurchase(
      itemName: itemName,
      estimatedPrice: estimatedPrice,
      categoryName: categoryName,
    );

    result.fold(
      (consultationEntity) => emit(ConsultationSuccess(consultationEntity)),
      (failure) => emit(ConsultationError(failure.message)),
    );
  }

  void reset() {
    emit(const ConsultationInitial());
  }
}
