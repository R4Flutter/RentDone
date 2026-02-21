import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_support/data/repositories/support_repository_impl.dart';
import 'package:rentdone/features/owner/owner_support/data/services/support_local_service.dart';
import 'package:rentdone/features/owner/owner_support/domain/repositories/support_repository.dart';
import 'package:rentdone/features/owner/owner_support/domain/usecases/get_support_content.dart';

final supportLocalServiceProvider = Provider<SupportLocalService>((ref) {
  return SupportLocalService();
});

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final service = ref.watch(supportLocalServiceProvider);
  return SupportRepositoryImpl(service);
});

final getSupportContentUseCaseProvider = Provider<GetSupportContent>((ref) {
  return GetSupportContent(ref.watch(supportRepositoryProvider));
});
