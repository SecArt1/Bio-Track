#!/usr/bin/env node

/**
 * ESP32 BioTrack Device Simulation - Clean AWS IoT Implementation
 * Simulates realistic sensor data from ESP32 device using AWS IoT Core
 */

const https = require('https');
const crypto = require('crypto');

// AWS Configuration from config.h
const AWS_CONFIG = {
    iotEndpoint: 'azvqnnby4qrmz-ats.iot.eu-central-1.amazonaws.com',
    apiGatewayUrl: 'https://azvqnnby4qrmz.execute-api.eu-central-1.amazonaws.com/prod',
    region: 'eu-central-1',
    deviceId: 'biotrack-device-001',
    thingName: 'biotrack-device-001',
    clientId: 'biotrack-device-001'
};

// MQTT Topics from config.h
const TOPICS = {
    telemetry: `biotrack/device/${AWS_CONFIG.deviceId}/telemetry`,
    commands: `biotrack/device/${AWS_CONFIG.deviceId}/commands`,
    status: `biotrack/device/${AWS_CONFIG.deviceId}/status`,
    responses: `biotrack/device/${AWS_CONFIG.deviceId}/responses`
};

// Realistic sensor value generators
const SensorSimulator = {
    heartRate: () => Math.round(60 + Math.random() * 40 + Math.sin(Date.now() / 10000) * 10),
    temperature: () => 36.1 + Math.random() * 1.4 + Math.sin(Date.now() / 20000) * 0.3,
    weight: () => 65 + Math.random() * 20 + Math.sin(Date.now() / 50000) * 2,
    spo2: () => Math.round(95 + Math.random() * 5),
    bioimpedance: () => 400 + Math.random() * 200,
    systolic: () => Math.round(110 + Math.random() * 30),
    diastolic: () => Math.round(70 + Math.random() * 20)
};

// Generate realistic ESP32 sensor payload
function generateSensorPayload(sensorType) {
    const timestamp = Date.now();
    const deviceId = AWS_CONFIG.deviceId;
    
    let sensorData = {
        deviceId,
        timestamp,
        sensor_type: sensorType,
        firmware_version: "1.0.2",
        battery_level: Math.round(20 + Math.random() * 80),
        signal_strength: Math.round(-40 - Math.random() * 40)
    };

    switch (sensorType) {
        case 'heart_rate':
            sensorData.value = SensorSimulator.heartRate();
            sensorData.unit = 'bpm';
            sensorData.confidence = 0.95;
            break;
            
        case 'temperature':
            sensorData.value = Number(SensorSimulator.temperature().toFixed(1));
            sensorData.unit = '°C';
            sensorData.sensor_id = 'DS18B20';
            break;
            
        case 'weight':
            sensorData.value = Number(SensorSimulator.weight().toFixed(1));
            sensorData.unit = 'kg';
            sensorData.sensor_id = 'HX711';
            sensorData.calibration_factor = 2280.0;
            break;
            
        case 'blood_oxygen':
            sensorData.value = SensorSimulator.spo2();
            sensorData.unit = '%';
            sensorData.sensor_id = 'MAX30102';
            break;
            
        case 'bioimpedance':
            sensorData.value = Number(SensorSimulator.bioimpedance().toFixed(1));
            sensorData.unit = 'Ω';
            sensorData.sensor_id = 'AD5941';
            sensorData.frequency = '50kHz';
            break;
            
        case 'blood_pressure':
            sensorData.systolic = SensorSimulator.systolic();
            sensorData.diastolic = SensorSimulator.diastolic();
            sensorData.unit = 'mmHg';
            sensorData.method = 'oscillometric';
            delete sensorData.value; // BP doesn't have a single value
            break;
    }

    return sensorData;
}

// Simulate AWS IoT Core MQTT message via API Gateway
async function sendToAWSIoT(topic, payload) {
    return new Promise((resolve, reject) => {
        const postData = JSON.stringify({
            topic: topic,
            payload: payload,
            deviceId: AWS_CONFIG.deviceId,
            timestamp: Date.now()
        });

        const options = {
            hostname: 'azvqnnby4qrmz.execute-api.eu-central-1.amazonaws.com',
            port: 443,
            path: '/prod/iot/publish',
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData),
                'User-Agent': 'ESP32-BioTrack/1.0.2'
            }
        };

        const req = https.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => data += chunk);
            res.on('end', () => {
                console.log(`📡 IoT Publish Response [${res.statusCode}]:`, data);
                resolve({ statusCode: res.statusCode, body: data });
            });
        });

        req.on('error', (error) => {
            console.error('❌ IoT Publish Error:', error.message);
            reject(error);
        });

        req.write(postData);
        req.end();
    });
}

// Send device status heartbeat
async function sendHeartbeat() {
    const status = {
        deviceId: AWS_CONFIG.deviceId,
        status: 'online',
        timestamp: Date.now(),
        uptime: Math.floor(Math.random() * 86400), // seconds
        free_heap: Math.floor(200000 + Math.random() * 100000),
        wifi_rssi: Math.floor(-40 - Math.random() * 40),
        firmware_version: "1.0.2",
        last_sensor_reading: Date.now() - Math.floor(Math.random() * 30000)
    };

    console.log('💓 Sending device heartbeat...');
    return await sendToAWSIoT(TOPICS.status, status);
}

// Send sensor data
async function sendSensorData(sensorType) {
    const sensorData = generateSensorPayload(sensorType);
    console.log(`📊 Sending ${sensorType} data:`, JSON.stringify(sensorData, null, 2));
    return await sendToAWSIoT(TOPICS.telemetry, sensorData);
}

// Send test command response
async function sendCommandResponse(commandId, result) {
    const response = {
        deviceId: AWS_CONFIG.deviceId,
        commandId: commandId,
        status: result.success ? 'completed' : 'failed',
        result: result,
        timestamp: Date.now()
    };

    console.log('📤 Sending command response...');
    return await sendToAWSIoT(TOPICS.responses, response);
}

// Simulate full health screening sequence
async function simulateHealthScreening() {
    console.log('\n🏥 Starting Full Health Screening Simulation...\n');
    
    // Send heartbeat first
    await sendHeartbeat();
    await new Promise(resolve => setTimeout(resolve, 1000));

    // Simulate sensor readings in sequence
    const sensors = ['heart_rate', 'temperature', 'weight', 'blood_oxygen', 'bioimpedance', 'blood_pressure'];
    
    for (const sensor of sensors) {
        await sendSensorData(sensor);
        await new Promise(resolve => setTimeout(resolve, 2000)); // 2 second delay between sensors
    }

    // Send completion response
    await sendCommandResponse('health_screening_001', {
        success: true,
        sensors_tested: sensors.length,
        duration: sensors.length * 2 + 1,
        message: 'Health screening completed successfully'
    });

    console.log('\n✅ Health screening simulation completed!\n');
}

// Simulate individual sensor test
async function simulateIndividualSensorTest(sensorType) {
    console.log(`\n🧪 Testing ${sensorType} sensor...\n`);
    
    await sendSensorData(sensorType);
    
    await sendCommandResponse(`${sensorType}_test_001`, {
        success: true,
        sensor: sensorType,
        readings: 1,
        message: `${sensorType} test completed successfully`
    });

    console.log(`\n✅ ${sensorType} test completed!\n`);
}

// Main simulation control
async function main() {
    const args = process.argv.slice(2);
    
    if (args.length === 0) {
        console.log('ESP32 BioTrack Simulation');
        console.log('Usage:');
        console.log('  node esp32-simulation-clean.js full-screening    # Simulate full health screening');
        console.log('  node esp32-simulation-clean.js heart_rate        # Test heart rate sensor');
        console.log('  node esp32-simulation-clean.js temperature       # Test temperature sensor');
        console.log('  node esp32-simulation-clean.js weight            # Test weight sensor');
        console.log('  node esp32-simulation-clean.js blood_oxygen      # Test SpO2 sensor');
        console.log('  node esp32-simulation-clean.js bioimpedance      # Test bioimpedance sensor');
        console.log('  node esp32-simulation-clean.js blood_pressure    # Test blood pressure');
        console.log('  node esp32-simulation-clean.js heartbeat         # Send device heartbeat');
        return;
    }

    const command = args[0];

    try {
        switch (command) {
            case 'full-screening':
                await simulateHealthScreening();
                break;
            case 'heartbeat':
                await sendHeartbeat();
                break;
            case 'heart_rate':
            case 'temperature':
            case 'weight':
            case 'blood_oxygen':
            case 'bioimpedance':
            case 'blood_pressure':
                await simulateIndividualSensorTest(command);
                break;
            default:
                console.error('❌ Unknown command:', command);
                process.exit(1);
        }
    } catch (error) {
        console.error('❌ Simulation failed:', error.message);
        process.exit(1);
    }
}

// Run if called directly
if (require.main === module) {
    main();
}

module.exports = {
    generateSensorPayload,
    sendToAWSIoT,
    simulateHealthScreening,
    simulateIndividualSensorTest
};
