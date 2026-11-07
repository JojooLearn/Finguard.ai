import '../../../../core/result/result.dart';
import '../entities/account_entity.dart';
import '../entities/category_entity.dart';

abstract class CategoryRepository {
  Future<Result<List<CategoryEntity>>> getCategories({TransactionType? type});
  Future<Result<CategoryEntity>> createCategory({
    required String name,
    required TransactionType type,
    AllocationType? allocationType,
    String? iconKey,
    String? colorHex,
  });
}

abstract class AccountRepository {
  Future<Result<List<AccountEntity>>> getAccounts();
  Future<Result<AccountEntity>> createAccount({
    required String name,
    required AccountType type,
    double openingBalance = 0.0,
    bool isDefault = false,
  });
}
