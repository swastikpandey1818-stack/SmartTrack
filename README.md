# Smart Track

Flutter Android app for the ESP32 smart plant system.

- ESP32: `GET /status`, `/pump/on`, `/pump/off`, `/pump/auto` (default `http://192.168.4.1`, changeable in Settings)
- Weather: Open-Meteo forecast + geocoding (no key)
- Storage: SQLite (readings, history, alerts) + SharedPreferences (settings, offline cache)

Structure: `lib/domain` (pure logic, tested) · `lib/data` (ESP32, weather, DB, cache) ·
`lib/services` (notifications) · `lib/app` (controller) · `lib/ui` (screens, widgets).

Build: push to `main`; GitHub > Actions > "Build Smart Track APK" > artifact `smart-track-v1.0.0-apk`.

