#!/usr/bin/env node

/**
 * ESP32 Firebase Direct Simulator
 * Directly updates Firebase Realtime Database to simulate ESP32 sensor data
 * This demonstrates the complete data flow that would be triggered by the Lambda function
 */

const https = require('https');

// Corrected Firebase configuration based on error response
const CONFIG = {
  DEVICE_ID: "biotrack-device-001",
  USER_ID: "FUbmmZXxY0OdJolvrQXP0JxMjmW2",
  FIREBASE_HOST: "bio-track-de846-default-rtdb.europe-west1.firebasedatabase.app"
};

class FirebaseSimulator {
  constructor() {
    this.deviceId = CONFIG.DEVICE_ID;
    this.userId = CONFIG.USER_ID;
  }

  // Generate realistic sensor data
  generateSensorData(sensorType) {
    const timestamp = Date.now();
    const baseData = {
      device_id: this.deviceId,
      user_id: this.userId,
      timestamp: timestamp
    };

    switch (sensorType) {
      case 'heart_rate':
        return {
          ...baseData,
          sensor_type: 'heart_rate',
          value: Math.round(Math.random() * 20 + 65), // 65-85 bpm
          unit: 'bpm'
        };
      
      case 'temperature':
        return {
          ...baseData,
          sensor_type: 'temperature',
          value: Math.round((Math.random() * 1.5 + 36.0) * 10) / 10, // 36.0-37.5°C
          unit: '°C'
        };
      
      case 'weight':
        return {
          ...baseData,
          sensor_type: 'weight',
          value: Math.round((Math.random() * 5 + 68.0) * 10) / 10, // 68.0-73.0 kg
          unit: 'kg'
        };
      
      case 'spo2':
        return {
          ...baseData,
          sensor_type: 'spo2',
          value: Math.round((Math.random() * 4 + 96.0) * 10) / 10, // 96.0-100.0%
          unit: '%'
        };
      
      case 'bioimpedance':
        return {
          ...baseData,
          sensor_type: 'bioimpedance',
          value: Math.round((Math.random() * 5 + 16.0) * 10) / 10, // 16.0-21.0% body fat
          unit: '%'
        };
      
      default:
        return baseData;
    }
  }

  // Send data to Firebase Realtime Database
  async sendToFirebase(path, data) {
    return new Promise((resolve, reject) => {
      const jsonData = JSON.stringify(data);
      const options = {
        hostname: CONFIG.FIREBASE_HOST,
        port: 443,
        path: `${path}.json`,
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Content-Length': Buffer.byteLength(jsonData)
        }
      };

      console.log(`📤 Sending to Firebase: ${CONFIG.FIREBASE_HOST}${path}.json`);
      console.log(`📊 Data:`, JSON.stringify(data, null, 2));

      const req = https.request(options, (res) => {
        let responseData = '';
        
        res.on('data', (chunk) => {
          responseData += chunk;
        });
        
        res.on('end', () => {
          console.log(`📥 Firebase Response (${res.statusCode}):`, responseData);
          if (res.statusCode >= 200 && res.statusCode < 300) {
            console.log(`✅ Successfully sent ${data.sensor_type || 'data'} to Firebase`);
            resolve({ statusCode: res.statusCode, data: responseData });
          } else {
            reject(new Error(`Firebase error: ${res.statusCode} - ${responseData}`));
          }
        });
      });

      req.on('error', (error) => {
        console.error(`❌ Firebase request failed: ${error.message}`);
        reject(error);
      });

      req.setTimeout(10000, () => {
        req.destroy();
        reject(new Error('Firebase request timeout'));
      });

      req.write(jsonData);
      req.end();
    });
  }

  // Simulate complete sensor reading cycle
  async simulateFullCycle() {
    console.log('🚀 Starting Firebase simulation cycle...');
    console.log(`📍 Device ID: ${this.deviceId}`);
    console.log(`👤 User ID: ${this.userId}`);
    console.log(`🔥 Firebase Host: ${CONFIG.FIREBASE_HOST}\n`);

    const sensors = ['heart_rate', 'temperature', 'weight', 'spo2', 'bioimpedance'];
    
    for (const sensor of sensors) {
      try {
        const sensorData = this.generateSensorData(sensor);
        
        // Send to device-specific path (simulates Lambda function output)
        await this.sendToFirebase(`/devices/${this.deviceId}/sensor_data`, sensorData);
        
        // Also send to user-specific path for the app to read
        await this.sendToFirebase(`/users/${this.userId}/latest_reading`, sensorData);
        
        console.log(''); // Empty line for readability
        
        // Small delay between sensors
        await new Promise(resolve => setTimeout(resolve, 1000));
        
      } catch (error) {
        console.error(`❌ Failed to send ${sensor} data:`, error.message);
      }
    }

    // Send device status
    try {
      const statusData = {
        device_id: this.deviceId,
        user_id: this.userId,
        status: 'online',
        last_seen: Date.now(),
        firmware_version: '1.0.2',
        battery_level: Math.floor(Math.random() * 30) + 70
      };

      await this.sendToFirebase(`/devices/${this.deviceId}/status`, statusData);
      console.log('✅ Device status updated\n');
      
    } catch (error) {
      console.error('❌ Failed to send device status:', error.message);
    }

    console.log('🎉 Simulation cycle complete!');
    console.log('📱 Check your mobile app for real-time updates.');
  }

  // Start continuous simulation
  async startContinuous() {
    console.log('🔄 Starting continuous Firebase simulation...');
    console.log('Press Ctrl+C to stop\n');

    // Initial cycle
    await this.simulateFullCycle();

    // Set up intervals for different sensors
    const intervals = [];

    // Heart rate every 5 seconds
    intervals.push(setInterval(async () => {
      try {
        const heartData = this.generateSensorData('heart_rate');
        await this.sendToFirebase(`/devices/${this.deviceId}/sensor_data`, heartData);
        await this.sendToFirebase(`/users/${this.userId}/latest_reading`, heartData);
      } catch (error) {
        console.error('❌ Heart rate update failed:', error.message);
      }
    }, 5000));

    // Temperature every 8 seconds
    intervals.push(setInterval(async () => {
      try {
        const tempData = this.generateSensorData('temperature');
        await this.sendToFirebase(`/devices/${this.deviceId}/sensor_data`, tempData);
        await this.sendToFirebase(`/users/${this.userId}/latest_reading`, tempData);
      } catch (error) {
        console.error('❌ Temperature update failed:', error.message);
      }
    }, 8000));

    // Status update every 30 seconds
    intervals.push(setInterval(async () => {
      try {
        const statusData = {
          device_id: this.deviceId,
          status: 'online',
          last_seen: Date.now(),
          uptime: Date.now() - 1750000000000 // Simulated uptime
        };
        await this.sendToFirebase(`/devices/${this.deviceId}/status`, statusData);
      } catch (error) {
        console.error('❌ Status update failed:', error.message);
      }
    }, 30000));

    // Handle graceful shutdown
    process.on('SIGINT', () => {
      console.log('\n🛑 Stopping continuous simulation...');
      intervals.forEach(interval => clearInterval(interval));
      process.exit(0);
    });
  }
}

// Command line interface
if (require.main === module) {
  const simulator = new FirebaseSimulator();
  
  const args = process.argv.slice(2);
  
  if (args.includes('--continuous') || args.includes('-c')) {
    simulator.startContinuous();
  } else {
    simulator.simulateFullCycle().then(() => {
      console.log('\n💡 Run with --continuous flag for real-time simulation');
      process.exit(0);
    }).catch((error) => {
      console.error('❌ Simulation failed:', error.message);
      process.exit(1);
    });
  }
}

module.exports = FirebaseSimulator;
