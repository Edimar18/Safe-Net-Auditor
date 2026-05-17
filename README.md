# Safe-Net Auditor

**Localized, offline 802.11 network security visualization.**
Sniff management frames with an ESP32 — visualize threats, deauth attacks, evil twins, and channel congestion in real time on an Android device over USB-C Serial. No cloud, no internet, no API keys.

---

## Screenshots

<!-- Replace these placeholders with actual screenshots -->
<p align="center">
  <img src="assets/screenshots/dashboard.png" width="200" alt="Dashboard" />
  <img src="assets/screenshots/auditor.png" width="200" alt="Auditor" />
  <img src="assets/screenshots/spectrum.png" width="200" alt="Spectrum" />
  <img src="assets/screenshots/history.png" width="200" alt="History" />
  <img src="assets/screenshots/settings.png" width="200" alt="Settings" />
</p>

> **To add screenshots:** Place PNG files in `assets/screenshots/` with these names:
> `dashboard.png` `auditor.png` `spectrum.png` `history.png` `settings.png`

---

## Features

### Real-Time Monitoring (Dashboard)
- **Live MGMT frame counter** — global or per-AP, with 40-point rolling bar graph
- **Trust Score gauge** (0–100) — drops on deauth spikes, high traffic, or evil twin presence
- **Threat banner** — ALL CLEAR / HIGH CONGESTION / UNDER ATTACK with animated color
- **Color-coded RSSI widget** — green (excellent) through red (dead zone)
- **Deauth counter** — red border when above threshold

### Attack Detection (Auditor)
- **Deauth spike graph** — 40-point rolling histogram, red bars above 20/sec
- **Deauth target identification** — BSSID Fingerprint flashes red on APs receiving deauth frames
- **Evil Twin Scanner** — groups BSSIDs sharing the same SSID, flags Espressif-chipset pairs as phishing risk, shows RSSI delta warnings for close-proximity twins
- **Per-AP BSSID fingerprint** — MAC, channel, signal strength, frame rate, vendor OUI, one-tap trust toggle

### Spectrum Analysis (Spectrum)
- **Channel congestion bar chart** — 1–13 real-time with grid lines and peak highlight
- **RSSI line graph** — 60-point rolling with reference lines at -30/-50/-70/-90 dBm
- **Live AP table** — sortable by signal strength with per-channel details

### Historical Analytics (History)
- **90-day incident heatmap** — severity color scale (grey → white → red)
- **24-hour traffic trends** — average frames/sec per hour bucket from SQLite
- **Database summary** — row counts for snapshots, APs logged, incidents
- **CSV Export** — raw snapshot telemetry for Excel / expert analysis
- **PDF Export** — comprehensive multi-page report with stats, tables, heatmap, network catalogue

### Settings
- Configurable deauth and packet thresholds
- Trusted network whitelist (MAC-based)
- Audit logging toggle
- Full database purge

---

## How It Works

```
ESP32 (Promiscuous Sniffer)
  │  • Channel hops 1–13 every 60ms
  │  • Sniffs 802.11 management frames only
  │  • Tracks per-AP frame counts, deauth targets, channel load
  │  • Outputs newline-delimited JSON at 1Hz over USB-C Serial @ 115200 baud
  │
  ▼ USB-C OTG Cable
Android Device
  │  • usb_serial reads raw bytes → buffers → splits on newline → parses JSON
  │  • Provider state updates live fields, rolling buffers, triggers UI rebuild
  │  • Every snapshot persisted to SQLite (snapshots, networks, RSSI, channels, incidents)
  │  • UI: 5-tab bottom navigation (Dashboard, Auditor, Spectrum, History, Settings)
```

### Hardware Required
- **ESP32 DevKit** (any variant — DevKit V1, S2, S3)
- **USB-C OTG adapter** (USB-A female to USB-C male, or direct USB-C)
- **Android phone/tablet** running Android 7+

### Software Stack
| Layer | Technology |
|-------|-----------|
| Firmware | Arduino C++ (ESP32, ArduinoJson 6.x) |
| App Framework | Flutter 3.x / Dart 3.9 |
| State Management | Provider (ChangeNotifier) |
| Persistence | SQLite (sqflite) |
| Serial | usb_serial (Android USB host) |
| Charts | CustomPaint / CustomPainter (hand-drawn) |
| UI | Space Mono font, retro terminal aesthetic |

---

## Quick Start

### 1. Flash the ESP32
1. Open `ESP32-CODE/ESP32-CODE.ino` in Arduino IDE
2. Install **ArduinoJson** (6.x) via Library Manager
3. Select board: **ESP32 Dev Module**
4. Upload

### 2. Build the Flutter App
```bash
flutter pub get
flutter run          # debug on connected device
flutter build apk    # release APK
```

### 3. Connect
1. Plug ESP32 into phone via USB-C OTG adapter
2. Launch Safe-Net Auditor
3. Tap **RETRY** on the connection banner if needed
4. Data flows live within 1 second

---

## Limitations

- **2.4 GHz only** — no 5 GHz / 6 GHz support (ESP32 hardware limitation)
- **Android only** — USB host mode required, no iOS/desktop
- **Management frames only** — does not capture data frames or encrypted payload
- **Passive sniffing** — no packet injection, no deauth transmission
- **Single ESP32 per device** — only one USB serial device connected at a time
- **No background operation** — app must be in foreground to receive serial data
- **OUI database is hardcoded** — ~30 vendors, not a full IEEE registry lookup
- **Channel hop at 60ms** — may miss frames on busy channels; a full 13-channel cycle takes ~780ms
- **Trust Score is heuristic** — not a cryptographic security assessment

---

## Project Structure

```
lib/
├── main.dart                          # App entry, theme, 5-tab scaffold
├── models/
│   └── network_model.dart             # NetworkInfo, NetworkData, TrustedNetwork
├── providers/
│   └── network_provider.dart          # Central ChangeNotifier state
├── screens/
│   ├── dashboard_screen.dart          # Live counters, trust gauge, threat banner
│   ├── auditor_screen.dart            # Deauth graph, evil twin scan, fingerprint
│   ├── spectrum_screen.dart           # Channel chart, RSSI line, AP table
│   ├── history_screen.dart            # Heatmap, trends, CSV/PDF export
│   └── settings_screen.dart           # Thresholds, trusted MACs, DB management
├── services/
│   ├── serial_service.dart            # USB-OTG serial to ESP32
│   ├── database_service.dart          # SQLite (7 tables, analytics queries)
│   └── export_service.dart            # CSV + PDF generation
└── widgets/
    ├── retro_widgets.dart             # UI kit: panels, buttons, text, sliders
    ├── trust_gauge.dart               # Semicircular gauge (CustomPaint)
    ├── ap_selector.dart               # Per-AP dropdown with signal bars
    └── connection_banner.dart         # ESP32 connection status banner

ESP32-CODE/
└── ESP32-CODE.ino                     # Arduino firmware for ESP32
```

---

## Contributing

### Adding Features
- **New ESP32 data field:** Edit `network_model.dart` → `network_provider.dart` → update firmware `ESP32-CODE.ino`
- **New screen:** Create in `lib/screens/` → register in `main.dart` bottom nav
- **New widget:** Add to `lib/widgets/` if reusable across screens
- **New DB column:** Bump schema version in `database_service.dart` with migration

### Code Style
- Monospaced Space Mono font for all text
- Terminal/retro aesthetic: black background, white borders, 0px border radius
- UPPERCASE headers and labels
- Color palette: `#000000` bg, `#FFFFFF` fg, `#39FF14` green accent, `#FF0000` red for danger
- All custom painting via `CustomPainter` — no third-party chart libraries for live data

### Testing
```bash
flutter test                     # Run widget tests
dart analyze                    # Static analysis
flutter build apk --debug       # Verify build
```

### Pull Requests
1. Fork the repository
2. Create a feature branch (`feature/cool-thing`)
3. Run `dart analyze` — zero errors required
4. Test on a physical Android device with ESP32 connected
5. Open a PR with description and screenshots if UI changed

---

## License

MIT License — use freely, attribution appreciated.

---

## Acknowledgments

- **Espressif** for the ESP32 promiscuous mode API
- **ArduinoJson** by Benoit Blanchon
- **Flutter** and the Dart team
- **Space Mono** by Colophon Foundry (Google Fonts)
