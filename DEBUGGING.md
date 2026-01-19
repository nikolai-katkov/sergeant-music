# Debugging Guide - Week 1 Audio Issues

## Current Status: ✅ FIXED - Production Ready

### Final Solution: hostTime Scheduling with Absolute Time

**Root Cause**: AVAudioEngine scheduling requires precise timing anchored to wall-clock time using `mach_absolute_time()`.

**Solution**:
1. Capture `mach_absolute_time()` when playback starts
2. Calculate each beat's absolute time from playback start
3. Convert to host time ticks using `mach_timebase_info`
4. Create `AVAudioTime(hostTime:)` for scheduling

**Key Implementation** ([PracticeCoordinator.swift:215-246](SergeantMusic/Services/PracticeCoordinator.swift#L215-L246)):
```swift
// At playback start
self.schedulingStartHostTime = mach_absolute_time()

// For each beat
private func scheduleMetronomeClicks() {
    let secondsPerBeat = 60.0 / musicalClock.tempo

    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let toNanos = Double(timebase.numer) / Double(timebase.denom)

    for i in 0..<Int(lookaheadBeats) {
        let beat = currentBeat + Double(i)
        let absoluteOffsetSeconds = 0.1 + (beat * secondsPerBeat)
        let offsetNanos = absoluteOffsetSeconds * 1_000_000_000.0
        let offsetTicks = UInt64(offsetNanos / toNanos)
        let scheduledHostTime = schedulingStartHostTime + offsetTicks

        let audioTime = AVAudioTime(hostTime: scheduledHostTime)
        let isAccent = Int(beat) % musicalClock.timeSignature.beatsPerBar == 0
        metronome.scheduleClick(at: audioTime, isAccent: isAccent)
    }
}
```

**Critical Details**:
- Uses **absolute time from playback start**, not relative to "now"
- Schedules 4 beats ahead with lookahead
- Reschedules every 2 beats for continuous playback
- HIGH pitch (1200Hz) on downbeat, LOW pitch (800Hz) on other beats

### Tempo Changes During Playback

**Solution** ([PracticeCoordinator.swift:184-211](SergeantMusic/Services/PracticeCoordinator.swift#L184-L211)):
```swift
func setTempo(_ bpm: Double) {
    musicalClock.tempo = bpm

    if isPlaying {
        // Stop player to clear scheduled buffers
        metronome.stop()

        // Calculate current beat position
        let elapsed = Date().timeIntervalSince(playbackStartTime)
        let oldSecondsPerBeat = 60.0 / musicalClock.tempo
        let currentBeat = elapsed / oldSecondsPerBeat

        // Reset timing anchors
        lastScheduledBeat = floor(currentBeat)
        playbackStartTime = Date()
        schedulingStartHostTime = mach_absolute_time()

        // Restart with new tempo
        metronome.start()
        scheduleMetronomeClicks()
    }
}
```

### Sample Rate Matching

**Critical Fix** ([AudioEngineManager.swift:47-62](SergeantMusic/Audio/AudioEngine/AudioEngineManager.swift#L47-L62)):
- Use actual system sample rate (typically 48kHz on real devices)
- Don't hardcode 44.1kHz
- Get from `engine.outputNode.outputFormat(forBus: 0).sampleRate`

---

## Previous Issues (Resolved)

### 1. Fixed Slider Crash (PracticeViewModel)
**Problem**: Slider was causing crashes due to synchronous calls in `didSet`
**Fix**: Made tempo updates asynchronous

---

## Testing Checklist

### ✅ Verified Working
- [x] Metronome plays on every beat (not once per bar)
- [x] HIGH pitch (1200Hz) on downbeat, LOW pitch (800Hz) on other beats
- [x] Correct timing at 120 BPM (0.5s between beeps)
- [x] Tempo changes work smoothly during playback
- [x] Audio continues in background
- [x] No crashes or audio glitches
- [x] Works on real iPhone device

### Production Deployment Checklist
- [x] All debug logging removed (except critical errors)
- [x] Diagnostic taps removed
- [x] Sample rate properly detected from system
- [x] Audio session configured for background playback
- [x] Interruption handling (phone calls, etc.)

---

## Common Issues & Solutions

### Issue 1: No Sound

**Symptoms**: App runs but no audio
**Solutions**:
- Test on **real device** (simulator audio is unreliable)
- Check device volume and silent mode switch
- Verify Info.plist has audio background mode enabled
- Check for "❌ Failed to start playback" in console

### Issue 2: Timing Drift

**Symptoms**: Metronome drifts out of sync over time
**Solutions**:
- Ensure using `mach_absolute_time()` for scheduling anchor
- Verify calculating absolute time from playback start, not relative
- Check system sample rate matches audio format

### Issue 3: Audio Interruptions

**Symptoms**: Audio stops on phone calls or other interruptions
**Solutions**:
- Check `setupInterruptionHandling()` is called in init
- Verify audio session category is `.playback`
- System will automatically pause; can resume after interruption ends

---

## Architecture Notes

### Why hostTime Instead of sampleTime?

Initially attempted using `AVAudioTime(sampleTime:atRate:)`, but discovered:
- Engine's `lastRenderTime` is unreliable immediately after start
- `playerNode.lastRenderTime` returns nil when not rendering
- hostTime provides wall-clock accuracy needed for metronome

### Critical Timing Pattern

**DO**:
```swift
let startHost = mach_absolute_time()  // Anchor
let absoluteTime = 0.1 + (beat * secondsPerBeat)
let scheduledHost = startHost + convertToTicks(absoluteTime)
```

**DON'T**:
```swift
let now = mach_absolute_time()  // Changes every call!
let relativeTime = 0.1 + (beat * secondsPerBeat)
let scheduledHost = now + convertToTicks(relativeTime)  // Wrong!
```

---

## If Still Having Issues

1. Check Xcode console for "❌ Failed" messages
2. Verify on real device (not simulator)
3. Ensure Info.plist has background audio mode
4. Check device is not in Low Power Mode
5. Try restarting the device
