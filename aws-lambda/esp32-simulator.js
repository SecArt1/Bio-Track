#!/usr/bin/env node

/**
 * ESP32 Traffic Simulator for BioTrack System
 * Simulates realistic ESP32 sensor data and network traffic
 * Based on actual configuration from config.h
 */

const https = require('https');
const http = require('http');

// Configuration from ESP32 config.h
const CONFIG = {
  // AWS IoT Configuration
  AWS_IOT_ENDPOINT: "azvqnnby4qrmz-ats.iot.eu-central-1.amazonaws.com",
  AWS_IOT_CLIENT_ID: "biotrack-device-001",
  DEVICE_ID: "biotrack-device-001",
  
  // Firebase Configuration
  FIREBASE_PROJECT_ID: "bio-track-de846",
  FIREBASE_HOST: "bio-track-de846-default-rtdb.firebaseio.com",
  FIREBASE_FUNCTIONS_URL: "https://us-central1-bio-track-de846.cloudfunctions.net",
  
  // API Gateway Endpoint (from previous tests)
  API_GATEWAY_URL: "https://vn5ycnp8nh.execute-api.eu-central-1.amazonaws.com/prod",
  
  // Sensor intervals
  HEART_RATE_INTERVAL: 5000,
  TEMPERATURE_INTERVAL: 5000,
  WEIGHT_INTERVAL: 2000,
  BIOIMPEDANCE_INTERVAL: 15000,
  
  // User ID for testing
  USER_ID: "FUbmmZXxY0OdJolvrQXP0JxMjmW2"
};

// Sensor data generators based on ESP32 implementation
class SensorSimulator {
  constructor() {
    this.deviceId = CONFIG.DEVICE_ID;
    this.userId = CONFIG.USER_ID;
    this.timestamp = Date.now();
  }

  // MAX30102 Heart Rate & SpO2 simulation
  generateHeartRateData() {
    const baseHeartRate = 75;
    const variation = Math.random() * 20 - 10; // ±10 bpm variation
    return {
      sensor_type: "heart_rate",
      value: Math.round(baseHeartRate + variation),
      unit: "bpm",
      device_id: this.deviceId,
      user_id: this.userId,
      timestamp: Date.now(),
      raw_data: {
        ir_value: Math.floor(Math.random() * 100000) + 50000,
        red_value: Math.floor(Math.random() * 80000) + 40000,
        signal_quality: Math.random() * 0.3 + 0.7 // 70-100% quality
      }
    };
  }

  generateSpO2Data() {
    const baseSpO2 = 98;
    const variation = Math.random() * 4 - 2; // ±2% variation
    return {
      sensor_type: "spo2",
      value: Math.round((baseSpO2 + variation) * 10) / 10,
      unit: "%",
      device_id: this.deviceId,
      user_id: this.userId,
      timestamp: Date.now(),
      raw_data: {
        ratio_of_ratios: Math.random() * 0.5 + 1.5,
        signal_strength: Math.random() * 0.2 + 0.8
      }
    };
  }

  // DS18B20 Temperature simulation
  generateTemperatureData() {
    const baseTemp = 36.5;
    const variation = Math.random() * 1.0 - 0.5; // ±0.5°C variation
    return {
      sensor_type: "temperature",
      value: Math.round((baseTemp + variation) * 10) / 10,
      unit: "°C",
      device_id: this.deviceId,
      user_id: this.userId,
      timestamp: Date.now(),
      raw_data: {
        sensor_resolution: 12,
        conversion_time: 750
      }
    };
  }

  // HX711 Load Cell (Weight) simulation
  generateWeightData() {
    const baseWeight = 70.0;
    const variation = Math.random() * 2.0 - 1.0; // ±1kg variation
    return {
      sensor_type: "weight",
      value: Math.round((baseWeight + variation) * 10) / 10,
      unit: "kg",
      device_id: this.deviceId,
      user_id: this.userId,
      timestamp: Date.now(),
      raw_data: {
        raw_adc: Math.floor(Math.random() * 16777215), // 24-bit ADC
        calibration_factor: 2280.0,
        tare_offset: 0
      }
    };
  }

  // AD5941 Bioimpedance simulation
  generateBioimpedanceData() {
    const baseBodyfat = 18.5;
    const variation = Math.random() * 3.0 - 1.5; // ±1.5% variation
    return {
      sensor_type: "bioimpedance",
      value: Math.round((baseBodyfat + variation) * 10) / 10,
      unit: "%",
      device_id: this.deviceId,
      user_id: this.userId,
      timestamp: Date.now(),
      raw_data: {
        impedance_50khz: Math.floor(Math.random() * 100) + 400,
        impedance_100khz: Math.floor(Math.random() * 80) + 380,
        phase_angle: Math.random() * 10 + 5,
        reactance: Math.random() * 50 + 20
      }
    };
  }

  // Blood glucose simulation (MAX30102 based)
  generateGlucoseData() {
    const baseGlucose = 95;
    const variation = Math.random() * 30 - 15; // ±15 mg/dL variation
    return {
      sensor_type: "blood_glucose",
      value: Math.round(baseGlucose + variation),
      unit: "mg/dL",
      device_id: this.deviceId,
      user_id: this.userId,
      timestamp: Date.now(),
      raw_data: {
        ir_ac: Math.random() * 1000 + 500,
        red_ac: Math.random() * 800 + 400,
        glucose_ratio: Math.random() * 0.5 + 0.7
      }
    };
  }

  // Device status heartbeat
  generateDeviceStatus() {
    return {
      device_id: this.deviceId,
      user_id: this.userId,
      status: "online",
      firmware_version: "1.0.2",
      battery_level: Math.floor(Math.random() * 30) + 70, // 70-100%
      wifi_rssi: -(Math.floor(Math.random() * 30) + 30), // -30 to -60 dBm
      free_heap: Math.floor(Math.random() * 50000) + 200000,
      uptime: Date.now() - this.timestamp,
      timestamp: Date.now()
    };
  }
}

// Network traffic simulator
class NetworkSimulator {
  constructor() {
    this.sensorSim = new SensorSimulator();
    this.isRunning = false;
    this.intervals = [];
  }

  // Send HTTP request with proper error handling
  async sendHttpRequest(url, data, method = 'POST') {
    return new Promise((resolve, reject) => {
      const urlObj = new URL(url);
      const options = {
        hostname: urlObj.hostname,
        port: urlObj.port || (urlObj.protocol === 'https:' ? 443 : 80),
        path: urlObj.pathname + urlObj.search,
        method: method,
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'ESP32-BioTrack/1.0.2',
          'X-Device-ID': CONFIG.DEVICE_ID,
          'X-User-ID': CONFIG.USER_ID
        }
      };

      if (data && method !== 'GET') {
        const jsonData = JSON.stringify(data);
        options.headers['Content-Length'] = Buffer.byteLength(jsonData);
      }

      const client = urlObj.protocol === 'https:' ? https : http;
      const req = client.request(options, (res) => {
        let responseData = '';
        
        res.on('data', (chunk) => {
          responseData += chunk;
        });
        
        res.on('end', () => {
          console.log(`📡 ${method} ${url} -> ${res.statusCode}`);
          if (responseData) {
            console.log(`📥 Response: ${responseData.substring(0, 200)}${responseData.length > 200 ? '...' : ''}`);
          }
          resolve({
            statusCode: res.statusCode,
            data: responseData,
            headers: res.headers
          });
        });
      });

      req.on('error', (error) => {
        console.error(`❌ Request failed: ${error.message}`);
        reject(error);
      });

      req.setTimeout(10000, () => {
        req.destroy();
        reject(new Error('Request timeout'));
      });

      if (data && method !== 'GET') {
        req.write(JSON.stringify(data));
      }
      
      req.end();
    });
  }

  // Simulate AWS IoT MQTT publish via HTTP
  async publishToAWSIoT(topic, data) {
    const payload = {
      topic: topic,
      payload: data,
      timestamp: Date.now(),
      clientId: CONFIG.AWS_IOT_CLIENT_ID
    };

    try {
      console.log(`📤 Publishing to AWS IoT topic: ${topic}`);
      console.log(`📊 Sensor data:`, JSON.stringify(data, null, 2));
      
      // Try API Gateway endpoint
      const response = await this.sendHttpRequest(
        `${CONFIG.API_GATEWAY_URL}/iot/publish`,
        payload
      );
      
      return response;
    } catch (error) {
      console.error(`❌ Failed to publish to AWS IoT: ${error.message}`);
      return null;
    }
  }

  // Send sensor data to Firebase directly (fallback)
  async sendToFirebase(data) {
    try {
      console.log(`📤 Sending directly to Firebase`);
      
      const response = await this.sendHttpRequest(
        `https://${CONFIG.FIREBASE_HOST}/devices/${CONFIG.DEVICE_ID}/sensor_data.json`,
        data,
        'PUT'
      );
      
      return response;
    } catch (error) {
      console.error(`❌ Failed to send to Firebase: ${error.message}`);
      return null;
    }
  }

  // Simulate full sensor reading cycle
  async simulateSensorCycle() {
    const sensors = [
      () => this.sensorSim.generateHeartRateData(),
      () => this.sensorSim.generateSpO2Data(),
      () => this.sensorSim.generateTemperatureData(),
      () => this.sensorSim.generateWeightData(),
      () => this.sensorSim.generateBioimpedanceData(),
      () => this.sensorSim.generateGlucoseData()
    ];

    console.log(`\n🔄 Starting sensor cycle simulation...`);
    
    for (const sensorFunc of sensors) {
      const sensorData = sensorFunc();
      const topic = `biotrack/device/${CONFIG.DEVICE_ID}/telemetry`;
      
      // Try AWS IoT first, then Firebase as fallback
      let success = await this.publishToAWSIoT(topic, sensorData);
      
      if (!success) {
        console.log(`🔄 Falling back to direct Firebase...`);
        success = await this.sendToFirebase(sensorData);
      }
      
      // Small delay between sensors
      await new Promise(resolve => setTimeout(resolve, 500));
    }
    
    console.log(`✅ Sensor cycle complete\n`);
  }

  // Start continuous simulation
  startSimulation() {
    if (this.isRunning) {
      console.log('⚠️ Simulation already running');
      return;
    }

    this.isRunning = true;
    console.log('🚀 Starting ESP32 traffic simulation...');
    console.log(`📍 Device ID: ${CONFIG.DEVICE_ID}`);
    console.log(`👤 User ID: ${CONFIG.USER_ID}`);
    console.log(`🌐 AWS IoT Endpoint: ${CONFIG.AWS_IOT_ENDPOINT}`);
    console.log(`🔥 Firebase Host: ${CONFIG.FIREBASE_HOST}\n`);

    // Initial sensor cycle
    this.simulateSensorCycle();

    // Heart rate and SpO2 every 5 seconds
    this.intervals.push(setInterval(() => {
      const heartData = this.sensorSim.generateHeartRateData();
      const spo2Data = this.sensorSim.generateSpO2Data();
      this.publishToAWSIoT(`biotrack/device/${CONFIG.DEVICE_ID}/telemetry`, heartData);
      setTimeout(() => {
        this.publishToAWSIoT(`biotrack/device/${CONFIG.DEVICE_ID}/telemetry`, spo2Data);
      }, 1000);
    }, CONFIG.HEART_RATE_INTERVAL));

    // Temperature every 5 seconds
    this.intervals.push(setInterval(() => {
      const tempData = this.sensorSim.generateTemperatureData();
      this.publishToAWSIoT(`biotrack/device/${CONFIG.DEVICE_ID}/telemetry`, tempData);
    }, CONFIG.TEMPERATURE_INTERVAL));

    // Weight every 2 seconds
    this.intervals.push(setInterval(() => {
      const weightData = this.sensorSim.generateWeightData();
      this.publishToAWSIoT(`biotrack/device/${CONFIG.DEVICE_ID}/telemetry`, weightData);
    }, CONFIG.WEIGHT_INTERVAL));

    // Bioimpedance every 15 seconds
    this.intervals.push(setInterval(() => {
      const bioData = this.sensorSim.generateBioimpedanceData();
      this.publishToAWSIoT(`biotrack/device/${CONFIG.DEVICE_ID}/telemetry`, bioData);
    }, CONFIG.BIOIMPEDANCE_INTERVAL));

    // Device status every 30 seconds
    this.intervals.push(setInterval(() => {
      const statusData = this.sensorSim.generateDeviceStatus();
      this.publishToAWSIoT(`biotrack/device/${CONFIG.DEVICE_ID}/status`, statusData);
    }, 30000));

    console.log('✅ Simulation intervals started. Press Ctrl+C to stop.\n');
  }

  // Stop simulation
  stopSimulation() {
    if (!this.isRunning) {
      console.log('⚠️ Simulation not running');
      return;
    }

    this.isRunning = false;
    this.intervals.forEach(interval => clearInterval(interval));
    this.intervals = [];
    console.log('🛑 Simulation stopped');
  }
}

// Command line interface
if (require.main === module) {
  const simulator = new NetworkSimulator();
  
  // Handle graceful shutdown
  process.on('SIGINT', () => {
    console.log('\n🛑 Shutting down simulation...');
    simulator.stopSimulation();
    process.exit(0);
  });

  // Parse command line arguments
  const args = process.argv.slice(2);
  
  if (args.includes('--single') || args.includes('-s')) {
    console.log('🔄 Running single sensor cycle...');
    simulator.simulateSensorCycle().then(() => {
      console.log('✅ Single cycle complete');
      process.exit(0);
    });
  } else if (args.includes('--status') || args.includes('-st')) {
    console.log('📊 Sending device status...');
    const statusData = simulator.sensorSim.generateDeviceStatus();
    simulator.publishToAWSIoT(`biotrack/device/${CONFIG.DEVICE_ID}/status`, statusData).then(() => {
      console.log('✅ Status sent');
      process.exit(0);
    });
  } else {
    // Start continuous simulation
    simulator.startSimulation();
  }
}

module.exports = { NetworkSimulator, SensorSimulator, CONFIG };
