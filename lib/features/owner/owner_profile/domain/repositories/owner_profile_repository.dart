import 'package:rentdone/features/owner/owner_profile/domain/entities/owner_profile.dart';
abstract class OwnerProfileRepository {
  Future<OwnerProfile> getOwnerProfile();
  Future<OwnerProfile> saveOwnerProfile(OwnerProfile profile);
}
