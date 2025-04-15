import 'package:flutter/material.dart';
// Import localization
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/language_provider.dart';

class FAQScreen extends StatelessWidget {
  // Get FAQ items with translations
  List<FAQSection> getFAQSections(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return [
      FAQSection(localizations.translate("general_questions"), [
        FAQItem(localizations.translate("what_is_biotrack"),
            localizations.translate("biotrack_description")),
        FAQItem(localizations.translate("who_can_use"),
            localizations.translate("who_can_use_answer")),
      ]),
      FAQSection(localizations.translate("features"), [
        FAQItem(localizations.translate("what_vital_signs"),
            localizations.translate("vital_signs_answer")),
        FAQItem(localizations.translate("how_measure_glucose"),
            localizations.translate("glucose_measurement_answer")),
      ]),
      FAQSection(localizations.translate("usage"), [
        FAQItem(localizations.translate("how_setup"),
            localizations.translate("setup_answer")),
        FAQItem(localizations.translate("use_without_smartphone"),
            localizations.translate("without_smartphone_answer")),
      ]),
      FAQSection(localizations.translate("troubleshooting"), [
        FAQItem(localizations.translate("why_inaccurate"),
            localizations.translate("inaccurate_answer")),
        FAQItem(localizations.translate("not_connecting"),
            localizations.translate("not_connecting_answer")),
      ]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final faqSections = getFAQSections(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          localizations.translate("faq"),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color.fromARGB(255, 3, 131, 194),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children:
              faqSections.map((section) => buildFAQSection(section)).toList(),
        ),
      ),
    );
  }

  // Widget to build a section of FAQ
  Widget buildFAQSection(FAQSection section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          section.title,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Divider(), // Divider between sections
        ...section.items.map((item) => buildFAQItem(item)).toList(),
        SizedBox(height: 20), // Space between sections
      ],
    );
  }

  // Widget to create each FAQ item with an expandable answer
  Widget buildFAQItem(FAQItem item) {
    return ExpansionTile(
      title: Text(item.question,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(item.answer,
              style: TextStyle(fontSize: 16, color: Colors.grey[700])),
        ),
      ],
    );
  }
}

// Model to hold FAQ section
class FAQSection {
  final String title;
  final List<FAQItem> items;

  FAQSection(this.title, this.items);
}

// Model to hold FAQ question and answer
class FAQItem {
  final String question;
  final String answer;

  FAQItem(this.question, this.answer);
}
