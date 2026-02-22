import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/owner/owner_profile/presentation/providers/owner_profile_provider.dart';
import 'package:rentdone/features/owner/owner_settings/presentation/providers/owner_settings_provider.dart';
import 'package:rentdone/shared/widgets/profile_picture_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  final String? avatarUrl;

  const ProfileScreen({super.key, this.avatarUrl});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();

    void markDirty() {
      if (_dirty) return;
      setState(() => _dirty = true);
    }

    _fullNameController.addListener(markDirty);
    _emailController.addListener(markDirty);
    _phoneController.addListener(markDirty);
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _hydrate(OwnerProfileState profile) {
    if (_dirty || profile.isLoading) return;
    _fullNameController.text = profile.fullName;
    _emailController.text = profile.email;
    _phoneController.text = profile.phone;
  }

  Future<void> _save(OwnerProfileState profile) async {
    await ref
        .read(ownerProfileProvider.notifier)
        .saveProfile(
          fullName: _fullNameController.text,
          email: _emailController.text,
          phone: _phoneController.text,
          location: profile.location,
        );
    if (mounted) {
      setState(() => _dirty = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(ownerProfileProvider);
    final settings = ref.watch(ownerSettingsProvider);
    final settingsNotifier = ref.read(ownerSettingsProvider.notifier);
    _hydrate(profile);

    ref.listen(ownerProfileProvider, (previous, next) {
      final messenger = ScaffoldMessenger.of(context);
      if (next.errorMessage != null && next.errorMessage!.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(next.errorMessage!)));
      }
      if (next.successMessage != null && next.successMessage!.isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(next.successMessage!)));
      }
    });

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: scheme.onSurface),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else {
              context.goNamed('ownerDashboard');
            }
          },
        ),
        title: Text(
          'Profile',
          style: TextStyle(
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: profile.isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context, profile: profile),
                    const SizedBox(height: 20),
                    _sectionTitle(context, 'Choose Character'),
                    const SizedBox(height: 12),
                    _characterPicker(context, ref, profile),
                    const SizedBox(height: 24),
                    _accountInfoCard(
                      context,
                      profile,
                      fullNameController: _fullNameController,
                      emailController: _emailController,
                      phoneController: _phoneController,
                    ),
                    const SizedBox(height: 16),
                    _ownerLocationCard(context, settings, settingsNotifier),
                    const SizedBox(height: 24),
                    _sectionTitle(context, 'Profile Meta'),
                    const SizedBox(height: 12),
                    _cardSection(
                      context,
                      children: [
                        _readonlyMetaRow(context, 'Role', profile.role),
                        const SizedBox(height: 8),
                        _readonlyMetaRow(context, 'Status', profile.status),
                        const SizedBox(height: 8),
                        _readonlyMetaRow(
                          context,
                          'Member ID',
                          profile.memberId,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header(BuildContext context, {required OwnerProfileState profile}) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        CircularProfileAvatar(
          photoUrl: profile.photoUrl,
          email: profile.email,
          radius: 45,
          showBorder: true,
          border: Border.all(
            color: scheme.onSurface.withValues(alpha: 0.1),
            width: 2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          profile.fullName,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          profile.email,
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

  Widget _accountInfoCard(
    BuildContext context,
    OwnerProfileState profile, {
    required TextEditingController fullNameController,
    required TextEditingController emailController,
    required TextEditingController phoneController,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [scheme.primary.withValues(alpha: 0.92), scheme.primary],
        ),
        border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: scheme.onPrimary.withValues(alpha: 0.16),
                ),
                child: Icon(
                  Icons.person_outline,
                  color: scheme.onPrimary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Profile',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Your personal contact details.',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _accountInfoInput(
            context,
            label: 'Full Name',
            controller: fullNameController,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          _accountInfoInput(
            context,
            label: 'Email',
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 10),
          _accountInfoInput(
            context,
            label: 'Phone',
            controller: phoneController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.onPrimary,
                foregroundColor: scheme.primary,
              ),
              onPressed: profile.isSaving ? null : () => _save(profile),
              icon: profile.isSaving
                  ? SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(profile.isSaving ? 'Saving...' : 'Save'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountInfoInput(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      style: TextStyle(
        color: scheme.onPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: scheme.onPrimary,
      decoration: InputDecoration(
        isDense: true,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        labelText: label,
        labelStyle: TextStyle(
          color: scheme.onPrimary.withValues(alpha: 0.78),
          fontSize: 13,
          fontWeight: FontWeight.w400,
        ),
        hintStyle: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.5)),
        filled: true,
        fillColor: scheme.onPrimary.withValues(alpha: 0.06),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.onPrimary.withValues(alpha: 0.24),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: scheme.onPrimary.withValues(alpha: 0.48),
          ),
        ),
      ),
    );
  }

  Widget _readonlyMetaRow(BuildContext context, String label, String value) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _ownerLocationCard(
    BuildContext context,
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.blueSurfaceGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.location_on_outlined,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Location',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Current owner location for map features.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onPrimary.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _locationSectionContent(settings, notifier, theme),
        ],
      ),
    );
  }

  Widget _locationSectionContent(
    OwnerSettingsState settings,
    OwnerSettingsNotifier notifier,
    ThemeData theme,
  ) {
    final locationErrorText = settings.errorMessage ?? '';
    final lowerError = locationErrorText.toLowerCase();
    final hasLocationIssue = lowerError.contains('location');
    final serviceDisabled = lowerError.contains('service is disabled');
    final permissionDenied =
        lowerError.contains('permission denied') ||
        lowerError.contains('permanently denied');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Current Location',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                  FilledButton.icon(
                    onPressed: settings.isFetchingLocation
                        ? null
                        : () => notifier.captureCurrentLocation(),
                    icon: settings.isFetchingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.location_searching),
                    label: Text(
                      settings.isFetchingLocation
                          ? 'Capturing...'
                          : 'Capture Now',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (settings.locationAddress.isNotEmpty) ...[
                Text('Address', style: theme.textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(
                  settings.locationAddress,
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                Text('Coordinates', style: theme.textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(
                  '${settings.locationLatitude?.toStringAsFixed(6) ?? 'N/A'}, '
                  '${settings.locationLongitude?.toStringAsFixed(6) ?? 'N/A'}',
                  style: theme.textTheme.bodySmall,
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'No location captured yet. Tap "Capture Now" to set your location.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.secondary,
                    ),
                  ),
                ),
              if (hasLocationIssue) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (serviceDisabled)
                      OutlinedButton.icon(
                        onPressed: () => notifier.openLocationSettings(),
                        icon: const Icon(Icons.settings),
                        label: const Text('Open Location Settings'),
                      ),
                    if (permissionDenied)
                      OutlinedButton.icon(
                        onPressed: () => notifier.openAppSettings(),
                        icon: const Icon(Icons.app_settings_alt),
                        label: const Text('Open App Settings'),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
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
