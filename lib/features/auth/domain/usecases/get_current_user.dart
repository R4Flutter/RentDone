import 'package:rentdone/features/auth/domain/entities/auth_user.dart';
import 'package:rentdone/features/auth/domain/repositories/auth_repository.dart';

class GetCurrentUser {
  final AuthRepository _repository;

  const GetCurrentUser(this._repository);

  Future<AuthUser?> call() {
    return _repository.getCurrentUser();
  }
}
