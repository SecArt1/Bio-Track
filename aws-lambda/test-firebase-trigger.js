#!/usr/bin/env node

/**
 * Simple ESP32 Firebase Test
 * 
 * This script sends realistic ESP32 sensor data that will trigger
 * the Lambda function to update Firebase Realtime Database,
 * which the mobile app is listening to.
 */

const https = require('https');

// Test configuration
const TEST_CONFIG = {
  deviceId: 'biotrack_device_001',
  userId: 'FUbmmZXxY0OdJolvrQXP0JxMjmW2', // Use the actual user ID from the error logs
  apiUrl: '5yg8qfthgb.execute-api.us-east-1.amazonaws.com',
  path: '/prod'
};

console.log('🧪 ESP32 to Firebase Test Script');
console.log('📱 This will simulate ESP32 sensor data that appears in the mobile app');
console.log('─'.repeat(60));

// Make HTTP request to Lambda
function sendToLambda(endpoint, data) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(data);
    
    const options = {
      hostname: TEST_CONFIG.apiUrl,
      port: 443,
      path: `${TEST_CONFIG.path}${endpoint}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'User-Agent': 'ESP32-BioTrack-Simulator/1.0',
        'X-Device-ID': TEST_CONFIG.deviceId
      }
    };

    console.log(`🌐 Sending to: https://${TEST_CONFIG.apiUrl}${TEST_CONFIG.path}${endpoint}`);
    console.log(`📤 Data: ${postData}`);

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => body += chunk);
      
      res.on('end', () => {
        console.log(`📊 Response Status: ${res.statusCode}`);
        console.log(`📋 Response Body: ${body}`);
        
        if (res.statusCode >= 200 && res.statusCode < 300) {
          resolve({ status: res.statusCode, data: body });
        } else {
          reject(new Error(`HTTP ${res.statusCode}: ${body}`));
        }
      });
    });

    req.on('error', (err) => {
      console.error(`❌ Request Error: ${err.message}`);
      reject(err);
    });

    req.write(postData);
    req.end();
  });
}

// Test 1: Send device status (this should trigger Firebase Realtime Database update)
async function testDeviceStatus() {
  console.log('\n🔧 Test 1: Device Status Update');
  
  const statusData = {
    deviceId: TEST_CONFIG.deviceId,
    userId: TEST_CONFIG.userId,
    status: 'online',
    timestamp: Date.now(),
    battery: 87,
    signal_strength: -42,
    firmware_version: '1.2.3'
  };

  try {
    await sendToLambda('/device/status', statusData);
    console.log('✅ Device status sent successfully');
  } catch (error) {
    console.error('❌ Device status failed:', error.message);
  }
}

// Test 2: Send sensor data (this should appear in the mobile app)
async function testSensorData(sensorType, value, unit) {
  console.log(`\n📊 Test 2: ${sensorType.toUpperCase()} Sensor Data`);
  
  const sensorData = {
    deviceId: TEST_CONFIG.deviceId,
    userId: TEST_CONFIG.userId,
    sensor_type: sensorType,
    value: value,
    unit: unit,
    timestamp: Date.now(),
    quality: 'good',
    session_id: `test_${Date.now()}`
  };

  try {
    await sendToLambda('/sensor/data', sensorData);
    console.log(`✅ ${sensorType} data sent successfully`);
  } catch (error) {
    console.error(`❌ ${sensorType} data failed:`, error.message);
  }
}

// Test 3: Send complete health screening data
async function testHealthScreening() {
  console.log('\n🏥 Test 3: Complete Health Screening');
  
  const screeningData = {
    deviceId: TEST_CONFIG.deviceId,
    userId: TEST_CONFIG.userId,
    timestamp: Date.now(),
    screening_type: 'full_health_check',
    results: {
      temperature: { value: 36.7, unit: '°C' },
      heart_rate: { value: 72, unit: 'bpm' },
      weight: { value: 70.5, unit: 'kg' },
      body_fat: { value: 18.2, unit: '%' },
      spo2: { value: 98, unit: '%' }
    },
    status: 'completed'
  };

  try {
    await sendToLambda('/health/screening', screeningData);
    console.log('✅ Health screening sent successfully');
  } catch (error) {
    console.error('❌ Health screening failed:', error.message);
  }
}

// Run all tests sequentially
async function runTests() {
  try {
    console.log('🚀 Starting ESP32 to Firebase simulation...');
    
    // Test device status
    await testDeviceStatus();
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test individual sensors
    await testSensorData('temperature', 36.8, '°C');
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    await testSensorData('heart_rate', 75, 'bpm');
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    await testSensorData('weight', 68.5, 'kg');
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    await testSensorData('bioimpedance', 22.1, '%');
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    await testSensorData('spo2', 97, '%');
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Test complete screening
    await testHealthScreening();
    
    console.log('\n🎉 All tests completed!');
    console.log('📱 Check your mobile app for the sensor data updates');
    console.log('🔥 Data should appear in Firebase Realtime Database under:');
    console.log(`   - devices/${TEST_CONFIG.deviceId}/sensor_data`);
    console.log(`   - devices/${TEST_CONFIG.deviceId}/status`);
    console.log(`   - users/${TEST_CONFIG.userId}/health_data`);
    
  } catch (error) {
    console.error('❌ Test execution failed:', error);
    process.exit(1);
  }
}

// Start the tests
runTests();
