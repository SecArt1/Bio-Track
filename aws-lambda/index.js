// AWS IoT Core to Firebase Bridge Lambda Function
// Supports both mock and real Firebase for testing and production

const { v4: uuidv4 } = require('uuid');

// Firebase configuration
const USE_MOCK_FIREBASE = process.env.USE_MOCK_FIREBASE === 'true';

let admin, db;

if (USE_MOCK_FIREBASE) {
  console.log('Using Mock Firebase for testing');
  
  // Mock Firestore implementation for testing
  const mockFirestore = {
    collection: (name) => ({
      add: async (data) => {
        console.log(`Mock Firestore: Adding to collection '${name}':`, JSON.stringify(data, null, 2));
        return { id: `mock_doc_${Date.now()}` };
      },
      doc: (id) => ({
        set: async (data, options) => {
          console.log(`Mock Firestore: Setting document '${id}' in collection '${name}':`, JSON.stringify(data, null, 2));
          return true;
        },
        update: async (data) => {
          console.log(`Mock Firestore: Updating document '${id}' in collection '${name}':`, JSON.stringify(data, null, 2));
          return true;
        },
        get: async () => {
          console.log(`Mock Firestore: Getting document '${id}' from collection '${name}'`);
          return {
            exists: false,
            data: () => ({ userId: null })
          };
        }
      })
    })
  };
  
  db = mockFirestore;
} else {
  console.log('Using Real Firebase Admin SDK');
  
  // Real Firebase Admin SDK
  admin = require('firebase-admin');
  
  // Check if running against emulator
  if (process.env.FIRESTORE_EMULATOR_HOST) {
    console.log('Using Firebase emulator at:', process.env.FIRESTORE_EMULATOR_HOST);
    // Initialize with minimal config for emulator
    if (!admin.apps.length) {
      admin.initializeApp({
        projectId: "bio-track-de846"
      });
    }
  } else {
    // Firebase service account configuration
    const serviceAccount = {
      type: "service_account",
      project_id: "bio-track-de846",
      private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
      private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      client_email: process.env.FIREBASE_CLIENT_EMAIL,
      client_id: process.env.FIREBASE_CLIENT_ID,
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL
    };

    // Initialize Firebase Admin if not already initialized
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount),
        databaseURL: "https://bio-track-de846-default-rtdb.europe-west1.firebasedatabase.app"
      });
    }
  }
  db = admin.firestore();
}

// Helper function to get proper timestamp based on Firebase mode
function getTimestamp(inputTimestamp = null) {
  if (USE_MOCK_FIREBASE) {
    return inputTimestamp ? new Date(inputTimestamp).toISOString() : new Date().toISOString();
  } else {
    return inputTimestamp ? new Date(inputTimestamp) : admin.firestore.FieldValue.serverTimestamp();
  }
}

/**
 * Main Lambda handler for AWS IoT Core to Firebase bridge
 * Processes MQTT messages from AWS IoT and syncs data to Firebase Firestore
 */
exports.handler = async (event, context) => {
    console.log('AWS IoT to Firebase Bridge - Event:', JSON.stringify(event, null, 2));
    
    try {
        // Debug logging for health check
        console.log('Debug - httpMethod:', event.httpMethod);
        console.log('Debug - path:', event.path);
        console.log('Debug - rawPath:', event.rawPath);
        console.log('Debug - condition check:', event.httpMethod === 'GET' && (event.path === '/health' || event.rawPath === '/health'));
        
        // Handle health check for connectivity testing
        if (event.httpMethod === 'GET' && (event.path === '/health' || event.rawPath === '/health')) {
            console.log('Health check requested');
            return {
                statusCode: 200,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
                },
                body: JSON.stringify({
                    status: 'healthy',
                    message: 'AWS IoT Bridge is operational',
                    timestamp: new Date().toISOString(),
                    environment: USE_MOCK_FIREBASE ? 'development' : 'production',
                    version: '1.0.0'
                })
            };
        }

        // Handle OPTIONS requests (CORS preflight)
        if (event.httpMethod === 'OPTIONS') {
            return {
                statusCode: 200,
                headers: {
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
                    'Access-Control-Allow-Methods': 'GET,POST,OPTIONS'
                },
                body: ''
            };
        }        // Handle device commands (existing logic)
        if (event.httpMethod === 'POST') {
            return await handleAPIRequest(event);
        }

        // Handle direct IoT events
        if (event.topic) {
            await processIoTMessage(event);
            return {
                statusCode: 200,
                body: JSON.stringify({ message: 'Successfully processed IoT data' })
            };
        }

        console.log('Unknown event type:', event);
        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Invalid request type' })
        };
        
    } catch (error) {
        console.error('Error processing request:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ 
                error: 'Internal server error',
                message: error.message 
            })
        };
    }
};

/**
 * Process IoT MQTT message and sync to Firebase
 */
async function processIoTMessage(message) {
  console.log('Full IoT message received:', JSON.stringify(message, null, 2));
  
  const { topic, timestamp, deviceId } = message;
    // Extract the actual payload/data from the message
  // The IoT event contains the sensor data directly in the message object
  const payload = {};
  
  // Add all non-undefined values from the message, excluding system fields
  Object.entries(message).forEach(([key, value]) => {
    if (!['topic', 'timestamp', 'deviceId'].includes(key) && value !== undefined) {
      payload[key] = value;
    }
  });
  
  console.log(`Processing message from topic: ${topic}, device: ${deviceId}`);
  console.log('Extracted payload:', JSON.stringify(payload, null, 2));

  // Parse the topic to determine message type
  const topicParts = topic.split('/');
  const messageType = topicParts[topicParts.length - 1]; // telemetry, status, responses

  switch (messageType) {
    case 'telemetry':
      await processTelemetryData(payload, deviceId, timestamp);
      break;
    case 'status':
      await processDeviceStatus(payload, deviceId, timestamp);
      break;
    case 'responses':
      await processDeviceResponse(payload, deviceId, timestamp);
      break;
    case 'pairing':
      await processDevicePairing(payload, deviceId, timestamp);
      break;
    default:
      console.log(`Unknown message type: ${messageType}`);
  }
}

/**
 * Process sensor telemetry data with user-specific storage
 */
async function processTelemetryData(data, deviceId, timestamp) {
  try {
    console.log(`Processing telemetry data for device ${deviceId}`);
    
    // Step 1: Find which user owns this device
    const userId = await findDeviceOwner(deviceId);
    if (!userId) {
      console.log(`No user found for device ${deviceId}, storing in unassigned collection`);
      return await storeUnassignedSensorData(deviceId, data, timestamp);
    }
    
    console.log(`Device ${deviceId} belongs to user ${userId}`);
    
    // Step 2: Create a unique test session ID
    const testId = generateTestId();
    
    // Step 3: Prepare sensor data
    const sensorData = {
      deviceId: deviceId,
      timestamp: getTimestamp(timestamp),
      ...data,
      processed: false,
      source: 'aws_iot'
    };

    // Validate sensor data
    const validation = validateSensorData(sensorData);
    if (!validation.isValid) {
      console.error('Invalid sensor data:', validation.errors);
      return;
    }

    // Step 4: Store sensor data under the specific user
    const userSensorData = {
      deviceId: deviceId,
      testId: testId,
      timestamp: sensorData.timestamp,
      sensorData: data,
      testType: determineSensorType(data),
      processed: false,
      createdAt: getTimestamp(),
      userId: userId
    };
    
    // Store in user-specific collection
    let docRef;
    if (USE_MOCK_FIREBASE) {
      console.log(`Mock Firestore: Adding to users/${userId}/sensor_data collection`);
      console.log('User sensor data:', JSON.stringify(userSensorData, null, 2));
      docRef = { id: `mock_test_${Date.now()}` };
    } else {
      docRef = await db.collection('users').doc(userId)
                     .collection('sensor_data').doc(testId)
                     .set(userSensorData);
      console.log(`Stored sensor data for user ${userId} with test ID: ${testId}`);
    }
    
    // Step 5: Update user's test summary
    await updateUserTestSummary(userId, testId, data);
    
    // Step 6: Update device status
    await updateDeviceStatus(deviceId, 'active', timestamp);
    
    // Step 7: Check for health alerts
    await checkHealthAlerts(userSensorData, deviceId, userId);

    // Step 8: Update user health metrics
    await updateUserHealthMetrics(userId, sensorData);

    return docRef;
    
  } catch (error) {
    console.error('Error processing telemetry data:', error);
    throw error;
  }
}

/**
 * Process device status updates
 */
async function processDeviceStatus(data, deviceId, timestamp) {
  try {
    const statusUpdate = {
      deviceId: deviceId,
      timestamp: getTimestamp(timestamp),
      ...data,
      source: 'aws_iot'
    };

    await db.collection('devices').doc(deviceId).set(statusUpdate, { merge: true });
    
    // Store status history
    await db.collection('device_status_history').add({
      ...statusUpdate,
      timestamp: getTimestamp()
    });

    console.log(`Updated device status for ${deviceId}:`, data.status);

  } catch (error) {
    console.error('Error processing device status:', error);
    throw error;
  }
}

/**
 * Process device command responses
 */
async function processDeviceResponse(data, deviceId, timestamp) {
  try {
    const responseData = {
      deviceId: deviceId,
      timestamp: getTimestamp(timestamp),
      ...data,
      source: 'aws_iot'
    };

    await db.collection('device_responses').add(responseData);

    // If this is a pairing response, update device-user association
    if (data.command === 'pair' && data.status === 'success' && data.userId) {
      await db.collection('devices').doc(deviceId).update({
        userId: data.userId,
        pairedAt: getTimestamp(),
        status: 'paired'
      });

      await db.collection('users').doc(data.userId).update({
        [`devices.${deviceId}`]: {
          deviceId: deviceId,
          pairedAt: getTimestamp(),
          status: 'active'
        }
      });
    }

    console.log(`Processed device response for ${deviceId}:`, data.command);

  } catch (error) {
    console.error('Error processing device response:', error);
    throw error;
  }
}

/**
 * Process device pairing requests
 */
async function processDevicePairing(data, deviceId, timestamp) {
  try {
    const { userId, pairingCode } = data;

    // Validate pairing code (implement your own logic)
    const isValidPairing = await validatePairingCode(userId, pairingCode, deviceId);
    
    if (isValidPairing) {
      // Update device with user association
      await db.collection('devices').doc(deviceId).update({
        userId: userId,
        pairedAt: getTimestamp(),
        status: 'paired'
      });

      // Update user with device association
      await db.collection('users').doc(userId).update({
        [`devices.${deviceId}`]: {
          deviceId: deviceId,
          pairedAt: getTimestamp(),
          status: 'active'
        }
      });

      console.log(`Successfully paired device ${deviceId} with user ${userId}`);
    } else {
      console.error(`Invalid pairing attempt for device ${deviceId} and user ${userId}`);
    }

  } catch (error) {
    console.error('Error processing device pairing:', error);
    throw error;
  }
}

/**
 * Update user health metrics based on sensor data
 */
async function updateUserHealthMetrics(userId, sensorData) {
  try {
    const userMetricsRef = db.collection('users').doc(userId).collection('health_metrics');
    
    // Create individual metric documents for each sensor reading
    const metricsToStore = [];

    if (sensorData.temperature) {
      metricsToStore.push({
        type: 'temperature',
        value: sensorData.temperature,
        unit: '°C',
        timestamp: sensorData.timestamp,
        deviceId: sensorData.deviceId
      });
    }

    if (sensorData.weight) {
      metricsToStore.push({
        type: 'weight',
        value: sensorData.weight,
        unit: 'kg',
        timestamp: sensorData.timestamp,
        deviceId: sensorData.deviceId
      });
    }

    if (sensorData.heartRate) {
      metricsToStore.push({
        type: 'heart_rate',
        value: sensorData.heartRate,
        unit: 'bpm',
        timestamp: sensorData.timestamp,
        deviceId: sensorData.deviceId
      });
    }

    if (sensorData.bioimpedance) {
      metricsToStore.push({
        type: 'bioimpedance',
        value: sensorData.bioimpedance.impedance,
        unit: 'ohms',
        bodyFat: sensorData.bioimpedance.bodyFat,
        muscleMass: sensorData.bioimpedance.muscleMass,
        timestamp: sensorData.timestamp,
        deviceId: sensorData.deviceId
      });
    }

    if (sensorData.spO2) {
      metricsToStore.push({
        type: 'spo2',
        value: sensorData.spO2,
        unit: '%',
        timestamp: sensorData.timestamp,
        deviceId: sensorData.deviceId
      });
    }

    // Store all metrics
    const batch = db.batch();
    metricsToStore.forEach(metric => {
      const docRef = userMetricsRef.doc();
      batch.set(docRef, {
        ...metric,
        id: docRef.id,
        createdAt: getTimestamp()
      });
    });

    await batch.commit();
    console.log(`Updated health metrics for user ${userId} with ${metricsToStore.length} readings`);

  } catch (error) {
    console.error('Error updating user health metrics:', error);
    throw error;
  }
}

/**
 * Check for health alerts based on sensor data with user-specific storage
 */
async function checkHealthAlerts(sensorData, deviceId, userId) {
  try {
    const alerts = [];
    const data = sensorData.sensorData || sensorData;

    // Temperature alerts
    if (data.temperature) {
      if (data.temperature < 36.0 || data.temperature > 38.0) {
        alerts.push({
          type: 'temperature_abnormal',
          severity: data.temperature < 35.0 || data.temperature > 39.0 ? 'high' : 'medium',
          value: data.temperature,
          message: `Abnormal body temperature: ${data.temperature}°C`,
          timestamp: getTimestamp(),
          deviceId: deviceId
        });
      }
    }

    // Heart rate alerts
    if (data.heartRate) {
      if (data.heartRate < 50 || data.heartRate > 120) {
        alerts.push({
          type: 'heart_rate_abnormal',
          severity: data.heartRate < 40 || data.heartRate > 150 ? 'high' : 'medium',
          value: data.heartRate,
          message: `Abnormal heart rate: ${data.heartRate} BPM`,
          timestamp: getTimestamp(),
          deviceId: deviceId
        });
      }
    }

    // SpO2 alerts
    if (data.spO2) {
      if (data.spO2 < 95) {
        alerts.push({
          type: 'spo2_low',
          severity: data.spO2 < 90 ? 'high' : 'medium',
          value: data.spO2,
          message: `Low blood oxygen saturation: ${data.spO2}%`,
          timestamp: getTimestamp(),
          deviceId: deviceId
        });
      }
    }

    // Store alerts if any
    if (alerts.length > 0) {
      if (USE_MOCK_FIREBASE) {
        console.log(`Mock Firestore: Created ${alerts.length} health alerts for user ${userId}`, alerts);
      } else {
        // Store in user-specific health alerts collection
        for (const alert of alerts) {
          await db.collection('users').doc(userId)
                 .collection('health_alerts').add(alert);
        }
        console.log(`Created ${alerts.length} health alerts for user ${userId}`);
      }
    }

    return alerts;

  } catch (error) {
    console.error('Error checking health alerts:', error);
    return [];
  }
}

/**
 * Validate sensor data
 */
function validateSensorData(data) {
  const errors = [];

  if (!data.deviceId) {
    errors.push('Device ID is required');
  }

  if (data.temperature && (data.temperature < 30 || data.temperature > 45)) {
    errors.push('Temperature out of valid range (30-45°C)');
  }

  if (data.heartRate && (data.heartRate < 30 || data.heartRate > 250)) {
    errors.push('Heart rate out of valid range (30-250 BPM)');
  }

  if (data.weight && (data.weight < 0 || data.weight > 500)) {
    errors.push('Weight out of valid range (0-500 kg)');
  }

  if (data.spO2 && (data.spO2 < 0 || data.spO2 > 100)) {
    errors.push('SpO2 out of valid range (0-100%)');
  }

  return {
    isValid: errors.length === 0,
    errors: errors
  };
}

/**
 * Validate pairing code (implement your custom logic)
 */
async function validatePairingCode(userId, pairingCode, deviceId) {
  try {
    // Check if user exists
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) {
      return false;
    }

    // Check if pairing code is valid (you can implement QR code validation, etc.)
    // For now, we'll use a simple check
    const validCode = `${userId}-${deviceId}`.substring(0, 8);
    return pairingCode === validCode;

  } catch (error) {
    console.error('Error validating pairing code:', error);
    return false;
  }
}

/**
 * Handle API Gateway requests (for device commands from mobile app)
 */
async function handleAPIRequest(event) {
  const { httpMethod, path, body } = event;
  
  if (httpMethod === 'POST' && path === '/device/command') {
    return await sendDeviceCommand(JSON.parse(body));
  }
  
  return {
    statusCode: 404,
    body: JSON.stringify({ error: 'Not found' })
  };
}

/**
 * Send command to device via AWS IoT Core
 */
async function sendDeviceCommand(commandData) {
  const AWS = require('aws-sdk');
  const iotData = new AWS.IotData({
    endpoint: process.env.AWS_IOT_ENDPOINT
  });
  try {
    const { deviceId, command, parameters } = commandData;
    
    console.log(`Checking connectivity for device: ${deviceId}`);
    
    // First check if device is online by checking device shadow or recent activity
    const isDeviceOnline = await checkDeviceOnlineStatus(deviceId);
    
    console.log(`Device ${deviceId} online status: ${isDeviceOnline}`);
    
    if (!isDeviceOnline) {
      console.log(`Device ${deviceId} is not online - returning 404`);
      return {
        statusCode: 404,
        body: JSON.stringify({ 
          error: 'Device not found',
          message: `Device ${deviceId} is not online or not connected`,
          deviceId: deviceId
        })
      };
    }
    
    console.log(`Device ${deviceId} is online - proceeding with command ${command}`);
    
    const payload = {
      command: command,
      parameters: parameters || {},
      timestamp: getTimestamp(),
      requestId: uuidv4()
    };

    const params = {
      topic: `biotrack/device/${deviceId}/commands`,
      payload: JSON.stringify(payload),
      qos: 1
    };

    await iotData.publish(params).promise();
    
    console.log(`Sent command ${command} to device ${deviceId}`);
    
    return {
      statusCode: 200,
      body: JSON.stringify({ 
        message: 'Command sent successfully',
        requestId: payload.requestId,
        deviceId: deviceId
      })
    };

  } catch (error) {
    console.error('Error sending device command:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
}

/**
 * Check if device is online by checking AWS IoT Thing Shadow only
 * Firebase is only used for user data storage, not device status
 */
async function checkDeviceOnlineStatus(deviceId) {
  try {
    console.log(`Starting AWS IoT connectivity check for device: ${deviceId}`);
    
    // Check if device has reported activity recently (within last 5 minutes)
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000);
    console.log(`Checking for IoT activity since: ${fiveMinutesAgo.toISOString()}`);
    
    // Use AWS IoT Data API to check device shadow
    const AWS = require('aws-sdk');
    const iotData = new AWS.IotData({
      endpoint: process.env.AWS_IOT_ENDPOINT
    });
    
    try {
      console.log(`Checking AWS IoT Thing Shadow for device: ${deviceId}`);
      
      const shadowParams = {
        thingName: deviceId
      };
      
      const shadowResult = await iotData.getThingShadow(shadowParams).promise();
      const shadow = JSON.parse(shadowResult.payload);
      
      console.log(`Device shadow retrieved successfully:`, JSON.stringify(shadow, null, 2));
      
      // Check device connection status from shadow
      const reportedState = shadow.state?.reported;
      const metadata = shadow.metadata?.reported;
      
      if (reportedState) {
        const connected = reportedState.connected;
        const lastActivity = reportedState.lastActivity || reportedState.timestamp;
        
        console.log(`Device ${deviceId} reported state - connected: ${connected}, lastActivity: ${lastActivity}`);
        
        // Check if device is connected and recently active
        if (connected) {
          // Check last activity timestamp
          let lastActivityDate;
          if (lastActivity) {
            // Handle different timestamp formats
            lastActivityDate = typeof lastActivity === 'number' 
              ? new Date(lastActivity < 10000000000 ? lastActivity * 1000 : lastActivity)  // Handle seconds vs milliseconds
              : new Date(lastActivity);
          } else if (metadata?.connected?.timestamp) {
            // Use metadata timestamp as fallback
            lastActivityDate = new Date(metadata.connected.timestamp * 1000);
          } else {
            console.log(`No timestamp available for device ${deviceId}`);
            return false;
          }
          
          const isRecentlyActive = lastActivityDate > fiveMinutesAgo;
          
          console.log(`Device ${deviceId} last activity: ${lastActivityDate.toISOString()}, recently active: ${isRecentlyActive}`);
          
          if (isRecentlyActive) {
            console.log(`Device ${deviceId} is ONLINE - connected and recently active`);
            return true;
          } else {
            console.log(`Device ${deviceId} is OFFLINE - connected but not recently active`);
            return false;
          }
        } else {
          console.log(`Device ${deviceId} is OFFLINE - not connected`);
          return false;
        }
      } else {
        console.log(`Device ${deviceId} shadow has no reported state`);
        return false;
      }
      
    } catch (shadowError) {
      console.log(`AWS IoT Thing Shadow not found for ${deviceId}:`, shadowError.message);
      
      // For new devices, shadow might not exist yet - this is normal
      if (shadowError.code === 'ResourceNotFoundException') {
        console.log(`Device ${deviceId} shadow doesn't exist yet - assuming offline`);
      }
      
      return false;
    }
    
  } catch (error) {
    console.error(`Error checking device ${deviceId} AWS IoT status:`, error);
    return false; // Assume offline if we can't determine status
  }
}

/**
 * Find which user owns a specific device
 */
async function findDeviceOwner(deviceId) {
  try {
    console.log(`Looking up owner for device: ${deviceId}`);
    
    if (USE_MOCK_FIREBASE) {
      console.log(`Mock Firestore: Looking up owner for device ${deviceId}`);
      // Mock response - in real scenario, this would be the actual user ID
      return 'mock_user_123';
    }
    
    // Method 1: Check device_pairings collection
    const pairingQuery = await db.collection('device_pairings')
                               .where('deviceId', '==', deviceId)
                               .where('status', '==', 'paired')
                               .limit(1)
                               .get();
    
    if (!pairingQuery.empty) {
      const pairingDoc = pairingQuery.docs[0];
      const userId = pairingDoc.data().userId;
      console.log(`Found owner via pairing: ${userId}`);
      return userId;
    }
    
    // Method 2: Check devices collection directly
    const deviceDoc = await db.collection('devices').doc(deviceId).get();
    if (deviceDoc.exists) {
      const deviceData = deviceDoc.data();
      const userId = deviceData.userId || deviceData.ownerId;
      if (userId) {
        console.log(`Found owner via device doc: ${userId}`);
        return userId;
      }
    }
    
    console.log(`No owner found for device: ${deviceId}`);
    return null;
    
  } catch (error) {
    console.error('Error finding device owner:', error);
    return null;
  }
}

/**
 * Store sensor data from unassigned devices
 */
async function storeUnassignedSensorData(deviceId, data, timestamp) {
  try {
    const unassignedData = {
      deviceId: deviceId,
      timestamp: getTimestamp(timestamp),
      sensorData: data,
      status: 'unassigned',
      needsAssignment: true,
      createdAt: getTimestamp()
    };
    
    if (USE_MOCK_FIREBASE) {
      console.log('Mock Firestore: Stored unassigned sensor data', unassignedData);
      return { id: `mock_unassigned_${Date.now()}` };
    } else {
      const docRef = await db.collection('unassigned_sensor_data').add(unassignedData);
      console.log(`Stored unassigned sensor data with ID: ${docRef.id}`);
      return docRef;
    }
  } catch (error) {
    console.error('Error storing unassigned sensor data:', error);
    throw error;
  }
}

/**
 * Update user's test summary
 */
async function updateUserTestSummary(userId, testId, sensorData) {
  try {
    const testSummary = {
      testId: testId,
      timestamp: getTimestamp(),
      sensorTypes: Object.keys(sensorData),
      status: 'completed',
      lastUpdated: getTimestamp()
    };
    
    if (USE_MOCK_FIREBASE) {
      console.log(`Mock Firestore: Updated test summary for user ${userId}`, testSummary);
    } else {
      // Update user's test history
      await db.collection('users').doc(userId)
             .collection('test_history').doc(testId)
             .set(testSummary);
      
      // Update user's latest activity
      await db.collection('users').doc(userId).update({
        lastTestDate: getTimestamp(),
        lastTestId: testId,
        totalTests: admin.firestore.FieldValue.increment(1)
      });
      
      console.log(`Updated test summary for user ${userId}`);
    }
  } catch (error) {
    console.error('Error updating user test summary:', error);
  }
}

/**
 * Update device status
 */
async function updateDeviceStatus(deviceId, status, timestamp) {
  try {
    const statusUpdate = {
      lastSeen: getTimestamp(timestamp),
      status: status,
      source: 'aws_iot'
    };
    
    if (USE_MOCK_FIREBASE) {
      console.log(`Mock Firestore: Updated device ${deviceId} status to ${status}`);
    } else {
      await db.collection('devices').doc(deviceId).set(statusUpdate, { merge: true });
      console.log(`Updated device ${deviceId} status to ${status}`);
    }
  } catch (error) {
    console.error('Error updating device status:', error);
  }
}

/**
 * Generate unique test ID
 */
function generateTestId() {
  const timestamp = Date.now();
  const random = Math.random().toString(36).substring(2, 8);
  return `test_${timestamp}_${random}`;
}

/**
 * Determine sensor type from data
 */
function determineSensorType(sensorData) {
  const sensors = Object.keys(sensorData);
  if (sensors.length === 1) {
    return sensors[0];
  } else if (sensors.length > 1) {
    return 'multi_sensor';
  }
  return 'unknown';
}
