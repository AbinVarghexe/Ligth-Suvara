import 'package:flutter/material.dart';

/// Global navigator key used by [NotificationService] to push routes
/// (e.g., [NotificationsScreen]) without a [BuildContext].
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
