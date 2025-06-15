#!/usr/bin/env node

/**
 * ESP32 Sensor Data Simulation Script
 * 
 * This script simulates an ESP32 device sending sensor data to AWS IoT Core,
 * which then triggers the Lambda function to process and store data in Firebase.
 * 
 * Usage:
 * node test-esp32-simulation.js [options]
 * 
 * Options:
 * --device-id <id>     Device ID (default: biotrack_device_001)
 * --user-id <id>       User ID for Firebase (default: test_user_123)
 * --continuous         Run continuous simulation
 * --interval <ms>      Interval between readings in ms (default: 5000)
 * --sensors <list>     Comma-separated list of sensors (default: all)
 */

const https = require('https');
const crypto = require('crypto');

// Configuration
const config = {
  baseUrl: 'https://5yg8qfthgb.execute-api.us-east-1.amazonaws.com/prod',
  deviceId: 'biotrack_device_001',
  userId: 'test_user_123',
  continuous: false,
  interval: 5000,
  sensors: ['temperature', 'weight', 'bioimpedance', 'heart_rate', 'spo2']
};

// Parse command line arguments
const args = process.argv.slice(2);
for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '--device-id':
      config.deviceId = args[++i];
      break;
    case '--user-id':
      config.userId = args[++i];
      break;
    case '--continuous':
      config.continuous = true;
      break;
    case '--interval':
      config.interval = parseInt(args[++i]);
      break;
    case '--sensors':
      config.sensors = args[++i].split(',');
      break;
    case '--help':
      console.log(`
ESP32 Sensor Data Simulation Script

Usage: node test-esp32-simulation.js [options]

Options:
  --device-id <id>     Device ID (default: ${config.deviceId})
  --user-id <id>       User ID for Firebase (default: ${config.userId})
  --continuous         Run continuous simulation
  --interval <ms>      Interval between readings in ms (default: ${config.interval})
  --sensors <list>     Comma-separated list of sensors (default: all)
  --help              Show this help message

Available sensors: temperature, weight, bioimpedance, heart_rate, spo2
      `);
      process.exit(0);
  }
}

// Sensor data generators
const sensorGenerators = {
  temperature: () => ({
    sensor_type: 'temperature',
    value: (36.0 + Math.random() * 2.0), // 36.0-38.0°C
    unit: '°C',
    quality: 'good',
    calibration_status: 'calibrated'
  }),
  
  weight: () => ({
    sensor_type: 'weight',
    value: (50 + Math.random() * 100), // 50-150 kg
    unit: 'kg',
    quality: 'good',
    stability: 'stable'
  }),
  
  bioimpedance: () => ({
    sensor_type: 'bioimpedance',
    value: (15 + Math.random() * 20), // 15-35% body fat
    unit: '%',
    quality: 'good',
    body_fat_percentage: (15 + Math.random() * 20),
    muscle_mass: (40 + Math.random() * 20),
    bone_mass: (2 + Math.random() * 2),
    water_percentage: (55 + Math.random() * 10)
  }),
  
  heart_rate: () => ({
    sensor_type: 'heart_rate',
    value: (60 + Math.random() * 40), // 60-100 bpm
    unit: 'bpm',
    quality: 'good',
    rhythm: 'regular',
    confidence: (85 + Math.random() * 15)
  }),
  
  spo2: () => ({
    sensor_type: 'spo2',
    value: (95 + Math.random() * 5), // 95-100%
    unit: '%',
    quality: 'good',
    pulse_strength: 'strong',
    perfusion_index: (2 + Math.random() * 8)
  })
};

// Generate realistic ESP32 sensor data
function generateSensorData(sensorType) {
  const generator = sensorGenerators[sensorType];
  if (!generator) {
    throw new Error(`Unknown sensor type: ${sensorType}`);
  }
  
  const baseData = generator();
  
  return {
    ...baseData,
    timestamp: Date.now(),
    device_id: config.deviceId,
    session_id: crypto.randomUUID(),
    firmware_version: "1.2.3",
    battery_level: 85 + Math.random() * 15,
    signal_strength: -45 - Math.random() * 30,
    location: {
      latitude: 30.0444 + (Math.random() - 0.5) * 0.01,
      longitude: 31.2357 + (Math.random() - 0.5) * 0.01
    }
  };
}

// Simulate ESP32 device status update
function generateDeviceStatus() {
  return {
    device_id: config.deviceId,
    status: 'online',
    timestamp: Date.now(),
    uptime: Math.floor(Math.random() * 86400000), // Up to 24 hours
    free_memory: Math.floor(200000 + Math.random() * 100000),
    wifi_strength: -45 - Math.random() * 30,
    firmware_version: "1.2.3",
    last_reboot_reason: 'power_on',
    sensors_active: config.sensors.length,
    error_count: Math.floor(Math.random() * 3)
  };
}

// Send HTTP request
function makeRequest(path, data) {
  return new Promise((resolve, reject) => {
    const postData = JSON.stringify(data);
    
    const options = {
      hostname: '5yg8qfthgb.execute-api.us-east-1.amazonaws.com',
      port: 443,
      path: `/prod${path}`,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData),
        'User-Agent': 'ESP32-BioTrack/1.2.3',
        'X-Device-ID': config.deviceId
      }
    };

    const req = https.request(options, (res) => {
      let body = '';
      res.on('data', (chunk) => {
        body += chunk;
      });
      
      res.on('end', () => {
        console.log(`📡 ${path} - Status: ${res.statusCode}`);
        if (res.statusCode >= 400) {
          console.log(`❌ Error Response: ${body}`);
        } else {
          console.log(`✅ Success Response: ${body}`);
        }
        resolve({ statusCode: res.statusCode, body });
      });
    });

    req.on('error', (err) => {
      console.error(`❌ Request failed: ${err.message}`);
      reject(err);
    });

    req.write(postData);
    req.end();
  });
}

// Simulate device registration
async function simulateDeviceRegistration() {
  console.log('🔧 Simulating device registration...');
  
  const registrationData = {
    device_id: config.deviceId,
    user_id: config.userId,
    device_type: 'biotrack_v2',
    firmware_version: '1.2.3',
    pairing_code: '123456',
    timestamp: Date.now(),
    capabilities: config.sensors,
    hardware_revision: 'B',
    serial_number: `BT${Date.now().toString().slice(-8)}`
  };
  
  try {
    await makeRequest('/device/register', registrationData);
  } catch (error) {
    console.error('Device registration failed:', error.message);
  }
}

// Simulate sensor data transmission
async function simulateSensorData(sensorType) {
  console.log(`📊 Simulating ${sensorType} sensor data...`);
  
  const sensorData = generateSensorData(sensorType);
  
  try {
    await makeRequest('/sensor/data', sensorData);
  } catch (error) {
    console.error(`${sensorType} data transmission failed:`, error.message);
  }
}

// Simulate device status update
async function simulateDeviceStatus() {
  console.log('📱 Simulating device status update...');
  
  const statusData = generateDeviceStatus();
  
  try {
    await makeRequest('/device/status', statusData);
  } catch (error) {
    console.error('Device status update failed:', error.message);
  }
}

// Simulate full health screening
async function simulateFullScreening() {
  console.log('🏥 Simulating full health screening...');
  
  const screeningData = {
    device_id: config.deviceId,
    user_id: config.userId,
    screening_id: crypto.randomUUID(),
    timestamp: Date.now(),
    screening_type: 'full_health_check',
    duration: 300, // 5 minutes
    sensors: config.sensors,
    notes: 'Automated full screening simulation'
  };
  
  try {
    await makeRequest('/screening/start', screeningData);
    
    // Simulate data from each sensor during screening
    for (const sensor of config.sensors) {
      await new Promise(resolve => setTimeout(resolve, 1000)); // 1 second delay
      await simulateSensorData(sensor);
    }
    
    // Mark screening as complete
    const completionData = {
      ...screeningData,
      status: 'completed',
      completion_timestamp: Date.now()
    };
    
    await makeRequest('/screening/complete', completionData);
    
  } catch (error) {
    console.error('Full screening simulation failed:', error.message);
  }
}

// Main simulation function
async function runSimulation() {
  console.log('🚀 Starting ESP32 Sensor Data Simulation');
  console.log(`📋 Configuration:`, config);
  console.log('─'.repeat(60));
  
  try {
    // Step 1: Register device
    await simulateDeviceRegistration();
    await new Promise(resolve => setTimeout(resolve, 2000));
    
    // Step 2: Send device status
    await simulateDeviceStatus();
    await new Promise(resolve => setTimeout(resolve, 1000));
    
    if (config.continuous) {
      console.log('🔄 Starting continuous simulation...');
      
      const runCycle = async () => {
        // Send status update
        await simulateDeviceStatus();
        
        // Send sensor data
        for (const sensor of config.sensors) {
          await simulateSensorData(sensor);
          await new Promise(resolve => setTimeout(resolve, 500));
        }
      };
      
      // Run initial cycle
      await runCycle();
      
      // Set up interval for continuous simulation
      setInterval(runCycle, config.interval);
      
      console.log(`⏱️  Continuous simulation started with ${config.interval}ms interval`);
      console.log('Press Ctrl+C to stop');
      
    } else {
      // Single run simulation
      console.log('📊 Running single simulation cycle...');
      
      // Simulate full screening
      await simulateFullScreening();
      
      console.log('✅ Simulation completed successfully!');
      process.exit(0);
    }
    
  } catch (error) {
    console.error('❌ Simulation failed:', error);
    process.exit(1);
  }
}

// Handle graceful shutdown
process.on('SIGINT', () => {
  console.log('\n🛑 Simulation stopped by user');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n🛑 Simulation terminated');
  process.exit(0);
});

// Start simulation
runSimulation().catch(error => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
