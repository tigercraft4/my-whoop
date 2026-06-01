import Foundation

/// OpenWhoop protocol library — WHOOP frame decoder (4.0 and 5.0 historical frames).
/// Implemented across Framing.swift / Values.swift / Schema.swift / Interpreter.swift (Phase B).
public enum WhoopProtocolInfo {
    /// URL of the bundled canonical decode schema (a resource of this package target).
    public static func schemaResourceURL() -> URL? {
        Bundle.module.url(forResource: "whoop_protocol_5", withExtension: "json")
    }
}
