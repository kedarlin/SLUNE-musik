import 'dart:io';

import 'package:disable_battery_optimization/disable_battery_optimization.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../core/theme/app_colors.dart';

class BatteryOptimizationHelper {
  static const String _promptedKey = 'promptedBackgroundReliability';

  static Future<void> promptForBackgroundReliability(
    BuildContext context,
  ) async {
    if (!Platform.isAndroid) {
      return;
    }

    final Box<dynamic> settings = Hive.box<dynamic>('settings');

    if (settings.get(_promptedKey, defaultValue: false) as bool) {
      return;
    }

    final bool alreadyDisabled =
        await DisableBatteryOptimization.isAllBatteryOptimizationDisabled ??
        false;

    if (alreadyDisabled) {
      await settings.put(_promptedKey, true);
      return;
    }

    if (!context.mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceHigh,
          title: const Text(
            'Keep music playing in the background',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: const Text(
            'Your phone aggressively restricts background apps by default, '
            'which can stop playback after a while. Allowing autostart and '
            'disabling battery optimization for this app fixes that - this '
            "opens your phone's own settings screen, not something the app "
            'can turn on by itself.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () async {
                await settings.put(_promptedKey, true);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
              child: const Text(
                'Not now',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                await settings.put(_promptedKey, true);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                await DisableBatteryOptimization.showDisableAllOptimizationsSettings(
                  'Allow autostart',
                  'Allow this app to start itself so music keeps playing in '
                      'the background.',
                  'Disable battery optimization',
                  'Prevent the system from stopping this app to save battery.',
                );
              },
              child: const Text(
                'Open settings',
                style: TextStyle(color: AppColors.accent),
              ),
            ),
          ],
        );
      },
    );
  }
}
