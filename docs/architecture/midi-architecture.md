# MIDI Architecture

## Overview

SergeantMusic's MIDI subsystem enables hands-free practice control via foot pedals and other MIDI controllers. This document details the architecture for MIDI device discovery, message parsing, command mapping, and integration with the audio engine.

## Core Requirements

- **Device Support:** Bluetooth MIDI, USB MIDI (Camera Adapter), Network MIDI
- **Low Latency:** MIDI → Audio command execution < 5ms jitter
- **Quantization:** Snap commands to musical grid (beat, bar)
- **Flexibility:** User-configurable MIDI mappings
- **Reliability:** Handle device connection/disconnection gracefully

## Technology Stack

### Core MIDI (Apple's MIDI Framework)
- Native iOS MIDI support
- Device discovery and connection
- Packet parsing and routing
- All three MIDI protocols: Bluetooth, USB, Network

### Why Core MIDI?
- **Built-in:** No external dependencies
- **Comprehensive:** Supports all MIDI protocols
- **Low-level:** Direct access to MIDI data
- **Reliable:** Apple-maintained, well-tested

## MIDI Subsystem Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  MIDI Subsystem                          │
│                                                          │
│  ┌──────────────────────────────────────────────────┐  │
│  │         MIDIManager                               │  │
│  │  - Core MIDI client lifecycle                     │  │
│  │  - Connection management                          │  │
│  │  - Device state tracking                          │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                      │
│  ┌────────────────┴─────────────────────────────────┐  │
│  │      MIDIDeviceScanner                            │  │
│  │  - Bluetooth MIDI discovery                       │  │
│  │  - USB MIDI enumeration                           │  │
│  │  - Network MIDI browsing                          │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                      │
│  ┌────────────────┴─────────────────────────────────┐  │
│  │      MIDIEventHandler                             │  │
│  │  - Parse MIDI packets                             │  │
│  │  - Timestamp events immediately                   │  │
│  │  - Route to audio queue                           │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                      │
│  ┌────────────────┴─────────────────────────────────┐  │
│  │      MIDICommandMapper                            │  │
│  │  - Map MIDI messages → app commands              │  │
│  │  - User-configurable mappings                     │  │
│  │  - Command validation                             │  │
│  └────────────────┬─────────────────────────────────┘  │
│                   │                                      │
│  ┌────────────────┴─────────────────────────────────┐  │
│  │      MIDIDeviceConfig                             │  │
│  │  - Store user mappings                            │  │
│  │  - Device-specific presets                        │  │
│  │  - Persistence (JSON)                             │  │
│  └──────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
                           ↓
                    Audio Queue
                           ↓
                    EventSequencer
```

## MIDI Event Flow

```
MIDI Device (Foot Pedal)
    ↓ (Bluetooth/USB/Network)
Core MIDI Callback
    ↓ (MIDIPacket)
MIDIEventHandler.handlePacket()
    ↓ (parse bytes, timestamp)
audioQueue.async { ... }
    ↓ (audio thread)
MIDICommandMapper.map()
    ↓ (MIDI → App Command)
EventSequencer.scheduleQuantized()
    ↓ (calculate next grid point)
Schedule Event at Quantized Time
    ↓ (audio render callback)
Execute Command (e.g., change chord)
    ↓ (lock-free queue)
Notify Main Thread
    ↓ (UI updates)
Update All Visualizations
```

**Timing:** Total latency from pedal press to audio change: < 5ms jitter

## Key Components

### 1. MIDIManager

**Responsibility:** Core MIDI client lifecycle and connection management.

**Key Tasks:**
- Initialize Core MIDI client
- Manage MIDI connections
- Track connected devices
- Handle connection/disconnection events
- Publish device state changes

**File:** `/MIDI/MIDIManager.swift`

```swift
import CoreMIDI

class MIDIManager {
    private var midiClient: MIDIClientRef = 0
    private var inputPort: MIDIPortRef = 0
    private var outputPort: MIDIPortRef = 0

    private var connectedDevices: [MIDIDevice] = []
    private let deviceScanner: MIDIDeviceScanner
    private let eventHandler: MIDIEventHandler

    func initialize() throws {
        // Create MIDI client
        let status = MIDIClientCreateWithBlock("SergeantMusic" as CFString, &midiClient) { notification in
            self.handleMIDINotification(notification)
        }

        guard status == noErr else {
            throw MIDIError.clientCreationFailed
        }

        // Create input port
        MIDIInputPortCreateWithBlock(midiClient, "Input" as CFString, &inputPort) { packetList, srcConnRefCon in
            self.handleMIDIPackets(packetList)
        }

        // Create output port (for future use)
        MIDIOutputPortCreate(midiClient, "Output" as CFString, &outputPort)

        // Start device scanning
        deviceScanner.startScanning()
    }

    func connect(to device: MIDIDevice) throws {
        guard let source = device.source else {
            throw MIDIError.invalidDevice
        }

        let status = MIDIPortConnectSource(inputPort, source, nil)
        guard status == noErr else {
            throw MIDIError.connectionFailed
        }

        connectedDevices.append(device)
        notifyDeviceConnected(device)
    }

    func disconnect(from device: MIDIDevice) throws {
        guard let source = device.source else { return }

        let status = MIDIPortDisconnectSource(inputPort, source)
        guard status == noErr else {
            throw MIDIError.disconnectionFailed
        }

        connectedDevices.removeAll { $0.id == device.id }
        notifyDeviceDisconnected(device)
    }

    private func handleMIDIPackets(_ packetList: UnsafePointer<MIDIPacketList>) {
        eventHandler.handlePacketList(packetList)
    }

    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) {
        let message = notification.pointee

        switch message.messageID {
        case .msgObjectAdded:
            deviceScanner.rescan()
        case .msgObjectRemoved:
            handleDeviceRemoved(notification)
        default:
            break
        }
    }
}
```

### 2. MIDIDeviceScanner

**Responsibility:** Discover and enumerate MIDI devices across all protocols.

**Key Tasks:**
- Scan for Bluetooth MIDI devices
- Enumerate USB MIDI devices
- Browse network MIDI sessions
- Provide device list to UI

**File:** `/MIDI/MIDIDeviceScanner.swift`

```swift
class MIDIDeviceScanner {
    private let midiClient: MIDIClientRef

    func startScanning() {
        scanBluetoothDevices()
        scanUSBDevices()
        scanNetworkDevices()
    }

    func scanBluetoothDevices() -> [MIDIDevice] {
        var devices: [MIDIDevice] = []

        // Bluetooth MIDI devices appear as sources
        let sourceCount = MIDIGetNumberOfSources()

        for i in 0..<sourceCount {
            let source = MIDIGetSource(i)
            if let device = createDevice(from: source, type: .bluetooth) {
                devices.append(device)
            }
        }

        return devices
    }

    func scanUSBDevices() -> [MIDIDevice] {
        var devices: [MIDIDevice] = []

        let deviceCount = MIDIGetNumberOfDevices()

        for i in 0..<deviceCount {
            let device = MIDIGetDevice(i)
            var property: Unmanaged<CFString>?

            // Check if USB device
            MIDIObjectGetStringProperty(device, kMIDIPropertyDriverOwner, &property)

            if let driverOwner = property?.takeRetainedValue() as String?,
               driverOwner.contains("AppleUSBAudio") {
                if let midiDevice = createDevice(from: device, type: .usb) {
                    devices.append(midiDevice)
                }
            }
        }

        return devices
    }

    func scanNetworkDevices() -> [MIDIDevice] {
        var devices: [MIDIDevice] = []

        // Network MIDI uses MIDINetworkSession
        let session = MIDINetworkSession.default()
        session.isEnabled = true
        session.connectionPolicy = .anyone

        // Network devices appear as sources
        for connection in session.connections() {
            if let device = createDevice(from: connection, type: .network) {
                devices.append(device)
            }
        }

        return devices
    }

    private func createDevice(from source: MIDIEndpointRef, type: MIDIDeviceType) -> MIDIDevice? {
        var name: Unmanaged<CFString>?
        MIDIObjectGetStringProperty(source, kMIDIPropertyName, &name)

        guard let deviceName = name?.takeRetainedValue() as String? else {
            return nil
        }

        return MIDIDevice(
            id: UUID(),
            name: deviceName,
            type: type,
            source: source
        )
    }
}

enum MIDIDeviceType {
    case bluetooth
    case usb
    case network
}

struct MIDIDevice: Identifiable {
    let id: UUID
    let name: String
    let type: MIDIDeviceType
    let source: MIDIEndpointRef?
}
```

### 3. MIDIEventHandler

**Responsibility:** Parse MIDI packets and route to audio thread.

**Key Tasks:**
- Parse MIDI bytes (status, data1, data2)
- Identify message type (Note On, Note Off, CC, etc.)
- Timestamp events immediately
- Dispatch to audio queue

**File:** `/MIDI/MIDIEventHandler.swift`

**Critical Pattern: Immediate Timestamping**

```swift
class MIDIEventHandler {
    private let audioQueue: DispatchQueue
    weak var delegate: MIDIEventDelegate?

    // Called on Core MIDI thread
    func handlePacketList(_ packetList: UnsafePointer<MIDIPacketList>) {
        var packet = packetList.pointee.packet
        let timestamp = mach_absolute_time() // Capture immediately!

        for _ in 0..<packetList.pointee.numPackets {
            handlePacket(packet, timestamp: timestamp)
            packet = MIDIPacketNext(&packet).pointee
        }
    }

    private func handlePacket(_ packet: MIDIPacket, timestamp: UInt64) {
        let bytes = Mirror(reflecting: packet.data).children.prefix(Int(packet.length))
        let data = Array(bytes.map { $0.value as! UInt8 })

        guard data.count >= 1 else { return }

        let status = data[0] & 0xF0
        let channel = data[0] & 0x0F

        // Parse message type
        let message: MIDIMessage?

        switch status {
        case 0x80: // Note Off
            guard data.count >= 3 else { return }
            message = .noteOff(channel: channel, note: data[1], velocity: data[2])

        case 0x90: // Note On
            guard data.count >= 3 else { return }
            message = .noteOn(channel: channel, note: data[1], velocity: data[2])

        case 0xB0: // Control Change
            guard data.count >= 3 else { return }
            message = .controlChange(channel: channel, controller: data[1], value: data[2])

        case 0xE0: // Pitch Bend
            guard data.count >= 3 else { return }
            let value = Int(data[1]) | (Int(data[2]) << 7)
            message = .pitchBend(channel: channel, value: value)

        default:
            message = nil
        }

        // Immediately dispatch to audio thread
        if let message = message {
            audioQueue.async { [weak self] in
                self?.delegate?.didReceiveMIDIMessage(message, timestamp: timestamp)
            }
        }
    }
}

protocol MIDIEventDelegate: AnyObject {
    func didReceiveMIDIMessage(_ message: MIDIMessage, timestamp: UInt64)
}

enum MIDIMessage {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case pitchBend(channel: UInt8, value: Int)
}
```

### 4. MIDICommandMapper

**Responsibility:** Map MIDI messages to application commands.

**Key Tasks:**
- Maintain user-configurable mappings
- Map MIDI → App commands
- Validate commands
- Load/save mappings

**File:** `/MIDI/MIDICommandMapper.swift`

```swift
class MIDICommandMapper: MIDIEventDelegate {
    private var mappings: [MIDIMapping] = []
    weak var delegate: CommandDelegate?

    // Load user mappings
    func loadMappings(for device: MIDIDevice) {
        // Load from JSON or defaults
        mappings = MIDIDeviceConfig.loadMappings(for: device.id) ?? defaultMappings()
    }

    // Called on audio thread
    func didReceiveMIDIMessage(_ message: MIDIMessage, timestamp: UInt64) {
        guard let command = mapToCommand(message) else { return }

        // Execute on audio thread
        delegate?.didReceiveCommand(command, timestamp: timestamp)
    }

    private func mapToCommand(_ message: MIDIMessage) -> AppCommand? {
        for mapping in mappings {
            if mapping.matches(message) {
                return mapping.command
            }
        }
        return nil
    }

    private func defaultMappings() -> [MIDIMapping] {
        return [
            // Foot pedal (CC 64) → Next Chord
            MIDIMapping(
                trigger: .controlChange(controller: 64, valueRange: 64...127),
                command: .nextChord
            ),
            // Note C1 → Previous Chord
            MIDIMapping(
                trigger: .noteOn(note: 36, velocityRange: 1...127),
                command: .previousChord
            ),
            // Note D1 → Toggle Play/Pause
            MIDIMapping(
                trigger: .noteOn(note: 38, velocityRange: 1...127),
                command: .togglePlayback
            ),
            // CC 1 (Mod Wheel) → Set Tempo
            MIDIMapping(
                trigger: .controlChange(controller: 1, valueRange: 0...127),
                command: .setTempo
            )
        ]
    }
}

protocol CommandDelegate: AnyObject {
    func didReceiveCommand(_ command: AppCommand, timestamp: UInt64)
}

struct MIDIMapping: Codable {
    let trigger: MIDITrigger
    let command: AppCommand

    func matches(_ message: MIDIMessage) -> Bool {
        switch (trigger, message) {
        case (.controlChange(let cc, let range), .controlChange(_, let controller, let value)):
            return controller == cc && range.contains(value)

        case (.noteOn(let note, let range), .noteOn(_, let n, let velocity)):
            return n == note && range.contains(velocity)

        default:
            return false
        }
    }
}

enum MIDITrigger: Codable {
    case noteOn(note: UInt8, velocityRange: ClosedRange<UInt8>)
    case noteOff(note: UInt8)
    case controlChange(controller: UInt8, valueRange: ClosedRange<UInt8>)
}

enum AppCommand: Codable {
    case nextChord
    case previousChord
    case togglePlayback
    case setTempo
    case startLoop
    case endLoop
}
```

### 5. Integration with EventSequencer

**Pattern:** MIDI commands trigger quantized events.

```swift
// In EventSequencer
class EventSequencer: CommandDelegate {
    private let quantizer: QuantizationEngine
    private let musicalClock: MusicalClock

    // Called on audio thread
    func didReceiveCommand(_ command: AppCommand, timestamp: UInt64) {
        switch command {
        case .nextChord:
            // Calculate next quantized beat
            let currentBeat = musicalClock.currentBeat
            let quantizedBeat = quantizer.nextBeatOnGrid(after: currentBeat, grid: .quarter)

            // Schedule chord change
            scheduleEvent(.chordChange, at: quantizedBeat)

        case .togglePlayback:
            if isPlaying {
                stop()
            } else {
                start()
            }

        case .startLoop:
            loopStartBeat = musicalClock.currentBeat

        case .endLoop:
            loopEndBeat = musicalClock.currentBeat
            enableLoop = true

        default:
            break
        }
    }
}
```

## MIDI Timing & Quantization

### Challenge
MIDI messages arrive asynchronously and must be quantized to musical grid.

### Solution
1. **Timestamp Immediately:** Capture `mach_absolute_time()` in MIDI callback
2. **Correlate to Audio Time:** Convert MIDI timestamp → audio sample time
3. **Quantize:** Snap to next grid point (beat, bar)
4. **Schedule:** Use sample-accurate scheduling

```swift
class QuantizationEngine {
    enum QuantizationGrid {
        case quarter   // 1/4 note
        case eighth    // 1/8 note
        case sixteenth // 1/16 note
        case bar       // Whole bar
    }

    func nextBeatOnGrid(after beat: Double, grid: QuantizationGrid) -> Double {
        let gridSize: Double

        switch grid {
        case .quarter:
            gridSize = 1.0
        case .eighth:
            gridSize = 0.5
        case .sixteenth:
            gridSize = 0.25
        case .bar:
            gridSize = 4.0 // Assuming 4/4 time
        }

        // Round up to next grid point
        let nextGrid = ceil(beat / gridSize) * gridSize

        // Handle lookahead (trigger slightly before beat)
        let lookahead = 0.1 // 100ms lookahead
        return max(nextGrid, beat + lookahead)
    }

    func quantize(_ timestamp: UInt64, to grid: QuantizationGrid) -> AVAudioTime {
        // Convert MIDI timestamp to audio time
        let audioTime = convertToAudioTime(timestamp)

        // Get current beat
        let beat = musicalClock.sampleTimeToBeat(audioTime.sampleTime)

        // Quantize
        let quantizedBeat = nextBeatOnGrid(after: beat, grid: grid)

        // Convert back to audio time
        let quantizedSampleTime = musicalClock.beatToSampleTime(quantizedBeat)

        return AVAudioTime(sampleTime: quantizedSampleTime, atRate: audioTime.sampleRate)
    }
}
```

## Device Configuration & Persistence

### MIDIDeviceConfig

**Responsibility:** Store and load user MIDI mappings.

**File:** `/MIDI/MIDIDeviceConfig.swift`

```swift
class MIDIDeviceConfig {
    private static let storageURL: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("midi-mappings.json")
    }()

    static func saveMappings(_ mappings: [MIDIMapping], for deviceID: UUID) throws {
        var config = loadAllConfigs() ?? [:]
        config[deviceID.uuidString] = mappings

        let data = try JSONEncoder().encode(config)
        try data.write(to: storageURL)
    }

    static func loadMappings(for deviceID: UUID) -> [MIDIMapping]? {
        guard let config = loadAllConfigs() else { return nil }
        return config[deviceID.uuidString]
    }

    private static func loadAllConfigs() -> [String: [MIDIMapping]]? {
        guard let data = try? Data(contentsOf: storageURL) else { return nil }
        return try? JSONDecoder().decode([String: [MIDIMapping]].self, from: data)
    }
}
```

## Error Handling

### Common MIDI Issues

1. **Device Not Found**
   - Symptom: Device appears disconnected
   - Fix: Rescan devices, check Bluetooth/USB connection

2. **MIDI Jitter**
   - Symptom: Commands execute at wrong time
   - Fix: Timestamp immediately, use quantization

3. **Connection Dropouts**
   - Symptom: Messages stop arriving
   - Fix: Handle reconnection, notify user

4. **Message Flooding**
   - Symptom: Too many MIDI messages
   - Fix: Throttle messages, debounce

```swift
class MIDIErrorHandler {
    func handleError(_ error: MIDIError) {
        switch error {
        case .deviceNotFound:
            notifyUser("MIDI device not found. Check connection.")
            rescanDevices()

        case .connectionFailed:
            notifyUser("Failed to connect to MIDI device.")
            // Retry after delay

        case .messageTooShort:
            // Log and ignore

        case .invalidMessage:
            // Log and ignore
        }
    }
}

enum MIDIError: Error {
    case clientCreationFailed
    case deviceNotFound
    case connectionFailed
    case disconnectionFailed
    case messageTooShort
    case invalidMessage
}
```

## Testing Strategy

### Unit Tests
- MIDI message parsing (bytes → MIDIMessage)
- Command mapping (MIDIMessage → AppCommand)
- Quantization accuracy (timestamp → quantized beat)

### Integration Tests
- Device discovery (Bluetooth, USB, Network)
- Connection lifecycle (connect, disconnect, reconnect)
- Message routing (MIDI → Audio → UI)

### Manual Testing
- Test with multiple device types:
  - Bluetooth foot pedal
  - USB MIDI keyboard (via Camera Adapter)
  - Network MIDI from Mac
- Measure MIDI jitter (< 5ms target)
- Test rapid successive commands
- Test connection stability (long session)

## Performance Monitoring

### Key Metrics

1. **MIDI Latency:** < 5ms jitter
   - Measure: Timestamp in callback → Event execution
   - Tool: High-resolution timer

2. **Message Loss:** Zero tolerance
   - Monitor: Missing expected messages
   - Log: Dropped packets

3. **Connection Stability:** > 99% uptime
   - Monitor: Disconnection events
   - Log: Connection duration

## UI Integration

### Settings View

```swift
struct MIDISettingsView: View {
    @StateObject var viewModel: MIDISettingsViewModel

    var body: some View {
        List {
            Section("Connected Devices") {
                ForEach(viewModel.connectedDevices) { device in
                    HStack {
                        Text(device.name)
                        Spacer()
                        Text(device.type.displayName)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Available Devices") {
                ForEach(viewModel.availableDevices) { device in
                    Button {
                        viewModel.connect(to: device)
                    } label: {
                        HStack {
                            Text(device.name)
                            Spacer()
                            Image(systemName: "plus.circle")
                        }
                    }
                }
            }

            Section("MIDI Mapping") {
                ForEach(viewModel.mappings) { mapping in
                    HStack {
                        Text(mapping.trigger.description)
                        Spacer()
                        Text(mapping.command.description)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .navigationTitle("MIDI Settings")
        .onAppear {
            viewModel.scanDevices()
        }
    }
}
```

## Critical Risks & Mitigations

### Risk 1: MIDI Jitter > 5ms
**Cause:** Delayed timestamping, slow callback processing
**Fix:** Timestamp immediately in callback, optimize parsing

### Risk 2: Device Discovery Failures
**Cause:** Bluetooth/USB permissions, device compatibility
**Fix:** Request permissions early, test with multiple devices

### Risk 3: Connection Dropouts
**Cause:** Bluetooth interference, USB cable issues
**Fix:** Implement reconnection logic, notify user

### Risk 4: Message Flooding
**Cause:** User holding pedal, rapid CC changes
**Fix:** Debounce messages, throttle updates

## Next Steps

1. Implement MIDIManager with device lifecycle
2. Implement MIDIDeviceScanner for all protocols
3. Implement MIDIEventHandler with immediate timestamping
4. Implement MIDICommandMapper with default mappings
5. Integrate with EventSequencer
6. Add MIDI settings UI
7. Test with real MIDI devices

---

**Related Documents:**
- [Architecture Overview](architecture-overview.md)
- [Audio Architecture](audio-architecture.md)
- [State Management](state-management.md)
- [ADR-003: MIDI Integration](../adr/ADR-003-midi-integration.md)
