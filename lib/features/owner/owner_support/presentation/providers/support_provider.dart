import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_support/di/owner_support_di.dart';
import 'package:rentdone/features/owner/owner_support/domain/entities/support_content.dart';

final supportContentProvider = Provider<SupportContent>((ref) {
  return ref.watch(getSupportContentUseCaseProvider).call();
});
