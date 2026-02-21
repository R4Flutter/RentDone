import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_dashboard/di/dashboard_di.dart';
import 'package:rentdone/features/owner/owner_dashboard/domain/entities/app_message.dart';

final messagesProvider = StreamProvider<List<AppMessage>>((ref) {
  final useCase = ref.watch(watchRecentMessagesUseCaseProvider);
  return useCase(limit: 6);
});
