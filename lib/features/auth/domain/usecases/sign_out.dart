import 'package:rentdone/features/auth/domain/repositories/auth_repository.dart';

class SignOut {
  final AuthRepository _repository;

  const SignOut(this._repository);

  Future<void> call() {
    return _repository.signOut();
  }
}
