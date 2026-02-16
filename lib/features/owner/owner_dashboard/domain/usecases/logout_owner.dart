import 'package:rentdone/features/owner/owner_dashboard/domain/repositories/session_repository.dart';

class LogoutOwner {
  final SessionRepository _repository;

  const LogoutOwner(this._repository);

  Future<void> call() {
    return _repository.signOut();
  }
}
