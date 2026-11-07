// 城市通微服務大黑客松 2026：我們的微服務入口設定。
//
// 建置入口：CODEFEST_SERVICE_URL=https://<已確認的服務網址> bash scripts/build-codefest.sh
// 腳本會以 --dart-define 覆蓋此預設；請勿放入 token 或其他 secret。
//
// Android 模擬器連線開發機時，明確使用：
//   CODEFEST_SERVICE_URL=http://10.0.2.2:5173 \
//     bash scripts/build-codefest.sh --debug --allow-emulator-http
// 開發伺服器需綁 0.0.0.0（Vite 用 --host）。完整操作見 docs/CODEFEST-BUILD.md。
const String kCodefestServiceUrl = String.fromEnvironment(
  'CODEFEST_SERVICE_URL',
  defaultValue: 'https://codefest.ciyang.dev',
);
