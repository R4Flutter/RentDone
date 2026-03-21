# 🎨 Glassmorphism Quick Migration Guide

**Copy-paste solutions for updating dialog screens to glassmorphism**

---

## Pattern 1: Simple Confirmation Dialog

### Current Code (❌ OLD)
```dart
showDialog<bool>(
  context: context,
  builder: (ctx) => AlertDialog(
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
    title: const Text('Confirm'),
    content: const Text('Are you sure?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx, false),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(ctx, true),
        child: const Text('Confirm'),
      ),
    ],
  ),
) ?? false;
```

### New Code (✅ GLASS)
```dart
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';

GlassDialogHelper.showConfirmDialog(
  context,
  title: 'Confirm',
  message: 'Are you sure?',
  confirmText: 'Confirm',
  cancelText: 'Cancel',
) ?? false;
```

---

## Pattern 2: Delete/Dangerous Action

### Current Code (❌ OLD)
```dart
AlertDialog(
  title: const Text('Delete Item?'),
  content: const Text('This cannot be undone.'),
  actions: [
    TextButton(
      onPressed: () => Navigator.pop(context, false),
      child: const Text('Keep'),
    ),
    FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: Colors.red,
      ),
      onPressed: () => Navigator.pop(context, true),
      child: const Text('Delete'),
    ),
  ],
)
```

### New Code (✅ GLASS)
```dart
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';

GlassDialogHelper.showConfirmDialog(
  context,
  title: 'Delete Item?',
  message: 'This action cannot be undone.',
  confirmText: 'Delete',
  cancelText: 'Keep',
  isDangerous: true,
) ?? false;
```

---

## Pattern 3: Error Dialog

### Current Code (❌ OLD)
```dart
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Error'),
    content: const Text('Something went wrong'),
    actions: [
      FilledButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('OK'),
      ),
    ],
  ),
);
```

### New Code (✅ GLASS)
```dart
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';

GlassDialogHelper.showErrorDialog(
  context,
  title: 'Error',
  message: 'Something went wrong',
  actionText: 'OK',
);
```

---

## Pattern 4: Success Dialog

### New Code (✅ GLASS)
```dart
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';

GlassDialogHelper.showSuccessDialog(
  context,
  title: 'Success!',
  message: 'Operation completed successfully.',
  actionText: 'Done',
  onDismiss: () {
    // Navigate or refresh
  },
);
```

---

## Pattern 5: Loading Dialog

### Current Code (❌ OLD)
```dart
showDialog(
  context: context,
  barrierDismissible: false,
  builder: (ctx) => AlertDialog(
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 16),
        const Text('Processing...'),
      ],
    ),
  ),
);
```

### New Code (✅ GLASS)
```dart
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';

GlassDialogHelper.showLoadingDialog(
  context,
  message: 'Processing...',
  dismissible: false,
);
```

---

## Pattern 6: Custom Form Dialog

### Current Code (❌ OLD)
```dart
showDialog(
  context: context,
  builder: (ctx) => AlertDialog(
    title: const Text('Edit Name'),
    content: TextField(
      controller: controller,
      decoration: const InputDecoration(labelText: 'Name'),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(ctx),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          Navigator.pop(ctx, controller.text);
        },
        child: const Text('Save'),
      ),
    ],
  ),
);
```

### New Code (✅ GLASS)
```dart
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';
import 'package:rentdone/shared/design/glassmorphism.dart';

GlassDialogHelper.showCustomDialog(
  context,
  title: 'Edit Name',
  content: TextField(
    controller: controller,
    decoration: const InputDecoration(labelText: 'Name'),
  ),
  actions: [
    GlassButton(
      onPressed: () => Navigator.pop(context),
      label: 'Cancel',
    ),
    GlassButton(
      onPressed: () => Navigator.pop(context, controller.text),
      label: 'Save',
      isPrimary: true,
    ),
  ],
);
```

---

## Pattern 7: Bottom Sheet

### Current Code (❌ OLD)
```dart
showModalBottomSheet(
  context: context,
  builder: (ctx) => Container(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Options'),
        // Content here
      ],
    ),
  ),
);
```

### New Code (✅ GLASS)
```dart
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';

GlassDialogHelper.showCustomBottomSheet(
  context,
  title: 'Options',
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      // Content here
    ],
  ),
);
```

---

## Files to Update (Priority Order)

### 🔴 CRITICAL (Today)
- [ ] `lib/features/owner/owner_payment/presentation/widgets/payment_history_card.dart`
  - Replace `_showConfirmDialog()` with `GlassDialogHelper.showConfirmDialog()`
  - Replace `_showInstallmentDialog()` with `GlassDialogHelper.showCustomDialog()`

- [ ] `lib/features/owner/owner_settings/presentation/pages/owner_settings_screen.dart`
  - Replace `_showChangePasswordDialog()` with glassmorphic version
  - Replace logout confirmation dialog

### 🟡 IMPORTANT (This Week)
- [ ] `lib/features/owner/owners_properties/presentation/pages/manage_property_screen.dart`
  - All `showDialog()` calls
  - All `AlertDialog` instances
  - All confirmation dialogs

- [ ] `lib/features/owner/owner_tenants/presentation/pages/manage_tenants_screen.dart`
  - Delete tenant confirmation
  - Add tenant form dialog
  - Tenant details modal

- [ ] `lib/features/owner/add_tenant/presentation/pages/owner_add_property.dart`
  - Form submission dialogs
  - Success/error dialogs
  - Loading dialogs

### 🟢 NICE-TO-HAVE (Next Week)
- [ ] `lib/features/owner/owner_notifications/`
  - Notification cards
  - Dismiss confirmation

- [ ] `lib/features/owner/owner_profile/`
  - Profile dialogs
  - Settings modals

---

## Search & Replace Commands

### Find all AlertDialog instances:
```bash
grep -r "AlertDialog(" lib/features/owner/
```

### Find all showDialog calls:
```bash
grep -r "showDialog(" lib/features/owner/
```

### Find all PopupMenuButton instances:
```bash
grep -r "PopupMenuItem(" lib/features/owner/
```

---

## Step-by-Step Update Process

### For Each File:

```dart
// 1. Add imports at the top
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';
import 'package:rentdone/shared/design/glassmorphism.dart';

// 2. Find `showDialog()` calls
// 3. Replace with appropriate `GlassDialogHelper` method
// 4. Remove old `AlertDialog` code
// 5. Test both light and dark modes
// 6. Commit with message: "refactor: Update dialogs to glassmorphism"
```

---

## Testing Checklist for Each Update

- [ ] Dialog appears with glass effect
- [ ] Text is readable
- [ ] Buttons respond to taps
- [ ] Dialog closes smoothly
- [ ] Works in light mode
- [ ] Works in dark mode
- [ ] No console errors
- [ ] No flickering
- [ ] Animations smooth

---

## Example: Complete File Update

### File: `manage_property_deletion.dart`

```dart
import 'package:flutter/material.dart';
import 'package:rentdone/shared/utils/glass_dialog_helper.dart';

class PropertyDeletionHandler {
  final BuildContext context;
  
  PropertyDeletionHandler(this.context);

  /// Show delete property dialog with glassmorphism
  Future<bool> showDeleteConfirmation(String propertyName) async {
    final confirmed = await GlassDialogHelper.showConfirmDialog(
      context,
      title: 'Delete Property',
      message: 'Are you sure you want to delete "$propertyName"?\n\n'
          'All associated data will be permanently removed.',
      confirmText: 'Delete',
      cancelText: 'Keep',
      isDangerous: true,
    ) ?? false;

    if (confirmed) {
      // Show loading dialog
      GlassDialogHelper.showLoadingDialog(
        context,
        message: 'Deleting property...',
        dismissible: false,
      );

      try {
        // Perform deletion
        await _deleteProperty(propertyName);
        
        // Close loading dialog
        Navigator.pop(context);
        
        // Show success
        await GlassDialogHelper.showSuccessDialog(
          context,
          title: 'Deleted',
          message: 'Property deleted successfully.',
          actionText: 'Done',
        );
        
        return true;
      } catch (e) {
        // Close loading dialog
        Navigator.pop(context);
        
        // Show error
        await GlassDialogHelper.showErrorDialog(
          context,
          title: 'Error',
          message: 'Failed to delete property: $e',
          actionText: 'Retry',
        );
        
        return false;
      }
    }
    
    return false;
  }

  Future<void> _deleteProperty(String name) async {
    // Implementation
  }
}
```

---

## Rollback Instructions

If something goes wrong:

```bash
# Revert last commit
git revert HEAD

# Or revert specific file
git checkout HEAD -- lib/features/owner/specific_file.dart
```

---

## Status Tracking

### Files Updated:
- [x] `glassmorphism.dart` - Core components
- [x] `glass_dialog_helper.dart` - Helper utilities
- [x] `botttom_nav_bar.dart` - Bottom nav
- [x] `dashboard_card.dart` - Dashboard cards
- [x] `payment_history_card.dart` - Payment dialogs

### Remaining:
- [ ] Property management dialogs
- [ ] Tenant management dialogs
- [ ] Settings dialogs
- [ ] Notification cards
- [ ] Profile screens

---

## Questions?

Refer to:
1. `GLASSMORPHISM_GUIDE.md` - Full documentation
2. `lib/shared/design/glassmorphism.dart` - Source code
3. `lib/shared/utils/glass_dialog_helper.dart` - Helper methods

**Happy glassmorphism-ing!** 🎨

