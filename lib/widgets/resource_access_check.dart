import 'package:flutter/material.dart';

import '../services/resource_access.dart';

/// Recheck at recording time: a previously opened resource may now be locked.
Future<bool> checkResourceAccess(
  BuildContext context,
  String userId,
  Map resource,
) async {
  try {
    final current = await ResourceAccess.fetchCurrentLevel(userId);
    if (!context.mounted) return false;
    final requiredLevel = ResourceAccess.parseLevel(resource['difficulty']);
    if (requiredLevel != null &&
        ResourceAccess.allows(current, requiredLevel)) {
      return true;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          requiredLevel == null
              ? 'This resource does not have a proficiency level yet. Choose another resource.'
              : ResourceAccess.lockedMessage(requiredLevel),
        ),
      ),
    );
  } catch (_) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Unable to verify your current level. Please try again.'),
      ),
    );
  }
  return false;
}
