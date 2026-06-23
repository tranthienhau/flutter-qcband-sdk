# Screenshot capture flow

This file documents how to (re)capture the screenshots committed in `screenshots/`.

## 1. Boot the simulator

```bash
# List available simulators
xcrun simctl list devices available

# Boot iPhone 17 Pro (or any iPhone simulator)
xcrun simctl boot "iPhone 17 Pro"

# Open Simulator.app so the booted device is visible
open -a Simulator
```

## 2. Enable screenshot / video mode

Open `lib/main.dart` and set the flag you need:

```dart
// For static PNG screenshots:
const kScreenshotMode = true;
const kVideoMode = false;

// For the video tour (used to produce demo.mp4):
const kScreenshotMode = false;
const kVideoMode = true;
```

## 3. Run the integration test (PNGs)

```bash
flutter pub get

flutter drive \
  --driver test_driver/integration_test.dart \
  --target integration_test/screenshot_test.dart \
  -d "iPhone 17 Pro"
```

Screenshots are written to `screenshots/NN-name.png` by the `onScreenshot` callback in `test_driver/integration_test.dart`.

## 4. Capture a video (demo.mp4)

With `kVideoMode = true` in `main.dart`:

```bash
# Start recording before launching the app
xcrun simctl io booted recordVideo screenshots/demo.mp4 &
RECORD_PID=$!

# Run the app (the video tour auto-navigates all screens)
flutter run -d "iPhone 17 Pro"

# After the tour ends (about 30 s), stop recording
kill $RECORD_PID
```

## How it works

- `kScreenshotMode = true` overrides `demoModeProvider` to `true` on startup and sets the router initial location to `/dashboard`, so the integration test starts with populated data.
- `kVideoMode = true` triggers `_runVideoTour()` in `ScanScreen`, which auto-starts a demo scan, connects to the first mock device, then auto-navigates through Heart Rate, Sleep, and SpO2 screens with timed delays.
- `MockQCBandRepository` supplies all data; no physical QCBand bracelet is needed.
