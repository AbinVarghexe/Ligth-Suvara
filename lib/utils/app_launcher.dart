import 'package:flutter/material.dart';
import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openYamaprarthanakalApp(BuildContext context) async {
  // Package name for Yama Prarthanakal app
  // IMPORTANT: Verify this matches the actual package name in Play Store
  // You can check by looking at the Play Store URL: https://play.google.com/store/apps/details?id=PACKAGE_NAME
  const packageName = 'org.praarthana.syromalabaryaamapraarthanakal';
  const playStoreUrl = 'https://play.google.com/store/apps/details?id=$packageName';

  debugPrint('=== Opening Yama Prarthanakal App ===');
  debugPrint('Package name: $packageName');

  // Step 1: Always try to open the app first (most reliable)
  // This works even if isAppInstalled() gives false negatives due to Android 11+ package visibility
  try {
    debugPrint('Attempting to launch app...');
    await LaunchApp.openApp(
      androidPackageName: packageName,
    );
    debugPrint('✓ LaunchApp.openApp() completed without error');
    // If we reach here without exception, the launch was attempted
    // On Android, if the app is installed, it should open
    // If it's not installed, Android might show Play Store automatically
    // We'll verify installation status below to handle edge cases
  } catch (launchError) {
    debugPrint('✗ LaunchApp.openApp() failed with error: $launchError');
    // Launch failed - likely app is not installed
    // Check installation status to confirm before redirecting
  }

  // Step 2: Verify installation status to make informed decision
  // This helps us determine if we should redirect to Play Store
  bool? isInstalled;
  try {
    isInstalled = await LaunchApp.isAppInstalled(
      androidPackageName: packageName,
    );
    debugPrint('Installation check result: ${isInstalled == true ? "INSTALLED" : isInstalled == false ? "NOT INSTALLED" : "UNKNOWN"}');
  } catch (checkError) {
    debugPrint('✗ Could not check installation: $checkError');
    isInstalled = null;
  }

  // Step 3: Make decision based on results
  // Only redirect to Play Store if we're confident the app is NOT installed
  if (isInstalled == false) {
    // App is definitely not installed - redirect to Play Store
    debugPrint('App is not installed. Opening Play Store...');
    try {
      final Uri uri = Uri.parse(playStoreUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        debugPrint('✓ Play Store opened');
      } else {
        debugPrint('✗ Could not launch Play Store URL');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Could not open Play Store."),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (playStoreError) {
      debugPrint('✗ Error opening Play Store: $playStoreError');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $playStoreError"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } else if (isInstalled == true) {
    // App is installed - launch should have worked
    // If it didn't, it's likely a different issue (permissions, app state, etc.)
    debugPrint('✓ App is installed. Launch should have succeeded.');
    // No action needed - app should have opened or user will see it in recent apps
  } else {
    // Could not determine installation status
    // Don't redirect to Play Store to avoid false redirects
    // The launch attempt above should have worked if app is installed
    debugPrint('? Installation status unknown. Launch was attempted - assuming it worked if app is installed.');
  }

  debugPrint('=== End of app launch attempt ===');
}
