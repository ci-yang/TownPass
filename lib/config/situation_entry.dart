// 情境入口「我遇到了……」微服務入口設定（BRA-592，與「台北通通通懂台北」分開）。
//
// 換 URL 用 --dart-define 覆蓋，不必改程式：
//   fvm flutter run --dart-define=SITUATION_SERVICE_URL=http://localhost:8767
//
// 常見值（網頁在 taipei-codefest-2026 repo 的 docs/prototypes/situation-entry/，`pnpm prototype:situation` 起在 8767）：
// - Android 模擬器 → 開發機 localhost：http://10.0.2.2:8767（預設）
// - iOS 模擬器 → 開發機 localhost：http://localhost:8767
// - 實機：部署後的 https 網址（部署前要先跟負責人確認網址）
const String kSituationServiceUrl = String.fromEnvironment(
  'SITUATION_SERVICE_URL',
  defaultValue: 'http://10.0.2.2:8767',
);
