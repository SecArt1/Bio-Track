import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
class HealthSummaryScreen extends StatelessWidget {
  const HealthSummaryScreen({super.key});

  // بيانات القياسات
  final Map<String, double> healthMetrics = const {
    "Weight (kg)": 70,
    "Body Fat (%)": 25.5,
    "Muscle Mass (kg)": 50.2,
    "Heart Rate (bpm)": 120,
    "Blood Glucose (mg/dL)": 55,
    "Body Temperature (°C)": 36.5,
  };

  // القيم الطبيعية لكل مقياس
  final Map<String, String> normalRanges = const {
    "Weight (kg)": "Varies by height and age",
    "Body Fat (%)": "10% - 20% (Men), 18% - 28% (Women)",
    "Muscle Mass (kg)": "Varies by body composition",
    "Heart Rate (bpm)": "60 - 100 bpm",
    "Blood Glucose (mg/dL)": "70 - 140 mg/dL",
    "Body Temperature (°C)": "36.1 - 37.2°C",
  };

  // ألوان مخصصة لكل مقياس صحي
  final Map<String, Color> healthMetricColors = const {
    "Weight (kg)": Color(0xFF0383C2),
    "Body Fat (%)":  Color(0xFF0383C2),
    "Muscle Mass (kg)":  Color(0xFF0383C2),
    "Heart Rate (bpm)":  Color(0xFF0383C2),
    "Blood Glucose (mg/dL)":  Color(0xFF0383C2),
    "Body Temperature (°C)":  Color(0xFF0383C2),
  };

  // تحديد الحالة الصحية
  String getHealthStatus(String metric, double value) {
    if (metric == "Heart Rate (bpm)") {
      if (value < 60) return "Below Average";
      if (value > 100) return "Above Average";
    } else if (metric == "Blood Glucose (mg/dL)") {
      if (value < 70) return "Below Average";
      if (value > 140) return "Above Average";
    } else if (metric == "Body Temperature (°C)") {
      if (value < 36.1) return "Below Average";
      if (value > 37.2) return "Above Average";
    }
    return "Average";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Health Summary",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0383C2),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ****** قائمة القراءات الصحية ******
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: healthMetrics.length,
                itemBuilder: (context, index) {
                  String key = healthMetrics.keys.elementAt(index);
                  double value = healthMetrics[key]!;
                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(key),
                          content: Text("Normal Range: ${normalRanges[key]}"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text("Close"),
                            ),
                          ],
                        ),
                      );
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              key,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: healthMetricColors[key] ?? Color(0xFF0383C2),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              "$value",
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              getHealthStatus(key, value),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: getHealthStatus(key, value) == "Average"
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 20),

            // ****** رسم تخطيط القلب (ECG) ******
            const Text(
              "ECG Report",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color:  Color(0xFF0383C2),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: [
                        const FlSpot(0, 1),
                        const FlSpot(1, 4),
                        const FlSpot(2, 2),
                        const FlSpot(3, 5),
                        const FlSpot(4, 3),
                        const FlSpot(5, 6),
                        const FlSpot(6, 2),
                        const FlSpot(7, 5),
                        const FlSpot(8, 1),
                      ],
                      isCurved: true,
                      color: Colors.red,
                      barWidth: 2,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ****** زر مشاركة التقرير ******
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // وظيفة زر المشاركة
                },
                icon: const Icon(Icons.share, color: Colors.white),
                label: const Text(
                  "Share Report",
                  style: TextStyle(fontSize: 16,
                      color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0383C2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}