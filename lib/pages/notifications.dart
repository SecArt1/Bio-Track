import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  // Notifications list (example)
  final List<Map<String, dynamic>> notifications = [
    {
      "title": "New Measurement Recorded",
      "subtitle": "Your health data has been updated. Check details.",
      "icon": Icons.health_and_safety,
      "color": Colors.blueAccent,
      "isNew": true,
    },
    {
      "title": "High Heart Rate Detected",
      "subtitle": "Please check your health status.",
      "icon": Icons.favorite,
      "color": Colors.redAccent,
      "isNew": true,
    },
    {
      "title": "Low Blood Sugar Alert",
      "subtitle": "Make sure to have a proper meal.",
      "icon": Icons.bloodtype,
      "color": Colors.orangeAccent,
      "isNew": false,
    },
    {
      "title": "Water Reminder",
      "subtitle": "Did you drink enough water today?",
      "icon": Icons.local_drink,
      "color": Colors.cyan,
      "isNew": false,
    },
    {
      "title": "Daily Health Tip",
      "subtitle": "Walking for 30 minutes daily improves heart health.",
      "icon": Icons.directions_walk,
      "color": Colors.green,
      "isNew": false,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Notifications",
        style:
          TextStyle(
            color: Colors.white
          ),),
        backgroundColor: Color(0XFF0383c2),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(10),
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          final notification = notifications[index];
          return Card(
            elevation: 4,
            margin: EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: notification["color"],
                child: Icon(notification["icon"], color: Colors.white),
              ),
              title: Text(
                notification["title"],
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(notification["subtitle"]),
              trailing: notification["isNew"]
                  ? Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "NEW",
                  style: TextStyle(color: Colors.white, fontSize: 12),
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