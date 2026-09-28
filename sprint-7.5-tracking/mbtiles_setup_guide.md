# How to Get the Offline Map File (MBTiles)

The pre-bundled map is a single `.mbtiles` file (SQLite database of PNG tiles)
downloaded from free, open-source tools. No API key, no cost.

---

## Step 1 — Download the map for Chhatrapati Sambhajinagar

Go to: https://extract.bbbike.org

1. Select format: **MBTiles (SQLite)**
2. On the map, draw a rectangle around Chhatrapati Sambhajinagar district
   - Centre roughly: 19.8762° N, 75.3433° E
   - Draw to include all areas: Osmanpura, Jyoti Nagar, Deshmesh Nagar, etc.
3. Enter your email → click Extract
4. You'll receive a download link within 10–30 minutes
5. Download the `.mbtiles` file (~30–80 MB depending on zoom levels)

**Alternative source:** https://openmaptiles.org/downloads/
- Download Maharashtra extract → crop with tool below if too large

---

## Step 2 — Trim to only the zoom levels you need

Install `mbtiles-optimizer` (Node.js, free):
```bash
npm install -g mbtiles-optimizer
mbtiles-optimizer input.mbtiles output.mbtiles --minZoom=10 --maxZoom=17
```

Zoom levels for this app:
- 10 = city overview (district level)
- 14 = neighbourhood level (most used)
- 17 = street level (delivery pin accuracy)

After trimming, the file should be 20–40 MB.

---

## Step 3 — Add to Flutter project

```
project_gsr_app/
└── assets/
    └── maps/
        └── csn_map.mbtiles    ← put the file here
```

Register in `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/maps/csn_map.mbtiles
```

**Note:** The first time the app runs, `MapService.init()` copies the file
from the APK bundle to the device's writable storage, then opens it as
a SQLite database. This takes 2–5 seconds on first launch only.

---

## Step 4 — Call init() at app startup

```dart
// In main.dart, before runApp()
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await MapService.init();   // copies MBTiles to device storage
  runApp(const GSRApp());
}
```

---

## Packages needed (add to pubspec.yaml)

```yaml
dependencies:
  flutter_map: ^6.0.0
  latlong2: ^0.9.0
  geolocator: ^12.0.0
  geocoding: ^3.0.0
  sqflite: ^2.3.2
  path_provider: ^2.1.0
  firebase_database: ^10.5.0
```

---

## Android permissions (android/app/src/main/AndroidManifest.xml)

Add inside `<manifest>` tag, before `<application>`:
```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.INTERNET"/>
```

---

## Updating the map

When roads or areas change (rare), replace `csn_map.mbtiles` and rebuild the APK.
OpenStreetMap data is community-maintained and regularly updated.
You can re-download a fresh extract from BBBike anytime — free, forever.
