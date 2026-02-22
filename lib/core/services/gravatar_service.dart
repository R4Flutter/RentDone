import 'dart:convert';
import 'package:crypto/crypto.dart';

/// Service to generate Gravatar URLs from email addresses.
/// Gravatar is a globally recognized avatar service that provides
/// profile pictures based on email addresses.
class GravatarService {
  /// Base URL for Gravatar images
  static const String _gravatarBaseUrl = 'https://www.gravatar.com/avatar';

  /// Generates a Gravatar URL for the given email address.
  ///
  /// [email] - The user's email address
  /// [size] - The desired image size in pixels (default: 200)
  /// [defaultImage] - What to show if no Gravatar exists:
  ///   - 'mp' (mystery person): simple cartoon silhouette (default)
  ///   - 'identicon': geometric pattern based on email hash
  ///   - 'monsterid': generated monster with different colors/faces
  ///   - 'wavatar': generated faces with differing features
  ///   - 'retro': 8-bit arcade-style pixelated faces
  ///   - 'robohash': generated robot/monster images
  ///   - '404': return 404 if no Gravatar exists
  ///   - 'blank': transparent PNG image
  ///
  /// Returns a full Gravatar URL string.
  static String getGravatarUrl(
    String email, {
    int size = 200,
    String defaultImage = 'mp',
  }) {
    // Normalize email: trim whitespace and convert to lowercase
    final normalizedEmail = email.trim().toLowerCase();

    // Generate MD5 hash of the email
    final emailHash = md5.convert(utf8.encode(normalizedEmail)).toString();

    // Construct the Gravatar URL with parameters
    return '$_gravatarBaseUrl/$emailHash?s=$size&d=$defaultImage';
  }

  /// Checks if an email is valid for Gravatar generation
  static bool isValidEmail(String email) {
    if (email.trim().isEmpty) return false;

    // Basic email validation regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    return emailRegex.hasMatch(email.trim());
  }

  /// Generates a Gravatar URL with fallback to identity-based default
  static String getGravatarUrlWithFallback(
    String email, {
    int size = 200,
    String fallbackType = 'identicon',
  }) {
    if (!isValidEmail(email)) {
      // Return a default identicon for invalid emails
      return getGravatarUrl(
        'default@example.com',
        size: size,
        defaultImage: fallbackType,
      );
    }

    return getGravatarUrl(email, size: size, defaultImage: fallbackType);
  }

  /// Generates multiple Gravatar URLs at different sizes for optimization
  static Map<String, String> getGravatarUrlsAtSizes(
    String email,
    List<int> sizes, {
    String defaultImage = 'mp',
  }) {
    return {
      for (var size in sizes)
        '${size}x$size': getGravatarUrl(
          email,
          size: size,
          defaultImage: defaultImage,
        ),
    };
  }
}
