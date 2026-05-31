import Foundation

// MARK: - TrainingState
// Reads recovery_to_strain.json (bundled resource, static asset) and maps
// (recovery %, strain 0–21) → "RESTORATIVE" | "OPTIMAL" | "OVERREACHING".
//
// Design decisions (D-05/D-08, 12-02-PLAN):
//   - Returns nil if the table failed to load (callers omit the badge).
//   - Never emits "IMPOSSIBLE" (D-05).
//   - Clamps recovery to 0–100 and rounds to Int to index the table.
//   - 101-entry table (recovery 0…100), one row per integer.

enum TrainingState {

    // MARK: - Lookup table row

    private struct Row: Decodable {
        let recovery: Int
        let lower_rec_strain: Double
        let rec_strain: Double
        let upper_rec_strain: Double
    }

    // MARK: - Static table (loaded once, thread-safe via static let)

    private static let table: [Row] = {
        guard
            let url  = Bundle.main.url(forResource: "recovery_to_strain", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let rows = try? JSONDecoder().decode([Row].self, from: data)
        else {
            return []
        }
        return rows.sorted { $0.recovery < $1.recovery }
    }()

    // MARK: - Public API

    /// Returns the Training State zone for the given recovery and strain values.
    ///
    /// - Parameters:
    ///   - recovery: Recovery score in the range 0–100 (clamped + rounded to Int).
    ///   - strain:   Daily strain score in the range 0–21.
    /// - Returns: `"RESTORATIVE"`, `"OPTIMAL"`, or `"OVERREACHING"`;
    ///            `nil` if the lookup table failed to load.
    static func trainingState(recovery: Double, strain: Double) -> String? {
        let rows = table
        guard !rows.isEmpty else { return nil }

        // Clamp recovery to 0–100 and round to nearest integer
        let idx = Int((min(100, max(0, recovery)).rounded()))

        // Find the matching row (table is 0-indexed by recovery integer)
        guard let row = rows.first(where: { $0.recovery == idx }) else {
            // Fallback: use last row if idx exceeds table range
            guard let last = rows.last else { return nil }
            return zone(strain: strain, row: last)
        }

        return zone(strain: strain, row: row)
    }

    // MARK: - Private helpers

    private static func zone(strain: Double, row: Row) -> String {
        if strain < row.lower_rec_strain {
            return "RESTORATIVE"
        } else if strain > row.upper_rec_strain {
            return "OVERREACHING"
        } else {
            return "OPTIMAL"
        }
    }
}
