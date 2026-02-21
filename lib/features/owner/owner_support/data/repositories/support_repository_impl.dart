import 'package:rentdone/features/owner/owner_support/data/services/support_local_service.dart';
import 'package:rentdone/features/owner/owner_support/domain/entities/support_content.dart';
import 'package:rentdone/features/owner/owner_support/domain/repositories/support_repository.dart';

class SupportRepositoryImpl implements SupportRepository {
  final SupportLocalService _service;

  SupportRepositoryImpl(this._service);

  @override
  SupportContent getSupportContent() {
    return _service.getSupportContent().toEntity();
  }
}
