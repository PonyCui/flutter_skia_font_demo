// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of dart._engine;

/// A virtual canvas that applies operations to multiple canvases at once.
class SkNWayCanvas {
  final List<SkCanvas> _canvases = <SkCanvas>[];

  void addCanvas(SkCanvas canvas) {
    _canvases.add(canvas);
  }

  /// Calls [save] on all canvases.
  int save() {
    int saveCount;
    for (int i = 0; i < _canvases.length; i++) {
      saveCount = _canvases[i].save();
    }
    return saveCount;
  }

  /// Calls [saveLayer] on all canvases.
  void saveLayer(ui.Rect bounds, ui.Paint paint) {
    for (int i = 0; i < _canvases.length; i++) {
      _canvases[i].saveLayer(bounds, paint);
    }
  }

  /// Calls [saveLayerWithFilter] on all canvases.
  void saveLayerWithFilter(ui.Rect bounds, ui.ImageFilter filter) {
    for (int i = 0; i < _canvases.length; i++) {
      _canvases[i].saveLayerWithFilter(bounds, filter);
    }
  }

  /// Calls [restore] on all canvases.
  void restore() {
    for (int i = 0; i < _canvases.length; i++) {
      _canvases[i].restore();
    }
  }

  /// Calls [restoreToCount] on all canvases.
  void restoreToCount(int count) {
    for (int i = 0; i < _canvases.length; i++) {
      _canvases[i].restoreToCount(count);
    }
  }

  /// Calls [translate] on all canvases.
  void translate(double dx, double dy) {
    for (int i = 0; i < _canvases.length; i++) {
      _canvases[i].translate(dx, dy);
    }
  }

  /// Calls [transform] on all canvases.
  void transform(Float64List matrix) {
    for (int i = 0; i < _canvases.length; i++) {
      _canvases[i].transform(matrix);
    }
  }

  /// Calls [clipPath] on all canvases.
  void clipPath(ui.Path path, bool doAntiAlias) {
    for (int i = 0; i < _canvases.length; i++) {
      _canvases[i].clipPath(path, doAntiAlias);
    }
  }

  /// Calls [clipRect] on all canvases.
  void clipRect(ui.Rect rect, ui.ClipOp clipOp, bool doAntiAlias) {
    for (int i = 0; i < _canvases.length; i++) {
      _canvases[i].clipRect(rect, clipOp, doAntiAlias);
    }
  }

  /// Calls [clipRRect] on all canvases.
  void clipRRect(ui.RRect rrect, bool doAntiAlias) {
    for (int i = 0; i < _canvases.length; i++) {
      _canvases[i].clipRRect(rrect, doAntiAlias);
    }
  }
}
