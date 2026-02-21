import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_profile/data/repositories/owner_profile_repository_impl.dart';
import 'package:rentdone/features/owner/owner_profile/data/services/owner_profile_auth_service.dart';
import 'package:rentdone/features/owner/owner_profile/domain/repositories/owner_profile_repository.dart';
import 'package:rentdone/features/owner/owner_profile/domain/usecases/get_owner_profile.dart';

final ownerProfileAuthServiceProvider = Provider<OwnerProfileAuthService>((
  ref,
) {
  return OwnerProfileAuthService();
});

final ownerProfileRepositoryProvider = Provider<OwnerProfileRepository>((ref) {
  final authService = ref.watch(ownerProfileAuthServiceProvider);
  return OwnerProfileRepositoryImpl(authService);
});

final getOwnerProfileUseCaseProvider = Provider<GetOwnerProfile>((ref) {
  final repository = ref.watch(ownerProfileRepositoryProvider);
  return GetOwnerProfile(repository);
});
