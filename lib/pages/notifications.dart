import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/language_provider.dart';
import 'package:bio_track/l10n/app_localizations.dart';

class NotificationsScreen extends StatelessWidget {
  NotificationsScreen({Key? key}) : super(key: key);

  // Notifications list (example)
  final List<Map<String, dynamic>> notifications = [
    {
      "titleKey": "new_measurement",
      "subtitleKey": "health_data_updated",
      "icon": Icons.health_and_safety,
      "color": Colors.blueAccent,
      "isNew": true,
    },
    {
      "titleKey": "high_heart_rate",
      "subtitleKey": "check_health_status",
      "icon": Icons.favorite,
      "color": Colors.redAccent,
      "isNew": true,
    },
    {
      "titleKey": "low_blood_sugar",
      "subtitleKey": "have_proper_meal",
      "icon": Icons.bloodtype,
      "color": Colors.orangeAccent,
      "isNew": false,
    },
    {
      "titleKey": "water_reminder",
      "subtitleKey": "drink_enough_water",
      "icon": Icons.local_drink,
      "color": Colors.cyan,
      "isNew": false,
    },
    {
      "titleKey": "daily_health_tip",
      "subtitleKey": "walking_tip",
      "icon": Icons.directions_walk,
      "color": Colors.green,
      "isNew": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          localizations.translate("notifications"),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0XFF0383c2),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return Card(
            elevation: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: notification["color"],
                child: Icon(notification["icon"], color: Colors.white),
              ),
              title: Text(
                localizations.translate(notification["titleKey"]),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle:
                  Text(localizations.translate(notification["subtitleKey"])),
              trailing: notification["isNew"]
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        localizations.translate("new"),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
