import CoreBluetooth

/// WHOOP backfill channel — the Gen4 GATT service (61080xxx) used by both WHOOP 4.0 and
/// WHOOP 5.0 to deliver historical type-47 frames. The UUID prefix "61080" follows the
/// Gen4 hardware spec, but this channel is actively used by WHOOP 5.0 for the backfill
/// offload (SEND_HISTORICAL_DATA → type-47 HISTORICAL_DATA frames arrive here).
extension BLEManager {
    /// GATT service UUID for the backfill (historical data) channel.
    /// UUID: 61080001-8D6D-82B8-614A-1C8CB0F8DCC6
    static let backfillService      = CBUUID(string: "61080001-8D6D-82B8-614A-1C8CB0F8DCC6")
    /// Notification characteristic that delivers historical type-47 frames during backfill.
    /// UUID: 61080005-8D6D-82B8-614A-1C8CB0F8DCC6
    static let backfillDataChar     = CBUUID(string: "61080005-8D6D-82B8-614A-1C8CB0F8DCC6")
}
