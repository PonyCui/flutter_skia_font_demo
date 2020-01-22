// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of dart.ui;

/// Initializes the platform.
Future<void> webOnlyInitializePlatform({
  engine.AssetManager assetManager,
}) async {
  if (!debugEmulateFlutterTesterEnvironment) {
    engine.window.locationStrategy = const engine.HashLocationStrategy();
  }

  engine.webOnlyInitializeEngine();

  // This needs to be after `webOnlyInitializeEngine` because that is where the
  // canvaskit script is added to the page.
  if (engine.experimentalUseSkia) {
    await engine.initializeSkia();
  }

  assetManager ??= const engine.AssetManager();
  await webOnlySetAssetManager(assetManager);
  if (engine.experimentalUseSkia) {
    await _fontCollection.ensureFontsLoaded();
    await engine.skiaFontCollection.ensureFontsLoaded();
  } else {
    await _fontCollection.ensureFontsLoaded();
  }

  _webOnlyIsInitialized = true;
}

engine.AssetManager _assetManager;
engine.FontCollection _fontCollection;

bool _webOnlyIsInitialized = false;
bool get webOnlyIsInitialized => _webOnlyIsInitialized;

/// Specifies that the platform should use the given [AssetManager] to load
/// assets.
///
/// The given asset manager is used to initialize the font collection.
Future<void> webOnlySetAssetManager(engine.AssetManager assetManager) async {
  assert(assetManager != null, 'Cannot set assetManager to null');
  if (assetManager == _assetManager) {
    return;
  }

  _assetManager = assetManager;

  if (engine.experimentalUseSkia) {
    _fontCollection ??= engine.FontCollection();
    _fontCollection.clear();
    engine.skiaFontCollection ??= engine.SkiaFontCollection();
  } else {
    _fontCollection ??= engine.FontCollection();
    _fontCollection.clear();
  }


  if (_assetManager != null) {
    if (engine.experimentalUseSkia) {
      await _fontCollection.registerFonts(_assetManager);
      await engine.skiaFontCollection.registerFonts(_assetManager);
    } else {
      await _fontCollection.registerFonts(_assetManager);
    }
  }

  if (debugEmulateFlutterTesterEnvironment && !engine.experimentalUseSkia) {
    _fontCollection.debugRegisterTestFonts();
  }
}

/// Flag that shows whether the Flutter Testing Behavior is enabled.
///
/// This flag can be used to decide if the code is running from a Flutter Test
/// such as a Widget test.
///
/// For example in these tests we use a predictable-size font which makes widget
/// tests less flaky.
bool get debugEmulateFlutterTesterEnvironment =>
    _debugEmulateFlutterTesterEnvironment;

set debugEmulateFlutterTesterEnvironment(bool value) {
  _debugEmulateFlutterTesterEnvironment = value;
  if (_debugEmulateFlutterTesterEnvironment) {
    const Size logicalSize = Size(800.0, 600.0);
    engine.window.webOnlyDebugPhysicalSizeOverride =
        logicalSize * window.devicePixelRatio;
  }
}

bool _debugEmulateFlutterTesterEnvironment = false;

/// This class handles downloading assets over the network.
engine.AssetManager get webOnlyAssetManager => _assetManager;

/// A collection of fonts that may be used by the platform.
engine.FontCollection get webOnlyFontCollection => _fontCollection;
