import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/stillStart.dart';
import 'package:bio_track/logInPage.dart';
class RegisterPage extends StatelessWidget {
  RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Padding(
        padding: const EdgeInsets.all(0.0),
        child: Column(
          
          children: [
            // First Container wrapping the top third section
            Flexible(
              flex: 1,
              child: Container(
                decoration: const BoxDecoration(
                  color: Color.fromARGB(255, 3, 131, 194),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40.0),
                    bottomRight: Radius.circular(40.0),
                  )
                ),
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 20.0),
                child: const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: "Let's ",
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 35.0,
                        ),
                      ),
                      TextSpan(
                        text: "\nCreate \nYour \nAccount",
                        style: TextStyle(
                          color: Color.fromARGB(255, 255, 255, 255),
                          fontSize: 35.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Second Container wrapping the remaining two-thirds section
            Flexible(
              
              flex: 2,
              child: Container(
                color: Colors.white,
              
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  
                  children: [
                    const SizedBox(height: 20),
                    TextField(
                      decoration: InputDecoration(
                        fillColor: const Color.fromARGB(255, 3, 131, 194),
                        iconColor: const Color.fromARGB(255, 3, 131, 194),
                        labelText: 'Full Name',
                        labelStyle: const TextStyle(
                          color: Color.fromARGB(255, 95, 127, 154),
                        ),
                        prefixIcon: const Icon(Icons.person),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 3, 131, 194),
                            width: 2.0,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        fillColor: const Color.fromARGB(255, 3, 131, 194),
                        iconColor: const Color.fromARGB(255, 3, 131, 194),
                        labelText: 'Email',
                        labelStyle: const TextStyle(
                          color: Color.fromARGB(255, 95, 127, 154),
                        ),
                        prefixIcon: const Icon(Icons.mail),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 3, 131, 194),
                            width: 2.0,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        fillColor: const Color.fromARGB(255, 3, 131, 194),
                        iconColor: const Color.fromARGB(255, 3, 131, 194),
                        labelText: 'Password',
                        labelStyle: const TextStyle(
                          color: Color.fromARGB(255, 95, 127, 154),
                        ),
                        prefixIcon: const Icon(Icons.lock),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 3, 131, 194),
                            width: 2.0,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194)),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      decoration: InputDecoration(
                        fillColor: const Color.fromARGB(255, 3, 131, 194),
                        iconColor: const Color.fromARGB(255, 3, 131, 194),
                        labelText: 'Retype Password',
                        labelStyle: const TextStyle(
                          color: Color.fromARGB(255, 95, 127, 154),
                        ),
                        prefixIcon: const Icon(Icons.person),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                            color: Color.fromARGB(255, 3, 131, 194),
                            width: 2.0,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30.0),
                          borderSide: const BorderSide(
                              color: Color.fromARGB(255, 3, 131, 194)),
                        ),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: false,
                          onChanged: (bool? value) {},
                          activeColor: const Color.fromARGB(255, 6, 106, 222),
                        ),
                        const Text(
                          'I agree to the Terms & Privacy',
                          style: TextStyle(
                            color: Color.fromARGB(255, 70, 108, 139),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle create account
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 2, 109, 162),
                          minimumSize: const Size(300, 50),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20.0),
                            side: const BorderSide(
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        ),
                        child: const Text(
                          'Sign up',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: (){
                          Navigator.push( context, MaterialPageRoute(builder: (context) => HomePage()), );
                        },
                        child: const Text(
                          'Have an account? Sign In',
                          style: TextStyle(
                            color: Color.fromARGB(255, 70, 108, 139),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
