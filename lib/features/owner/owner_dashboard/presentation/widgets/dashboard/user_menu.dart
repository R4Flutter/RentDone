import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_profile/presentation/providers/owner_profile_provider.dart';

class UserMenu extends ConsumerWidget {
  const UserMenu({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = OwnerDashboardColors.isDark(context);
    final profile = ref.watch(ownerProfileProvider);

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () => context.goNamed('ownerProfile'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        height: 36,
        width: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? AppColors.cFF1E293B : AppColors.cFFF1F5F9,
          border: Border.all(
            color: OwnerDashboardColors.border(context).withValues(alpha: 0.8),
          ),
          boxShadow: [
            BoxShadow(
              color: OwnerDashboardColors.brandPrimary(
                context,
              ).withValues(alpha: isDark ? 0.16 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipOval(
          child: profile.photoUrl.isNotEmpty
              ? Image.network(
                  profile.photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Image.asset(
                      profile.avatar.assetPath,
                      fit: BoxFit.cover,
                    );
                  },
                )
              : Image.asset(profile.avatar.assetPath, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
