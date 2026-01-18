# Debugging Guide - Week 1 Audio Issues

## Changes Made

### 1. Fixed Slider Crash (PracticeViewModel)
**Problem**: Slider was causing crashes due to synchronous calls in `didSet`
**Fix**: Made tempo updates asynchronous and fixed clamping logic

```swift
@Published var tempo: Double = 120.0 {
    didSet {
        let clampedTempo = max(40, min(240, tempo))
        if clampedTempo != tempo {
            tempo = clampedTempo
        }
        Task {
            await MainActor.run {
                coordinator.setTempo(tempo)
            }
        }
    }
}
```

### 2. Added Comprehensive Logging
Added emoji-based logging throughout the audio pipeline to help diagnose issues:
- 🎵 = Operation starting
- ✅ = Success
- ❌ = Failure/Error
- ▶️ = Playback control
- 🎼 = Tempo change

## How to Debug

### Step 1: Check Console Output

Run the app in Xcode and watch the console. You should see:

```
🎵 Configuring audio session...
✅ Audio session configured
🎵 Attaching metronome to engine...
✅ Metronome attached
🎵 Initializing audio engine...
✅ Audio engine initialized
```

### Step 2: Test Play Button

Press the play button and look for:

```
▶️ Start playback requested
🎵 Starting audio engine...
✅ Audio engine started
🎵 Starting metronome player...
✅ Metronome player started
🎵 Scheduling initial metronome clicks...
✅ Initial clicks scheduled
✅ Playback started successfully
```

### Step 3: Test Slider

Move the tempo slider and look for:

```
🎼 Setting tempo to 150 BPM
```

## Common Issues & Solutions

### Issue 1: No Sound

**Symptoms**: App runs but no audio
**Possible causes**:
1. Simulator audio routing issues
2. System volume muted
3. Audio session not configured
4. AVAudioEngine not starting

**Solutions**:
- **Test on real device** (simulator audio is unreliable)
- Check system volume
- Check console for error messages starting with ❌
- Verify you see "✅ Audio engine started"

### Issue 2: App Crashes on Launch

**Symptoms**: App crashes immediately
**Possible causes**:
1. PracticeCoordinator init failing
2. Audio format issues
3. Missing audio permissions

**Solutions**:
- Check console for "❌ Failed to setup audio engine"
- Look for the specific error message
- Verify Info.plist has audio background mode configured

### Issue 3: Slider Crashes App

**Symptoms**: App crashes when moving tempo slider
**Status**: ✅ **FIXED** in this update

**What was wrong**: The `didSet` was recursively setting tempo and calling coordinator synchronously

### Issue 4: Audio Permissions

**iOS requires audio permissions for background audio**

Check your Info.plist has:
```xml
<key>UIBackgroundModes</key>
<array>
    <string>audio</string>
</array>
```

And in Xcode target settings:
- Signing & Capabilities → Background Modes → ✅ Audio, AirPlay, and Picture in Picture

## Testing Checklist

- [ ] App launches without crash
- [ ] Console shows successful audio setup (✅ messages)
- [ ] Play button shows without crashing
- [ ] Tempo slider moves without crashing
- [ ] Tempo value updates on screen
- [ ] Bar:Beat display shows 1:1
- [ ] Press play button
- [ ] Console shows playback started
- [ ] **On real device**: Hear metronome clicks
- [ ] Move slider while playing
- [ ] Press pause button

## Next Steps Based on Console Output

### If you see ❌ errors:

1. **"Audio session configuration failed"**
   - Check device is not in silent mode
   - Check no other audio app is hogging the session
   - Try restarting device

2. **"Failed to attach metronome"**
   - Audio engine initialization issue
   - Check audio format compatibility

3. **"Failed to start audio engine"**
   - Session not active
   - Engine already running
   - Hardware access denied

### If no errors but no sound:

1. **Test on real iPhone/iPad** (not simulator)
2. Check device volume buttons
3. Check device is not in silent mode (check switch on side)
4. Try plugging in headphones
5. Check Control Center audio routing

## Simulator vs Device

**Note**: The iOS Simulator has known audio issues:
- Clicks may not play or be delayed
- Sample rates might not match
- Buffer underruns more common
- Latency measurements meaningless

**Always test audio on a real device!**

## Console Debugging Commands

If you want more detailed logging, add these to relevant files:

```swift
// In AudioEngineManager.swift
print("🔊 Audio format: \(audioFormat)")
print("🔊 Sample rate: \(audioFormat.sampleRate)")
print("🔊 Channel count: \(audioFormat.channelCount)")

// In MetronomeNode.swift
print("🔊 Click buffer allocated: \(buffer.frameLength) frames")

// In MusicalClock.swift
print("⏱️ Samples per beat: \(samplesPerBeat)")
```

## Expected Normal Flow

1. App Launch:
   - Audio session configured ✅
   - Metronome attached ✅
   - Engine initialized ✅

2. Press Play:
   - Start playback requested ▶️
   - Engine started ✅
   - Metronome started ✅
   - Clicks scheduled ✅
   - Playback running ✅

3. Move Slider:
   - Tempo change logged 🎼
   - No crashes
   - Audio continues

4. Hear clicks:
   - High pitch on beat 1 (downbeat)
   - Lower pitch on beats 2, 3, 4

## If Still No Sound After All This

The most likely issue is **simulator audio**. Try:

1. Close simulator
2. Quit Xcode
3. Restart Mac
4. Open project
5. Run on **real iPhone/iPad**

You should hear clicks if:
- Device volume is up
- Not in silent mode
- Background audio capability is enabled
- No other app has exclusive audio access
