//
//  MusicalClockTests.swift
//  SergeantMusicTests
//
//  Unit tests for MusicalClock time conversions.
//

import XCTest
@testable import SergeantMusic

final class MusicalClockTests: XCTestCase {
    var clock: MusicalClock!

    override func setUp() {
        super.setUp()
        // 120 BPM, 4/4 time, 44.1kHz
        clock = MusicalClock(tempo: 120.0, timeSignature: .fourFour, sampleRate: 44100.0)
    }

    override func tearDown() {
        clock = nil
        super.tearDown()
    }

    // MARK: - Samples Per Beat

    func testSamplesPerBeat_120BPM() {
        // At 120 BPM: 60 / 120 = 0.5 seconds per beat
        // 0.5 * 44100 = 22050 samples per beat
        XCTAssertEqual(clock.samplesPerBeat, 22050.0, accuracy: 0.1)
    }

    func testSamplesPerBeat_60BPM() {
        clock.tempo = 60.0
        // At 60 BPM: 60 / 60 = 1.0 seconds per beat
        // 1.0 * 44100 = 44100 samples per beat
        XCTAssertEqual(clock.samplesPerBeat, 44100.0, accuracy: 0.1)
    }

    func testSamplesPerBeat_240BPM() {
        clock.tempo = 240.0
        // At 240 BPM: 60 / 240 = 0.25 seconds per beat
        // 0.25 * 44100 = 11025 samples per beat
        XCTAssertEqual(clock.samplesPerBeat, 11025.0, accuracy: 0.1)
    }

    // MARK: - Beat to Sample Time

    func testBeatToSampleTime_firstBeat() {
        // Beat 1 at 120 BPM = 22050 samples
        let sampleTime = clock.beatToSampleTime(1.0)
        XCTAssertEqual(sampleTime, 22050)
    }

    func testBeatToSampleTime_fourthBeat() {
        // Beat 4 at 120 BPM = 88200 samples
        let sampleTime = clock.beatToSampleTime(4.0)
        XCTAssertEqual(sampleTime, 88200)
    }

    func testBeatToSampleTime_fractional() {
        // Beat 1.5 at 120 BPM = 33075 samples
        let sampleTime = clock.beatToSampleTime(1.5)
        XCTAssertEqual(sampleTime, 33075)
    }

    // MARK: - Sample Time to Beat

    func testSampleTimeToBeat_oneBar() {
        // 4 beats at 120 BPM = 88200 samples
        let beat = clock.sampleTimeToBeat(88200)
        XCTAssertEqual(beat, 4.0, accuracy: 0.001)
    }

    func testSampleTimeToBeat_halfBeat() {
        // 0.5 beats at 120 BPM = 11025 samples
        let beat = clock.sampleTimeToBeat(11025)
        XCTAssertEqual(beat, 0.5, accuracy: 0.001)
    }

    // MARK: - Round Trip Conversions

    func testRoundTrip_beatToSampleToBeat() {
        let originalBeat = 7.5
        let sampleTime = clock.beatToSampleTime(originalBeat)
        let convertedBeat = clock.sampleTimeToBeat(sampleTime)
        XCTAssertEqual(originalBeat, convertedBeat, accuracy: 0.001)
    }

    func testRoundTrip_sampleToBeatToSample() {
        let originalSample: Int64 = 100000
        let beat = clock.sampleTimeToBeat(originalSample)
        let convertedSample = clock.beatToSampleTime(beat)
        XCTAssertEqual(originalSample, convertedSample)
    }

    // MARK: - Bar Calculations

    func testSampleTimeToBar_firstBar() {
        // First 4 beats = bar 0
        let sampleTime = clock.beatToSampleTime(3.0)
        let bar = clock.sampleTimeToBar(sampleTime)
        XCTAssertEqual(bar, 0)
    }

    func testSampleTimeToBar_secondBar() {
        // Beats 4-7 = bar 1
        let sampleTime = clock.beatToSampleTime(5.0)
        let bar = clock.sampleTimeToBar(sampleTime)
        XCTAssertEqual(bar, 1)
    }

    func testSampleTimeToBar_tenthBar() {
        // Beat 40 = bar 10
        let sampleTime = clock.beatToSampleTime(40.0)
        let bar = clock.sampleTimeToBar(sampleTime)
        XCTAssertEqual(bar, 10)
    }

    // MARK: - Beat in Bar

    func testBeatInBar_firstBeat() {
        let sampleTime = clock.beatToSampleTime(0.0)
        let beatInBar = clock.sampleTimeToBeatInBar(sampleTime)
        XCTAssertEqual(beatInBar, 1)  // 1-indexed
    }

    func testBeatInBar_fourthBeat() {
        let sampleTime = clock.beatToSampleTime(3.0)
        let beatInBar = clock.sampleTimeToBeatInBar(sampleTime)
        XCTAssertEqual(beatInBar, 4)
    }

    func testBeatInBar_secondBarFirstBeat() {
        let sampleTime = clock.beatToSampleTime(4.0)
        let beatInBar = clock.sampleTimeToBeatInBar(sampleTime)
        XCTAssertEqual(beatInBar, 1)
    }

    // MARK: - Bar/Beat to Sample Time

    func testBarBeatToSampleTime() {
        // Bar 2, beat 3 = overall beat 11 (bars are 0-indexed, beats within bar are 0-indexed)
        let sampleTime = clock.barBeatToSampleTime(bar: 2, beat: 2)
        let expectedSample = clock.beatToSampleTime(10.0)  // Bar 2 starts at beat 8, +2 beats = 10
        XCTAssertEqual(sampleTime, expectedSample)
    }

    // MARK: - Quantization

    func testQuantizeBeat_quarterNote() {
        let beat = 1.3
        let quantized = clock.quantizeBeat(beat, to: 1.0)
        XCTAssertEqual(quantized, 1.0, accuracy: 0.001)
    }

    func testQuantizeBeat_eighthNote() {
        let beat = 1.7
        let quantized = clock.quantizeBeat(beat, to: 0.5)
        XCTAssertEqual(quantized, 1.5, accuracy: 0.001)
    }

    // MARK: - Next Boundaries

    func testNextBeatBoundary() {
        let currentSample = clock.beatToSampleTime(1.5)
        let nextBeat = clock.nextBeatBoundary(after: currentSample)
        let expectedSample = clock.beatToSampleTime(2.0)
        XCTAssertEqual(nextBeat, expectedSample)
    }

    func testNextBarBoundary() {
        let currentSample = clock.beatToSampleTime(2.5)  // Middle of first bar
        let nextBar = clock.nextBarBoundary(after: currentSample)
        let expectedSample = clock.beatToSampleTime(4.0)  // Start of second bar
        XCTAssertEqual(nextBar, expectedSample)
    }

    // MARK: - Different Time Signatures

    func testThreeFour_barCalculation() {
        clock.timeSignature = .threeFour
        // 3 beats per bar
        let sampleTime = clock.beatToSampleTime(5.0)  // Beat 5 = bar 1 (0-indexed)
        let bar = clock.sampleTimeToBar(sampleTime)
        XCTAssertEqual(bar, 1)
    }

    // MARK: - Playback Position Tracking

    func testAdvance() {
        clock.reset()
        XCTAssertEqual(clock.currentSampleTime, 0)

        clock.advance(by: 22050)  // 1 beat at 120 BPM
        XCTAssertEqual(clock.currentSampleTime, 22050)
        XCTAssertEqual(clock.currentBeat, 1.0, accuracy: 0.001)
    }

    func testSeek() {
        clock.seek(to: 44100)  // 2 beats at 120 BPM
        XCTAssertEqual(clock.currentSampleTime, 44100)
        XCTAssertEqual(clock.currentBeat, 2.0, accuracy: 0.001)
    }

    func testReset() {
        clock.seek(to: 100000)
        clock.reset()
        XCTAssertEqual(clock.currentSampleTime, 0)
        XCTAssertEqual(clock.currentBeat, 0.0, accuracy: 0.001)
    }
}
