import 'package:rentdone/features/owner/owner_profile/data/models/owner_profile_dto.dart';
import 'package:rentdone/features/owner/owner_profile/data/services/owner_profile_auth_service.dart';
import 'package:rentdone/features/owner/owner_profile/domain/entities/owner_profile.dart';
import 'package:rentdone/features/owner/owner_profile/domain/repositories/owner_profile_repository.dart';

class OwnerProfileRepositoryImpl implements OwnerProfileRepository {
  final OwnerProfileAuthService _authService;

  OwnerProfileRepositoryImpl(this._authService);

  @override
  Future<OwnerProfile> getOwnerProfile() async {
    final dto = await _authService.getOwnerProfile();
    return dto.toEntity();
  }

  @override
  Future<OwnerProfile> saveOwnerProfile(OwnerProfile profile) async {
    final dto = OwnerProfileDto.fromEntity(profile);
    final saved = await _authService.saveOwnerProfile(dto);
    return saved.toEntity();
  }
}
