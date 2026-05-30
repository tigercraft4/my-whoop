import XCTest
@testable import WhoopProtocol

/// Tests for the Maverick outer-wrapper strip (D-02), mirroring strip_maverick() /
/// parse_maverick() in re/survey_5/validate_frames_5.py. Frames are synthetic.
final class MaverickTests: XCTestCase {
    /// Build a valid Maverick-wrapped frame: [0xAA][0x01][len u16-LE][body...][trailer 4B].
    /// total == len + 8 (4-byte header + body + 4-byte trailer).
    static func wrap(body: [UInt8], trailer: [UInt8] = [0xDE, 0xAD, 0xBE, 0xEF]) -> [UInt8] {
        precondition(trailer.count == 4)
        let length = body.count
        var f: [UInt8] = [0xAA, 0x01, UInt8(length & 0xFF), UInt8((length >> 8) & 0xFF)]
        f.append(contentsOf: body)
        f.append(contentsOf: trailer)
        return f
    }

    func testStripReturnsBodyForValidWrapper() {
        // body = role(0x01) + token(3) + ptype(40) + seq(0) + subseq(0) + payload(2)
        let body: [UInt8] = [0x01, 0xAA, 0xBB, 0xCC, 40, 0, 0, 0x12, 0x34]
        let frame = Self.wrap(body: body)
        XCTAssertEqual(stripMaverick(frame), body)
    }

    func testStripNilWhenTooShort() {
        XCTAssertNil(stripMaverick([0xAA, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])) // 8 bytes < 9
    }

    func testStripNilWhenNotSOF() {
        var frame = Self.wrap(body: [0x01, 0x00, 0x00, 0x00, 40])
        frame[0] = 0x00
        XCTAssertNil(stripMaverick(frame))
    }

    func testStripNilWhenVersionByteWrong() {
        var frame = Self.wrap(body: [0x01, 0x00, 0x00, 0x00, 40])
        frame[1] = 0x02 // not 0x01 -> not a Maverick wrapper
        XCTAssertNil(stripMaverick(frame))
    }

    func testStripNilWhenLengthInconsistent() {
        var frame = Self.wrap(body: [0x01, 0x00, 0x00, 0x00, 40])
        // corrupt the declared length so frame.count != length + 8
        frame[2] = UInt8((frame[2] &+ 1))
        XCTAssertNil(stripMaverick(frame))
    }

    func testStripBodyOffsetIsFour() {
        // The body MUST start at offset 4 (after [SOF][ver][len-lo][len-hi]).
        let body: [UInt8] = [0x01, 0x11, 0x22, 0x33, 43, 7]
        let frame = Self.wrap(body: body)
        let stripped = stripMaverick(frame)
        XCTAssertEqual(stripped?.first, frame[4])
        XCTAssertEqual(stripped?.count, body.count)
    }

    func testParseFrameMaverickReadsTypeAndSeqFromBody() {
        // body[4] = ptype, body[5] = seq (same numeric offsets as the 4.0 path frame[4]/frame[5]).
        // Use an EVENT type (known in the schema) so typeName resolves to a named type.
        let body: [UInt8] = [0x01, 0x00, 0x00, 0x00, 40, 7, 0x00, 0x00]
        let frame = Self.wrap(body: body)
        let parsed = parseFrame(frame)
        XCTAssertTrue(parsed.ok)
        XCTAssertEqual(parsed.seq, 7)
    }

    func testParseFrameNonWrappedUsesExistingPath() {
        // A 4.0-style frame (frame[1] != 0x01) must go through the existing path unchanged.
        let frame = FramingTests.hex("aa1800ff28020f3de10128663c0000000000000000000000da855212")
        let parsed = parseFrame(frame)
        XCTAssertTrue(parsed.ok)
        // type at frame[4] = 0x28 = 40 -> REALTIME_DATA, seq at frame[5] = 0x02.
        XCTAssertEqual(parsed.seq, 2)
    }
}
