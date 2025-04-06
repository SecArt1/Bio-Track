import 'package:flutter/material.dart';

class FAQScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Frequently Asked Questions",
        style: TextStyle(color: Colors.white),),
        backgroundColor: Color.fromARGB(255, 3, 131, 194),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildFAQSection("General Questions", [
              FAQItem("What is BioTrack?", "BioTrack is an integrated vital signs monitoring system that measures body composition, heart rate, blood glucose, body temperature, and plantar pressure."),
              FAQItem("Who can use BioTrack?", "Anyone interested in tracking their health metrics, including fitness enthusiasts, medical patients, and general users."),
            ]),

            buildFAQSection("Features", [
              FAQItem("What vital signs does BioTrack monitor?", "BioTrack monitors body composition (InBody metrics), heart rate, blood glucose, body temperature, and plantar pressure."),
              FAQItem("How does BioTrack measure blood glucose?", "BioTrack uses the MAX30102 sensor to estimate blood glucose levels through non-invasive techniques."),
            ]),

            buildFAQSection("Usage", [
              FAQItem("How do I set up BioTrack?", "Simply connect BioTrack to the mobile app, follow the on-screen instructions, and place your hands and feet on the device to start measuring."),
              FAQItem("Can I use BioTrack without a smartphone?", "BioTrack is designed to work best with the mobile app, but some basic readings may be available on the device's screen."),
            ]),

            buildFAQSection("Troubleshooting", [
              FAQItem("Why is my measurement inaccurate?", "Ensure proper contact with sensors, clean the device, and avoid movement during measurement."),
              FAQItem("What should I do if BioTrack is not connecting to the app?", "Check Bluetooth settings, restart the device, and ensure the app is updated to the latest version."),
            ]),
          ],
        ),
      ),
    );
  }

  // Widget to build a section of FAQ
  Widget buildFAQSection(String sectionTitle, List<FAQItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionTitle,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Divider(), // خط فاصل بين الأقسام
        ...items.map((item) => buildFAQItem(item)).toList(),
        SizedBox(height: 20), // مسافة بين الأقسام
      ],
    );
  }

  // Widget to create each FAQ item with an expandable answer
  Widget buildFAQItem(FAQItem item) {
    return ExpansionTile(
      title: Text(item.question, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(item.answer, style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        ),
      ],
    );
  }
}

// Model to hold FAQ question and answer
class FAQItem {
  final String question;
  final String answer;

  FAQItem(this.question, this.answer);
}