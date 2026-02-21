import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_profile/presentation/providers/owner_profile_provider.dart';


class ProfileScreen extends ConsumerWidget {
  final String? fullName;
  final String? email;
  final String? phone;
  final String? avatarUrl;

  final VoidCallback? onEditProfile;
  final VoidCallback? onTapFullName;
  final VoidCallback? onTapEmail;
  final VoidCallback? onTapPhone;
  final VoidCallback? onTapNotifications;
  final VoidCallback? onTapChangePassword;
  final VoidCallback? onTapLinkedAccounts;

  const ProfileScreen({
    super.key,
    this.fullName,
    this.email,
    this.phone,
    this.avatarUrl,
    this.onEditProfile,
    this.onTapFullName,
    this.onTapEmail,
    this.onTapPhone,
    this.onTapNotifications,
    this.onTapChangePassword,
    this.onTapLinkedAccounts,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(ownerProfileProvider);
    final displayName = fullName ?? profile.fullName;
    final displayEmail = email ?? profile.email;
    final displayPhone = phone ?? profile.phone;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
 

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              _header(
                context,
                profile: profile,
                displayName: displayName,
                displayEmail: displayEmail,
              ),
              const SizedBox(height: 20),
              _sectionTitle(context, 'Choose Character'),
              const SizedBox(height: 12),
              _characterPicker(context, ref, profile),
              const SizedBox(height: 24),
              _sectionTitle(context, 'Account Info'),
              const SizedBox(height: 12),
              _cardSection(context,
                children: [
                  _profileRow(
                    context,
                    icon: Icons.person_outline,
                    label: 'Full Name',
                    value: displayName,
                    onTap: onTapFullName,
                    semanticsLabel: 'Full name',
                  ),
                  const SizedBox(height: 8),
                  _profileRow(
                    context,
                    icon: Icons.email_outlined,
                    label: 'Email Address',
                    value: displayEmail,
                    onTap: onTapEmail,
                    semanticsLabel: 'Email address',
                  ),
                  const SizedBox(height: 8),
                  _profileRow(
                    context,
                    icon: Icons.phone_outlined,
                    label: 'Phone Number',
                    value: displayPhone,
                    onTap: onTapPhone,
                    semanticsLabel: 'Phone number',
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _sectionTitle(context, 'App Preferences'),
              const SizedBox(height: 12),
              _cardSection( context,
                children: [
                  _profileRow(
                    context,
                    icon: Icons.notifications_outlined,
                    label: 'Notification Preferences',
                    value: 'Manage alerts',
                    onTap: onTapNotifications,
                    semanticsLabel: 'Notification preferences',
                  ),
                  const SizedBox(height: 8),
                  _profileRow(
                    context,
                    icon: Icons.lock_outline,
                    label: 'Change Password',
                    value: 'Update password',
                    onTap: onTapChangePassword,
                    semanticsLabel: 'Change password',
                  ),
                  const SizedBox(height: 8),
                  _profileRow(
                    context,
                    icon: Icons.link_outlined,
                    label: 'Linked Accounts',
                    value: 'Google, Apple',
                    onTap: onTapLinkedAccounts,
                    semanticsLabel: 'Linked accounts',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context, {
    required OwnerProfileState profile,
    required String displayName,
    required String displayEmail,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.1),
                  width: 2,
                ),
                color: scheme.surface,
                image: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(avatarUrl!),
                        fit: BoxFit.cover,
                      )
                    : DecorationImage(
                        image: AssetImage(profile.avatar.assetPath),
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            Positioned(
              right: -2,
              top: -2,
              child: Semantics(
                label: 'Edit profile',
                button: true,
                child: Material(
                  color: scheme.surface,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEditProfile,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit,
                        size: 18,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          displayName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          displayEmail,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _characterPicker(
    BuildContext context,
    WidgetRef ref,
    OwnerProfileState profile,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 420;
        final options = OwnerAvatar.values.map((avatar) {
          return _CharacterOption(
            avatar: avatar,
            selected: avatar == profile.avatar,
            onTap: () =>
                ref.read(ownerProfileProvider.notifier).setAvatar(avatar),
          );
        }).toList();

        if (isWide) {
          return Row(
            children: [
              Expanded(child: options[0]),
              const SizedBox(width: 12),
              Expanded(child: options[1]),
            ],
          );
        }

        return Column(
          children: [options[0], const SizedBox(height: 12), options[1]],
        );
      },
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    final text = Theme.of(context).textTheme;

    return Text(title, style: text.titleLarge);
  }

  Widget _cardSection(BuildContext context, {required List<Widget> children}) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      color: scheme.surface,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(children: children),
      ),
    );
  }

  Widget _profileRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String semanticsLabel,
    VoidCallback? onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
   
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: scheme.surface,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: scheme.onSurface.withValues(alpha: 0.6),
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.chevron_right, color: scheme.onSurface),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterOption extends StatelessWidget {
  final OwnerAvatar avatar;
  final bool selected;
  final VoidCallback onTap;

  const _CharacterOption({
    required this.avatar,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
   
    final borderColor = selected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.1);
    final bgColor = selected
        ? scheme.primary.withValues(alpha: 0.08)
        : scheme.surface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(avatar.assetPath, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avatar.label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected ? 'Selected' : 'Tap to select',
                    style: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? scheme.primary
                          : scheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected
                  ? scheme.primary
                  : scheme.onSurface.withValues(alpha: 0.6),
            ),
          ],
        ),
      ),
    );
  }
}
