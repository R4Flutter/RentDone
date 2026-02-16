import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';
import 'package:rentdone/features/owner/owner_dashboard/presentation/providers/dashboard_di.dart';

final messagesProvider = StreamProvider<List<AppMessage>>((ref) {
  final useCase = ref.watch(watchRecentMessagesUseCaseProvider);
  return useCase(limit: 6);
});
