part of dart._engine;

class SkParagraphPatchBuilder extends EngineParagraphBuilder {

  static Function(String) _widgetUpdater;

  SkParagraphPatchBuilder(EngineParagraphStyle style) : super(style);

  @override
  EngineParagraph build() {
    if (_widgetUpdater == null && Zone.current["SkParagraphPatch.updater"] != null) {
      _widgetUpdater = Zone.current["SkParagraphPatch.updater"];
    }
    final fromParagraph = _tryBuildPlainText() ?? _buildRichText();
    return SkParagraphPatch(fromParagraph);
  }
}

class SkParagraphPatch extends EngineParagraph {
  SkParagraphPatch(EngineParagraph fromParagraph)
      : super(
          paragraphElement: fromParagraph._paragraphElement,
          geometricStyle: fromParagraph._geometricStyle,
          plainText: fromParagraph._plainText,
          paint: _convertSkPaintToSurfacePaint(fromParagraph._paint),
          textAlign: fromParagraph._textAlign,
          textDirection: fromParagraph._textDirection,
          background: _convertSkPaintToSurfacePaint(fromParagraph._background),
        );

  ui.Image pixelCache;
}

class SkParagraphPatchStyle extends EngineParagraphStyle {
  SkParagraphPatchStyle({
    ui.TextAlign textAlign,
    ui.TextDirection textDirection,
    int maxLines,
    String fontFamily,
    double fontSize,
    double height,
    ui.FontWeight fontWeight,
    ui.FontStyle fontStyle,
    ui.StrutStyle strutStyle,
    String ellipsis,
    ui.Locale locale,
  }) : super(
          textAlign: textAlign,
          textDirection: textDirection,
          maxLines: maxLines,
          fontFamily: fontFamily,
          fontSize: fontSize,
          height: height,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          strutStyle: strutStyle,
          ellipsis: ellipsis,
          locale: locale,
        );
}

class SkTextPatchStyle extends EngineTextStyle {
  SkTextPatchStyle({
    ui.Color color,
    ui.TextDecoration decoration,
    ui.Color decorationColor,
    ui.TextDecorationStyle decorationStyle,
    double decorationThickness,
    ui.FontWeight fontWeight,
    ui.FontStyle fontStyle,
    ui.TextBaseline textBaseline,
    String fontFamily,
    List<String> fontFamilyFallback,
    double fontSize,
    double letterSpacing,
    double wordSpacing,
    double height,
    ui.Locale locale,
    ui.Paint background,
    ui.Paint foreground,
    List<ui.Shadow> shadows,
    List<ui.FontFeature> fontFeatures,
  }) : super(
          color: color,
          decoration: decoration,
          decorationColor: decorationColor,
          decorationStyle: decorationStyle,
          decorationThickness: decorationThickness,
          fontWeight: fontWeight,
          fontStyle: fontStyle,
          textBaseline: textBaseline,
          fontFamily: fontFamily,
          fontFamilyFallback: fontFamilyFallback,
          fontSize: fontSize,
          letterSpacing: letterSpacing,
          wordSpacing: wordSpacing,
          height: height,
          locale: locale,
          background: _convertSkPaintToSurfacePaint(background),
          foreground: _convertSkPaintToSurfacePaint(foreground),
          shadows: shadows,
          fontFeatures: fontFeatures,
        );
}

SurfacePaint _convertSkPaintToSurfacePaint(dynamic value) {
  if (value == null) {
    return null;
  } else if (value is SurfacePaint) {
    return null;
  } else if (value is SkPaint) {
    return SurfacePaint()
      ..blendMode = value.blendMode
      ..filterQuality = value.filterQuality
      ..maskFilter = value.maskFilter
      ..shader = value.shader
      ..isAntiAlias = value.isAntiAlias
      ..color = value.color
      ..colorFilter = value.colorFilter
      ..strokeWidth = value.strokeWidth
      ..style = value.style
      ..strokeJoin = value.strokeJoin
      ..strokeCap = value.strokeCap;
  } else {
    return null;
  }
}
