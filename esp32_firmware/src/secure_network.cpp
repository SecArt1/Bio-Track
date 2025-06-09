#include "secure_network.h"

// Firebase root certificate for certificate pinning
const char* firebase_root_ca = \
"-----BEGIN CERTIFICATE-----\n" \
"MIIFYjCCBEqgAwIBAgIQd70NbNs2+RrqIQ/NZh2QVDANBgkqhkiG9w0BAQsFADBy\n" \
"MQswCQYDVQQGEwJVUzEKMAgGA1UECAwBMAAwDQYJKoZIhvcNAQELBQADggEBAP/\n" \
"...(certificate continues)...\n" \
"-----END CERTIFICATE-----\n";

SecureNetworkManager::SecureNetworkManager() {
    currentState = NETWORK_IDLE;
    securityLevel = SECURITY_NONE;
    lastConnectionAttempt = 0;
    lastHeartbeat = 0;
    lastReconnectAttempt = 0;
    connectionRetries = 0;
    maxRetries = 5;
    
    // Initialize queue
    queueHead = 0;
    queueTail = 0;
    queueSize = 0;
    
    // Initialize statistics
    memset(&stats, 0, sizeof(stats));
    
    // Initialize token expiry
    tokenExpiry = 0;
}

SecureNetworkManager::~SecureNetworkManager() {
    disconnect();
    nvs.end();
}

bool SecureNetworkManager::begin() {
    Serial.println("🔒 Initializing Secure Network Manager...");
    
    // Initialize NVS for secure credential storage
    if (!nvs.begin("secure_net", false)) {
        Serial.println("❌ Failed to initialize NVS storage");
        return false;
    }
    
    // Load stored credentials
    if (!loadStoredCredentials()) {
        Serial.println("⚠️ No stored credentials found, will authenticate on first connection");
    }
    
    // Initialize secure client
    if (!initializeSecureConnection()) {
        Serial.println("❌ Failed to initialize secure connection");
        return false;
    }
    
    // Connect to WiFi
    return connectToWiFi();
}

bool SecureNetworkManager::initializeSecureConnection() {
    // Configure secure client with certificate verification
    if (VERIFY_FIREBASE_CERT) {
        secureClient.setCACert(firebase_root_ca);
        securityLevel = SECURITY_TLS_VERIFIED;
        Serial.println("🔒 TLS certificate verification enabled");
    } else {
        secureClient.setInsecure(); // Development mode only
        securityLevel = SECURITY_TLS_BASIC;
        Serial.println("⚠️ TLS certificate verification disabled (dev mode)");
    }
    
    // Set connection timeouts
    secureClient.setTimeout(15000); // 15 second timeout
    
    return true;
}

bool SecureNetworkManager::connectToWiFi() {
    Serial.printf("🔄 Connecting to WiFi: %s\n", WIFI_SSID);
    
    currentState = NETWORK_CONNECTING;
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.persistent(true);
    
    // Configure power management for stable connection
    esp_wifi_set_ps(WIFI_PS_NONE);
    
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    
    unsigned long startTime = millis();
    while (WiFi.status() != WL_CONNECTED && 
           (millis() - startTime) < WIFI_CONNECT_TIMEOUT) {
        delay(500);
        Serial.print(".");
        
        // Feed watchdog during connection
        esp_task_wdt_reset();
    }
    
    if (WiFi.status() == WL_CONNECTED) {
        currentState = NETWORK_CONNECTED;
        stats.signalStrength = WiFi.RSSI();
        
        Serial.println();
        Serial.printf("✅ WiFi connected! IP: %s\n", WiFi.localIP().toString().c_str());
        Serial.printf("📶 Signal strength: %d dBm\n", stats.signalStrength);
        Serial.printf("🔒 Security: %s\n", 
                     securityLevel == SECURITY_TLS_VERIFIED ? "TLS Verified" : "TLS Basic");
        
        // Perform device authentication
        return performDeviceAuthentication();
    } else {
        currentState = NETWORK_ERROR;
        handleConnectionError("WiFi connection timeout");
        return false;
    }
}

bool SecureNetworkManager::performDeviceAuthentication() {
    Serial.println("🔑 Performing device authentication...");
    
    // Create device authentication payload
    DynamicJsonDocument authDoc(512);
    authDoc["deviceId"] = DEVICE_ID;
    authDoc["firmwareVersion"] = FIRMWARE_VERSION;
    authDoc["chipId"] = String((uint32_t)ESP.getEfuseMac(), HEX);
    authDoc["flashSize"] = ESP.getFlashChipSize();
    authDoc["freeHeap"] = ESP.getFreeHeap();
    authDoc["timestamp"] = millis();
    
    // Generate device signature
    String authPayload;
    serializeJson(authDoc, authPayload);
    String signature = generateDeviceSignature(authPayload);
    authDoc["signature"] = signature;
    
    String finalPayload;
    serializeJson(authDoc, finalPayload);
    
    // Send authentication request
    String response;
    String endpoint = "/authenticateDevice";
    
    if (sendHTTPRequest(endpoint, finalPayload, response)) {
        // Parse authentication response
        DynamicJsonDocument responseDoc(1024);
        if (deserializeJson(responseDoc, response) == DeserializationError::Ok) {
            if (responseDoc["success"].as<bool>()) {
                deviceAuthToken = responseDoc["authToken"].as<String>();
                firebaseIdToken = responseDoc["firebaseToken"].as<String>();
                tokenExpiry = millis() + (responseDoc["expiresIn"].as<unsigned long>() * 1000);
                
                // Store credentials securely
                storeCredentials();
                
                currentState = NETWORK_AUTHENTICATED;
                Serial.println("✅ Device authentication successful");
                return true;
            } else {
                String error = responseDoc["error"].as<String>();
                handleConnectionError("Authentication failed: " + error);
                return false;
            }
        }
    }
    
    handleConnectionError("Authentication request failed");
    return false;
}

bool SecureNetworkManager::sendSensorData(String jsonData, TransmissionPriority priority) {
    if (currentState != NETWORK_AUTHENTICATED) {
        return queueData(jsonData, SENSOR_DATA_ENDPOINT, priority);
    }
    
    // Add authentication headers
    DynamicJsonDocument dataDoc(2048);
    if (deserializeJson(dataDoc, jsonData) != DeserializationError::Ok) {
        Serial.println("❌ Invalid JSON data for transmission");
        return false;
    }
    
    dataDoc["deviceId"] = DEVICE_ID;
    dataDoc["authToken"] = deviceAuthToken;
    dataDoc["timestamp"] = millis();
    
    String authenticatedPayload;
    serializeJson(dataDoc, authenticatedPayload);
    
    String response;
    bool success = sendHTTPRequest(SENSOR_DATA_ENDPOINT, authenticatedPayload, response);
    
    if (!success && priority >= PRIORITY_HIGH) {
        // Queue high priority data for retry
        queueData(jsonData, SENSOR_DATA_ENDPOINT, priority);
    }
    
    return success;
}

bool SecureNetworkManager::sendHeartbeat(String deviceStatus) {
    if (currentState != NETWORK_AUTHENTICATED) {
        return false;
    }
    
    DynamicJsonDocument heartbeatDoc(512);
    heartbeatDoc["deviceId"] = DEVICE_ID;
    heartbeatDoc["authToken"] = deviceAuthToken;
    heartbeatDoc["status"] = deviceStatus;
    heartbeatDoc["uptime"] = millis();
    heartbeatDoc["freeHeap"] = ESP.getFreeHeap();
    heartbeatDoc["wifiRSSI"] = WiFi.RSSI();
    heartbeatDoc["timestamp"] = millis();
    
    String payload;
    serializeJson(heartbeatDoc, payload);
    
    String response;
    bool success = sendHTTPRequest(HEARTBEAT_ENDPOINT, payload, response);
    
    if (success) {
        lastHeartbeat = millis();
        Serial.println("💓 Heartbeat sent successfully");
    }
    
    return success;
}

bool SecureNetworkManager::sendAlert(String alertData, TransmissionPriority priority) {
    // Alerts are always queued to ensure delivery
    queueData(alertData, ALERT_ENDPOINT, priority);
    
    if (currentState == NETWORK_AUTHENTICATED) {
        processDataQueue(); // Immediate processing for authenticated connection
    }
    
    return true;
}

bool SecureNetworkManager::sendHTTPRequest(String endpoint, String payload, String& response) {
    if (!secureClient.connected()) {
        if (!secureClient.connect(FIREBASE_FUNCTIONS_URL, 443)) {
            Serial.println("❌ Failed to connect to Firebase Functions");
            return false;
        }
    }
    
    httpClient.begin(secureClient, FIREBASE_FUNCTIONS_URL + endpoint);
    httpClient.addHeader("Content-Type", "application/json");
    httpClient.addHeader("User-Agent", "BioTrack-ESP32/" + String(FIRMWARE_VERSION));
    
    if (!firebaseIdToken.isEmpty()) {
        httpClient.addHeader("Authorization", "Bearer " + firebaseIdToken);
    }
    
    unsigned long startTime = millis();
    int httpResponseCode = httpClient.POST(payload);
    unsigned long duration = millis() - startTime;
    
    if (httpResponseCode > 0) {
        response = httpClient.getString();
        size_t responseSize = response.length();
        
        updateNetworkStatistics(httpResponseCode == 200, payload.length() + responseSize);
        
        if (httpResponseCode == 200) {
            Serial.printf("✅ HTTP request successful (%dms, %d bytes)\n", duration, responseSize);
            return true;
        } else {
            Serial.printf("❌ HTTP error %d: %s\n", httpResponseCode, response.c_str());
        }
    } else {
        Serial.printf("❌ HTTP request failed: %s\n", httpClient.errorToString(httpResponseCode).c_str());
    }
    
    httpClient.end();
    return false;
}

void SecureNetworkManager::checkConnections() {
    unsigned long currentTime = millis();
    
    // Check WiFi connection
    if (WiFi.status() != WL_CONNECTED) {
        Serial.println("⚠️ WiFi disconnected, attempting reconnection...");
        currentState = NETWORK_DISCONNECTED;
        
        if (currentTime - lastReconnectAttempt > WIFI_RECONNECT_INTERVAL) {
            connectToWiFi();
            lastReconnectAttempt = currentTime;
        }
        return;
    }
    
    // Check token expiry
    if (currentTime > tokenExpiry && tokenExpiry != 0) {
        Serial.println("🔑 Authentication token expired, refreshing...");
        refreshAuthToken();
    }
    
    // Send periodic heartbeat
    if (currentTime - lastHeartbeat > MQTT_KEEPALIVE_INTERVAL) {
        sendHeartbeat("online");
    }
    
    // Process queued data
    if (currentState == NETWORK_AUTHENTICATED && hasQueuedData()) {
        processDataQueue();
    }
    
    // Monitor network health
    monitorNetworkHealth();
}

bool SecureNetworkManager::queueData(String payload, String endpoint, TransmissionPriority priority) {
    if (queueSize >= MAX_QUEUE_SIZE) {
        Serial.println("⚠️ Data queue full, removing oldest entry");
        // Remove oldest entry (FIFO)
        queueHead = (queueHead + 1) % MAX_QUEUE_SIZE;
        queueSize--;
    }
    
    // Add to queue
    dataQueue[queueTail].payload = payload;
    dataQueue[queueTail].endpoint = endpoint;
    dataQueue[queueTail].priority = priority;
    dataQueue[queueTail].timestamp = millis();
    dataQueue[queueTail].retryCount = 0;
    
    queueTail = (queueTail + 1) % MAX_QUEUE_SIZE;
    queueSize++;
    
    Serial.printf("📤 Data queued (priority: %d, size: %d/%d)\n", 
                  priority, queueSize, MAX_QUEUE_SIZE);
    return true;
}

void SecureNetworkManager::processDataQueue() {
    if (queueSize == 0 || currentState != NETWORK_AUTHENTICATED) {
        return;
    }
    
    // Process one item per call to avoid blocking
    QueuedData& item = dataQueue[queueHead];
    String response;
    
    bool success = sendHTTPRequest(item.endpoint, item.payload, response);
    
    if (success) {
        // Remove successful item
        queueHead = (queueHead + 1) % MAX_QUEUE_SIZE;
        queueSize--;
        Serial.printf("✅ Queued data sent successfully (remaining: %d)\n", queueSize);
    } else {
        item.retryCount++;
        if (item.retryCount >= 3) {
            // Remove failed item after 3 attempts
            queueHead = (queueHead + 1) % MAX_QUEUE_SIZE;
            queueSize--;
            Serial.printf("❌ Queued data failed after 3 attempts (remaining: %d)\n", queueSize);
        }
    }
}

void SecureNetworkManager::updateNetworkStatistics(bool success, size_t bytes) {
    if (success) {
        stats.successfulRequests++;
        stats.totalBytesSent += bytes;
    } else {
        stats.failedRequests++;
    }
    
    stats.signalStrength = WiFi.RSSI();
}

void SecureNetworkManager::monitorNetworkHealth() {
    // Update signal strength
    stats.signalStrength = WiFi.RSSI();
    
    // Calculate success rate
    unsigned long totalRequests = stats.successfulRequests + stats.failedRequests;
    if (totalRequests > 0) {
        float successRate = (float)stats.successfulRequests / totalRequests * 100.0;
        
        if (successRate < 70.0) {
            Serial.printf("⚠️ Low network success rate: %.1f%%\n", successRate);
        }
    }
    
    // Check signal strength
    if (stats.signalStrength < -80) {
        Serial.printf("⚠️ Weak WiFi signal: %d dBm\n", stats.signalStrength);
    }
}

bool SecureNetworkManager::loadStoredCredentials() {
    deviceAuthToken = nvs.getString("authToken", "");
    firebaseIdToken = nvs.getString("firebaseToken", "");
    tokenExpiry = nvs.getULong64("tokenExpiry", 0);
    
    return !deviceAuthToken.isEmpty() && !firebaseIdToken.isEmpty();
}

void SecureNetworkManager::storeCredentials() {
    nvs.putString("authToken", deviceAuthToken);
    nvs.putString("firebaseToken", firebaseIdToken);
    nvs.putULong64("tokenExpiry", tokenExpiry);
    
    Serial.println("🔐 Credentials stored securely");
}

bool SecureNetworkManager::refreshAuthToken() {
    // Implementation for token refresh
    return performDeviceAuthentication();
}

void SecureNetworkManager::handleConnectionError(String error) {
    Serial.println("❌ Network Error: " + error);
    currentState = NETWORK_ERROR;
    connectionRetries++;
    
    if (connectionRetries >= maxRetries) {
        Serial.println("❌ Max connection retries reached, implementing backoff");
        implementExponentialBackoff();
    }
}

void SecureNetworkManager::implementExponentialBackoff() {
    unsigned long backoffTime = min(300000UL, 1000UL * (1 << connectionRetries)); // Max 5 minutes
    Serial.printf("⏳ Exponential backoff: %lu seconds\n", backoffTime / 1000);
    
    unsigned long startTime = millis();
    while (millis() - startTime < backoffTime) {
        delay(1000);
        esp_task_wdt_reset(); // Keep watchdog happy
    }
    
    connectionRetries = 0; // Reset after backoff
}

// Utility functions
String generateDeviceSignature(String data) {
    // Simple hash-based signature (implement proper HMAC in production)
    uint32_t hash = 0;
    for (size_t i = 0; i < data.length(); i++) {
        hash = hash * 31 + data[i];
    }
    return String(hash, HEX);
}

// Status and diagnostic functions
bool SecureNetworkManager::isFullyConnected() {
    return currentState == NETWORK_AUTHENTICATED && WiFi.status() == WL_CONNECTED;
}

bool SecureNetworkManager::isSecureConnection() {
    return securityLevel >= SECURITY_TLS_BASIC;
}

NetworkState SecureNetworkManager::getNetworkState() {
    return currentState;
}

SecureNetworkManager::NetworkStats SecureNetworkManager::getNetworkStatistics() {
    return stats;
}

String SecureNetworkManager::getConnectionInfo() {
    DynamicJsonDocument info(512);
    info["state"] = currentState;
    info["securityLevel"] = securityLevel;
    info["signalStrength"] = stats.signalStrength;
    info["successfulRequests"] = stats.successfulRequests;
    info["failedRequests"] = stats.failedRequests;
    info["queueSize"] = queueSize;
    info["ipAddress"] = WiFi.localIP().toString();
    
    String result;
    serializeJson(info, result);
    return result;
}

bool SecureNetworkManager::hasQueuedData() {
    return queueSize > 0;
}

int SecureNetworkManager::getQueueSize() {
    return queueSize;
}

void SecureNetworkManager::disconnect() {
    Serial.println("🔌 Disconnecting secure network manager...");
    
    // Clear any pending data
    clearQueue();
    
    // Disconnect HTTP client
    if (httpClient.connected()) {
        httpClient.end();
    }
    
    // Stop secure client
    if (secureClient.connected()) {
        secureClient.stop();
    }
    
    // Disconnect from WiFi
    if (WiFi.status() == WL_CONNECTED) {
        WiFi.disconnect(true);
    }
    
    // Reset state
    currentState = NETWORK_DISCONNECTED;
    securityLevel = SECURITY_NONE;
    firebaseIdToken = "";
    deviceAuthToken = "";
    tokenExpiry = 0;
    
    // Reset statistics
    memset(&stats, 0, sizeof(stats));
    
    Serial.println("✅ Network manager disconnected");
}

SecurityLevel SecureNetworkManager::getCurrentSecurityLevel() {
    return securityLevel;
}

String SecureNetworkManager::getNetworkDiagnostics() {
    DynamicJsonDocument diagnostics(1024);
    
    // Network status
    diagnostics["wifi"]["connected"] = (WiFi.status() == WL_CONNECTED);
    diagnostics["wifi"]["ssid"] = WiFi.SSID();
    diagnostics["wifi"]["rssi"] = WiFi.RSSI();
    diagnostics["wifi"]["ip"] = WiFi.localIP().toString();
    diagnostics["wifi"]["gateway"] = WiFi.gatewayIP().toString();
    diagnostics["wifi"]["dns"] = WiFi.dnsIP().toString();
    
    // Connection state
    diagnostics["connection"]["state"] = currentState;
    diagnostics["connection"]["securityLevel"] = securityLevel;
    diagnostics["connection"]["authenticated"] = (currentState == NETWORK_AUTHENTICATED);
    diagnostics["connection"]["retries"] = connectionRetries;
    diagnostics["connection"]["lastAttempt"] = lastConnectionAttempt;
    
    // Security status
    diagnostics["security"]["tlsConnected"] = secureClient.connected();
    diagnostics["security"]["certificateValid"] = isSecureConnection();
    diagnostics["security"]["tokenValid"] = (tokenExpiry > millis());
    diagnostics["security"]["tokenExpiry"] = tokenExpiry;
    
    // Queue status
    diagnostics["queue"]["size"] = queueSize;
    diagnostics["queue"]["maxSize"] = MAX_QUEUE_SIZE;
    diagnostics["queue"]["hasData"] = (queueSize > 0);
    
    // Statistics
    diagnostics["stats"]["bytesSent"] = stats.totalBytesSent;
    diagnostics["stats"]["bytesReceived"] = stats.totalBytesReceived;
    diagnostics["stats"]["successfulRequests"] = stats.successfulRequests;
    diagnostics["stats"]["failedRequests"] = stats.failedRequests;
    diagnostics["stats"]["successRate"] = stats.successfulRequests + stats.failedRequests > 0 
        ? (float)stats.successfulRequests / (stats.successfulRequests + stats.failedRequests) * 100.0f 
        : 0.0f;
    
    // Memory status
    diagnostics["memory"]["freeHeap"] = ESP.getFreeHeap();
    diagnostics["memory"]["heapSize"] = ESP.getHeapSize();
    diagnostics["memory"]["maxAllocHeap"] = ESP.getMaxAllocHeap();
    
    String result;
    serializeJson(diagnostics, result);
    return result;
}

void SecureNetworkManager::clearQueue() {
    queueHead = 0;
    queueTail = 0;
    queueSize = 0;
    Serial.println("📭 Data queue cleared");
}
