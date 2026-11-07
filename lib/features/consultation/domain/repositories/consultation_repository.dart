import '../../../../core/result/result.dart';
import '../entities/consultation_result_entity.dart';

abstract class ConsultationRepository {
  Future<Result<ConsultationResultEntity>> consultPurchase({
    required String itemName,
    required double estimatedPrice,
    String? categoryName,
  });
}
