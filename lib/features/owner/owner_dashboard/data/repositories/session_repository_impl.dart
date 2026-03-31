import 'package:rentdone/features/owner/owner_dashboard/data/services/session_auth_service.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/repositories/session_repository.dart';

class SessionRepositoryImpl implements SessionRepository {
  final SessionAuthService _service;

  SessionRepositoryImpl(this._service);

  @override
  Future<void> signOut() {
    return _service.signOut();
  }
}
