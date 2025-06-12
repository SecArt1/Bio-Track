/**
 * BioTrack ESP32 Health Monitoring System
 * Firebase Cloud Functions for real-time data processing
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

/**
 * MQTT over HTTPS endpoint for ESP32 devices
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>} Promise that resolves when request is handled
 */
exports.receiveSensorData = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== "POST") {
      return res.status(405).json({error: "Method not allowed"});
    }

    const sensorData = req.body;
    const deviceId = sensorData.deviceId || sensorData.device_id;

    if (!deviceId) {
      return res.status(400).json({error: "Device ID is required"});
    }

    // Validate sensor data
    const validatedData = await validateSensorData(sensorData);
    if (!validatedData.isValid) {
      return res.status(400).json({error: validatedData.errors});
    }

    // Store in Firestore
    const docRef = await db.collection("sensor_data").add({
      ...sensorData,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      processed: false,
    });

    // Store latest reading for device
    await db.collection("devices").doc(deviceId).set({
      lastReading: sensorData,
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      status: "online",
    }, {merge: true});

    // Trigger real-time processing
    await processSensorDataRealtime(sensorData, docRef.id);

    res.status(200).json({
      success: true,
      documentId: docRef.id,
      message: "Sensor data received and processed",
    });
  } catch (error) {
    console.error("Error processing sensor data:", error);
    res.status(500).json({error: "Internal server error"});
  }
});

/**
 * Device heartbeat endpoint
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>} Promise that resolves when request is handled
 */
exports.deviceHeartbeat = functions.https.onRequest(async (req, res) => {
  try {
    const {deviceId, status, uptime, freeHeap, wifiRSSI} = req.body;

    await db.collection("devices").doc(deviceId).update({
      status: status || "online",
      uptime: uptime,
      freeHeap: freeHeap,
      wifiRSSI: wifiRSSI,
      lastHeartbeat: admin.firestore.FieldValue.serverTimestamp(),
    });

    res.status(200).json({success: true});
  } catch (error) {
    console.error("Error updating device heartbeat:", error);
    res.status(500).json({error: "Internal server error"});
  }
});

/**
 * Alert processing endpoint
 * @param {Object} req - Express request object
 * @param {Object} res - Express response object
 * @returns {Promise<void>} Promise that resolves when request is handled
 */
exports.processAlert = functions.https.onRequest(async (req, res) => {
  try {
    const alertData = req.body;

    // Store alert
    const alertRef = await db.collection("alerts").add({
      ...alertData,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      acknowledged: false,
      processed: false,
    });

    // Process alert based on severity
    await processHealthAlert(alertData, alertRef.id);

    res.status(200).json({
      success: true,
      alertId: alertRef.id,
    });
  } catch (error) {
    console.error("Error processing alert:", error);
    res.status(500).json({error: "Internal server error"});
  }
});

/**
 * Real-time sensor data processing
 * @param {Object} sensorData - Sensor data object
 * @param {string} documentId - Firestore document ID
 * @return {Promise<void>} Promise that resolves when processing is complete
 */
async function processSensorDataRealtime(sensorData, documentId) {
  try {
    const {deviceId} = sensorData;

    // Analyze data for anomalies
    const analysis = await analyzeSensorData(sensorData);

    // Store analysis results
    await db.collection("sensor_data").doc(documentId).update({
      analysis: analysis,
      processed: true,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Check for alert conditions
    const alerts = checkAlertConditions(sensorData, analysis);

    for (const alert of alerts) {
      await createAlert(deviceId, alert);
    }

    // Update user's health metrics
    await updateUserHealthMetrics(deviceId, sensorData);
  } catch (error) {
    console.error("Error in real-time processing:", error);
  }
}

/**
 * Validate incoming sensor data
 * @param {Object} data - Sensor data to validate
 * @return {Promise<Object>} Validation result with isValid flag and errors
 */
async function validateSensorData(data) {
  const errors = [];

  // Check required fields
  if (!data.deviceId && !data.device_id) {
    errors.push("Device ID is required");
  }

  // Validate heart rate
  if (data.heartRate || data.heart_rate) {
    const hr = data.heartRate || data.heart_rate.value;
    if (hr < 30 || hr > 250) {
      errors.push("Heart rate out of valid range (30-250 BPM)");
    }
  }

  // Validate temperature
  if (data.temperature) {
    const temp = data.temperature.value || data.temperature;
    if (temp < 30 || temp > 45) {
      errors.push("Temperature out of valid range (30-45°C)");
    }
  }

  // Validate weight
  if (data.weight) {
    const weight = data.weight.value || data.weight;
    if (weight < 0 || weight > 500) {
      errors.push("Weight out of valid range (0-500 kg)");
    }
  }

  // Validate bioimpedance
  if (data.bioimpedance) {
    const impedance = data.bioimpedance.impedance;
    if (impedance && (impedance < 10 || impedance > 10000)) {
      errors.push("Bioimpedance out of valid range (10-10000 ohms)");
    }
  }

  // Validate ECG
  if (data.ecg) {
    const bpm = data.ecg.avgBPM;
    if (bpm && (bpm < 30 || bpm > 220)) {
      errors.push("ECG BPM out of valid range (30-220 BPM)");
    }
  }

  // Validate glucose
  if (data.glucose) {
    const glucose = data.glucose.glucoseLevel;
    if (glucose && (glucose < 50 || glucose > 600)) {
      errors.push("Glucose level out of valid range (50-600 mg/dL)");
    }
  }

  // Validate blood pressure
  if (data.bloodPressure) {
    const systolic = data.bloodPressure.systolic;
    const diastolic = data.bloodPressure.diastolic;
    if (systolic && (systolic < 70 || systolic > 250)) {
      errors.push("Systolic pressure out of valid range (70-250 mmHg)");
    }
    if (diastolic && (diastolic < 40 || diastolic > 150)) {
      errors.push("Diastolic pressure out of valid range (40-150 mmHg)");
    }
  }

  // Validate body composition
  if (data.bodyComposition) {
    const bodyFat = data.bodyComposition.bodyFatPercentage;
    const muscleMass = data.bodyComposition.muscleMassKg;
    const quality = data.bodyComposition.measurementQuality;
    
    if (bodyFat && (bodyFat < 3 || bodyFat > 50)) {
      errors.push("Body fat percentage out of valid range (3-50%)");
    }
    if (muscleMass && (muscleMass < 10 || muscleMass > 80)) {
      errors.push("Muscle mass out of valid range (10-80 kg)");
    }
    if (quality && quality < 50) {
      errors.push("Body composition measurement quality too low (<50%)");
    }
  }

  return {
    isValid: errors.length === 0,
    errors: errors,
  };
}

/**
 * Analyze sensor data for patterns and anomalies
 * @param {Object} data - Sensor data to analyze
 * @return {Promise<Object>} Analysis results
 */
async function analyzeSensorData(data) {
  const analysis = {
    heartRateVariability: null,
    temperatureTrend: null,
    weightTrend: null,
    overallHealth: "normal",
    recommendations: [],
  };

  // Heart rate analysis
  if (data.heartRate || data.heart_rate) {
    const hr = data.heartRate || data.heart_rate.value;
    const spo2 = data.spo2 || (data.heart_rate && data.heart_rate.spo2);

    if (hr > 100) {
      analysis.overallHealth = "elevated";
      analysis.recommendations
          .push("Monitor heart rate - slightly elevated");
    }

    if (spo2 && spo2 < 95) {
      analysis.overallHealth = "concerning";
      analysis.recommendations
          .push("Low blood oxygen - consider medical consultation");
    }
  }

  // Temperature analysis
  if (data.temperature) {
    const temp = data.temperature.value || data.temperature;

    if (temp > 37.5) {
      analysis.overallHealth = "elevated";
      analysis.recommendations.push("Elevated temperature detected");
    }
  }

  return analysis;
}

/**
 * Check for alert conditions
 * @param {Object} data - Sensor data
 * @param {Object} analysis - Analysis results
 * @return {Array} Array of alerts
 */
function checkAlertConditions(data, analysis) {
  const alerts = [];

  // Critical heart rate alerts
  if (data.heartRate || data.heart_rate) {
    const hr = data.heartRate || data.heart_rate.value;

    if (hr > 180) {
      alerts.push({
        type: "CRITICAL_HIGH_HEART_RATE",
        severity: "critical",
        message: `Critical high heart rate: ${hr} BPM`,
        value: hr,
      });
    } else if (hr < 40) {
      alerts.push({
        type: "CRITICAL_LOW_HEART_RATE",
        severity: "critical",
        message: `Critical low heart rate: ${hr} BPM`,
        value: hr,
      });
    }
  }

  // SpO2 alerts
  if (data.spo2 || (data.heart_rate && data.heart_rate.spo2)) {
    const spo2 = data.spo2 || data.heart_rate.spo2;

    if (spo2 < 90) {
      alerts.push({
        type: "CRITICAL_LOW_SPO2",
        severity: "critical",
        message: `Critical low blood oxygen: ${spo2}%`,
        value: spo2,
      });
    }
  }

  // Temperature alerts
  if (data.temperature) {
    const temp = data.temperature.value || data.temperature;

    if (temp > 39.0) {
      alerts.push({
        type: "HIGH_FEVER",
        severity: "high",
        message: `High fever detected: ${temp}°C`,
        value: temp,
      });
    }
  }

  // ECG alerts
  if (data.ecg) {
    if (data.ecg.leadOff) {
      alerts.push({
        type: "ECG_LEAD_OFF",
        severity: "medium",
        message: "ECG lead disconnected",
        value: true,
      });
    }

    const ecgBpm = data.ecg.avgBPM;
    if (ecgBpm && (ecgBpm > 200 || ecgBpm < 35)) {
      alerts.push({
        type: "ECG_ABNORMAL_RHYTHM",
        severity: "high",
        message: `Abnormal ECG rhythm detected: ${ecgBpm} BPM`,
        value: ecgBpm,
      });
    }
  }

  // Glucose alerts
  if (data.glucose) {
    const glucose = data.glucose.glucoseLevel;
    if (glucose) {
      if (glucose > 180) {
        alerts.push({
          type: "HIGH_GLUCOSE",
          severity: "high",
          message: `High blood glucose: ${glucose} mg/dL`,
          value: glucose,
        });
      } else if (glucose < 70) {
        alerts.push({
          type: "LOW_GLUCOSE",
          severity: "critical",
          message: `Low blood glucose: ${glucose} mg/dL`,
          value: glucose,
        });
      }
    }
  }

  // Blood pressure alerts
  if (data.bloodPressure) {
    const systolic = data.bloodPressure.systolic;
    const diastolic = data.bloodPressure.diastolic;

    if (systolic && diastolic) {
      if (systolic > 180 || diastolic > 120) {
        alerts.push({
          type: "HYPERTENSIVE_CRISIS",
          severity: "critical",
          message: `Hypertensive crisis: ${systolic}/${diastolic} mmHg`,
          value: `${systolic}/${diastolic}`,
        });
      } else if (systolic > 140 || diastolic > 90) {
        alerts.push({
          type: "HIGH_BLOOD_PRESSURE",
          severity: "high",
          message: `High blood pressure: ${systolic}/${diastolic} mmHg`,
          value: `${systolic}/${diastolic}`,
        });
      }
    }
  }

  // Body composition alerts
  if (data.bodyComposition) {
    const bodyFat = data.bodyComposition.bodyFatPercentage;
    const muscleMass = data.bodyComposition.muscleMassKg;
    const visceralFat = data.bodyComposition.visceralFatLevel;
    const quality = data.bodyComposition.measurementQuality;

    // Body fat percentage alerts
    if (bodyFat) {
      if (bodyFat > 35) {
        alerts.push({
          type: "HIGH_BODY_FAT",
          severity: "high",
          message: `High body fat percentage: ${bodyFat.toFixed(1)}%`,
          value: bodyFat,
        });
      } else if (bodyFat < 5) {
        alerts.push({
          type: "LOW_BODY_FAT",
          severity: "high",
          message: `Very low body fat percentage: ${bodyFat.toFixed(1)}%`,
          value: bodyFat,
        });
      }
    }

    // Visceral fat alerts
    if (visceralFat && visceralFat > 15) {
      alerts.push({
        type: "HIGH_VISCERAL_FAT",
        severity: "high",
        message: `High visceral fat level: ${visceralFat.toFixed(1)}`,
        value: visceralFat,
      });
    }

    // Measurement quality alerts
    if (quality && quality < 60) {
      alerts.push({
        type: "LOW_MEASUREMENT_QUALITY",
        severity: "warning",
        message: `Low body composition measurement quality: ${quality.toFixed(1)}%`,
        value: quality,
      });
    }
  }

  return alerts;
}

/**
 * Create and store alert
 * @param {string} deviceId - Device ID
 * @param {Object} alertData - Alert data
 * @return {Promise<string>} Alert ID
 */
async function createAlert(deviceId, alertData) {
  const alert = {
    deviceId: deviceId,
    type: alertData.type,
    severity: alertData.severity,
    message: alertData.message,
    value: alertData.value,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    acknowledged: false,
    notificationSent: false,
  };

  const alertRef = await db.collection("alerts").add(alert);

  // Send immediate notification for critical alerts
  if (alertData.severity === "critical") {
    await sendCriticalAlertNotification(deviceId, alert);
  }

  return alertRef.id;
}

/**
 * Process health alert
 * @param {Object} alertData - Alert data
 * @param {string} alertId - Alert ID
 * @return {Promise<void>} Promise that resolves when processing is complete
 */
async function processHealthAlert(alertData, alertId) {
  try {
    // Update alert as processed
    await db.collection("alerts").doc(alertId).update({
      processed: true,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Trigger notifications based on severity
    if (alertData.severity === "critical") {
      await sendCriticalAlertNotification(alertData.deviceId, alertData);
    }
  } catch (error) {
    console.error("Error processing health alert:", error);
  }
}

/**
 * Send critical alert notifications
 * @param {string} deviceId - Device ID
 * @param {Object} alert - Alert object
 * @return {Promise<void>} Promise that resolves when notification is sent
 */
async function sendCriticalAlertNotification(deviceId, alert) {
  try {
    // Get device owner information
    const deviceDoc = await db.collection("devices").doc(deviceId).get();
    if (!deviceDoc.exists) {
      return;
    }

    const deviceData = deviceDoc.data();
    const userId = deviceData.userId;

    if (userId) {
      // Send push notification to user
      await sendPushNotification(userId, {
        title: "🚨 Critical Health Alert",
        body: alert.message,
        data: {
          type: "critical_alert",
          alertId: alert.id,
          deviceId: deviceId,
        },
      });

      // Send email notification if configured
      await sendEmailAlert(userId, alert);
    }
  } catch (error) {
    console.error("Error sending critical alert notification:", error);
  }
}

/**
 * Send push notification
 * @param {string} userId - User ID
 * @param {Object} payload - Notification payload
 * @return {Promise<void>} Promise that resolves when notification is sent
 */
async function sendPushNotification(userId, payload) {
  try {
    const userDoc = await db.collection("users").doc(userId).get();
    if (!userDoc.exists) {
      return;
    }

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title: payload.title,
          body: payload.body,
        },
        data: payload.data || {},
      };

      await admin.messaging().send(message);
      console.log("Push notification sent successfully");
    }
  } catch (error) {
    console.error("Error sending push notification:", error);
  }
}

/**
 * Update user health metrics
 * @param {string} deviceId - Device ID
 * @param {Object} sensorData - Sensor data
 * @return {Promise<void>} Promise that resolves when metrics are updated
 */
async function updateUserHealthMetrics(deviceId, sensorData) {
  try {
    const deviceDoc = await db.collection("devices").doc(deviceId).get();
    if (!deviceDoc.exists) {
      return;
    }

    const deviceData = deviceDoc.data();
    const userId = deviceData.userId;

    if (userId) {
      const userRef = db.collection("users").doc(userId);
      const userDoc = await userRef.get();

      if (userDoc.exists) {
        const updates = {
          lastMeasurement: admin.firestore.FieldValue
              .serverTimestamp(),
        };

        // Update latest readings
        if (sensorData.heartRate || sensorData.heart_rate) {
          updates.latestHeartRate = sensorData.heartRate ||
                        sensorData.heart_rate.value;
          updates.latestSpO2 = sensorData.spo2 ||
                        (sensorData.heart_rate && sensorData.heart_rate.spo2);
        }

        if (sensorData.temperature) {
          updates.latestTemperature = sensorData.temperature.value ||
                        sensorData.temperature;
        }

        if (sensorData.weight) {
          updates.latestWeight = sensorData.weight.value ||
                        sensorData.weight;
        }

        if (sensorData.bioimpedance) {
          updates.latestBioimpedance = sensorData.bioimpedance.impedance;
        }

        if (sensorData.ecg) {
          updates.latestECG = {
            avgBPM: sensorData.ecg.avgBPM,
            avgFilteredValue: sensorData.ecg.avgFilteredValue,
            leadOff: sensorData.ecg.leadOff,
          };
        }

        if (sensorData.glucose) {
          updates.latestGlucose = sensorData.glucose.glucoseLevel;
          updates.latestGlucoseQuality = sensorData.glucose.signalQuality;
        }

        if (sensorData.bloodPressure) {
          updates.latestBloodPressure = {
            systolic: sensorData.bloodPressure.systolic,
            diastolic: sensorData.bloodPressure.diastolic,
            PWV: sensorData.bloodPressure.PWV,
            HRV: sensorData.bloodPressure.HRV,
          };
        }

        if (sensorData.bodyComposition) {
          updates.latestBodyComposition = {
            bodyFatPercentage: sensorData.bodyComposition.bodyFatPercentage,
            muscleMassKg: sensorData.bodyComposition.muscleMassKg,
            bodyWaterPercentage: sensorData.bodyComposition.bodyWaterPercentage,
            BMR: sensorData.bodyComposition.BMR,
            metabolicAge: sensorData.bodyComposition.metabolicAge,
            visceralFatLevel: sensorData.bodyComposition.visceralFatLevel,
            measurementQuality: sensorData.bodyComposition.measurementQuality,
            phaseAngle: sensorData.bodyComposition.phaseAngle,
          };
        }

        await userRef.update(updates);
      }
    }
  } catch (error) {
    console.error("Error updating user health metrics:", error);
  }
}

/**
 * Firestore trigger for real-time data processing
 */
exports.onSensorDataCreated = functions.firestore
    .document("sensor_data/{documentId}")
    .onCreate(async (snap, context) => {
      const data = snap.data();
      const documentId = context.params.documentId;

      // Process the data if not already processed
      if (!data.processed) {
        await processSensorDataRealtime(data, documentId);
      }
    });

/**
 * Daily health summary generation
 */
exports.generateDailySummary = functions.pubsub
    .schedule("0 23 * * *") // Run at 11 PM daily
    .timeZone("UTC")
    .onRun(async (context) => {
      try {
        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const tomorrow = new Date(today);
        tomorrow.setDate(tomorrow.getDate() + 1);

        // Get all sensor data for today
        const todayData = await db.collection("sensor_data")
            .where("timestamp", ">=", today)
            .where("timestamp", "<", tomorrow)
            .get();

        // Process by device
        const deviceSummaries = {};

        todayData.forEach((doc) => {
          const data = doc.data();
          const deviceId = data.deviceId || data.device_id;

          if (!deviceSummaries[deviceId]) {
            deviceSummaries[deviceId] = {
              deviceId: deviceId,
              date: today,
              measurements: [],
              summary: {},
            };
          }

          deviceSummaries[deviceId].measurements.push(data);
        });

        // Generate summaries for each device
        for (const [deviceId, summary] of Object.entries(deviceSummaries)) {
          // Add deviceId to summary data for processing
          summary.deviceId = deviceId;
          const processedSummary = generateDeviceDailySummary(summary);

          await db.collection("daily_summaries").add({
            ...processedSummary,
            generatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }

        const deviceCount = Object.keys(deviceSummaries).length;
        console.log(`Generated daily summaries for ${deviceCount} devices`);
      } catch (error) {
        console.error("Error generating daily summary:", error);
      }
    });

/**
 * Generate device daily summary
 * @param {Object} data - Device measurement data
 * @return {Object} Processed summary
 */
function generateDeviceDailySummary(data) {
  const measurements = data.measurements;

  const summary = {
    deviceId: data.deviceId,
    date: data.date,
    totalMeasurements: measurements.length,
    heartRate: {
      readings: [],
      average: 0,
      min: 0,
      max: 0,
    },
    temperature: {
      readings: [],
      average: 0,
      min: 0,
      max: 0,
    },
    weight: {
      readings: [],
      average: 0,
      trend: "stable",
    },
    alerts: {
      total: 0,
      critical: 0,
      high: 0,
    },
  };

  // Process heart rate data
  const heartRates = measurements
      .filter((m) => m.heartRate || m.heart_rate)
      .map((m) => m.heartRate || m.heart_rate.value);

  if (heartRates.length > 0) {
    summary.heartRate.readings = heartRates;
    summary.heartRate.average = heartRates.reduce((a, b) => a + b) /
            heartRates.length;
    summary.heartRate.min = Math.min(...heartRates);
    summary.heartRate.max = Math.max(...heartRates);
  }

  // Process temperature data
  const temperatures = measurements
      .filter((m) => m.temperature)
      .map((m) => m.temperature.value || m.temperature);

  if (temperatures.length > 0) {
    summary.temperature.readings = temperatures;
    summary.temperature.average = temperatures.reduce((a, b) => a + b) /
            temperatures.length;
    summary.temperature.min = Math.min(...temperatures);
    summary.temperature.max = Math.max(...temperatures);
  }

  // Process weight data
  const weights = measurements
      .filter((m) => m.weight)
      .map((m) => m.weight.value || m.weight);

  if (weights.length > 0) {
    summary.weight.readings = weights;
    summary.weight.average = weights.reduce((a, b) => a + b) /
            weights.length;

    // Calculate weight trend
    if (weights.length > 1) {
      const first = weights[0];
      const last = weights[weights.length - 1];
      const diff = last - first;

      if (diff > 0.5) {
        summary.weight.trend = "increasing";
      } else if (diff < -0.5) {
        summary.weight.trend = "decreasing";
      } else {
        summary.weight.trend = "stable";
      }
    }
  }

  return summary;
}

/**
 * Email alert functionality (requires configuration)
 * @param {string} userId - User ID
 * @param {Object} alert - Alert object
 * @return {Promise<void>} Promise that resolves when email is sent
 */
async function sendEmailAlert(userId, alert) {
  // This would require email service configuration
  // Implementation depends on your email provider (SendGrid, etc.)
  console.log(`Email alert would be sent for user ${userId}:`, alert.message);
}
