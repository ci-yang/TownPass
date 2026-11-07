// 城市通微服務大黑客松 2026：我們的微服務入口設定。
//
// 換 URL 只要改這一個常數，或在建置時用 --dart-define 覆蓋（不必改程式）：
//   fvm flutter run --dart-define=CODEFEST_SERVICE_URL=http://192.168.1.23:5173
//
// 常見值：
// - Android 模擬器 → 開發機 localhost：http://10.0.2.2:5173（預設）
// - iOS 模擬器 → 開發機 localhost：http://localhost:5173
// - 實機（手機與開發機同一 Wi-Fi）：http://<開發機區網 IP>:5173
//   查 IP：macOS 執行 `ipconfig getifaddr en0`；dev server 要綁 0.0.0.0（Vite 用 `--host`）
// - 部署後（正式）：https://codefest.ciyang.dev
const String kCodefestServiceUrl = String.fromEnvironment(
  'CODEFEST_SERVICE_URL',
  defaultValue: 'http://10.0.2.2:5173',
);
