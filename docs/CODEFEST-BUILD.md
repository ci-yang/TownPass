# Codefest Android 建置與交接

`scripts/build-codefest.sh` 以環境變數指定這次 APK 的微服務入口。`lib/config/codefest.dart` 的預設值是 `https://codefest.ciyang.dev`；腳本仍要求明確提供 `CODEFEST_SERVICE_URL`，避免將尚未確認的部署網址包入 APK。這是公開入口，不能包含 token、帳密或其他 secret。

## 工具與檢查

Flutter 版本以 `.fvmrc` 為準，目前為 3.47.6（Dart 3.13.5）。需要 Python 3、Java 17、Android SDK 36；目前 Gradle 設定使用 NDK 29.0.13113456。把 Flutter 的 `bin` 加入 `PATH`，設定 `JAVA_HOME` 及 `ANDROID_HOME`；也可個別指定 `FLUTTER_BIN` 與 `DART_BIN`。

以下流程不產出 APK。請先把環境變數設為已確認的部署入口，再執行：

```bash
python3 scripts/test_build_codefest.py
bash scripts/build-codefest.sh --dry-run
bash scripts/build-codefest.sh --check
```

腳本依序鎖定 `pubspec.lock` 安裝依賴、執行 `build_runner`、分析本次設定與測試、驗證 Codefest 入口和既有官方服務入口，最後用 `flutter build apk --config-only` 產生 Android 建置設定。`--check` 不代表 Android 編譯通過，也不代表實機測試通過。

完整專案檢查另外執行 `flutter analyze --no-pub` 與 `flutter test --no-pub`。目前 repo 的 `test/widget_test.dart` 是 counter 範本；需與 Codefest 專用測試的結果分開判讀。

2026-11-07 在 `feat/codefest-platform` 的檢查結果：建置入口 7 組 Python 測試、Codefest 2 個 Flutter 測試、本次設定與測試的分析、`--check` 全部通過。全專案分析回報 25 項 warning/info；全套測試的 counter 範本失敗（找不到預期的 `0`）。這些問題所在檔案未在本次修改。ADB 沒有連接裝置，尚未執行實機驗收。

## 產出 APK

確認部署入口可以連線，且 `CODEFEST_SERVICE_URL` 已設為該 HTTPS URL 後：

```bash
bash scripts/build-codefest.sh
```

輸出為 `build/app/outputs/flutter-apk/app-release.apk`。目前 repo 的 release 使用 debug signing config，供比賽 demo 安裝；這不等於已完成商店簽署設定。

Android 模擬器使用開發機服務時，HTTP 例外必須明確開啟；開發伺服器需監聽 `0.0.0.0`：

```bash
CODEFEST_SERVICE_URL=http://10.0.2.2:5173 \
  bash scripts/build-codefest.sh --debug --allow-emulator-http
```

HTTP 例外只接受 Android 模擬器的 `10.0.2.2`，其他主機及 release 模式都要求 HTTPS。此限制在 Codefest 建置入口套用；沒有變更共用 WebView 的 origin 政策或其他服務的 cleartext 設定。

## 裝置驗收待辦

連接 Android 12 以上裝置後，仍需確認「台北通通通懂台北」入口載入這次部署、選擇精確或概略定位可收到 bridge 回覆、拒絕定位時頁面可以繼續操作，並抽查其他官方服務入口。沒有連接裝置時不可把這些項目寫成通過。

本次 manifest 同時宣告 `ACCESS_FINE_LOCATION` 與 `ACCESS_COARSE_LOCATION`，依據 [Android 官方定位權限說明](https://developer.android.com/codelabs/approximate-location)。APK 建置與簽署參考 [Flutter 官方 Android 發布文件](https://docs.flutter.dev/deployment/android)。
