// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

part of dart._engine;

/// Allocates and caches 0 or more canvas(s) for [BitmapCanvas].
///
/// [BitmapCanvas] signals allocation of first canvas using allocateCanvas.
/// When a painting command such as drawImage or drawParagraph requires
/// multiple canvases for correct compositing, it calls allocateExtraCanvas and
/// adds the canvas(s) to a [_pool] of active canvas(s).
///
/// To make sure transformations and clips are preserved correctly when a new
/// canvas is allocated, [_CanvasPool] replays the current stack on the newly
/// allocated canvas. It also maintains a [_saveContextCount] so that
/// the context stack can be reinitialized to default when reused in the future.
///
/// On a subsequent repaint, when a Picture determines that a [BitmapCanvas]
/// can be reused, [_CanvasPool] will move canvas(s) from pool to reusablePool
/// to prevent reallocation.
class _CanvasPool extends _SaveStackTracking {
  html.CanvasRenderingContext2D _context;
  ContextStateHandle _contextHandle;
  final int _widthInBitmapPixels, _heightInBitmapPixels;
  // List of canvases that have been allocated and used in this paint cycle.
  List<html.CanvasElement> _pool;
  // List of canvases available to reuse from prior paint cycle.
  List<html.CanvasElement> _reusablePool;
  // Current canvas element or null if marked for lazy allocation.
  html.CanvasElement _canvas;
  html.HtmlElement _rootElement;
  int _saveContextCount = 0;

  _CanvasPool(this._widthInBitmapPixels, this._heightInBitmapPixels);

  html.CanvasRenderingContext2D get context {
    if (_canvas == null) {
      _createCanvas();
      assert(_context != null);
      assert(_canvas != null);
    }
    return _context;
  }

  ContextStateHandle get contextHandle {
    if (_canvas == null) {
      _createCanvas();
      assert(_context != null);
      assert(_canvas != null);
    }
    return _contextHandle;
  }

  // Allocating extra canvas items. Save current canvas so we can dispose
  // and replay the clip/transform stack on top of new canvas.
  void allocateExtraCanvas() {
    assert(_rootElement != null);
    // Place clean copy of current canvas with context stack restored and paint
    // reset into pool.
    if (_canvas != null) {
      _restoreContextSave();
      _contextHandle.reset();
      _pool ??= [];
      _pool.add(_canvas);
      _canvas = null;
      _context = null;
      _contextHandle = null;
    }
  }

  void allocateCanvas(html.HtmlElement rootElement) {
    _rootElement = rootElement;
  }

  void _createCanvas() {
    bool requiresClearRect = false;
    if (_reusablePool != null && _reusablePool.isNotEmpty) {
      _canvas = _reusablePool.removeAt(0);
      requiresClearRect = true;
    } else {
      // Compute the final CSS canvas size given the actual pixel count we
      // allocated. This is done for the following reasons:
      //
      // * To satisfy the invariant: pixel size = css size * device pixel ratio.
      // * To make sure that when we scale the canvas by devicePixelRatio (see
      //   _initializeViewport below) the pixels line up.
      final double cssWidth =
          _widthInBitmapPixels / EngineWindow.browserDevicePixelRatio;
      final double cssHeight =
          _heightInBitmapPixels / EngineWindow.browserDevicePixelRatio;
      _canvas = html.CanvasElement(
        width: _widthInBitmapPixels,
        height: _heightInBitmapPixels,
      );
      _canvas.style
        ..position = 'absolute'
        ..width = '${cssWidth}px'
        ..height = '${cssHeight}px';
    }
    _rootElement.append(_canvas);
    _context = _canvas.context2D;
    _contextHandle = ContextStateHandle(_context);
    _initializeViewport();
    if (requiresClearRect) {
      // Now that the context is reset, clear old contents.
      _context.clearRect(0, 0, _widthInBitmapPixels, _heightInBitmapPixels);
    }
    _replayClipStack();
  }

  @override
  void clear() {
    super.clear();

    if (_canvas != null) {
      // Restore to the state where we have only applied the scaling.
      html.CanvasRenderingContext2D ctx = _context;
      if (ctx != null) {
        try {
          ctx.font = '';
        } catch (e) {
          // Firefox may explode here:
          // https://bugzilla.mozilla.org/show_bug.cgi?id=941146
          if (!_isNsErrorFailureException(e)) {
            rethrow;
          }
        }
      }
    }
    reuse();
    resetTransform();
  }

  set initialTransform(ui.Offset transform) {
    translate(transform.dx, transform.dy);
  }

  int _replaySingleSaveEntry(
      int clipDepth, Matrix4 transform, List<_SaveClipEntry> clipStack) {
    final html.CanvasRenderingContext2D ctx = _context;
    if (!transform.isIdentity()) {
      final double ratio = EngineWindow.browserDevicePixelRatio;
      ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      ctx.transform(transform[0], transform[1], transform[4], transform[5],
          transform[12], transform[13]);
    }
    if (clipStack != null) {
      for (int clipCount = clipStack.length;
          clipDepth < clipCount;
          clipDepth++) {
        _SaveClipEntry clipEntry = clipStack[clipDepth];
        if (clipEntry.rect != null) {
          _clipRect(ctx, clipEntry.rect);
        } else if (clipEntry.rrect != null) {
          _clipRRect(ctx, clipEntry.rrect);
        } else if (clipEntry.path != null) {
          _runPath(ctx, clipEntry.path);
          ctx.clip();
        }
      }
    }
    return clipDepth;
  }

  void _replayClipStack() {
    // Replay save/clip stack on this canvas now.
    html.CanvasRenderingContext2D ctx = _context;
    int clipDepth = 0;
    for (int saveStackIndex = 0, len = _saveStack.length;
        saveStackIndex < len;
        saveStackIndex++) {
      _SaveStackEntry saveEntry = _saveStack[saveStackIndex];
      clipDepth = _replaySingleSaveEntry(
          clipDepth, saveEntry.transform, saveEntry.clipStack);
      ctx.save();
      ++_saveContextCount;
    }
    _replaySingleSaveEntry(clipDepth, _currentTransform, _clipStack);
  }

  // Marks this pool for reuse.
  void reuse() {
    if (_canvas != null) {
      _restoreContextSave();
      _contextHandle.reset();
      _pool ??= [];
      _pool.add(_canvas);
      _context = null;
      _contextHandle = null;
    }
    _reusablePool = _pool;
    _pool = null;
    _canvas = null;
    _context = null;
    _contextHandle = null;
  }

  void endOfPaint() {
    if (_reusablePool != null) {
      for (html.CanvasElement e in _reusablePool) {
        e.remove();
      }
      _reusablePool = null;
    }
    _restoreContextSave();
  }

  void _restoreContextSave() {
    while (_saveContextCount != 0) {
      _context.restore();
      --_saveContextCount;
    }
  }

  /// Configures the canvas such that its coordinate system follows the scene's
  /// coordinate system, and the pixel ratio is applied such that CSS pixels are
  /// translated to bitmap pixels.
  void _initializeViewport() {
    html.CanvasRenderingContext2D ctx = context;
    // Save the canvas state with top-level transforms so we can undo
    // any clips later when we reuse the canvas.
    ctx.save();
    ++_saveContextCount;

    // We always start with identity transform because the surrounding transform
    // is applied on the DOM elements.
    ctx.setTransform(1, 0, 0, 1, 0, 0);

    // This scale makes sure that 1 CSS pixel is translated to the correct
    // number of bitmap pixels.
    ctx.scale(EngineWindow.browserDevicePixelRatio, EngineWindow.browserDevicePixelRatio);
  }

  void resetTransform() {
    if (_canvas != null) {
      _canvas.style.transformOrigin = '';
      _canvas.style.transform = '';
    }
  }

  // Returns a data URI containing a representation of the image in this
  // canvas.
  String toDataUrl() => _canvas.toDataUrl();

  @override
  void save() {
    super.save();
    if (_canvas != null) {
      context.save();
      ++_saveContextCount;
    }
  }

  @override
  void restore() {
    super.restore();
    if (_canvas != null) {
      context.restore();
      contextHandle.reset();
      --_saveContextCount;
    }
  }

  @override
  void translate(double dx, double dy) {
    super.translate(dx, dy);
    if (_canvas != null) {
      context.translate(dx, dy);
    }
  }

  @override
  void scale(double sx, double sy) {
    super.scale(sx, sy);
    if (_canvas != null) {
      context.scale(sx, sy);
    }
  }

  @override
  void rotate(double radians) {
    super.rotate(radians);
    if (_canvas != null) {
      context.rotate(radians);
    }
  }

  @override
  void skew(double sx, double sy) {
    super.skew(sx, sy);
    if (_canvas != null) {
      context.transform(1, sy, sx, 1, 0, 0);
      //                |  |   |   |  |  |
      //                |  |   |   |  |  f - vertical translation
      //                |  |   |   |  e - horizontal translation
      //                |  |   |   d - vertical scaling
      //                |  |   c - horizontal skewing
      //                |  b - vertical skewing
      //                a - horizontal scaling
      //
      // Source: https://developer.mozilla.org/en-US/docs/Web/API/CanvasRenderingContext2D/transform
    }
  }

  @override
  void transform(Float64List matrix4) {
    super.transform(matrix4);
    // Canvas2D transform API:
    //
    // ctx.transform(a, b, c, d, e, f);
    //
    // In 3x3 matrix form assuming vector representation of (x, y, 1):
    //
    // a c e
    // b d f
    // 0 0 1
    //
    // This translates to 4x4 matrix with vector representation of (x, y, z, 1)
    // as:
    //
    // a c 0 e
    // b d 0 f
    // 0 0 1 0
    // 0 0 0 1
    //
    // This matrix is sufficient to represent 2D rotates, translates, scales,
    // and skews.
    if (_canvas != null) {
      context.transform(matrix4[0], matrix4[1], matrix4[4], matrix4[5],
          matrix4[12], matrix4[13]);
    }
  }

  void clipRect(ui.Rect rect) {
    super.clipRect(rect);
    if (_canvas != null) {
      _clipRect(context, rect);
    }
  }

  void _clipRect(html.CanvasRenderingContext2D ctx, ui.Rect rect) {
    ctx.beginPath();
    ctx.rect(rect.left, rect.top, rect.width, rect.height);
    ctx.clip();
  }

  void clipRRect(ui.RRect rrect) {
    super.clipRRect(rrect);
    if (_canvas != null) {
      _clipRRect(context, rrect);
    }
  }

  void _clipRRect(html.CanvasRenderingContext2D ctx, ui.RRect rrect) {
    final ui.Path path = ui.Path()..addRRect(rrect);
    _runPath(ctx, path);
    ctx.clip();
  }

  void clipPath(ui.Path path) {
    super.clipPath(path);
    if (_canvas != null) {
      html.CanvasRenderingContext2D ctx = context;
      _runPath(ctx, path);
      ctx.clip();
    }
  }

  void drawColor(ui.Color color, ui.BlendMode blendMode) {
    html.CanvasRenderingContext2D ctx = context;
    contextHandle.blendMode = blendMode;
    contextHandle.fillStyle = colorToCssString(color);
    contextHandle.strokeStyle = '';
    ctx.beginPath();
    // Fill a virtually infinite rect with the color.
    //
    // We can't use (0, 0, width, height) because the current transform can
    // cause it to not fill the entire clip.
    ctx.fillRect(-10000, -10000, 20000, 20000);
  }

  // Fill a virtually infinite rect with the color.
  void fill() {
    html.CanvasRenderingContext2D ctx = context;
    ctx.beginPath();
    // We can't use (0, 0, width, height) because the current transform can
    // cause it to not fill the entire clip.
    ctx.fillRect(-10000, -10000, 20000, 20000);
  }

  void strokeLine(ui.Offset p1, ui.Offset p2) {
    html.CanvasRenderingContext2D ctx = context;
    ctx.beginPath();
    ctx.moveTo(p1.dx, p1.dy);
    ctx.lineTo(p2.dx, p2.dy);
    ctx.stroke();
  }

  /// 'Runs' the given [path] by applying all of its commands to the canvas.
  void _runPath(html.CanvasRenderingContext2D ctx, SurfacePath path) {
    ctx.beginPath();
    for (Subpath subpath in path.subpaths) {
      for (PathCommand command in subpath.commands) {
        switch (command.type) {
          case PathCommandTypes.bezierCurveTo:
            final BezierCurveTo curve = command;
            ctx.bezierCurveTo(
                curve.x1, curve.y1, curve.x2, curve.y2, curve.x3, curve.y3);
            break;
          case PathCommandTypes.close:
            ctx.closePath();
            break;
          case PathCommandTypes.ellipse:
            final Ellipse ellipse = command;
            ctx.ellipse(
                ellipse.x,
                ellipse.y,
                ellipse.radiusX,
                ellipse.radiusY,
                ellipse.rotation,
                ellipse.startAngle,
                ellipse.endAngle,
                ellipse.anticlockwise);
            break;
          case PathCommandTypes.lineTo:
            final LineTo lineTo = command;
            ctx.lineTo(lineTo.x, lineTo.y);
            break;
          case PathCommandTypes.moveTo:
            final MoveTo moveTo = command;
            ctx.moveTo(moveTo.x, moveTo.y);
            break;
          case PathCommandTypes.rRect:
            final RRectCommand rrectCommand = command;
            _RRectToCanvasRenderer(ctx)
                .render(rrectCommand.rrect, startNewPath: false);
            break;
          case PathCommandTypes.rect:
            final RectCommand rectCommand = command;
            ctx.rect(rectCommand.x, rectCommand.y, rectCommand.width,
                rectCommand.height);
            break;
          case PathCommandTypes.quadraticCurveTo:
            final QuadraticCurveTo quadraticCurveTo = command;
            ctx.quadraticCurveTo(quadraticCurveTo.x1, quadraticCurveTo.y1,
                quadraticCurveTo.x2, quadraticCurveTo.y2);
            break;
          default:
            throw UnimplementedError('Unknown path command $command');
        }
      }
    }
  }

  void drawRect(ui.Rect rect, ui.PaintingStyle style) {
    context.beginPath();
    context.rect(rect.left, rect.top, rect.width, rect.height);
    contextHandle.paint(style);
  }

  void drawRRect(ui.RRect roundRect, ui.PaintingStyle style) {
    _RRectToCanvasRenderer(context).render(roundRect);
    contextHandle.paint(style);
  }

  void drawDRRect(ui.RRect outer, ui.RRect inner, ui.PaintingStyle style) {
    _RRectRenderer renderer = _RRectToCanvasRenderer(context);
    renderer.render(outer);
    renderer.render(inner, startNewPath: false, reverse: true);
    contextHandle.paint(style);
  }

  void drawOval(ui.Rect rect, ui.PaintingStyle style) {
    context.beginPath();
    context.ellipse(rect.center.dx, rect.center.dy, rect.width / 2,
        rect.height / 2, 0, 0, 2.0 * math.pi, false);
    contextHandle.paint(style);
  }

  void drawCircle(ui.Offset c, double radius, ui.PaintingStyle style) {
    context.beginPath();
    context.ellipse(c.dx, c.dy, radius, radius, 0, 0, 2.0 * math.pi, false);
    contextHandle.paint(style);
  }

  void drawPath(ui.Path path, ui.PaintingStyle style) {
    _runPath(context, path);
    contextHandle.paint(style);
  }

  void drawShadow(ui.Path path, ui.Color color, double elevation,
      bool transparentOccluder) {
    final List<CanvasShadow> shadows =
        ElevationShadow.computeCanvasShadows(elevation, color);
    if (shadows.isNotEmpty) {
      for (final CanvasShadow shadow in shadows) {
        // TODO(het): Shadows with transparent occluders are not supported
        // on webkit since filter is unsupported.
        if (transparentOccluder && browserEngine != BrowserEngine.webkit) {
          // We paint shadows using a path and a mask filter instead of the
          // built-in shadow* properties. This is because the color alpha of the
          // paint is added to the shadow. The effect we're looking for is to just
          // paint the shadow without the path itself, but if we use a non-zero
          // alpha for the paint the path is painted in addition to the shadow,
          // which is undesirable.
          context.save();
          context.translate(shadow.offsetX, shadow.offsetY);
          context.filter = _maskFilterToCss(
              ui.MaskFilter.blur(ui.BlurStyle.normal, shadow.blur));
          context.strokeStyle = '';
          context.fillStyle = colorToCssString(shadow.color);
          _runPath(context, path);
          context.fill();
          context.restore();
        } else {
          // TODO(het): We fill the path with this paint, then later we clip
          // by the same path and fill it with a fully opaque color (we know
          // the color is fully opaque because `transparentOccluder` is false.
          // However, due to anti-aliasing of the clip, a few pixels of the
          // path we are about to paint may still be visible after we fill with
          // the opaque occluder. For that reason, we fill with the shadow color,
          // and set the shadow color to fully opaque. This way, the visible
          // pixels are less opaque and less noticeable.
          context.save();
          context.filter = 'none';
          context.strokeStyle = '';
          context.fillStyle = colorToCssString(shadow.color);
          context.shadowBlur = shadow.blur;
          context.shadowColor = colorToCssString(shadow.color.withAlpha(0xff));
          context.shadowOffsetX = shadow.offsetX;
          context.shadowOffsetY = shadow.offsetY;
          _runPath(context, path);
          context.fill();
          context.restore();
        }
      }
    }
  }

  void dispose() {
    // Webkit has a threshold for the amount of canvas pixels an app can
    // allocate. Even though our canvases are being garbage-collected as
    // expected when we don't need them, Webkit keeps track of their sizes
    // towards the threshold. Setting width and height to zero tricks Webkit
    // into thinking that this canvas has a zero size so it doesn't count it
    // towards the threshold.
    if (browserEngine == BrowserEngine.webkit && _canvas != null) {
      _canvas.width = _canvas.height = 0;
    }
    _clearPool();
  }

  void _clearPool() {
    if (_pool != null) {
      for (html.CanvasElement c in _pool) {
        if (browserEngine == BrowserEngine.webkit) {
          c.width = c.height = 0;
        }
        c.remove();
      }
    }
    _pool = null;
  }
}

// Optimizes applying paint parameters to html canvas.
//
// See https://www.w3.org/TR/2dcontext/ for defaults used in this class
// to initialize current values.
//
class ContextStateHandle {
  html.CanvasRenderingContext2D context;
  ContextStateHandle(this.context);
  ui.BlendMode _currentBlendMode = ui.BlendMode.srcOver;
  ui.StrokeCap _currentStrokeCap = ui.StrokeCap.butt;
  ui.StrokeJoin _currentStrokeJoin = ui.StrokeJoin.miter;
  // Fill style and stroke style are Object since they can have a String or
  // shader object such as a gradient.
  Object _currentFillStyle;
  Object _currentStrokeStyle;
  double _currentLineWidth = 1.0;
  String _currentFilter = 'none';

  set blendMode(ui.BlendMode blendMode) {
    if (blendMode != _currentBlendMode) {
      _currentBlendMode = blendMode;
      context.globalCompositeOperation =
          _stringForBlendMode(blendMode) ?? 'source-over';
    }
  }

  set strokeCap(ui.StrokeCap strokeCap) {
    strokeCap ??= ui.StrokeCap.butt;
    if (strokeCap != _currentStrokeCap) {
      _currentStrokeCap = strokeCap;
      context.lineCap = _stringForStrokeCap(strokeCap);
    }
  }

  set lineWidth(double lineWidth) {
    if (lineWidth != _currentLineWidth) {
      _currentLineWidth = lineWidth;
      context.lineWidth = lineWidth;
    }
  }

  set strokeJoin(ui.StrokeJoin strokeJoin) {
    strokeJoin ??= ui.StrokeJoin.miter;
    if (strokeJoin != _currentStrokeJoin) {
      _currentStrokeJoin = strokeJoin;
      context.lineJoin = _stringForStrokeJoin(strokeJoin);
    }
  }

  set fillStyle(Object colorOrGradient) {
    if (!identical(colorOrGradient, _currentFillStyle)) {
      _currentFillStyle = colorOrGradient;
      context.fillStyle = colorOrGradient;
    }
  }

  set strokeStyle(Object colorOrGradient) {
    if (!identical(colorOrGradient, _currentStrokeStyle)) {
      _currentStrokeStyle = colorOrGradient;
      context.strokeStyle = colorOrGradient;
    }
  }

  set filter(String filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      context.filter = filter;
    }
  }

  void paint(ui.PaintingStyle style) {
    if (style == ui.PaintingStyle.stroke) {
      context.stroke();
    } else {
      context.fill();
    }
  }

  void reset() {
    context.fillStyle = '';
    // Read back fillStyle/strokeStyle values from context so that input such
    // as rgba(0, 0, 0, 0) is correctly compared and doesn't cause diff on
    // setter.
    _currentFillStyle = context.fillStyle;
    context.strokeStyle = '';
    _currentStrokeStyle = context.strokeStyle;
    context.filter = 'none';
    _currentFilter = 'none';
    context.globalCompositeOperation = 'source-over';
    _currentBlendMode = ui.BlendMode.srcOver;
    context.lineWidth = 1.0;
    _currentLineWidth = 1.0;
    context.lineCap = 'butt';
    _currentStrokeCap = ui.StrokeCap.butt;
    context.lineJoin = 'miter';
    _currentStrokeJoin = ui.StrokeJoin.miter;
  }
}

/// Provides save stack tracking functionality to implementations of
/// [EngineCanvas].
class _SaveStackTracking {
  // !Warning: this vector should not be mutated.
  static final Vector3 _unitZ = Vector3(0.0, 0.0, 1.0);

  final List<_SaveStackEntry> _saveStack = <_SaveStackEntry>[];

  /// The stack that maintains clipping operations used when text is painted
  /// onto bitmap canvas but is composited as separate element.
  List<_SaveClipEntry> _clipStack;

  /// Returns whether there are active clipping regions on the canvas.
  bool get isClipped => _clipStack != null;

  /// Empties the save stack and the element stack, and resets the transform
  /// and clip parameters.
  
  void clear() {
    _saveStack.clear();
    _clipStack = null;
    _currentTransform = Matrix4.identity();
  }

  /// The current transformation matrix.
  Matrix4 get currentTransform => _currentTransform;
  Matrix4 _currentTransform = Matrix4.identity();

  /// Saves current clip and transform on the save stack.
  
  void save() {
    _saveStack.add(_SaveStackEntry(
      transform: _currentTransform.clone(),
      clipStack:
          _clipStack == null ? null : List<_SaveClipEntry>.from(_clipStack),
    ));
  }

  /// Restores current clip and transform from the save stack.
  
  void restore() {
    if (_saveStack.isEmpty) {
      return;
    }
    final _SaveStackEntry entry = _saveStack.removeLast();
    _currentTransform = entry.transform;
    _clipStack = entry.clipStack;
  }

  /// Multiplies the [currentTransform] matrix by a translation.
  
  void translate(double dx, double dy) {
    _currentTransform.translate(dx, dy);
  }

  /// Scales the [currentTransform] matrix.
  
  void scale(double sx, double sy) {
    _currentTransform.scale(sx, sy);
  }

  /// Rotates the [currentTransform] matrix.
  
  void rotate(double radians) {
    _currentTransform.rotate(_unitZ, radians);
  }

  /// Skews the [currentTransform] matrix.
  
  void skew(double sx, double sy) {
    final Matrix4 skewMatrix = Matrix4.identity();
    final Float64List storage = skewMatrix.storage;
    storage[1] = sy;
    storage[4] = sx;
    _currentTransform.multiply(skewMatrix);
  }

  /// Multiplies the [currentTransform] matrix by another matrix.
  
  void transform(Float64List matrix4) {
    _currentTransform.multiply(Matrix4.fromFloat64List(matrix4));
  }

  /// Adds a rectangle to clipping stack.
  
  void clipRect(ui.Rect rect) {
    _clipStack ??= <_SaveClipEntry>[];
    _clipStack.add(_SaveClipEntry.rect(rect, _currentTransform.clone()));
  }

  /// Adds a round rectangle to clipping stack.
  
  void clipRRect(ui.RRect rrect) {
    _clipStack ??= <_SaveClipEntry>[];
    _clipStack.add(_SaveClipEntry.rrect(rrect, _currentTransform.clone()));
  }

  /// Adds a path to clipping stack.
  
  void clipPath(ui.Path path) {
    _clipStack ??= <_SaveClipEntry>[];
    _clipStack.add(_SaveClipEntry.path(path, _currentTransform.clone()));
  }
}
