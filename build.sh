rm -rf /Users/saiakirahui/flutter/bin/cache/flutter_web_sdk
cp -a /Volumes/PonySSD/engine/src/out/host_debug_unopt/flutter_web_sdk /Users/saiakirahui/flutter/bin/cache/flutter_web_sdk
rm -rf .dart_tool
flutter build web --profile --dart-define=FLUTTER_WEB_USE_SKIA=true
