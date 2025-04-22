import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart'; // For date formatting
import 'package:bio_track/l10n/language_provider.dart';
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:bio_track/theme_provider.dart'; // Import ThemeProvider

// Define a Notification model for better structure
class AppNotification {
  final String id; // Unique ID for each notification
  final String titleKey;
  final String subtitleKey;
  final IconData icon;
  final Color color;
  bool isNew;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.titleKey,
    required this.subtitleKey,
    required this.icon,
    required this.color,
    this.isNew = true,
    required this.timestamp,
  });
}

// Convert to StatefulWidget
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _isLoading = true;
  List<AppNotification> _notifications = [];
  String? _error;

  // Simulated initial notifications list
  final List<AppNotification> _initialNotifications = [
    AppNotification(
      id: '1',
      titleKey: "new_measurement",
      subtitleKey: "health_data_updated",
      icon: Icons.health_and_safety,
      color: Colors.blueAccent,
      isNew: true,
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    AppNotification(
      id: '2',
      titleKey: "high_heart_rate",
      subtitleKey: "check_health_status",
      icon: Icons.favorite,
      color: Colors.redAccent,
      isNew: true,
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    AppNotification(
      id: '3',
      titleKey: "low_blood_sugar",
      subtitleKey: "have_proper_meal",
      icon: Icons.bloodtype,
      color: Colors.orangeAccent,
      isNew: false,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AppNotification(
      id: '4',
      titleKey: "water_reminder",
      subtitleKey: "drink_enough_water",
      icon: Icons.local_drink,
      color: Colors.cyan,
      isNew: false,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AppNotification(
      id: '5',
      titleKey: "daily_health_tip",
      subtitleKey: "walking_tip",
      icon: Icons.directions_walk,
      color: Colors.green,
      isNew: false,
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  // Simulate fetching notifications
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null; // Reset error on reload
    });

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    // In a real app, fetch from Firestore, API, etc.
    // Handle potential errors during fetch
    try {
      // Simulate success
      // Sort by timestamp descending (newest first)
      _initialNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      if (mounted) {
        setState(() {
          _notifications =
              List.from(_initialNotifications); // Create a mutable copy
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Failed to load notifications."; // Use localized string
          _isLoading = false;
        });
      }
    }
  }

  // Mark a notification as read
  void _markAsRead(String id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index].isNew = false;
        // In a real app, update the backend as well
      }
    });
  }

  // Handle tapping on a notification
  void _handleNotificationTap(AppNotification notification) {
    print("Tapped notification: ${notification.titleKey}");
    // Mark as read when tapped
    if (notification.isNew) {
      _markAsRead(notification.id);
    }
    // TODO: Implement navigation or action based on notification type
    // e.g., Navigator.push(context, MaterialPageRoute(builder: (_) => DetailsScreen(notificationId: notification.id)));
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context); // Use theme data
    final themeProvider =
        Provider.of<ThemeProvider>(context); // Access theme provider

    return Scaffold(
      // Use theme background color
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        // Use theme AppBar colors
        title: Text(
          localizations.translate("notifications"),
          style: TextStyle(color: theme.appBarTheme.foregroundColor),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: IconThemeData(color: theme.appBarTheme.foregroundColor),
        elevation: 2, // Consistent elevation
      ),
      body: RefreshIndicator(
        onRefresh: _loadNotifications, // Enable pull-to-refresh
        color: theme.primaryColor, // Use theme primary color for indicator
        child: _buildBody(localizations, theme),
      ),
    );
  }

  // Helper method to build the body content
  Widget _buildBody(AppLocalizations localizations, ThemeData theme) {
    if (_isLoading) {
      return Center(
          child: CircularProgressIndicator(color: theme.primaryColor));
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline,
                  color: theme.colorScheme.error, size: 50),
              const SizedBox(height: 16),
              Text(
                localizations.translate(
                    'error_loading_notifications'), // Use localized error message
                style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadNotifications,
                child: Text(localizations.translate('retry')),
              ),
            ],
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return _buildEmptyState(localizations, theme);
    }

    // Build the list view
    return ListView.builder(
      padding: const EdgeInsets.all(10),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _NotificationTile(
          notification: notification,
          localizations: localizations,
          theme: theme,
          onTap: () => _handleNotificationTap(notification),
        );
      },
    );
  }

  // Widget for the empty state
  Widget _buildEmptyState(AppLocalizations localizations, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 80,
            color: theme.disabledColor, // Use theme disabled color
          ),
          const SizedBox(height: 16),
          Text(
            localizations
                .translate('no_notifications_yet'), // Use localized string
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            localizations.translate(
                'new_notifications_appear_here'), // Use localized string
            style: TextStyle(
              fontSize: 16,
              color: theme.textTheme.bodyLarge?.color?.withOpacity(0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Separate widget for the notification list tile for better structure
class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final AppLocalizations localizations;
  final ThemeData theme;
  final VoidCallback onTap;

  const _NotificationTile({
    Key? key,
    required this.notification,
    required this.localizations,
    required this.theme,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Format the timestamp
    final String formattedTime =
        DateFormat('MMM d, hh:mm a').format(notification.timestamp);

    return Card(
      // Use theme card properties
      color: theme.cardColor,
      elevation: theme.cardTheme.elevation ?? 4,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: theme.cardTheme.shape ??
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              notification.color.withOpacity(0.2), // Softer background
          child: Icon(notification.icon, color: notification.color),
        ),
        title: Text(
          localizations.translate(notification.titleKey),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color, // Use theme text color
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations.translate(notification.subtitleKey),
              style: TextStyle(
                color: theme.textTheme.bodyMedium?.color
                    ?.withOpacity(0.8), // Use theme secondary text color
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formattedTime, // Display formatted time
              style: TextStyle(
                fontSize: 12,
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.6),
              ),
            ),
          ],
        ),
        trailing: notification.isNew
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color:
                      theme.primaryColor, // Use theme primary color for badge
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  localizations.translate("new"),
                  style: TextStyle(
                    color: theme
                        .colorScheme.onPrimary, // Use theme onPrimary color
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            : null,
        onTap: onTap, // Handle tap
      ),
    );
  }
}
