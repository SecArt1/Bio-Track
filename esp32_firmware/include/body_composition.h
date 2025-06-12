#ifndef BODY_COMPOSITION_H
#define BODY_COMPOSITION_H

#include <Arduino.h>
#include "BIA_Application.h"

// User profile for body composition calculations
struct UserProfile {
    int age;                    // Age in years
    float height;               // Height in cm
    float weight;               // Weight in kg
    bool isMale;                // Gender (true = male, false = female)
    int activityLevel;          // Activity level (1-5 scale)
    bool isAthlete;             // Professional athlete flag
};

// Body composition results
struct BodyComposition {
    // Basic measurements
    float bodyFatPercentage;    // Body fat percentage (%)
    float muscleMassKg;         // Muscle mass in kg
    float fatMassKg;            // Fat mass in kg
    float fatFreeMass;          // Fat-free mass in kg
    float bodyWaterPercentage;  // Total body water (%)
    
    // Advanced metrics
    float visceralFatLevel;     // Visceral fat level (1-59 scale)
    float boneMassKg;           // Bone mass in kg
    float metabolicAge;         // Metabolic age in years
    float BMR;                  // Basal Metabolic Rate (kcal/day)
    float muscleMassPercentage; // Muscle mass percentage
    
    // Quality indicators
    float measurementQuality;   // Quality score (0-100%)
    bool validReading;          // Overall validity
    unsigned long timestamp;    // Measurement timestamp
    
    // Raw BIA data used
    float resistance50kHz;      // Resistance at 50kHz
    float reactance50kHz;       // Reactance at 50kHz
    float impedance50kHz;       // Impedance at 50kHz
    float phaseAngle;           // Phase angle
};

// BMI and health categories
enum class BMICategory {
    UNDERWEIGHT,
    NORMAL,
    OVERWEIGHT,
    OBESE_CLASS1,
    OBESE_CLASS2,
    OBESE_CLASS3
};

enum class BodyFatCategory {
    ESSENTIAL,      // Very low (essential fat only)
    ATHLETIC,       // Athletic range
    FITNESS,        // Fitness range
    AVERAGE,        // Average range
    ABOVE_AVERAGE,  // Above average
    OBESE          // Obese range
};

class BodyCompositionAnalyzer {
public:
    BodyCompositionAnalyzer();
    
    // Configuration
    void setUserProfile(const UserProfile& profile);
    UserProfile getUserProfile() const { return userProfile; }
    
    // Main analysis function
    BodyComposition analyzeBodyComposition(const BIAResult* biaResults, int resultCount, float currentWeight);
    
    // Single frequency analysis (simplified)
    BodyComposition analyzeFromSingleFrequency(float resistance, float reactance, float frequency, float weight);
    
    // Validation and quality assessment
    bool validateBIAData(const BIAResult& result);
    float assessMeasurementQuality(const BIAResult* results, int count);
    
    // Health categorization
    BMICategory getBMICategory(float bmi) const;
    BodyFatCategory getBodyFatCategory(float bodyFatPercentage, bool isMale, int age) const;
    String getHealthRecommendation(const BodyComposition& composition) const;
    
    // Utility functions
    float calculateBMI(float weight, float height) const;
    float calculateIdealWeight(float height, bool isMale) const;
    String getBodyCompositionSummary(const BodyComposition& composition) const;
    
    // Calibration and adjustment
    void setEquationParameters(float fatFreeConstant, float fatConstant);
    void enableAthleteMode(bool enable) { athleteModeEnabled = enable; }
    
private:
    UserProfile userProfile;
    bool profileSet;
    bool athleteModeEnabled;
    
    // Equation parameters (can be calibrated)
    float fatFreeMassConstant;  // Typically around 0.593 for adults
    float fatMassConstant;      // Typically around 0.146 for adults
    
    // Core calculation methods
    float calculateTotalBodyWater(float resistance, float height, float weight, bool isMale, int age);
    float calculateFatFreeMass(float totalBodyWater);
    float calculateFatMass(float weight, float fatFreeMass);
    float calculateMuscleMass(float fatFreeMass, float boneMass);
    float calculateBoneMass(float height, float weight, bool isMale);
    float calculateVisceralFat(float bodyFatPercentage, float waistCircumference, int age, bool isMale);
    float calculateMetabolicAge(float BMR, bool isMale);
    float calculateBMR(float weight, float height, int age, bool isMale, float muscleMass);
    
    // Equation selection based on demographics
    float getResistanceCorrection(int age, bool isMale);
    float getEthnicityCorrection(const String& ethnicity);
    
    // Phase angle analysis
    float calculatePhaseAngle(float resistance, float reactance);
    float assessCellularHealth(float phaseAngle, int age, bool isMale);
    
    // Multi-frequency analysis
    float calculateExtracellularWater(const BIAResult* results, int count);
    float calculateIntracellularWater(float totalWater, float extracellularWater);
    
    // Validation helpers
    bool isReasonableBodyFat(float bodyFatPercentage, int age, bool isMale);
    bool isReasonableMuscleMass(float muscleMassPercentage, int age, bool isMale);
    
    // Constants for different populations
    struct PopulationConstants {
        float tbwConstant;      // Total body water constant
        float heightFactor;     // Height factor
        float weightFactor;     // Weight factor
        float ageFactor;        // Age factor
        float genderFactor;     // Gender factor
    };
    
    PopulationConstants getConstantsForDemographic(int age, bool isMale, bool isAthlete);
};

// Utility functions for body composition analysis
namespace BodyCompositionUtils {
    // Standard reference ranges
    struct ReferenceRanges {
        float bodyFatMin, bodyFatMax;
        float muscleMassMin, muscleMassMax;
        float waterMin, waterMax;
    };
    
    ReferenceRanges getReferenceRanges(int age, bool isMale);
    String interpretPhaseAngle(float phaseAngle, int age, bool isMale);
    String getBodyTypeClassification(const BodyComposition& comp);
    
    // Trend analysis
    void addHistoricalData(const BodyComposition& composition);
    String analyzeTrends(int daysPeriod = 30);
    
    // Validation ranges
    const float MIN_VALID_RESISTANCE = 200.0f;     // Ohms
    const float MAX_VALID_RESISTANCE = 1000.0f;    // Ohms
    const float MIN_VALID_REACTANCE = 10.0f;       // Ohms
    const float MAX_VALID_REACTANCE = 200.0f;      // Ohms
    const float MIN_PHASE_ANGLE = 2.0f;            // Degrees
    const float MAX_PHASE_ANGLE = 20.0f;           // Degrees
}

#endif // BODY_COMPOSITION_H
