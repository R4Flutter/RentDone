import 'package:rentdone/features/owner/owner_profile/domain/entities/owner_profile.dart';
import 'package:rentdone/features/owner/owner_profile/domain/repositories/owner_profile_repository.dart';

class GetOwnerProfile {
  final OwnerProfileRepository _repository;

  const GetOwnerProfile(this._repository);

  OwnerProfile call() {
    return _repository.getOwnerProfile();
  }
}
