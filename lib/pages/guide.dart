import 'package:flutter/material.dart';
import 'package:bio_track/StartTest.dart';
// Import localization
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/language_provider.dart';

class InstructionsScreen extends StatefulWidget {
  @override
  _InstructionsScreenState createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  int _currentStep = 0;

  List<Map<String, String>> _getSteps(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return [
      {
        "title": localizations.translate("preparation_title"),
        "description": localizations.translate("preparation_description")
      },
      {
        "title": localizations.translate("body_preparation_title"),
        "description": localizations.translate("body_preparation_description")
      },
      {
        "title": localizations.translate("foot_placement_title"),
        "description": localizations.translate("foot_placement_description")
      },
      {
        "title": localizations.translate("hand_placement_title"),
        "description": localizations.translate("hand_placement_description")
      },
      {
        "title": localizations.translate("during_measurement_title"),
        "description": localizations.translate("during_measurement_description")
      },
      {
        "title": localizations.translate("after_measurement_title"),
        "description": localizations.translate("after_measurement_description")
      },
    ];
  }

  void _nextStep() {
    setState(() {
      if (_currentStep < _getSteps(context).length - 1) {
        _currentStep++;
      } else {
        Navigator.pop(context);
      }
    });
  }

  void _startTest() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => HealthSummaryScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;
    final steps = _getSteps(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          localizations.translate("user_guide"),
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Color(0XFF0383c2),
        elevation: 2,
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.blue,
              child: Text(
                "${_currentStep + 1}",
                style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            SizedBox(height: 20),
            Text(
              steps[_currentStep]["title"]!,
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900]),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 10),
            Text(
              steps[_currentStep]["description"]!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
            ),
            SizedBox(height: 30),

            // Next/Finish button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0XFF0383c2),
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 5,
              ),
              onPressed: _nextStep,
              child: Text(
                _currentStep == steps.length - 1
                    ? localizations.translate("finish")
                    : localizations.translate("next"),
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

            SizedBox(height: 20),

            // OR word in elegant styling
            Text(
              localizations.translate("or"),
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600]),
            ),

            SizedBox(height: 20),

            // "Let's Start Test" button
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: Color(0XFF0383c2), width: 2),
                ),
                backgroundColor: Colors.white,
                elevation: 3,
              ),
              onPressed: _startTest,
              child: Text(
                localizations.translate("lets_start_test"),
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0XFF0383c2)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
