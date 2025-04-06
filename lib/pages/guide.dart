
import 'package:flutter/material.dart';
import 'package:bio_track/StartTest.dart';

class InstructionsScreen extends StatefulWidget {
  @override
  _InstructionsScreenState createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  int _currentStep = 0;

  final List<Map<String, String>> _steps = [
    {
      "title": "Preparation",
      "description": "Ensure the device is turned on and fully charged."
    },
    {
      "title": "Body Preparation",
      "description": "Clean your hands and feet to remove dirt or lotions."
    },
    {
      "title": "Foot Placement",
      "description": "Step onto the scale barefoot and ensure full contact with the sensors."
    },
    {
      "title": "Hand Placement",
      "description": "Hold the hand grips firmly, ensuring proper contact with the electrodes."
    },
    {
      "title": "During Measurement",
      "description": "Stay still and wait until all measurements are successfully recorded."
    },
    {
      "title": "After Measurement",
      "description": "Review your data and clean the device if necessary."
    },
  ];

  void _nextStep() {
    setState(() {
      if (_currentStep < _steps.length - 1) {
        _currentStep++;
      } else {
        Navigator.pop(context);
      }
    });
  }

  void _startTest() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => HealthSummaryScreen()), // انتقل إلى الشاشة الجديدة
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("User Guide",
        style: TextStyle(color: Colors.white),),
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
                style: TextStyle(fontSize: 30,
                    fontWeight: FontWeight.bold,
                    color: Colors.white),
              ),
            ),
            SizedBox(height: 20),
            Text(
              _steps[_currentStep]["title"]!,
              style: TextStyle(fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900]),
            ),
            SizedBox(height: 10),
            Text(
              _steps[_currentStep]["description"]!,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, color: Colors.grey[800]),
            ),
            SizedBox(height: 30),

            // زر Next/Finish
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
                _currentStep == _steps.length - 1 ? "Finish" : "Next",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),

            SizedBox(height: 20),

            // كلمة OR بشكل أنيق
            Text(
              "or",
              style: TextStyle(fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[600]),
            ),

            SizedBox(height: 20),

            // زر "Let's Start Test"
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: Color(0XFF0383c2), width: 2), // إطار أزرق
                ),
                backgroundColor: Colors.white, // خلفية بيضاء
                elevation: 3,
              ),
              onPressed: _startTest,
              child: Text(
                "Let's Start Test",
                style: TextStyle(fontSize: 18,
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