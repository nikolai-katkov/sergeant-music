# How to Enable Audio in Xcode - SergeantMusic

## Step 1: Add Background Audio Capability

1. **Open your project in Xcode**
2. **Select the project** in the Project Navigator (blue icon at the top)
3. **Select the "SergeantMusic" target** (under TARGETS, not the project)
4. **Click the "Signing & Capabilities" tab** at the top
5. **Click the "+ Capability" button**
6. **Search for "Background Modes"** and double-click it
7. **Check the box** for: ✅ **"Audio, AirPlay, and Picture in Picture"**

This allows the app to play audio even when in the background or when the screen is locked.

## Step 2: Add Audio Privacy Description (Info.plist)

While not strictly required for playback-only apps, it's good practice:

1. **In the Project Navigator**, find and select **`Info.plist`** (or Info tab in target settings)
2. **Right-click** in the list and select **"Add Row"**
3. **Add this key**: `Privacy - Microphone Usage Description`
   - **Value**: `This app does not use the microphone` (or leave it out if not needed)

Note: For Week 1, we're only doing **playback** (metronome), so microphone permission is not needed. We'll add it in Week 2 when we add MIDI input.

## Step 3: Verify Audio Session Category

Our code already sets this correctly in `AudioSessionManager.swift`:

```swift
try session.setCategory(.playback, mode: .default, options: [])
```

This tells iOS we want to play audio.

## Step 4: Test Audio Output

### Option A: Test on Simulator (Limited)

**Note**: Simulator audio is unreliable. Expect:
- Clicks may not play
- Timing may be off
- Glitches are common

To enable simulator audio:
1. **Run the app** in simulator
2. **Check Mac volume** (not simulator volume)
3. **Check Mac sound output** (System Settings → Sound → Output)

### Option B: Test on Real Device (Recommended)

This is the only reliable way to test audio:

1. **Connect iPhone/iPad** via USB
2. **Select your device** in Xcode's device dropdown (top toolbar)
3. **Click Run (▶️)** or press ⌘R
4. **On the device**:
   - Check volume buttons
   - Make sure device is not in silent mode (check the physical switch)
   - Check Control Center audio routing
   - Try with headphones plugged in

## Step 5: Check Console Logs

When you run the app, check Xcode's console (bottom panel) for these messages:

### Success messages:
```
🎵 Configuring audio session...
✅ Audio session configured
🎵 Attaching metronome to engine...
✅ Metronome attached
🎵 Initializing audio engine...
✅ Audio engine initialized
```

### When you press Play:
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

### Error messages (if something's wrong):
```
❌ Failed to setup audio engine: <error details>
```

## Step 6: Troubleshooting "No Sound"

### If you see ✅ success messages but no sound:

1. **Test on real device** (not simulator)
2. **Check device volume**:
   - Press volume up button several times
   - Open Control Center and check volume slider
3. **Check silent mode**:
   - Look at the physical switch on the side of iPhone/iPad
   - Orange = silent mode (no sound)
   - Switch it to show no orange
4. **Try with headphones**:
   - Plug in wired headphones or connect AirPods
   - This bypasses any speaker routing issues
5. **Check audio routing**:
   - Open Control Center
   - Long-press the music card
   - Check where audio is being sent (iPhone, AirPods, etc.)
6. **Restart the app**:
   - Stop app in Xcode
   - Press Run again

### If you see ❌ error messages:

1. **"AVAudioSession error"**:
   - Another app might be using audio
   - Try closing other audio apps
   - Restart device

2. **"Audio engine failed to start"**:
   - Check Background Modes is enabled
   - Clean build folder (Product → Clean Build Folder)
   - Rebuild (Product → Build)

3. **"Buffer allocation failed"**:
   - Sample rate or format issue
   - Check the audio format in console

## Step 7: Expected Behavior

When everything is working:

1. **Launch app**: You see the UI with Play button, tempo slider
2. **Press Play**:
   - Button changes to Pause icon
   - Console shows success messages
   - **You hear clicks**: High pitch on beat 1, lower pitch on beats 2, 3, 4
   - Bar:Beat counter updates (1:1, 1:2, 1:3, 1:4, 2:1, ...)
3. **Move slider**:
   - Tempo changes in real-time
   - Clicks speed up/slow down
   - No crashes
4. **Press Pause**:
   - Clicks stop
   - Button changes back to Play icon

## Quick Checklist

- [ ] Added "Background Modes" capability
- [ ] Checked "Audio, AirPlay, and Picture in Picture"
- [ ] Built the project successfully (⌘B)
- [ ] Running on real iPhone/iPad (not simulator)
- [ ] Device volume is UP
- [ ] Device is NOT in silent mode (check physical switch)
- [ ] Console shows ✅ success messages
- [ ] Pressed Play button
- [ ] Can hear metronome clicks

## Common Xcode Audio Settings

### Build Settings to Check (usually automatic):

1. **Deployment Target**: iOS 16.0 or later
   - Project Settings → General → Minimum Deployments

2. **Code Signing**:
   - Signing & Capabilities → Automatically manage signing
   - Select your Team

3. **Framework Links** (should be automatic):
   - AVFoundation.framework
   - Combine.framework

## Still No Sound?

If you've checked everything and still no sound:

1. **Clean Build Folder**: Product → Clean Build Folder (⇧⌘K)
2. **Delete Derived Data**:
   - Xcode → Settings → Locations
   - Click arrow next to Derived Data path
   - Delete the `SergeantMusic-xxx` folder
3. **Restart Xcode**
4. **Rebuild**: Product → Build (⌘B)
5. **Test on device again**

## Audio Debugging Code

Add this to `AudioSessionManager.swift` in `configureForPractice()` to see more details:

```swift
print("🔊 Audio session info:")
print("   Category: \(session.category.rawValue)")
print("   Sample rate: \(session.sampleRate) Hz")
print("   Buffer duration: \(session.ioBufferDuration * 1000) ms")
print("   Output volume: \(session.outputVolume)")
print("   Route: \(session.currentRoute.outputs.map { $0.portName })")
```

This will help diagnose routing and configuration issues.

---

## TL;DR - Quick Fix

**Most common issue**: Testing on simulator instead of real device.

**Solution**:
1. Connect iPhone/iPad
2. Select it in Xcode device dropdown
3. Press Run (⌘R)
4. Turn volume up on device
5. Make sure not in silent mode
6. Press Play in app
7. You should hear clicks!
