import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/register.dart';
import 'package:bio_track/stillStart.dart';
import 'package:bio_track/logInPage.dart';

class ForgotPassword extends StatelessWidget {
  const ForgotPassword({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Padding(
              padding: const EdgeInsets.all(0.0),
              child: Container(
                height: 200,
                width: double.infinity,
                color: Colors.white,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 70),
                    Image.asset(
                      'assets/Lock.jpg',
                      width: 150,
                    ),

                    
               const SizedBox(height: 20),
                  const Text(
                    'Forgot',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0XFF0383c2),
                    decorationColor: Color(0XFF0383c2),
                    fontSize: 45,
                    fontWeight:FontWeight.bold,
                    ),
                  ),

                const SizedBox(height: 0),
                  const Text(
                    'Password?',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0XFF0383c2),
                    decorationColor: Color(0XFF0383c2),
                    fontSize: 45,
                    ),
                  ),

             const SizedBox(height: 40),
                  const Text(
                    'No worries, we\'ll send you \n reset instruction',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0XFF0383c2),
                    decorationColor: Color(0XFF0383c2),
                    fontSize: 17,
                    ),
                  ),

                  ],
                ),
              ),
            ),
          ),

          Expanded(
            flex: 2,
            child: Container(
              decoration: const BoxDecoration(
                color: Color.fromARGB(255, 3, 131, 194),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40.0),
                  topRight: Radius.circular(40.0),
                ),
              ),
              width: double.infinity,
              child:
               Column(
                children: [
                  
                  // const SizedBox(height: 20),
                  // TextButton(
                  //   onPressed: () {
                  //     // Handle email
                  //   },
                  //   child: const Text('Email',
                  //       textAlign: TextAlign.left,
                  //       style: TextStyle(color: Colors.white,

                  //       fontSize: 12,
                  //       )
                  //       ),
                  // ),


                   const SizedBox(height: 85),
                    SizedBox(
                      width: 300,
                      height: 50,
                      child: 

                      TextField(
                        decoration: InputDecoration(
                          fillColor: const Color.fromARGB(255, 255, 255, 255),
                          iconColor: const Color.fromARGB(255, 255, 255, 255),
                          labelText: '  Enter Your Email',

                          labelStyle: 
                          const TextStyle( 
                            fontSize: 17,
                            color: Color.fromARGB(255, 255, 255, 255),
                          ),
                          
                          prefixIcon: const Icon(Icons.mail,
                          color: Color.fromARGB(255, 255, 255, 255),),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(35.0),
                            borderSide: const BorderSide(
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                          
                        ),
                      ),
                    ),

                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      // Handle login
                    },
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(300, 50),
                      backgroundColor: const Color.fromARGB(255, 255, 255, 255),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.0),
                      ),
                    ),
                    child: const Text(
                      'Reset Password',
                      style: TextStyle(
                        color: Color.fromARGB(255, 2, 113, 169),
                        fontSize: 17,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                  TextButton(
                        onPressed: (){
                          Navigator.push( context, MaterialPageRoute(builder: (context) => HomePage()), );
                        },
                        child: const Text(
                          'Back to Login',
                          style: TextStyle(
                            color: Color.fromARGB(255, 255, 255, 255),
                            fontSize: 22,
                          ),
                        ),
                      ),
                  const SizedBox(height: 25),
                   const SizedBox(
                      height: 10,
                      width: 10,
                      child: TextField(
                        decoration: 
                           InputDecoration(
                           prefixIcon: const Icon(
                              Icons.arrow_back_outlined,
                              color: Color.fromARGB(255, 255, 255, 255),
                            ),
                          ),
                        ),
                      ),

                  //const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );

  }
}
