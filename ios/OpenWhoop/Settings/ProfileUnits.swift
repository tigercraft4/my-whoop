import Foundation

// MARK: - ProfileUnits
// Pure math helpers for imperial ↔ metric conversions used in the user profile editor.
// All functions are stateless; no I/O, no dependencies.

enum ProfileUnits {

    // MARK: - Height

    /// Converts feet + inches to centimetres.
    static func heightCm(feet: Double, inches: Double) -> Double {
        let totalInches = feet * 12 + inches
        return totalInches * 2.54
    }

    /// Converts centimetres to (feet, inches).
    static func heightFtIn(cm: Double) -> (feet: Double, inches: Double) {
        let totalInches = cm / 2.54
        let feet = (totalInches / 12).rounded(.down)
        let inches = totalInches - feet * 12
        return (feet, inches)
    }

    // MARK: - Weight

    /// Converts pounds to kilograms.
    static func weightKg(lbs: Double) -> Double {
        lbs * 0.45359237
    }

    /// Converts kilograms to pounds.
    static func weightLbs(kg: Double) -> Double {
        kg / 0.45359237
    }
}
