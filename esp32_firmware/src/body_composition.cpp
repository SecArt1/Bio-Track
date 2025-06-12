#include "body_composition.h"
#include <math.h>

BodyCompositionAnalyzer::BodyCompositionAnalyzer() {
    profileSet = false;
    athleteModeEnabled = false;
    
    // Default equation parameters (Kushner & Schoeller, 1986)
    fatFreeMassConstant = 0.593f;
    fatMassConstant = 0.146f;
    
    // Initialize user profile with defaults
    userProfile = {25, 170.0f, 70.0f, true, 3, false};
}

void BodyCompositionAnalyzer::setUserProfile(const UserProfile& profile) {
    userProfile = profile;
    profileSet = true;
    
    Serial.printf("👤 User profile set: Age=%d, Height=%.1fcm, Weight=%.1fkg, Gender=%s\n",
                  profile.age, profile.height, profile.weight, 
                  profile.isMale ? "Male" : "Female");
}

BodyComposition BodyCompositionAnalyzer::analyzeBodyComposition(const BIAResult* biaResults, int resultCount, float currentWeight) {
    BodyComposition composition = {};
    composition.timestamp = millis();
    composition.validReading = false;
    
    if (!profileSet || resultCount == 0 || !biaResults) {
        Serial.println("❌ Invalid input for body composition analysis");
        return composition;
    }
    
    // Update weight if provided
    if (currentWeight > 0) {
        userProfile.weight = currentWeight;
    }
    
    // Find the 50kHz measurement (standard for body composition)
    const BIAResult* result50kHz = nullptr;
    float targetFreq = 50000.0f;
    float minFreqDiff = 999999.0f;
    
    for (int i = 0; i < resultCount; i++) {
        if (validateBIAData(biaResults[i])) {
            float freqDiff = abs(biaResults[i].Frequency - targetFreq);
            if (freqDiff < minFreqDiff) {
                minFreqDiff = freqDiff;
                result50kHz = &biaResults[i];
            }
        }
    }
    
    if (!result50kHz) {
        Serial.println("❌ No valid 50kHz measurement found");
        return composition;
    }
    
    // Store raw BIA data
    composition.resistance50kHz = result50kHz->Resistance;
    composition.reactance50kHz = result50kHz->Reactance;
    composition.impedance50kHz = result50kHz->Magnitude;
    composition.phaseAngle = calculatePhaseAngle(result50kHz->Resistance, result50kHz->Reactance);
    
    // Calculate body composition using multiple approaches
    
    // 1. Total Body Water (TBW) calculation
    float tbw = calculateTotalBodyWater(result50kHz->Resistance, userProfile.height, 
                                       userProfile.weight, userProfile.isMale, userProfile.age);
    
    // 2. Fat-Free Mass (FFM) calculation
    float ffm = calculateFatFreeMass(tbw);
    composition.fatFreeMass = ffm;
    
    // 3. Fat Mass calculation
    float fatMass = calculateFatMass(userProfile.weight, ffm);
    composition.fatMassKg = fatMass;
    composition.bodyFatPercentage = (fatMass / userProfile.weight) * 100.0f;
    
    // 4. Muscle Mass calculation
    float boneMass = calculateBoneMass(userProfile.height, userProfile.weight, userProfile.isMale);
    composition.boneMassKg = boneMass;
    composition.muscleMassKg = calculateMuscleMass(ffm, boneMass);
    composition.muscleMassPercentage = (composition.muscleMassKg / userProfile.weight) * 100.0f;
    
    // 5. Body Water percentage
    composition.bodyWaterPercentage = (tbw / userProfile.weight) * 100.0f;
    
    // 6. Advanced metrics
    composition.visceralFatLevel = calculateVisceralFat(composition.bodyFatPercentage, 0, userProfile.age, userProfile.isMale);
    composition.BMR = calculateBMR(userProfile.weight, userProfile.height, userProfile.age, 
                                  userProfile.isMale, composition.muscleMassKg);
    composition.metabolicAge = calculateMetabolicAge(composition.BMR, userProfile.isMale);
    
    // 7. Quality assessment
    composition.measurementQuality = assessMeasurementQuality(biaResults, resultCount);
    
    // 8. Validation
    composition.validReading = (composition.measurementQuality > 60.0f &&
                               isReasonableBodyFat(composition.bodyFatPercentage, userProfile.age, userProfile.isMale) &&
                               isReasonableMuscleMass(composition.muscleMassPercentage, userProfile.age, userProfile.isMale));
    
    if (composition.validReading) {
        Serial.println("✅ Body composition analysis completed successfully");
        Serial.printf("📊 Body Fat: %.1f%%, Muscle: %.1fkg, Water: %.1f%%\n",
                     composition.bodyFatPercentage, composition.muscleMassKg, composition.bodyWaterPercentage);
    } else {
        Serial.println("⚠️ Body composition analysis completed with low quality");
    }
    
    return composition;
}

BodyComposition BodyCompositionAnalyzer::analyzeFromSingleFrequency(float resistance, float reactance, float frequency, float weight) {
    // Create a single BIAResult for analysis
    BIAResult result;
    result.Resistance = resistance;
    result.Reactance = reactance;
    result.Magnitude = sqrt(resistance * resistance + reactance * reactance);
    result.Frequency = frequency;
    result.Phase = atan2(reactance, resistance) * 180.0f / PI;
    result.Valid = true;
    result.Timestamp = millis();
    
    return analyzeBodyComposition(&result, 1, weight);
}

float BodyCompositionAnalyzer::calculateTotalBodyWater(float resistance, float height, float weight, bool isMale, int age) {
    // Use validated prediction equations
    PopulationConstants constants = getConstantsForDemographic(age, isMale, userProfile.isAthlete);
    
    // Kushner equation (widely validated)
    float heightSquared = (height * height) / 10000.0f; // Convert cm² to m²
    float tbw;
    
    if (isMale) {
        // Male equation: TBW = 0.396 × (Height²/R) + 0.143 × Weight + 8.399
        tbw = 0.396f * (heightSquared / resistance) + 0.143f * weight + 8.399f;
    } else {
        // Female equation: TBW = 0.372 × (Height²/R) + 0.096 × Weight + 4.649
        tbw = 0.372f * (heightSquared / resistance) + 0.096f * weight + 4.649f;
    }
    
    // Age correction (TBW decreases with age)
    if (age > 30) {
        float ageCorrection = (age - 30) * 0.02f; // 2% decrease per decade after 30
        tbw *= (1.0f - ageCorrection);
    }
    
    // Athlete correction (athletes have higher TBW)
    if (userProfile.isAthlete || athleteModeEnabled) {
        tbw *= 1.05f; // 5% increase for athletes
    }
    
    return tbw;
}

float BodyCompositionAnalyzer::calculateFatFreeMass(float totalBodyWater) {
    // Fat-free mass hydration constant: FFM = TBW / hydration_constant
    // Adult hydration constant is approximately 73.2%
    float hydrationConstant = 0.732f;
    
    // Adjust for age (hydration decreases with age)
    if (userProfile.age > 60) {
        hydrationConstant = 0.715f; // Lower hydration in elderly
    } else if (userProfile.age < 18) {
        hydrationConstant = 0.750f; // Higher hydration in children
    }
    
    return totalBodyWater / hydrationConstant;
}

float BodyCompositionAnalyzer::calculateFatMass(float weight, float fatFreeMass) {
    float fatMass = weight - fatFreeMass;
    
    // Ensure reasonable bounds
    if (fatMass < 0) fatMass = 0;
    if (fatMass > weight * 0.6f) fatMass = weight * 0.6f; // Maximum 60% body fat
    
    return fatMass;
}

float BodyCompositionAnalyzer::calculateMuscleMass(float fatFreeMass, float boneMass) {
    // Muscle mass = Fat-free mass - Bone mass - Organs mass
    // Typical organ mass is about 7-10% of body weight
    float organMass = userProfile.weight * 0.08f; // 8% for organs
    
    float muscleMass = fatFreeMass - boneMass - organMass;
    
    // Ensure reasonable bounds
    if (muscleMass < userProfile.weight * 0.25f) muscleMass = userProfile.weight * 0.25f;
    if (muscleMass > userProfile.weight * 0.55f) muscleMass = userProfile.weight * 0.55f;
    
    return muscleMass;
}

float BodyCompositionAnalyzer::calculateBoneMass(float height, float weight, bool isMale) {
    // Validated bone mass prediction equations
    float boneMass;
    
    if (isMale) {
        // Male: Bone mass = 0.244 × Weight + 7.8
        boneMass = 0.244f * weight + 7.8f;
    } else {
        // Female: Bone mass = 0.245 × Weight + 5.4
        boneMass = 0.245f * weight + 5.4f;
    }
    
    // Height adjustment
    float heightFactor = height / 170.0f; // Normalize to 170cm
    boneMass *= heightFactor;
    
    // Age adjustment (bone mass decreases after 30)
    if (userProfile.age > 30) {
        float ageReduction = (userProfile.age - 30) * 0.005f; // 0.5% per year after 30
        boneMass *= (1.0f - ageReduction);
    }
    
    return boneMass;
}

float BodyCompositionAnalyzer::calculateBMR(float weight, float height, int age, bool isMale, float muscleMass) {
    // Enhanced Mifflin-St Jeor equation with muscle mass component
    float bmr;
    
    if (isMale) {
        bmr = 10.0f * weight + 6.25f * height - 5.0f * age + 5;
    } else {
        bmr = 10.0f * weight + 6.25f * height - 5.0f * age - 161;
    }
    
    // Muscle mass adjustment (muscle is metabolically active)
    float muscleFactor = (muscleMass / weight) / (isMale ? 0.45f : 0.36f); // Relative to average
    bmr *= (0.85f + 0.3f * muscleFactor); // Adjust based on muscle mass
    
    return bmr;
}

float BodyCompositionAnalyzer::calculatePhaseAngle(float resistance, float reactance) {
    if (resistance <= 0) return 0;
    return atan(reactance / resistance) * 180.0f / PI;
}

bool BodyCompositionAnalyzer::validateBIAData(const BIAResult& result) {
    if (!result.Valid) return false;
    
    // Check reasonable ranges
    if (result.Resistance < BodyCompositionUtils::MIN_VALID_RESISTANCE || 
        result.Resistance > BodyCompositionUtils::MAX_VALID_RESISTANCE) {
        return false;
    }
    
    if (abs(result.Reactance) < BodyCompositionUtils::MIN_VALID_REACTANCE || 
        abs(result.Reactance) > BodyCompositionUtils::MAX_VALID_REACTANCE) {
        return false;
    }
    
    float phaseAngle = calculatePhaseAngle(result.Resistance, result.Reactance);
    if (phaseAngle < BodyCompositionUtils::MIN_PHASE_ANGLE || 
        phaseAngle > BodyCompositionUtils::MAX_PHASE_ANGLE) {
        return false;
    }
    
    return true;
}

float BodyCompositionAnalyzer::assessMeasurementQuality(const BIAResult* results, int count) {
    if (count == 0) return 0;
    
    float qualityScore = 100.0f;
    
    // Check data consistency
    if (count > 1) {
        float resistanceVariation = 0;
        float reactanceVariation = 0;
        
        for (int i = 1; i < count; i++) {
            resistanceVariation += abs(results[i].Resistance - results[i-1].Resistance);
            reactanceVariation += abs(results[i].Reactance - results[i-1].Reactance);
        }
        
        resistanceVariation /= count;
        reactanceVariation /= count;
        
        // Penalize high variation
        if (resistanceVariation > 20) qualityScore -= 30;
        if (reactanceVariation > 10) qualityScore -= 20;
    }
    
    // Check phase angle quality
    for (int i = 0; i < count; i++) {
        float phaseAngle = calculatePhaseAngle(results[i].Resistance, results[i].Reactance);
        if (phaseAngle < 3.0f || phaseAngle > 15.0f) {
            qualityScore -= 15;
        }
    }
    
    return max(0.0f, qualityScore);
}

bool BodyCompositionAnalyzer::isReasonableBodyFat(float bodyFatPercentage, int age, bool isMale) {
    // Age and gender-specific reasonable ranges
    float minFat, maxFat;
    
    if (isMale) {
        if (age < 30) { minFat = 8; maxFat = 25; }
        else if (age < 50) { minFat = 11; maxFat = 28; }
        else { minFat = 13; maxFat = 32; }
    } else {
        if (age < 30) { minFat = 16; maxFat = 35; }
        else if (age < 50) { minFat = 19; maxFat = 38; }
        else { minFat = 22; maxFat = 42; }
    }
    
    return (bodyFatPercentage >= minFat && bodyFatPercentage <= maxFat);
}

bool BodyCompositionAnalyzer::isReasonableMuscleMass(float muscleMassPercentage, int age, bool isMale) {
    // Reasonable muscle mass ranges
    float minMuscle, maxMuscle;
    
    if (isMale) {
        minMuscle = 35; maxMuscle = 55;
    } else {
        minMuscle = 28; maxMuscle = 48;
    }
    
    // Age adjustment
    if (age > 50) {
        minMuscle -= 5;
        maxMuscle -= 3;
    }
    
    return (muscleMassPercentage >= minMuscle && muscleMassPercentage <= maxMuscle);
}

BodyCompositionAnalyzer::PopulationConstants BodyCompositionAnalyzer::getConstantsForDemographic(int age, bool isMale, bool isAthlete) {
    PopulationConstants constants;
    
    // Base constants
    if (isMale) {
        constants.tbwConstant = 0.396f;
        constants.heightFactor = 1.0f;
        constants.weightFactor = 0.143f;
        constants.ageFactor = 8.399f;
        constants.genderFactor = 1.0f;
    } else {
        constants.tbwConstant = 0.372f;
        constants.heightFactor = 1.0f;
        constants.weightFactor = 0.096f;
        constants.ageFactor = 4.649f;
        constants.genderFactor = 0.95f;
    }
    
    // Age adjustments
    if (age < 18) {
        constants.tbwConstant *= 1.05f; // Children have higher water content
    } else if (age > 60) {
        constants.tbwConstant *= 0.95f; // Elderly have lower water content
    }
    
    // Athlete adjustments
    if (isAthlete) {
        constants.tbwConstant *= 1.03f;
        constants.weightFactor *= 1.02f;
    }
    
    return constants;
}

float BodyCompositionAnalyzer::calculateBMI(float weight, float height) const {
    float heightM = height / 100.0f; // Convert cm to m
    return weight / (heightM * heightM);
}

BMICategory BodyCompositionAnalyzer::getBMICategory(float bmi) const {
    if (bmi < 18.5f) return BMICategory::UNDERWEIGHT;
    else if (bmi < 25.0f) return BMICategory::NORMAL;
    else if (bmi < 30.0f) return BMICategory::OVERWEIGHT;
    else if (bmi < 35.0f) return BMICategory::OBESE_CLASS1;
    else if (bmi < 40.0f) return BMICategory::OBESE_CLASS2;
    else return BMICategory::OBESE_CLASS3;
}

BodyFatCategory BodyCompositionAnalyzer::getBodyFatCategory(float bodyFatPercentage, bool isMale, int age) const {
    // Age and gender-specific categories
    if (isMale) {
        if (bodyFatPercentage < 6) return BodyFatCategory::ESSENTIAL;
        else if (bodyFatPercentage < 14) return BodyFatCategory::ATHLETIC;
        else if (bodyFatPercentage < 18) return BodyFatCategory::FITNESS;
        else if (bodyFatPercentage < 25) return BodyFatCategory::AVERAGE;
        else if (bodyFatPercentage < 30) return BodyFatCategory::ABOVE_AVERAGE;
        else return BodyFatCategory::OBESE;
    } else {
        if (bodyFatPercentage < 14) return BodyFatCategory::ESSENTIAL;
        else if (bodyFatPercentage < 21) return BodyFatCategory::ATHLETIC;
        else if (bodyFatPercentage < 25) return BodyFatCategory::FITNESS;
        else if (bodyFatPercentage < 32) return BodyFatCategory::AVERAGE;
        else if (bodyFatPercentage < 38) return BodyFatCategory::ABOVE_AVERAGE;
        else return BodyFatCategory::OBESE;
    }
}

String BodyCompositionAnalyzer::getBodyCompositionSummary(const BodyComposition& composition) const {
    String summary = "📊 Body Composition Analysis:\n";
    summary += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
    summary += String("🔸 Body Fat: ") + String(composition.bodyFatPercentage, 1) + "%\n";
    summary += String("💪 Muscle Mass: ") + String(composition.muscleMassKg, 1) + "kg\n";
    summary += String("💧 Body Water: ") + String(composition.bodyWaterPercentage, 1) + "%\n";
    summary += String("🦴 Bone Mass: ") + String(composition.boneMassKg, 1) + "kg\n";
    summary += String("🔥 BMR: ") + String(composition.BMR, 0) + " kcal/day\n";
    summary += String("📈 Quality: ") + String(composition.measurementQuality, 0) + "%\n";
    summary += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
      return summary;
}

float BodyCompositionAnalyzer::calculateVisceralFat(float bodyFatPercentage, float waistCircumference, int age, bool isMale) {
    // Visceral fat estimation based on body fat percentage and demographic factors
    // This is an approximation based on research correlations
    
    float baseFactor = 0.0f;
    
    // Age factor - visceral fat tends to increase with age
    float ageFactor = (age - 20) * 0.05f;
    if (ageFactor < 0) ageFactor = 0;
    
    // Gender factor - males tend to store more visceral fat
    float genderFactor = isMale ? 1.2f : 0.8f;
    
    // Body fat percentage correlation
    if (bodyFatPercentage < 10) {
        baseFactor = 1.0f;
    } else if (bodyFatPercentage < 15) {
        baseFactor = 2.0f + (bodyFatPercentage - 10) * 0.3f;
    } else if (bodyFatPercentage < 25) {
        baseFactor = 3.5f + (bodyFatPercentage - 15) * 0.4f;
    } else if (bodyFatPercentage < 35) {
        baseFactor = 7.5f + (bodyFatPercentage - 25) * 0.6f;
    } else {
        baseFactor = 13.5f + (bodyFatPercentage - 35) * 0.8f;
    }
    
    float visceralFat = baseFactor * genderFactor + ageFactor;
    
    // Cap the visceral fat level at reasonable limits
    if (visceralFat < 1.0f) visceralFat = 1.0f;
    if (visceralFat > 30.0f) visceralFat = 30.0f;
    
    return visceralFat;
}

float BodyCompositionAnalyzer::calculateMetabolicAge(float BMR, bool isMale) {
    // Calculate metabolic age based on BMR compared to average BMR for age groups
    // This gives an estimate of how the person's metabolism compares to their chronological age
    
    float chronologicalAge = static_cast<float>(userProfile.age);
    
    // Average BMR values by age and gender (kcal/day)
    // These are based on Harris-Benedict equation averages
    float averageBMR = 0.0f;
    
    if (isMale) {
        if (chronologicalAge < 25) {
            averageBMR = 1800.0f;
        } else if (chronologicalAge < 35) {
            averageBMR = 1750.0f;
        } else if (chronologicalAge < 45) {
            averageBMR = 1700.0f;
        } else if (chronologicalAge < 55) {
            averageBMR = 1650.0f;
        } else if (chronologicalAge < 65) {
            averageBMR = 1600.0f;
        } else {
            averageBMR = 1550.0f;
        }
    } else {
        if (chronologicalAge < 25) {
            averageBMR = 1400.0f;
        } else if (chronologicalAge < 35) {
            averageBMR = 1350.0f;
        } else if (chronologicalAge < 45) {
            averageBMR = 1300.0f;
        } else if (chronologicalAge < 55) {
            averageBMR = 1250.0f;
        } else if (chronologicalAge < 65) {
            averageBMR = 1200.0f;
        } else {
            averageBMR = 1150.0f;
        }
    }
    
    // Calculate metabolic age based on BMR ratio
    // Higher BMR = younger metabolic age, Lower BMR = older metabolic age
    float bmrRatio = BMR / averageBMR;
    float metabolicAge = chronologicalAge / bmrRatio;
    
    // Apply reasonable bounds
    float minAge = chronologicalAge - 15.0f;
    float maxAge = chronologicalAge + 15.0f;
    
    if (minAge < 18.0f) minAge = 18.0f;
    if (maxAge > 80.0f) maxAge = 80.0f;
    
    if (metabolicAge < minAge) metabolicAge = minAge;
    if (metabolicAge > maxAge) metabolicAge = maxAge;
    
    return metabolicAge;
}

// Utility namespace implementations
namespace BodyCompositionUtils {
    BodyCompositionUtils::ReferenceRanges getReferenceRanges(int age, bool isMale) {
        ReferenceRanges ranges;
        
        if (isMale) {
            if (age < 30) {
                ranges = {8, 20, 38, 52, 55, 65};
            } else if (age < 50) {
                ranges = {11, 23, 35, 49, 52, 62};
            } else {
                ranges = {13, 25, 32, 46, 50, 60};
            }
        } else {
            if (age < 30) {
                ranges = {16, 30, 32, 45, 50, 60};
            } else if (age < 50) {
                ranges = {19, 33, 30, 43, 48, 58};
            } else {
                ranges = {22, 35, 28, 40, 45, 55};
            }
        }
        
        return ranges;
    }
    
    String interpretPhaseAngle(float phaseAngle, int age, bool isMale) {
        String interpretation;
        
        if (phaseAngle >= 7.0f) {
            interpretation = "Excellent cellular health";
        } else if (phaseAngle >= 5.5f) {
            interpretation = "Good cellular health";
        } else if (phaseAngle >= 4.0f) {
            interpretation = "Average cellular health";
        } else {
            interpretation = "Below average cellular health";
        }
        
        return interpretation;
    }
}
