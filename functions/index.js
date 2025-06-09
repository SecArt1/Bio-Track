/**
 * BioTrack ESP32 Health Monitoring System
 * Firebase Cloud Functions for real-time data processing
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const {PubSub} = require('@google-cloud/pubsub');
const nodemailer = require('nodemailer');

admin.initializeApp();
const db = admin.firestore();
const pubsub = new PubSub();

// MQTT over HTTPS endpoint for ESP32 devices
exports.receiveSensorData = functions.https.onRequest(async (req, res) => {
  try {
    if (req.method !== 'POST') {
      return res.status(405).json({error: 'Method not allowed'});
    }

    const sensorData = req.body;
    const deviceId = sensorData.deviceId || sensorData.device_id;
    
    if (!deviceId) {
      return res.status(400).json({error: 'Device ID is required'});
    }

    // Validate sensor data
    const validatedData = await validateSensorData(sensorData);
    if (!validatedData.isValid) {
      return res.status(400).json({error: validatedData.errors});
    }

    // Store in Firestore
    const docRef = await db.collection('sensor_data').add({
      ...sensorData,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      processed: false
    });

    // Store latest reading for device
    await db.collection('devices').doc(deviceId).set({
      lastReading: sensorData,
      lastSeen: admin.firestore.FieldValue.serverTimestamp(),
      status: 'online'
    }, {merge: true});

    // Trigger real-time processing
    await processSensorDataRealtime(sensorData, docRef.id);

    res.status(200).json({
      success: true,
      documentId: docRef.id,
      message: 'Sensor data received and processed'
    });

  } catch (error) {
    console.error('Error processing sensor data:', error);
    res.status(500).json({error: 'Internal server error'});
  }
});

// Device heartbeat endpoint
exports.deviceHeartbeat = functions.https.onRequest(async (req, res) => {
  try {
    const {deviceId, status, uptime, freeHeap, wifiRSSI} = req.body;
    
    await db.collection('devices').doc(deviceId).update({
      status: status || 'online',
      uptime: uptime,
      freeHeap: freeHeap,
      wifiRSSI: wifiRSSI,
      lastHeartbeat: admin.firestore.FieldValue.serverTimestamp()
    });

    res.status(200).json({success: true});
  } catch (error) {
    console.error('Error updating device heartbeat:', error);
    res.status(500).json({error: 'Internal server error'});
  }
});

// Alert processing endpoint
exports.processAlert = functions.https.onRequest(async (req, res) => {
  try {
    const alertData = req.body;
    const {deviceId, alertType, value, severity} = alertData;

    // Store alert
    const alertRef = await db.collection('alerts').add({
      ...alertData,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      acknowledged: false,
      processed: false
    });

    // Process alert based on severity
    await processHealthAlert(alertData, alertRef.id);

    res.status(200).json({
      success: true,
      alertId: alertRef.id
    });

  } catch (error) {
    console.error('Error processing alert:', error);
    res.status(500).json({error: 'Internal server error'});
  }
});

// Real-time sensor data processing
async function processSensorDataRealtime(sensorData, documentId) {
  try {
    const {deviceId} = sensorData;
    
    // Analyze data for anomalies
    const analysis = await analyzeSensorData(sensorData);
    
    // Store analysis results
    await db.collection('sensor_data').doc(documentId).update({
      analysis: analysis,
      processed: true,
      processedAt: admin.firestore.FieldValue.serverTimestamp()
    });

    // Check for alert conditions
    const alerts = checkAlertConditions(sensorData, analysis);
    
    for (const alert of alerts) {
      await createAlert(deviceId, alert);
    }

    // Update user's health metrics
    await updateUserHealthMetrics(deviceId, sensorData);

  } catch (error) {
    console.error('Error in real-time processing:', error);
  }
}

// Validate incoming sensor data
async function validateSensorData(data) {
  const errors = [];
  
  // Check required fields
  if (!data.deviceId && !data.device_id) {
    errors.push('Device ID is required');
  }
  
  // Validate heart rate
  if (data.heartRate || data.heart_rate) {
    const hr = data.heartRate || data.heart_rate.value;
    if (hr < 30 || hr > 250) {
      errors.push('Heart rate out of valid range (30-250 BPM)');
    }
  }

  // Validate temperature
  if (data.temperature) {
    const temp = data.temperature.value || data.temperature;
    if (temp < 30 || temp > 45) {
      errors.push('Temperature out of valid range (30-45°C)');
    }
  }

  // Validate weight
  if (data.weight) {
    const weight = data.weight.value || data.weight;
    if (weight < 0 || weight > 500) {
      errors.push('Weight out of valid range (0-500 kg)');
    }
  }

  return {
    isValid: errors.length === 0,
    errors: errors
  };
}

// Analyze sensor data for patterns and anomalies
async function analyzeSensorData(data) {
  const analysis = {
    heartRateVariability: null,
    temperatureTrend: null,
    weightTrend: null,
    overallHealth: 'normal',
    recommendations: []
  };

  // Heart rate analysis
  if (data.heartRate || data.heart_rate) {
    const hr = data.heartRate || data.heart_rate.value;
    const spo2 = data.spo2 || (data.heart_rate && data.heart_rate.spo2);
    
    if (hr > 100) {
      analysis.overallHealth = 'elevated';
      analysis.recommendations.push('Monitor heart rate - slightly elevated');
    }
    
    if (spo2 && spo2 < 95) {
      analysis.overallHealth = 'concerning';
      analysis.recommendations.push('Low blood oxygen - consider medical consultation');
    }
  }

  // Temperature analysis
  if (data.temperature) {
    const temp = data.temperature.value || data.temperature;
    
    if (temp > 37.5) {
      analysis.overallHealth = 'elevated';
      analysis.recommendations.push('Elevated temperature detected');
    }
  }

  return analysis;
}

// Check for alert conditions
function checkAlertConditions(data, analysis) {
  const alerts = [];

  // Critical heart rate alerts
  if (data.heartRate || data.heart_rate) {
    const hr = data.heartRate || data.heart_rate.value;
    
    if (hr > 180) {
      alerts.push({
        type: 'CRITICAL_HIGH_HEART_RATE',
        severity: 'critical',
        message: `Critical high heart rate: ${hr} BPM`,
        value: hr
      });
    } else if (hr < 40) {
      alerts.push({
        type: 'CRITICAL_LOW_HEART_RATE',
        severity: 'critical',
        message: `Critical low heart rate: ${hr} BPM`,
        value: hr
      });
    }
  }

  // SpO2 alerts
  if (data.spo2 || (data.heart_rate && data.heart_rate.spo2)) {
    const spo2 = data.spo2 || data.heart_rate.spo2;
    
    if (spo2 < 90) {
      alerts.push({
        type: 'CRITICAL_LOW_SPO2',
        severity: 'critical',
        message: `Critical low blood oxygen: ${spo2}%`,
        value: spo2
      });
    }
  }

  // Temperature alerts
  if (data.temperature) {
    const temp = data.temperature.value || data.temperature;
    
    if (temp > 39.0) {
      alerts.push({
        type: 'HIGH_FEVER',
        severity: 'high',
        message: `High fever detected: ${temp}°C`,
        value: temp
      });
    }
  }

  return alerts;
}

// Create and store alert
async function createAlert(deviceId, alertData) {
  const alert = {
    deviceId: deviceId,
    type: alertData.type,
    severity: alertData.severity,
    message: alertData.message,
    value: alertData.value,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    acknowledged: false,
    notificationSent: false
  };

  const alertRef = await db.collection('alerts').add(alert);
  
  // Send immediate notification for critical alerts
  if (alertData.severity === 'critical') {
    await sendCriticalAlertNotification(deviceId, alert);
  }

  return alertRef.id;
}

// Send critical alert notifications
async function sendCriticalAlertNotification(deviceId, alert) {
  try {
    // Get device owner information
    const deviceDoc = await db.collection('devices').doc(deviceId).get();
    if (!deviceDoc.exists) return;

    const deviceData = deviceDoc.data();
    const userId = deviceData.userId;

    if (userId) {
      // Send push notification to user
      await sendPushNotification(userId, {
        title: '🚨 Critical Health Alert',
        body: alert.message,
        data: {
          type: 'critical_alert',
          alertId: alert.id,
          deviceId: deviceId
        }
      });

      // Send email notification if configured
      await sendEmailAlert(userId, alert);
    }

  } catch (error) {
    console.error('Error sending critical alert notification:', error);
  }
}

// Send push notification
async function sendPushNotification(userId, payload) {
  try {
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (fcmToken) {
      const message = {
        token: fcmToken,
        notification: {
          title: payload.title,
          body: payload.body
        },
        data: payload.data || {}
      };

      await admin.messaging().send(message);
      console.log('Push notification sent successfully');
    }
  } catch (error) {
    console.error('Error sending push notification:', error);
  }
}

// Update user health metrics
async function updateUserHealthMetrics(deviceId, sensorData) {
  try {
    const deviceDoc = await db.collection('devices').doc(deviceId).get();
    if (!deviceDoc.exists) return;

    const deviceData = deviceDoc.data();
    const userId = deviceData.userId;

    if (userId) {
      const userRef = db.collection('users').doc(userId);
      const userDoc = await userRef.get();
      
      if (userDoc.exists) {
        const updates = {
          lastMeasurement: admin.firestore.FieldValue.serverTimestamp()
        };

        // Update latest readings
        if (sensorData.heartRate || sensorData.heart_rate) {
          updates.latestHeartRate = sensorData.heartRate || sensorData.heart_rate.value;
          updates.latestSpO2 = sensorData.spo2 || (sensorData.heart_rate && sensorData.heart_rate.spo2);
        }

        if (sensorData.temperature) {
          updates.latestTemperature = sensorData.temperature.value || sensorData.temperature;
        }

        if (sensorData.weight) {
          updates.latestWeight = sensorData.weight.value || sensorData.weight;
        }

        await userRef.update(updates);
      }
    }
  } catch (error) {
    console.error('Error updating user health metrics:', error);
  }
}

// Firestore trigger for real-time data processing
exports.onSensorDataCreated = functions.firestore
  .document('sensor_data/{documentId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const documentId = context.params.documentId;
    
    // Process the data if not already processed
    if (!data.processed) {
      await processSensorDataRealtime(data, documentId);
    }
  });

// Daily health summary generation
exports.generateDailySummary = functions.pubsub
  .schedule('0 23 * * *') // Run at 11 PM daily
  .timeZone('UTC')
  .onRun(async (context) => {
    try {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      // Get all sensor data for today
      const todayData = await db.collection('sensor_data')
        .where('timestamp', '>=', today)
        .where('timestamp', '<', tomorrow)
        .get();

      // Process by device
      const deviceSummaries = {};
      
      todayData.forEach(doc => {
        const data = doc.data();
        const deviceId = data.deviceId || data.device_id;
        
        if (!deviceSummaries[deviceId]) {
          deviceSummaries[deviceId] = {
            deviceId: deviceId,
            date: today,
            measurements: [],
            summary: {}
          };
        }
        
        deviceSummaries[deviceId].measurements.push(data);
      });

      // Generate summaries for each device
      for (const [deviceId, summary] of Object.entries(deviceSummaries)) {
        const processedSummary = generateDeviceDailySummary(summary);
        
        await db.collection('daily_summaries').add({
          ...processedSummary,
          generatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
      }

      console.log(`Generated daily summaries for ${Object.keys(deviceSummaries).length} devices`);
      
    } catch (error) {
      console.error('Error generating daily summary:', error);
    }
  });

// Generate device daily summary
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
      max: 0
    },
    temperature: {
      readings: [],
      average: 0,
      min: 0,
      max: 0
    },
    weight: {
      readings: [],
      average: 0,
      trend: 'stable'
    },
    alerts: {
      total: 0,
      critical: 0,
      high: 0
    }
  };

  // Process heart rate data
  const heartRates = measurements
    .filter(m => m.heartRate || m.heart_rate)
    .map(m => m.heartRate || m.heart_rate.value);
    
  if (heartRates.length > 0) {
    summary.heartRate.readings = heartRates;
    summary.heartRate.average = heartRates.reduce((a, b) => a + b) / heartRates.length;
    summary.heartRate.min = Math.min(...heartRates);
    summary.heartRate.max = Math.max(...heartRates);
  }

  // Process temperature data
  const temperatures = measurements
    .filter(m => m.temperature)
    .map(m => m.temperature.value || m.temperature);
    
  if (temperatures.length > 0) {
    summary.temperature.readings = temperatures;
    summary.temperature.average = temperatures.reduce((a, b) => a + b) / temperatures.length;
    summary.temperature.min = Math.min(...temperatures);
    summary.temperature.max = Math.max(...temperatures);
  }

  // Process weight data
  const weights = measurements
    .filter(m => m.weight)
    .map(m => m.weight.value || m.weight);
    
  if (weights.length > 0) {
    summary.weight.readings = weights;
    summary.weight.average = weights.reduce((a, b) => a + b) / weights.length;
    
    // Calculate weight trend
    if (weights.length > 1) {
      const first = weights[0];
      const last = weights[weights.length - 1];
      const diff = last - first;
      
      if (diff > 0.5) summary.weight.trend = 'increasing';
      else if (diff < -0.5) summary.weight.trend = 'decreasing';
      else summary.weight.trend = 'stable';
    }
  }

  return summary;
}

// Email alert functionality (requires configuration)
async function sendEmailAlert(userId, alert) {
  // This would require email service configuration
  // Implementation depends on your email provider (SendGrid, etc.)
  console.log(`Email alert would be sent for user ${userId}:`, alert.message);
}
