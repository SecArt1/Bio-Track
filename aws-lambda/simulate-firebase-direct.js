#!/usr/bin/env node

/**
 * Direct Firebase ESP32 Simulation
 * 
 * This script directly updates Firebase Realtime Database to simulate
 * what the ESP32 device and Lambda function would do, triggering
 * real-time updates in the mobile app.
 */

const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin SDK
const serviceAccountPath = path.join(__dirname, '..', 'bio-track-de846-firebase-adminsdk-fbsvc-093069fb20.json');

if (!fs.existsSync(serviceAccountPath)) {
  console.error('❌ Firebase service account key not found at:', serviceAccountPath);
  console.error('📁 Please ensure the Firebase service account JSON file is in the project root');
  process.exit(1);
}

const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: 'https://bio-track-de846-default-rtdb.firebaseio.com/'
});

const db = admin.database();

// Configuration
const config = {
  deviceId: 'biotrack_device_001',
  userId: 'FUbmmZXxY0OdJolvrQXP0JxMjmW2'
};

console.log('🔥 Direct Firebase ESP32 Simulation');
console.log('📱 This will update Firebase Realtime Database directly');
console.log('🎯 Mobile app should receive real-time updates');
console.log('─'.repeat(60));

// Update device status
async function updateDeviceStatus() {
  console.log('\n🔧 Updating device status...');
  
  const statusData = {
    status: 'online',
    timestamp: admin.database.ServerValue.TIMESTAMP,
    battery_level: 87,
    signal_strength: -42,
    firmware_version: '1.2.3',
    uptime: 3600000,
    last_seen: new Date().toISOString()
  };

  try {
    await db.ref(`devices/${config.deviceId}/status`).set(statusData);
    console.log('✅ Device status updated in Firebase');
    return true;
  } catch (error) {
    console.error('❌ Failed to update device status:', error.message);
    return false;
  }
}

// Send sensor data
async function sendSensorData(sensorType, value, unit, additionalData = {}) {
  console.log(`\n📊 Sending ${sensorType} data: ${value} ${unit}`);
  
  const sensorData = {
    sensor_type: sensorType,
    value: value,
    unit: unit,
    timestamp: admin.database.ServerValue.TIMESTAMP,
    device_id: config.deviceId,
    quality: 'good',
    session_id: `sim_${Date.now()}`,
    ...additionalData
  };

  try {
    // Update latest sensor data
    await db.ref(`devices/${config.deviceId}/sensor_data`).set(sensorData);
    
    // Add to sensor history
    await db.ref(`devices/${config.deviceId}/sensor_history`).push(sensorData);
    
    // Update user's health data
    const userHealthPath = `users/${config.userId}/health_data/${sensorType}`;
    await db.ref(userHealthPath).set({
      latest_value: value,
      unit: unit,
      timestamp: admin.database.ServerValue.TIMESTAMP,
      source: 'device',
      device_id: config.deviceId
    });
    
    console.log(`✅ ${sensorType} data updated in Firebase`);
    return true;
  } catch (error) {
    console.error(`❌ Failed to send ${sensorType} data:`, error.message);
    return false;
  }
}

// Send complete health screening
async function sendHealthScreening() {
  console.log('\n🏥 Sending complete health screening...');
  
  const screeningId = `screening_${Date.now()}`;
  const screeningData = {
    screening_id: screeningId,
    device_id: config.deviceId,
    user_id: config.userId,
    timestamp: admin.database.ServerValue.TIMESTAMP,
    screening_type: 'full_health_check',
    status: 'completed',
    duration: 300,
    results: {
      temperature: { value: 36.8, unit: '°C', status: 'normal' },
      heart_rate: { value: 72, unit: 'bpm', status: 'normal' },
      weight: { value: 70.5, unit: 'kg', status: 'normal' },
      body_fat: { value: 18.5, unit: '%', status: 'good' },
      spo2: { value: 98, unit: '%', status: 'excellent' },
      muscle_mass: { value: 52.3, unit: 'kg', status: 'good' }
    },
    notes: 'Direct Firebase simulation'
  };

  try {
    // Add to screening history
    await db.ref(`users/${config.userId}/health_screenings`).push(screeningData);
    
    // Update latest screening
    await db.ref(`users/${config.userId}/latest_screening`).set(screeningData);
    
    console.log('✅ Health screening saved to Firebase');
    return true;
  } catch (error) {
    console.error('❌ Failed to save health screening:', error.message);
    return false;
  }
}

// Create test notifications
async function sendTestNotification() {
  console.log('\n🔔 Creating test notification...');
  
  const notification = {
    id: `notif_${Date.now()}`,
    title: 'Health Data Updated',
    message: 'New sensor readings available from your BioTrack device',
    type: 'health_update',
    timestamp: admin.database.ServerValue.TIMESTAMP,
    read: false,
    data: {
      device_id: config.deviceId,
      sensor_count: 5
    }
  };

  try {
    await db.ref(`users/${config.userId}/notifications`).push(notification);
    console.log('✅ Test notification created');
    return true;
  } catch (error) {
    console.error('❌ Failed to create notification:', error.message);
    return false;
  }
}

// Main simulation function
async function runSimulation() {
  try {
    console.log('🚀 Starting direct Firebase simulation...');
    
    // Step 1: Update device status
    await updateDeviceStatus();
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Step 2: Send temperature data
    await sendSensorData('temperature', 36.8, '°C', {
      calibration_status: 'calibrated',
      ambient_temp: 22.5
    });
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Step 3: Send heart rate data
    await sendSensorData('heart_rate', 72, 'bpm', {
      rhythm: 'regular',
      confidence: 95,
      measurement_duration: 30
    });
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Step 4: Send weight data
    await sendSensorData('weight', 70.5, 'kg', {
      stability: 'stable',
      calibration_offset: 0.0
    });
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Step 5: Send bioimpedance data
    await sendSensorData('bioimpedance', 18.5, '%', {
      body_fat_percentage: 18.5,
      muscle_mass: 52.3,
      bone_mass: 3.2,
      water_percentage: 62.1,
      metabolic_age: 25
    });
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Step 6: Send SpO2 data
    await sendSensorData('spo2', 98, '%', {
      pulse_strength: 'strong',
      perfusion_index: 5.2,
      measurement_time: 15
    });
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Step 7: Send complete health screening
    await sendHealthScreening();
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    // Step 8: Create test notification
    await sendTestNotification();
    
    console.log('\n🎉 Simulation completed successfully!');
    console.log('📱 Check your mobile app for real-time updates');
    console.log('🔥 Data has been written to Firebase Realtime Database:');
    console.log(`   • devices/${config.deviceId}/sensor_data`);
    console.log(`   • devices/${config.deviceId}/status`);
    console.log(`   • users/${config.userId}/health_data`);
    console.log(`   • users/${config.userId}/health_screenings`);
    console.log(`   • users/${config.userId}/notifications`);
    
    console.log('\n📊 Mobile app should show:');
    console.log('   • Live sensor data updates in testing screen');
    console.log('   • Device status changes');
    console.log('   • New health screening results');
    console.log('   • Push notifications');
    
  } catch (error) {
    console.error('❌ Simulation failed:', error);
  } finally {
    process.exit(0);
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Simulation stopped by user');
  process.exit(0);
});

// Start simulation
runSimulation();
