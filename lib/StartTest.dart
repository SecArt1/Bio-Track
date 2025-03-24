import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:bio_track/edit_profile.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({Key? key}) : super(key: key);

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Top Section taking one-third of the screen
          Padding(
            padding: const EdgeInsets.all(0),
            child: Column(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Color.fromARGB(255, 5, 138, 214),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      const SizedBox(
                        height: 40,
                      ),
                      Container(
                        color: const Color.fromARGB(255, 5, 138, 214),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'BioTrack',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold),
                                ),
                                Row(
                                  children: [
                                    TextButton(
                                      onPressed: () {
                                        // Handle Amira button press
                                        Navigator.push( context, MaterialPageRoute(builder: (context) => EditProfilePage()), );
                                      },
                                      style: TextButton.styleFrom(
                                        side: const BorderSide(
                                            color: Color.fromARGB(
                                                207, 207, 208, 212),
                                            width: 1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(50),
                                        ),
                                      ),
                                      child: const Text(
                                        'Amira',
                                        style: TextStyle(
                                            fontSize: 14,
                                            color: Color.fromARGB(
                                                255, 255, 255, 255)),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    const Icon(Icons.notifications, size: 24),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 10), // Adjusted spacing
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(1))),
                                  onPressed: () {
                                    // Handle Dashboard button press
                                    print('Dashboard button pressed');
                                  },
                                  child: const Text(
                                    'Dashboard',
                                    style: TextStyle(
                                        color:
                                            Color.fromARGB(255, 255, 255, 255),
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Handle Detail button press
                                    print('Detail button pressed');
                                  },
                                  child: const Text(
                                    'Detail',
                                    style: TextStyle(
                                        color:
                                            Color.fromARGB(207, 207, 208, 212),
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Handle History button press
                                    print('History button pressed');
                                  },
                                  child: const Text(
                                    'History',
                                    style: TextStyle(
                                        color:
                                            Color.fromARGB(207, 207, 208, 212),
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () {
                                    // Handle Ranking button press
                                    print('Ranking button pressed');
                                  },
                                  child: const Text(
                                    'Ranking',
                                    style: TextStyle(
                                        color:
                                            Color.fromARGB(207, 207, 208, 212),
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Bottom Section taking two-thirds of the screen
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(15.0),
              child: Column(
                children: [
                  const SizedBox(
                    height: 10,
                  ),
                  Container(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      "BioTrack Test Summary",
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Summary Cards
                      InkWell(
                        onTap: () {
                          // Handle Weight card press
                          print('Weight card pressed');
                        },
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color:
                                      const Color.fromARGB(255, 118, 131, 149),
                                  width: 3),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(0.0),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  const Text(
                                    'Weight Kg',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(255, 160, 175, 187),
                                      fontSize: 18,
                                    ),
                                  ),
                                  const Text('96.7',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 0, 0, 0),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      )),
                                  SizedBox(
                                    width: 70,
                                    height: 20,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: const Color.fromARGB(
                                            255, 191, 23, 46),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                      onPressed: () {},
                                      child: const Text(
                                        "above avg",
                                        style: TextStyle(fontSize: 10),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          // Handle Skeletal Muscle Mass card press
                          print('Skeletal Muscle Mass card pressed');
                        },
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color:
                                      const Color.fromARGB(255, 118, 131, 149),
                                  width: 3),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(0.0),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  const Text(
                                    'Muscle Mass',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(255, 185, 195, 203),
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Text('30.1',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 0, 0, 0),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      )),
                                  SizedBox(
                                    width: 70,
                                    height: 20,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: const Color.fromARGB(
                                            255, 191, 23, 46),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                      onPressed: () {},
                                      child: const Text(
                                        "above avg",
                                        style: TextStyle(fontSize: 10),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          // Handle Percent Body Fat card press
                          print('Percent Body Fat card pressed');
                        },
                        child: SizedBox(
                          width: 120,
                          height: 120,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                  color:
                                      const Color.fromARGB(255, 109, 123, 143),
                                  width: 3),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(0.0),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  const Text(
                                    'Body Fat %',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color.fromARGB(255, 185, 195, 203),
                                      fontSize: 18,
                                    ),
                                  ),
                                  const Text('16.8',
                                      style: TextStyle(
                                        color: Color.fromARGB(255, 0, 0, 0),
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      )),
                                  SizedBox(
                                    width: 70,
                                    height: 20,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        foregroundColor: Colors.white,
                                        backgroundColor: const Color.fromARGB(
                                            255, 14, 167, 47),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                      ),
                                      onPressed: () {},
                                      child: const Text(
                                        "avg",
                                        style: TextStyle(fontSize: 11),
                                        textAlign: TextAlign.left,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Add the graph here
                  Expanded(
                    child: ListView(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Summary Cards
                            InkWell(
                              onTap: () {
                                // Handle Weight card press
                                print('Weight card pressed');
                              },
                              child: SizedBox(
                                width: 120,
                                height: 120,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                        color: const Color.fromARGB(
                                            255, 118, 131, 149),
                                        width: 3),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(0.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        const Text(
                                          'B_Pressure',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 160, 175, 187),
                                            fontSize: 18,
                                          ),
                                        ),
                                        const Text('96.7/40',
                                            style: TextStyle(
                                              color:
                                                  Color.fromARGB(255, 0, 0, 0),
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            )),
                                        SizedBox(
                                          width: 70,
                                          height: 20,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                      255, 191, 23, 46),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                            ),
                                            onPressed: () {},
                                            child: const Text(
                                              "LOW",
                                              style: TextStyle(fontSize: 10),
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                // Handle Skeletal Muscle Mass card press
                                print('Skeletal Muscle Mass card pressed');
                              },
                              child: SizedBox(
                                width: 120,
                                height: 120,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                        color: const Color.fromARGB(
                                            255, 118, 131, 149),
                                        width: 3),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(0.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        const Text(
                                          'Suger Level',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 185, 195, 203),
                                            fontSize: 18,
                                          ),
                                        ),
                                        const Text('120.1 mg/dl',
                                            style: TextStyle(
                                              color:
                                                  Color.fromARGB(255, 0, 0, 0),
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                            )),
                                        SizedBox(
                                          width: 70,
                                          height: 20,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                      255, 14, 167, 47),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                            ),
                                            onPressed: () {},
                                            child: const Text(
                                              "avg",
                                              style: TextStyle(fontSize: 10),
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                // Handle Percent Body Fat card press
                                print('Percent Body Fat card pressed');
                              },
                              child: SizedBox(
                                width: 120,
                                height: 120,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(
                                        color: const Color.fromARGB(
                                            255, 109, 123, 143),
                                        width: 3),
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(0.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        const Text(
                                          'Temperature',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Color.fromARGB(
                                                255, 185, 195, 203),
                                            fontSize: 15,
                                          ),
                                        ),
                                        const Text('36.8 C',  
                                            style: TextStyle(
                                              color:
                                                  Color.fromARGB(255, 0, 0, 0),
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            )),
                                        SizedBox(
                                          width: 70,
                                          height: 20,
                                          child: ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              foregroundColor: Colors.white,
                                              backgroundColor:
                                                  const Color.fromARGB(
                                                      255, 14, 167, 47),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                              ),
                                            ),
                                            onPressed: () {},
                                            child: const Text(
                                              "avg",
                                              style: TextStyle(fontSize: 11),
                                              textAlign: TextAlign.left,
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SfCartesianChart(
                            primaryXAxis: NumericAxis(),
                            primaryYAxis: NumericAxis(),
                            series: <CartesianSeries>[
                              SplineSeries<ChartData, double>(
                                dataSource: [
                                  ChartData(0, 70),
                                  ChartData(1, 75),
                                  ChartData(2, 80),
                                  ChartData(3, 78),
                                  ChartData(4, 85),
                                  ChartData(5, 90),
                                  ChartData(6, 88),
                                  ChartData(7, 92),
                                  ChartData(8, 87),
                                  ChartData(15, 85),
                                ],
                                xValueMapper: (ChartData data, _) => data.x,
                                yValueMapper: (ChartData data, _) => data.y,
                                color: const Color.fromARGB(55, 202, 197, 196),
                                width: 5,
                                splineType: SplineType.natural,
                              )
                            ],
                          ),
                        ),
                        
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChartData {
  ChartData(this.x, this.y);
  final double x;
  final double y;
}
