import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
// Import localization
import 'package:bio_track/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:bio_track/l10n/language_provider.dart';

class HealthSummaryScreen extends StatelessWidget {
  const HealthSummaryScreen({super.key});

  // بيانات القياسات - Health metrics data
  final Map<String, double> healthMetrics = const {
    "Weight (kg)": 70,
    "Body Fat (%)": 25.5,
    "Muscle Mass (kg)": 50.2,
    "Heart Rate (bpm)": 120,
    "Blood Glucose (mg/dL)": 55,
    "Body Temperature (°C)": 36.5,
  };

  // القيم الطبيعية لكل مقياس - Normal ranges for each metric
  final Map<String, String> normalRanges = const {
    "Weight (kg)": "Varies by height and age",
    "Body Fat (%)": "10% - 20% (Men), 18% - 28% (Women)",
    "Muscle Mass (kg)": "Varies by body composition",
    "Heart Rate (bpm)": "60 - 100 bpm",
    "Blood Glucose (mg/dL)": "70 - 140 mg/dL",
    "Body Temperature (°C)": "36.1 - 37.2°C",
  };

  // ألوان مخصصة لكل مقياس صحي - Custom colors for each health metric
  final Map<String, Color> healthMetricColors = const {
    "Weight (kg)": Color(0xFF0383C2),
    "Body Fat (%)": Color(0xFF0383C2),
    "Muscle Mass (kg)": Color(0xFF0383C2),
    "Heart Rate (bpm)": Color(0xFF0383C2),
    "Blood Glucose (mg/dL)": Color(0xFF0383C2),
    "Body Temperature (°C)": Color(0xFF0383C2),
  };

  // تحديد الحالة الصحية - Determine health status
  String getHealthStatus(String metric, double value, BuildContext context) {
    final localizations = AppLocalizations.of(context);

    if (metric == "Heart Rate (bpm)") {
      if (value < 60) return localizations.translate("below_average");
      if (value > 100) return localizations.translate("above_average");
    } else if (metric == "Blood Glucose (mg/dL)") {
      if (value < 70) return localizations.translate("below_average");
      if (value > 140) return localizations.translate("above_average");
    } else if (metric == "Body Temperature (°C)") {
      if (value < 36.1) return localizations.translate("below_average");
      if (value > 37.2) return localizations.translate("above_average");
    }
    return localizations.translate("average");
  }

  // Getting translated metric names
  String getTranslatedMetricName(String englishName, BuildContext context) {
    final localizations = AppLocalizations.of(context);

    Map<String, String> translationKeys = {
      "Weight (kg)": "weight_kg",
      "Body Fat (%)": "body_fat_percent",
      "Muscle Mass (kg)": "muscle_mass_kg",
      "Heart Rate (bpm)": "heart_rate_bpm",
      "Blood Glucose (mg/dL)": "blood_glucose_mgdl",
      "Body Temperature (°C)": "body_temperature_c"
    };

    return localizations.translate(translationKeys[englishName] ?? englishName);
  }

  // Getting translated normal ranges
  String getTranslatedNormalRange(String metric, BuildContext context) {
    final localizations = AppLocalizations.of(context);

    Map<String, String> rangeKeys = {
      "Weight (kg)": "weight_normal_range",
      "Body Fat (%)": "body_fat_normal_range",
      "Muscle Mass (kg)": "muscle_mass_normal_range",
      "Heart Rate (bpm)": "heart_rate_normal_range",
      "Blood Glucose (mg/dL)": "blood_glucose_normal_range",
      "Body Temperature (°C)": "body_temperature_normal_range"
    };

    return localizations.translate(rangeKeys[metric] ?? "");
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final languageProvider = Provider.of<LanguageProvider>(context);
    final isArabic = languageProvider.isArabic;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          localizations.translate("health_summary"),
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: const Color(0xFF0383C2),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // ****** قائمة القراءات الصحية - Health readings list ******
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
                  String translatedMetric =
                      getTranslatedMetricName(key, context);
                  String healthStatus = getHealthStatus(key, value, context);

                  return GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text(translatedMetric),
                          content: Text(
                              "${localizations.translate("normal_range")}: ${getTranslatedNormalRange(key, context)}"),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text(localizations.translate("close")),
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
                              translatedMetric,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: healthMetricColors[key] ??
                                    Color(0xFF0383C2),
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
                              healthStatus,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: healthStatus ==
                                        localizations.translate("average")
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

            // ****** رسم تخطيط القلب (ECG) - ECG Chart ******
            Text(
              localizations.translate("ecg_report"),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0383C2),
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
                      spots: const [
                        FlSpot(0, 1),
                        FlSpot(1, 4),
                        FlSpot(2, 2),
                        FlSpot(3, 5),
                        FlSpot(4, 3),
                        FlSpot(5, 6),
                        FlSpot(6, 2),
                        FlSpot(7, 5),
                        FlSpot(8, 1),
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

            // ****** زر مشاركة التقرير - Share Report Button ******
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // وظيفة زر المشاركة - Share button function
                },
                icon: const Icon(Icons.share, color: Colors.white),
                label: Text(
                  localizations.translate("share_report"),
                  style: const TextStyle(fontSize: 16, color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0383C2),
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
