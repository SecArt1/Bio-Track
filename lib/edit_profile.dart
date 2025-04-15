import 'package:flutter/material.dart';
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/language_provider.dart';

class EditProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 255, 255, 255),

      /////////////////////// PART 1 ///////////////////////

      //AppBar with Title
      appBar: AppBar(
        title: Text(
          localizations.translate("edit_profile"),
          style: const TextStyle(
            color: Color(0xff0383c2),
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
      ),

      /////////////////////// PART 2 ///////////////////////
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              /////////////////////////////// Profile Avatar ///////////////////////////////
              const Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundImage: AssetImage('assets/Dr. Amira.jpg'),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: CircleAvatar(
                        backgroundColor: Color(0XFF0383c2),
                        radius: 18,
                        child: Icon(Icons.edit, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              ////////////////////////////////// Filed ////////////////////////////////
              const SizedBox(height: 50),

              // Name Field (First Field)
              SizedBox(
                width: 400,
                height: 80,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: localizations.translate("name"),
                    labelStyle: const TextStyle(
                      color: Color.fromARGB(255, 95, 127, 154),
                    ),
                    prefixIcon: const Icon(Icons.person_rounded),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 3, 131, 194),
                      ),
                    ),
                  ),
                ),
              ),

              // Gender Selection (Male/Female)
              const SizedBox(height: 6),
              SizedBox(
                width: 400,
                height: 60,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: localizations.translate("gender"),
                    labelStyle: const TextStyle(
                      color: Color.fromARGB(255, 95, 127, 154),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 3, 131, 194),
                      ),
                    ),
                  ),
                  child: DropdownButton<String>(
                    isExpanded: true,
                    hint: Text(localizations.translate("gender")),
                    value:
                        null, // Add a variable here to manage the selected value
                    items: [
                      DropdownMenuItem<String>(
                        value: 'Male',
                        child: Text(localizations.translate("male")),
                      ),
                      DropdownMenuItem<String>(
                        value: 'Female',
                        child: Text(localizations.translate("female")),
                      ),
                    ],
                    onChanged: (value) {
                      // Add your gender selection logic here
                    },
                  ),
                ),
              ),

              // Add space between Gender and Date of Birth
              const SizedBox(height: 20),

              // Date of Birth
              SizedBox(
                width: 400,
                height: 80,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: localizations.translate("date_of_birth"),
                    labelStyle: const TextStyle(
                      color: Color.fromARGB(255, 95, 127, 154),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 3, 131, 194),
                      ),
                    ),
                  ),
                  readOnly: true, // Set to true for date selection
                  onTap: () async {
                    DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    // If you wish, you can update the field with the selected date.
                  },
                ),
              ),

              // Height
              SizedBox(
                width: 400,
                height: 80,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: localizations.translate("height"),
                    labelStyle: const TextStyle(
                      color: Color.fromARGB(255, 95, 127, 154),
                    ),
                    prefixIcon: const Icon(Icons.height),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 3, 131, 194),
                      ),
                    ),
                  ),
                ),
              ),

              /////////////////////////////// Other Fields ///////////////////////////////
              SizedBox(
                width: 400,
                height: 80,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: localizations.translate("phone"),
                    labelStyle: const TextStyle(
                      color: Color.fromARGB(255, 95, 127, 154),
                    ),
                    prefixIcon: const Icon(Icons.phone_rounded),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 3, 131, 194),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(
                width: 400,
                height: 80,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: localizations.translate("email"),
                    labelStyle: const TextStyle(
                      color: Color.fromARGB(255, 95, 127, 154),
                    ),
                    prefixIcon: const Icon(Icons.mail_rounded),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 3, 131, 194),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(
                width: 400,
                height: 80,
                child: TextField(
                  decoration: InputDecoration(
                    labelText: localizations.translate("password"),
                    labelStyle: const TextStyle(
                      color: Color.fromARGB(255, 95, 127, 154),
                    ),
                    prefixIcon: const Icon(Icons.lock),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30.0),
                      borderSide: const BorderSide(
                        color: Color.fromARGB(255, 3, 131, 194),
                      ),
                    ),
                  ),
                ),
              ),

              /////////////////////////////// Buttons ///////////////////////////////
              const SizedBox(height: 60),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(3, 131, 194, 1),
                        minimumSize: const Size(100, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          side: const BorderSide(
                            color: Color.fromRGBO(180, 180, 181, 0.3),
                          ),
                        ),
                      ),
                      child: Text(
                        localizations.translate("save"),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromRGBO(3, 131, 194, 1),
                        minimumSize: const Size(100, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20.0),
                          side: const BorderSide(
                            color: Color.fromRGBO(180, 180, 181, 0.3),
                          ),
                        ),
                      ),
                      child: Text(
                        localizations.translate("clear"),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
