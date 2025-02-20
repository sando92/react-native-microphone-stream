# React Native Microphone Stream

A high-performance native module for real-time audio capture and streaming in React Native. Optimized for applications requiring continuous audio processing such as sound visualization, audio analysis, and real-time sound detection.

## Features

- 🎤 Real-time audio streaming with configurable settings
- ⚡️ High-performance native implementation
- 📊 16-bit PCM audio data output
- ⚙️ Configurable sample rate, channels, and buffer size
- 🔄 Continuous streaming with minimal latency
- 📱 iOS and Android support
- 🎯 Optimized for audio analysis applications

## Installation

1. Add the GitHub repository to your dependencies in `package.json`:
```json
{
  "dependencies": {
    "react-native-microphone-stream": "github:sando92/react-native-microphone-stream"
  }
}
```

2. Install dependencies:
```bash
npm install
# or
yarn install
```

Alternatively, you can install directly using npm/yarn:
```bash
npm install github:sando92/react-native-microphone-stream
# or
yarn add github:sando92/react-native-microphone-stream
```

### iOS Setup

1. Add microphone permission to `Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>We need access to your microphone to record audio</string>
```

2. Install pods:
```bash
cd ios && pod install
```

### Android Setup

1. Add permission to `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
```

## Basic Usage

```javascript
import React, { useEffect } from 'react';
import MicrophoneStream from 'react-native-microphone-stream';

function AudioComponent() {
  useEffect(() => {
    // Configure audio settings
    MicrophoneStream.init({
      sampleRate: 44100,      // 44.1kHz for full audio spectrum
      channels: 1,            // Mono audio
      bitsPerSample: 16,      // 16-bit audio
      audioSource: Platform.select({
        android: 5,           // MediaRecorder.AudioSource.CAMCORDER
        ios: undefined,
      }),
    });

    // Start listening to audio data
    const subscription = MicrophoneStream.addListener((data) => {
      // data is an array of 16-bit PCM samples
      processAudioData(data);
    });

    // Start recording
    MicrophoneStream.start();

    // Cleanup on unmount
    return () => {
      MicrophoneStream.stop();
      subscription.remove();
    };
  }, []);

  const processAudioData = (data) => {
    // Process your audio data here
    // Example: Calculate audio level
    const sum = data.reduce((acc, val) => acc + Math.abs(val), 0);
    const average = sum / data.length;
    console.log('Average audio level:', average);
  };

  return null; // Or your UI components
}
```

## Common Use Cases

### 1. Audio Level Monitoring
```javascript
const calculateDecibels = (data) => {
  if (!data.length) return -Infinity;
  
  // Calculate RMS (Root Mean Square)
  const sum = data.reduce((acc, val) => acc + (val * val), 0);
  const rms = Math.sqrt(sum / data.length);
  
  // Convert to dB (reference level is maximum PCM value)
  return 20 * Math.log10(rms / 32768);
};
```

### 2. Waveform Visualization
```javascript
const calculateWaveform = (data, segments = 64) => {
  const samplesPerSegment = Math.floor(data.length / segments);
  const waveform = new Array(segments).fill(0);
  
  for (let i = 0; i < segments; i++) {
    let sum = 0;
    const offset = i * samplesPerSegment;
    
    // Calculate average amplitude for this segment
    for (let j = 0; j < samplesPerSegment; j++) {
      sum += Math.abs(data[offset + j] || 0);
    }
    
    waveform[i] = sum / samplesPerSegment;
  }
  
  return waveform;
};
```

### 3. Frequency Analysis
```javascript
const detectFrequencyRange = (data, sampleRate = 44100) => {
  let zeroCrossings = 0;
  
  // Count zero crossings to estimate frequency
  for (let i = 1; i < data.length; i++) {
    if (data[i] * data[i - 1] < 0) {
      zeroCrossings++;
    }
  }
  
  // Calculate fundamental frequency
  return (zeroCrossings * sampleRate) / (2 * data.length);
};
```

## API Reference

### Methods

#### `init(options: AudioConfig)`
Initialize the audio capture system with specified configuration.

Options:
- `sampleRate`: number (default: 44100)
- `channels`: number (default: 1)
- `bitsPerSample`: number (default: 16)
- `audioSource`: number (Android only, default: 5)

#### `start()`
Start audio capture and streaming.

#### `stop()`
Stop audio capture and streaming.

#### `pause()`
Pause audio capture (maintains resources).

#### `addListener(callback: (data: number[]) => void)`
Add a listener for audio data. Returns a subscription object with a `remove()` method.

### Audio Data Format

The audio data is provided as an array of 16-bit PCM samples, normalized to the range [-32768, 32767].

## Performance Considerations

1. **Buffer Size**: The default buffer size is optimized for most use cases. Adjust if needed:
   - Smaller buffers: Lower latency but more CPU usage
   - Larger buffers: Higher latency but less CPU usage

2. **Sample Rate**: Choose based on your needs:
   - 44.1kHz: Full audio spectrum (recommended for music)
   - 22.05kHz: Adequate for voice
   - 16kHz: Minimal for basic audio detection

3. **Memory Management**: Always remove listeners when components unmount:
```javascript
useEffect(() => {
  const subscription = MicrophoneStream.addListener(handleAudio);
  return () => subscription.remove();
}, []);
```

## Troubleshooting

1. **No Audio Data**:
   - Check microphone permissions
   - Verify initialization configuration
   - Ensure no other app is using the microphone

2. **High Latency**:
   - Reduce buffer size
   - Simplify audio processing in listeners
   - Check for blocking operations in the JS thread

3. **iOS Issues**:
   - Verify audio session configuration
   - Check Info.plist permissions
   - Ensure proper pod installation

4. **Android Issues**:
   - Verify manifest permissions
   - Check audioSource compatibility
   - Test with different Android API levels

## License

MIT
