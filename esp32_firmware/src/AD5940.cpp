#include "AD5940.h"

AD5940Class AD5940;

AD5940Class::AD5940Class() {
    _csPin = -1;
    _resetPin = -1;
    _intPin = -1;
    _initialized = false;
}

bool AD5940Class::begin(int csPin, int resetPin, int intPin) {
    _csPin = csPin;
    _resetPin = resetPin;
    _intPin = intPin;
    
    // Configure pins
    pinMode(_csPin, OUTPUT);
    digitalWrite(_csPin, HIGH);
    
    if (_resetPin >= 0) {
        pinMode(_resetPin, OUTPUT);
        digitalWrite(_resetPin, HIGH);
    }
    
    if (_intPin >= 0) {
        pinMode(_intPin, INPUT);
    }
    
    // Initialize SPI (should be done in main setup)
    SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));
    
    // Reset and check ID
    if (!reset()) {
        return false;
    }
    
    delay(100);
    
    uint32_t id = readID();
    if (id != 0x5502) { // Expected AD5940 ID
        Serial.printf("AD5940 ID mismatch: 0x%04X (expected 0x5502)\n", id);
        return false;
    }
    
    _initialized = true;
    Serial.println("AD5940 initialized successfully");
    return true;
}

bool AD5940Class::reset() {
    if (_resetPin >= 0) {
        digitalWrite(_resetPin, LOW);
        delay(10);
        digitalWrite(_resetPin, HIGH);
        delay(100);
    }
    
    // Software reset via SPI
    selectChip();
    spiTransfer(AD5940_SPICMD_RESET);
    deselectChip();
    delay(100);
    
    return true;
}

uint32_t AD5940Class::readID() {
    selectChip();
    spiTransfer(AD5940_SPICMD_GETID);
    uint32_t id = spiRead32();
    deselectChip();
    return id & 0xFFFF;
}

bool AD5940Class::initializeBIA() {
    if (!_initialized) return false;
    
    Serial.println("Configuring AD5940 for BIA measurement...");
    
    // Configure clock system
    if (!configureClock()) {
        Serial.println("Failed to configure clock");
        return false;
    }
    
    // Configure AFE (Analog Front End)
    if (!configureAFE()) {
        Serial.println("Failed to configure AFE");
        return false;
    }
    
    // Configure DSP
    if (!configureDSP()) {
        Serial.println("Failed to configure DSP");
        return false;
    }
    
    // Configure sequencer
    if (!configureSequencer()) {
        Serial.println("Failed to configure sequencer");
        return false;
    }
    
    Serial.println("AD5940 BIA configuration complete");
    return true;
}

bool AD5940Class::configureClock() {
    // Configure system clock to 16MHz
    if (!writeRegister(0x0C, 0x00000001)) return false; // Enable 16MHz oscillator
    delay(10);
    
    // Select 16MHz as system clock
    if (!writeRegister(0x0D, 0x00000000)) return false;
    
    return true;
}

bool AD5940Class::configureAFE() {
    // Configure excitation amplifier
    if (!writeRegister(0x1068, 0x00000027)) return false; // EXCITAMPGAIN
    
    // Configure current source
    if (!writeRegister(0x1074, 0x00000003)) return false; // EXCITDACGAIN
    
    // Configure ADC
    if (!writeRegister(0x1020, 0x00008009)) return false; // ADCCON
    if (!writeRegister(0x1024, 0x00000003)) return false; // DFTCON
    
    // Configure PGA
    if (!writeRegister(0x1078, 0x00000000)) return false; // PGACON
    if (!writeRegister(0x107C, 0x00000005)) return false; // PGAGAIN
    
    return true;
}

bool AD5940Class::configureDSP() {
    // Configure DFT settings
    if (!writeRegister(0x1024, 0x00000003)) return false; // DFTCON
    if (!writeRegister(0x1028, 0x00000080)) return false; // DFTNUM
    
    // Configure statistics block
    if (!writeRegister(0x1038, 0x00000001)) return false; // STATSCON
    
    return true;
}

bool AD5940Class::configureSequencer() {
    // Basic sequencer configuration for continuous measurement
    if (!writeRegister(0x3000, 0x00000001)) return false; // SEQ0INFO
    if (!writeRegister(0x3004, 0x00000000)) return false; // SEQ1INFO
    
    return true;
}

bool AD5940Class::startBIA() {
    if (!_initialized) return false;
    
    // Start the measurement sequence
    if (!writeRegister(0x0000, 0x00000001)) return false; // Start sequencer
    
    Serial.println("BIA measurement started");
    return true;
}

bool AD5940Class::stopBIA() {
    if (!_initialized) return false;
    
    // Stop the measurement sequence
    if (!writeRegister(0x0000, 0x00000000)) return false; // Stop sequencer
    
    Serial.println("BIA measurement stopped");
    return true;
}

bool AD5940Class::getBIAData(fFreqPoint* data, uint32_t* count) {
    if (!_initialized || !isReady()) return false;
    
    // Read DFT results
    uint32_t realData = readRegister(0x1030); // DFTREAL
    uint32_t imagData = readRegister(0x1034); // DFTIMAG
    
    if (realData == 0 && imagData == 0) {
        *count = 0;
        return false;
    }
    
    // Calculate impedance from DFT results
    data[0].FreqHz = 10000; // Current frequency (would need to track this)
    data[0].Impedance = calculateImpedance(realData, imagData);
    
    *count = 1;
    return true;
}

fImpPolar AD5940Class::calculateImpedance(uint32_t realData, uint32_t imagData) {
    fImpPolar result;
    
    // Convert raw DFT data to voltage
    float realVolt = (float)((int32_t)realData) / 32768.0f; // Assuming 16-bit signed
    float imagVolt = (float)((int32_t)imagData) / 32768.0f;
    
    // Calculate magnitude and phase
    result.Magnitude = sqrt(realVolt * realVolt + imagVolt * imagVolt);
    result.Phase = atan2(imagVolt, realVolt) * 180.0f / PI;
    
    // Apply calibration factors (simplified)
    result.Magnitude *= 1000.0f; // Convert to ohms (calibration dependent)
    
    return result;
}

bool AD5940Class::writeRegister(uint16_t addr, uint32_t data) {
    selectChip();
    
    spiTransfer(AD5940_SPICMD_SETREG);
    spiWrite16(addr);
    
    // Write 32-bit data
    spiTransfer((data >> 24) & 0xFF);
    spiTransfer((data >> 16) & 0xFF);
    spiTransfer((data >> 8) & 0xFF);
    spiTransfer(data & 0xFF);
    
    deselectChip();
    
    // Verify write
    uint32_t readBack = readRegister(addr);
    return (readBack == data);
}

uint32_t AD5940Class::readRegister(uint16_t addr) {
    selectChip();
    
    spiTransfer(AD5940_SPICMD_GETREG);
    spiWrite16(addr);
    
    uint32_t data = spiRead32();
    
    deselectChip();
    return data;
}

bool AD5940Class::isReady() {
    uint32_t status = readRegister(0x0008); // SPIREG
    return !(status & AD5940_SPIREG_M_READY);
}

void AD5940Class::selectChip() {
    digitalWrite(_csPin, LOW);
    delayMicroseconds(1);
}

void AD5940Class::deselectChip() {
    delayMicroseconds(1);
    digitalWrite(_csPin, HIGH);
}

uint8_t AD5940Class::spiTransfer(uint8_t data) {
    return SPI.transfer(data);
}

void AD5940Class::spiWrite16(uint16_t data) {
    spiTransfer((data >> 8) & 0xFF);
    spiTransfer(data & 0xFF);
}

uint32_t AD5940Class::spiRead32() {
    uint32_t data = 0;
    data |= ((uint32_t)spiTransfer(0x00)) << 24;
    data |= ((uint32_t)spiTransfer(0x00)) << 16;
    data |= ((uint32_t)spiTransfer(0x00)) << 8;
    data |= ((uint32_t)spiTransfer(0x00));
    return data;
}
