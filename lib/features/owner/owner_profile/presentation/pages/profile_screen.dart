import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/owner/owner_profile/presentation/providers/owner_profile_provider.dart';

const Color _bg = Color(0xFFF8F9FA);
const Color _card = Color(0xFFFFFFFF);
const Color _primaryText = Color(0xFF202124);
const Color _secondaryText = Color(0xFF5F6368);
const Color _divider = Color(0xFFE0E0E0);
const Color _accent = Color(0xFF2563EB);

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

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Profile',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _primaryText,
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
              _sectionTitle('Choose Character'),
              const SizedBox(height: 12),
              _characterPicker(context, ref, profile),
              const SizedBox(height: 24),
              _sectionTitle('Account Info'),
              const SizedBox(height: 12),
              _cardSection(
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
              _sectionTitle('App Preferences'),
              const SizedBox(height: 12),
              _cardSection(
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
                border: Border.all(color: _divider, width: 2),
                color: _card,
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
                  color: _card,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onEditProfile,
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.edit, size: 18, color: _secondaryText),
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
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _primaryText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          displayEmail,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: _secondaryText,
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
            onTap: () => ref
                .read(ownerProfileProvider.notifier)
                .setAvatar(avatar),
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
          children: [
            options[0],
            const SizedBox(height: 12),
            options[1],
          ],
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _primaryText,
      ),
    );
  }

  Widget _cardSection({required List<Widget> children}) {
    return Card(
      color: _card,
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
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: Material(
        color: _card,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                Icon(icon, color: _secondaryText, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: _secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(
                  Icons.chevron_right,
                  color: _secondaryText,
                ),
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
    final borderColor = selected ? _accent : _divider;
    final bgColor = selected ? _accent.withValues(alpha: 0.08) : _card;

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
                border: Border.all(color: _divider),
              ),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Image.asset(
                  avatar.assetPath,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    avatar.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: _primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    selected ? 'Selected' : 'Tap to select',
                    style: TextStyle(
                      fontSize: 13,
                      color: selected ? _accent : _secondaryText,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? _accent : _secondaryText,
            ),
          ],
        ),
      ),
    );
  }
}
