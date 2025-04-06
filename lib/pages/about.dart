import 'package:flutter/material.dart';

class AboutPage extends StatelessWidget {
  final List<Map<String, String>> teamMembers = [
    {
      "name": "Dr. Amira El-sonbaty",
      "email": "dr_eng.amira@yahoo.com",
      "image": "assets/Dr. Amira.jpg"
    },
    {
      "name": "Aya Aymen Mansour Elsalamony",
      "email": "ayaaaayman21@gmail.com",
      "image": "assets/Aya Aymen .jpg"
    },
    {
      "name": "Aya Abbas Mohamed Abbas",
      "email": "ayaayaabbas2002@gmail.com",
      "image": "assets/Aya Abbas .jpg"
    },
    {
      "name": "Tuqa Elsaeed Ibrahim Elsaeed",
      "email": "ttuqqa2@gmail.com",
      "image": "assets/Tuqa Elsaeed .jpg"
    },
    {
      "name": "Haneen Mohamed Siyaam",
      "email": "haneensiyaam20@gmail.com",
      "image": "assets/Haneen Siyaam .jpg"
    },
    {
      "name": "AbdELRhman Elsayed Ali Hefny",
      "email": "abdohefny27@gmail.com",
      "image": "assets/AbdELRhman Hefny .jpg"
    },
    {
      "name": "Abdelrahman Elsayed Mohamed Hamouda",
      "email": "abdelrahman.hamouda29@gmail.com",
      "image": "assets/Abdelrahman Hamouda.jpg"
    },
    {
      "name": "Abdelrahman Fawzy Abdelrahman Mohamed",
      "email": "abdelrahmanfawzy310@gmail.com",
      "image": "assets/Abdelrahman Fawzy .jpg"
    },
    {
      "name": "Mohamed Sabry Elsaadwi",
      "email": "s00659680@gmail.com",
      "image": "assets/Mohamed Sabry.jpg"
    },
    {
      "name": "Mohamed Abdelnaser Ibrahim Elawady",
      "email": "mohamedelawady1@proton.me",
      "image": "assets/Mohamed Elawady .jpg"
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("About us",
        style:
          TextStyle(color: Colors.white),),
        backgroundColor: Color(0xff0383c2),
      ),
      body: Column(
        children: [

          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "BioTrack is an advanced health monitoring system that measures vital signs such as body composition, heart rate, blood glucose, and temperature, focusing on lower limb health. It provides accurate insights through a user-friendly mobile application.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),


          Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Team Members",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),


          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              itemCount: teamMembers.length,
              itemBuilder: (context, index) {
                return buildTeamMember(
                  teamMembers[index]["name"]!,
                  teamMembers[index]["email"]!,
                  teamMembers[index]["image"]!,
                );
              },
            ),
          ),
        ],
      ),
    );
  }


  Widget buildTeamMember(String name, String email, String imagePath) {
    return Card(
      elevation: 2,
      margin: EdgeInsets.symmetric(vertical: 5),
      child: ListTile(
        leading: CircleAvatar(
          radius: 25,
          backgroundImage: AssetImage(imagePath),
          backgroundColor: Colors.grey[300],
        ),
        title: Text(name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500)),
        subtitle: Text(email, style: TextStyle(color: Colors.blue)),
      ),
    );
  }

}