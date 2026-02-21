import 'package:rentdone/features/owner/owner_support/domain/entities/support_content.dart';
import 'package:rentdone/features/owner/owner_support/domain/repositories/support_repository.dart';

class GetSupportContent {
  final SupportRepository _repository;

  const GetSupportContent(this._repository);

  SupportContent call() {
    return _repository.getSupportContent();
  }
}
