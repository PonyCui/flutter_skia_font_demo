// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of dart._engine;

Future<void> Function(String, ByteData, ui.PlatformMessageResponseCallback) pluginMessageCallHandler;

void webOnlySetPluginHandler(Future<void> Function(String, ByteData, ui.PlatformMessageResponseCallback) handler) {
  pluginMessageCallHandler = handler;
}
