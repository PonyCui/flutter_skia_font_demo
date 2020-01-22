import 'dart:async';

import 'package:flutter/widgets.dart' as widgets;
import 'package:flutter/rendering.dart' as rendering;

runApp(widgets.Widget widget) {
  runZoned(() {
    widgets.runApp(widget);
  }, zoneValues: {"SkParagraphPatch.updater": TextUpdater.instance._updater});
}

class TextUpdater {
  static final instance = TextUpdater();

  _updater(String text) {
    _markNeedsPaint(widgets.WidgetsBinding.instance.renderView, text);
  }

  _markNeedsPaint(rendering.RenderObject renderObject, String text) {
    __markNeedsPaint(rendering.RenderObject _renderObject) {
      if (_renderObject is rendering.RenderParagraph && _renderObject.text?.toPlainText() == text) {
        _renderObject.markNeedsPaint();
      }
      _renderObject.visitChildren(__markNeedsPaint);
    }

    __markNeedsPaint(renderObject);
  }
}
