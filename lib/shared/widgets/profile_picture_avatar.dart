import 'package:flutter/material.dart';
import 'package:rentdone/core/services/gravatar_service.dart';

/// A widget that displays a user's profile picture with Gravatar fallback.
///
/// This widget automatically:
/// - Shows the provided photoUrl if available
/// - Falls back to a Gravatar generated from the user's email
/// - Shows a placeholder icon if neither is available
class ProfilePictureAvatar extends StatelessWidget {
  /// The URL of the user's profile picture
  final String? photoUrl;

  /// The user's email address (used for Gravatar generation)
  final String? email;

  /// The size of the avatar (width and height in pixels)
  final double size;

  /// Optional border radius (defaults to circular)
  final BorderRadius? borderRadius;

  /// Optional border
  final Border? border;

  /// Background color when no image is available
  final Color? backgroundColor;

  /// Icon color for placeholder
  final Color? iconColor;

  /// Whether to show a border
  final bool showBorder;

  const ProfilePictureAvatar({
    super.key,
    this.photoUrl,
    this.email,
    this.size = 48,
    this.borderRadius,
    this.border,
    this.backgroundColor,
    this.iconColor,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveBackgroundColor =
        backgroundColor ?? theme.colorScheme.primary.withValues(alpha: 0.1);
    final effectiveIconColor =
        iconColor ?? theme.colorScheme.onSurface.withValues(alpha: 0.5);

    // Determine which image URL to use
    String? imageUrl = photoUrl;

    // If no photoUrl but email is provided, generate Gravatar
    if ((imageUrl == null || imageUrl.isEmpty) &&
        email != null &&
        email!.isNotEmpty) {
      imageUrl = GravatarService.getGravatarUrlWithFallback(
        email!,
        size: (size * 2).toInt(), // 2x for retina displays
        fallbackType: 'identicon',
      );
    }

    final hasValidImage = imageUrl != null && imageUrl.isNotEmpty;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
        border: showBorder
            ? border ??
                  Border.all(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
                    width: 2,
                  )
            : null,
        color: hasValidImage ? null : effectiveBackgroundColor,
        image: hasValidImage
            ? DecorationImage(
                image: NetworkImage(imageUrl),
                fit: BoxFit.cover,
                onError: (error, stackTrace) {
                  // Image failed to load, will show fallback icon instead
                },
              )
            : null,
      ),
      child: !hasValidImage
          ? Icon(Icons.person, size: size * 0.6, color: effectiveIconColor)
          : null,
    );
  }
}

/// A circular variant of ProfilePictureAvatar
class CircularProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? email;
  final double radius;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool showBorder;
  final Border? border;

  const CircularProfileAvatar({
    super.key,
    this.photoUrl,
    this.email,
    this.radius = 24,
    this.backgroundColor,
    this.iconColor,
    this.showBorder = true,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ProfilePictureAvatar(
      photoUrl: photoUrl,
      email: email,
      size: radius * 2,
      borderRadius: BorderRadius.circular(radius * 2),
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      showBorder: showBorder,
      border: border,
    );
  }
}

/// A square variant of ProfilePictureAvatar with rounded corners
class SquareProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String? email;
  final double size;
  final double borderRadius;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool showBorder;
  final Border? border;

  const SquareProfileAvatar({
    super.key,
    this.photoUrl,
    this.email,
    this.size = 48,
    this.borderRadius = 12,
    this.backgroundColor,
    this.iconColor,
    this.showBorder = false,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return ProfilePictureAvatar(
      photoUrl: photoUrl,
      email: email,
      size: size,
      borderRadius: BorderRadius.circular(borderRadius),
      backgroundColor: backgroundColor,
      iconColor: iconColor,
      showBorder: showBorder,
      border: border,
    );
  }
}
