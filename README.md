# AirCall – Your Voice. Your Network.

Offline voice calls between Android phones on the same Wi-Fi or hotspot.
No internet, no Firebase, no STUN/TURN, no analytics.

## Setup (once)
1. Install Flutter (stable) and Android Studio / Android SDK.
2. Unzip this folder, open a terminal inside it and run:
   `bash setup.sh`
   (creates the Android project, applies the manifest permissions, sets minSdk 23,
   installs packages and generates the launcher icons)
3. Start an Android emulator or connect an Android phone with USB debugging enabled.
   Run `flutter devices`, then start the app on that device with
   `flutter run -d <android-device-id> --release`. In VS Code, select the Android
   device in the device picker before pressing Run. This project targets Android;
   selecting Windows makes Flutter build the desktop app and download Windows WebRTC binaries.

## How it works
| Layer | File | What it does |
|---|---|---|
| Discovery | `core/services/discovery_service.dart` | UDP :45454 broadcast announce every 2 s, direct reply to new devices, /24 sweep on refresh |
| Signaling | `core/services/signaling_service.dart` | Every phone runs a TCP server on :45455. The caller connects to the callee and exchanges JSON lines (invite, ringing, accept, offer, answer, candidate, hangup, reject, busy) |
| Audio | `core/services/webrtc_service.dart` | flutter_webrtc, audio only, `iceServers: []` (host candidates only), echo cancellation + noise suppression |
| Call logic | `features/calling/call_controller.dart` | Riverpod state machine: calling → ringing → connecting → connected → ended, timers, quality, history |

Incoming messages are validated (size limit 64 KB, field types/lengths, protocol version,
handshake timeout, busy rejection while in a call).

## Dependencies
- flutter_riverpod – state management
- flutter_webrtc – real-time audio transport
- permission_handler – microphone permission
- shared_preferences – device name, theme, call history (local only)
- connectivity_plus – tells Wi-Fi from hotspot
- flutter_launcher_icons (dev) – adaptive icon from `assets/icon/`

## Android configuration
`android_overlay/.../AndroidManifest.xml` declares: INTERNET (required for local sockets),
ACCESS_NETWORK_STATE, ACCESS_WIFI_STATE, CHANGE_WIFI_MULTICAST_STATE, NEARBY_WIFI_DEVICES
(neverForLocation), RECORD_AUDIO, MODIFY_AUDIO_SETTINGS, BLUETOOTH(_CONNECT), WAKE_LOCK.
minSdk is 23 (set by `setup.sh`).

## Test checklist (two physical phones)
- Same Wi-Fi router, with and without internet
- Phone A hotspot, phone B joined to it (A's own IP shows as "Hotspot network")
- Call both directions, accept / decline / no answer / busy
- Mute, speaker, end call from each side
- Turn Wi-Fi off mid-call (call ends with "Connection lost")
- Settings → Network diagnostics shows ports and devices seen

## Known limits
- Calls only ring while AirCall is open. Receiving calls in the background needs an Android
  foreground service, which is not included.
- Some routers use "client isolation" and block phone-to-phone traffic; a phone hotspot always works.
- No ringtone sound (vibration only). Add an audio asset + player package if wanted.
- Discovery uses UDP broadcast rather than NSD/mDNS because it is more reliable on hotspots.
