#ifndef _AD5940_H_
#define _AD5940_H_

#include <Arduino.h>
#include <SPI.h>

// AD5940 Register Definitions
#define AD5940_SPIREG_M_READY       0x20000000
#define AD5940_SPIREG_M_OVERFLOW    0x40000000
#define AD5940_SPIREG_M_UNDERFLOW   0x80000000

// AD5940 Commands
#define AD5940_SPICMD_GETID         0x62
#define AD5940_SPICMD_RESET         0x63
#define AD5940_SPICMD_SETREG        0x20
#define AD5940_SPICMD_GETREG        0x60

// BIA Configuration
#define BIA_MAX_DATACOUNT           6000
#define BIA_FREQ_START              1000.0f    // Start frequency in Hz
#define BIA_FREQ_END                100000.0f  // End frequency in Hz
#define BIA_FREQ_POINTS             100        // Number of frequency points

// Data structures
typedef struct {
    float Real;
    float Image;
} fComplexPolar;

typedef struct {
    float Magnitude;
    float Phase;
} fImpPolar;

typedef struct {
    uint32_t FreqHz;
    fImpPolar Impedance;
} fFreqPoint;

// AD5940 Class
class AD5940Class {
public:
    AD5940Class();
    bool begin(int csPin, int resetPin = -1, int intPin = -1);
    bool reset();
    uint32_t readID();
    
    // BIA specific functions
    bool initializeBIA();
    bool startBIA();
    bool stopBIA();
    bool getBIAData(fFreqPoint* data, uint32_t* count);
    fImpPolar calculateImpedance(uint32_t realData, uint32_t imagData);
    
    // Low level functions
    bool writeRegister(uint16_t addr, uint32_t data);
    uint32_t readRegister(uint16_t addr);
    bool isReady();
    
private:
    int _csPin;
    int _resetPin;
    int _intPin;
    bool _initialized;
    
    void selectChip();
    void deselectChip();
    uint8_t spiTransfer(uint8_t data);
    void spiWrite16(uint16_t data);
    uint32_t spiRead32();
    
    // BIA configuration
    bool configureClock();
    bool configureAFE();
    bool configureDSP();
    bool configureSequencer();
};

extern AD5940Class AD5940;

#endif // _AD5940_H_
