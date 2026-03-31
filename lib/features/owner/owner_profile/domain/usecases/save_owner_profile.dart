import 'package:rentdone/features/owner/owner_profile/domain/entities/owner_profile.dart';
import 'package:rentdone/features/owner/owner_profile/domain/repositories/owner_profile_repository.dart';

class SaveOwnerProfile {
  final OwnerProfileRepository _repository;

  const SaveOwnerProfile(this._repository);

  Future<OwnerProfile> call(OwnerProfile profile) {
    return _repository.saveOwnerProfile(profile);
  }
}
