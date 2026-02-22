# Email-Based Profile Picture System

## Overview

This system automatically generates and displays profile pictures for users based on their email addresses using the Gravatar service. When a user logs in, their email is used to fetch or generate a unique profile picture that appears throughout the app.

## Features

✅ **Automatic Gravatar Integration**: Profile pictures are automatically generated from user emails
✅ **Fallback System**: Multiple fallback options ensure users always have a profile picture
✅ **Firebase Integration**: Email-based photos are stored in Firebase on login/signup
✅ **Reusable Widgets**: Easy-to-use widgets for displaying profile pictures consistently
✅ **Retina Display Support**: High-resolution images for crisp display on all devices
✅ **Network Error Handling**: Graceful fallback to placeholder icons if images fail to load

## How It Works

### 1. Gravatar Service

The `GravatarService` (`lib/core/services/gravatar_service.dart`) generates unique URLs from email addresses:

```dart
// Generate a Gravatar URL from an email
final gravatarUrl = GravatarService.getGravatarUrlWithFallback(
  'user@example.com',
  size: 400,
  fallbackType: 'identicon',
);
```

**Fallback Types Available:**
- `identicon`: Geometric pattern based on email hash (default)
- `mp` (mystery person): Simple cartoon silhouette
- `monsterid`: Generated monster with different colors/faces
- `wavatar`: Generated faces with differing features
- `retro`: 8-bit arcade-style pixelated faces
- `robohash`: Generated robot/monster images

### 2. Authentication Flow

When users log in or sign up (`lib/features/auth/data/services/auth_firebase_services.dart`):

1. User authenticates via Google, Email, or Phone
2. System generates a Gravatar URL from their email
3. Both the Firebase photo URL (if available) and Gravatar are stored in Firestore
4. The final photo URL prioritizes: Custom Upload → Firebase Auth Photo → Gravatar

```dart
// During login/signup
final gravatarUrl = GravatarService.getGravatarUrlWithFallback(
  userEmail,
  size: 400,
  fallbackType: 'identicon',
);

await docRef.set({
  'photoUrl': user.photoURL ?? gravatarUrl,
  'gravatarUrl': gravatarUrl,
  // ... other fields
});
```

### 3. Profile Management

The profile service (`lib/features/owner/owner_profile/data/services/owner_profile_auth_service.dart`) handles profile pictures:

**On Profile Load:**
- Fetches user data from Firestore
- Generates fresh Gravatar from current email
- Returns custom photo if available, otherwise Gravatar

**On Profile Save:**
- Regenerates Gravatar if email changes
- Updates both `photoUrl` and `gravatarUrl` fields
- Maintains custom photos if user uploaded one

### 4. UI Components

#### ProfilePictureAvatar Widget

The main widget (`lib/shared/widgets/profile_picture_avatar.dart`) displays profile pictures:

```dart
// Basic usage
ProfilePictureAvatar(
  photoUrl: user.photoUrl,
  email: user.email,
  size: 48,
)

// Circular variant
CircularProfileAvatar(
  photoUrl: user.photoUrl,
  email: user.email,
  radius: 24,
  showBorder: true,
)

// Square variant with rounded corners
SquareProfileAvatar(
  photoUrl: user.photoUrl,
  email: user.email,
  size: 48,
  borderRadius: 12,
)
```

**Widget Features:**
- Automatically generates Gravatar if no photoUrl provided
- Shows placeholder icon if both photoUrl and email are missing
- Handles network errors gracefully
- Customizable size, border, colors, and shape

## Implementation in Your App

### Profile Screen

The profile header (`lib/features/owner/owner_profile/presentation/pages/profile_screen.dart`) displays the user's picture:

```dart
CircularProfileAvatar(
  photoUrl: profile.photoUrl,
  email: profile.email,
  radius: 45,
  showBorder: true,
)
```

### Tenant List

Tenant cards (`lib/features/owner/owner_tenants/presentation/pages/manage_tenants_screen.dart`) show tenant profile pictures:

```dart
CircularProfileAvatar(
  photoUrl: tenant.photoUrl,
  email: tenant.email,
  radius: 22,
)
```

## Database Schema

### Firestore `users` Collection

```json
{
  "uid": "user-unique-id",
  "email": "user@example.com",
  "emailLowercase": "user@example.com",
  "photoUrl": "https://lh3.googleusercontent.com/..." or "https://www.gravatar.com/avatar/...",
  "gravatarUrl": "https://www.gravatar.com/avatar/hash?s=400&d=identicon",
  "name": "User Name",
  "phone": "+1234567890",
  "role": "owner",
  "createdAt": timestamp,
  "updatedAt": timestamp
}
```

**Key Fields:**
- `photoUrl`: The active profile picture URL (custom upload, Firebase Auth photo, or Gravatar)
- `gravatarUrl`: The generated Gravatar URL (always available as fallback)
- `email`: Used to generate Gravatar URLs
- `emailLowercase`: Normalized for lookups

## Testing the System

### Test with Different Emails

1. **Existing Gravatar User**: Use an email that has a Gravatar account (e.g., your GitHub email)
2. **New User**: Use any email to see the identicon pattern
3. **No Email**: Test with phone-only authentication to see placeholder

### Verify Backend Storage

Check Firestore after login:
```javascript
// Firebase Console → Firestore → users collection
{
  photoUrl: "https://www.gravatar.com/avatar/...",
  gravatarUrl: "https://www.gravatar.com/avatar/..."
}
```

### UI Verification Points

- ✅ Profile screen header shows picture
- ✅ Tenant list shows pictures for all tenants
- ✅ Pictures update when email changes
- ✅ Network errors show placeholder icon
- ✅ Pictures are crisp on all screen sizes

## Customization

### Change Default Fallback Type

Edit `lib/core/services/gravatar_service.dart`:

```dart
static String getGravatarUrlWithFallback(
  String email, {
  int size = 200,
  String fallbackType = 'robohash', // Change this
}) {
  // ...
}
```

### Change Picture Sizes

Update size parameters in widgets:

```dart
// For retina displays, use 2x the display size
CircularProfileAvatar(
  email: user.email,
  radius: 48, // Widget generates 96x96 image internally
)
```

### Add Custom Upload Feature

To allow users to upload custom profile pictures:

1. Add image picker in profile screen
2. Upload to Firebase Storage or Cloudinary
3. Update `photoUrl` field in Firestore
4. System will automatically use uploaded photo over Gravatar

## Dependencies

```yaml
dependencies:
  crypto: ^3.0.3  # For MD5 hash generation (Gravatar)
```

## Security & Privacy

- **No PII Exposure**: Only MD5 hashes of emails are sent to Gravatar
- **HTTPS**: All Gravatar URLs use secure HTTPS
- **Fallback Privacy**: Identicon patterns don't expose personal information
- **Optional**: Users can override with custom profile pictures

## Troubleshoetries

### Profile Picture Not Showing

1. Check email is valid in Firestore
2. Verify internet connection
3. Check browser console for network errors
4. Ensure `photoUrl` field exists in user document

### Wrong Picture Displayed

1. Verify email is correct
2. Clear Flutter's image cache: `PaintingBinding.instance.imageCache.clear()`
3. Check if multiple accounts share the same email

### Performance Issues

1. Profile pictures are cached by Flutter's image cache
2. Use appropriate sizes (don't request 4000x4000 for 48px display)
3. Consider local caching for offline scenarios

## Future Enhancements

- [ ] Local caching of profile pictures
- [ ] Support for alternative avatar services
- [ ] Profile picture upload UI
- [ ] Image compression for custom uploads
- [ ] Animated placeholder while loading

## Support

For issues or questions about the email-based profile picture system, check:
- Gravatar documentation: https://en.gravatar.com/site/implement/
- Flutter networking: https://docs.flutter.dev/cookbook/networking/fetch-data
