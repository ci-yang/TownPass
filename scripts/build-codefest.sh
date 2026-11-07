#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
用法：CODEFEST_SERVICE_URL=https://<服務網址> bash scripts/build-codefest.sh [選項]
  --check                 準備依賴、產碼、檢查設定及 Android 建置設定，不產出 APK
  --dry-run               驗證 URL 並列出命令，不執行 Flutter/Dart
  --debug                 建置 debug APK（預設 release）
  --allow-emulator-http   僅限 --debug 搭配 http://10.0.2.2 的明確開發例外
  --help                  顯示說明

需要 Flutter/Dart（版本見 .fvmrc）、Python 3、Java 17、Android SDK。
可用 FLUTTER_BIN、DART_BIN 指定執行檔。URL 必須是公開服務入口，不得含 secret。
EOF
}

mode=release
check_only=false
dry_run=false
allow_emulator_http=false
for argument in "$@"; do
  case "$argument" in
    --check) check_only=true ;;
    --dry-run) dry_run=true ;;
    --debug) mode=debug ;;
    --allow-emulator-http) allow_emulator_http=true ;;
    --help|-h) usage; exit 0 ;;
    *) printf '未知選項：%s\n' "$argument" >&2; usage >&2; exit 2 ;;
  esac
done

if [[ -z "${CODEFEST_SERVICE_URL:-}" ]]; then
  printf '%s\n' '請明確設定 CODEFEST_SERVICE_URL；建置腳本不使用隱含網址。' >&2
  exit 2
fi

python3 - "$CODEFEST_SERVICE_URL" "$mode" "$allow_emulator_http" <<'PY'
import sys
from urllib.parse import urlsplit

value, mode, allow_http = sys.argv[1:]
try:
    if any(character.isspace() or ord(character) < 32 for character in value):
        raise ValueError("URL 不可含空白或控制字元")
    if "\\" in value or "," in value:
        raise ValueError("URL 不可含反斜線或逗號；需要時請使用百分比編碼")
    url = urlsplit(value)
    if not url.hostname or url.username is not None or url.password is not None:
        raise ValueError("URL 需要主機名稱，且不可含帳號或密碼")
    if url.port == 0:
        raise ValueError("URL port 必須介於 1 至 65535")
    if allow_http == "true" and mode != "debug":
        raise ValueError("--allow-emulator-http 必須搭配 --debug")
    emulator_http = (
        mode == "debug"
        and allow_http == "true"
        and url.scheme == "http"
        and url.hostname == "10.0.2.2"
    )
    if url.scheme != "https" and not emulator_http:
        raise ValueError("需要 HTTPS；HTTP 僅允許明確開啟的 debug Android 模擬器入口")
except ValueError as error:
    print(f"CODEFEST_SERVICE_URL 無效：{error}", file=sys.stderr)
    sys.exit(2)
PY

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
flutter_bin="${FLUTTER_BIN:-flutter}"
dart_bin="${DART_BIN:-dart}"

run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  if [[ "$dry_run" == false ]]; then
    "$@"
  fi
}

run "$flutter_bin" pub get --enforce-lockfile
run "$dart_bin" run build_runner build
run "$flutter_bin" analyze --no-pub lib/config/codefest.dart test/codefest_service_test.dart
run "$flutter_bin" test --no-pub \
  "--dart-define=CODEFEST_SERVICE_URL=$CODEFEST_SERVICE_URL" \
  "--dart-define=EXPECTED_CODEFEST_SERVICE_URL=$CODEFEST_SERVICE_URL" \
  test/codefest_service_test.dart

build_arguments=(build apk "--$mode" --no-pub "--dart-define=CODEFEST_SERVICE_URL=$CODEFEST_SERVICE_URL")
if [[ "$check_only" == true ]]; then
  build_arguments+=(--config-only)
fi
run "$flutter_bin" "${build_arguments[@]}"

if [[ "$dry_run" == false && "$check_only" == false ]]; then
  printf 'APK：%s/build/app/outputs/flutter-apk/app-%s.apk\n' "$repo_root" "$mode"
fi
