# Demo for resolved issue

This demo explains how we resolve the issue [https://github.com/flutter/flutter/issues/47041](https://github.com/flutter/flutter/issues/47041).

This issue was reported by `videah`, and fixed at master, but another issue still exists.

## Font loading issue

Flutter Web has a backend using Skia and webGL, compiled Skia as a wasm module, so we can use Skia as a service render content to a canvas with webGL context.

We didn't compile with font, font should define and load by developer. While building a pure English language app, it's okay. But, how about a Chinese app or app with multiple languages? That's the problem, the Chinese or Japanese font assets is too large to load.

So, we need to find out a way to render text.

## Solution

There's two way to render text, use Html.Canvas drawText method, use Html.SVG and Html.Image and Html.Canvas drawImage method.

### Html.Canvas drawText

It's really easy to draw text with Canvas, and the Flutter Web has [implmented](https://github.com/flutter/engine/blob/5dc24e3a503610227dbd0e3f065f9ae69e712793/lib/web_ui/lib/src/engine/bitmap_canvas.dart#L472) it.

Also, the Flutter Web has [implmented](https://github.com/flutter/engine/blob/5dc24e3a503610227dbd0e3f065f9ae69e712793/lib/web_ui/lib/src/engine/text/paragraph.dart#L236) a text layout service using Html.

So, we just need to use Flutter Web `EngineParagraph` and `BitmapCanvas`, and send result to Skia, render it.

### Html.SVG and Html.Image and Html.Canvas drawImage

Why we need SVG? Because `Html.Canvas drawText` can only draw simple text.

Image with SVG source, is a hacking way to solve this problem. [Code](https://github.com/PonyCui/flutter/blob/fed253253c9daa87d9bd04b0b9da3a68ba83204e/lib/web_ui/lib/src/engine/compositor/canvas.dart#L186)

We put all text html to SVG data url, set source to ImageElement, and draw ImageElement to a offscreen CanvasElement.

And then, send result to Skia, render it.

## Implementation

The Flutter engine code has pushed to [https://github.com/PonyCui/flutter/tree/web_skia_fontLoadingPatch](https://github.com/PonyCui/flutter/tree/web_skia_fontLoadingPatch).

The Demo code is [here](https://github.com/PonyCui/flutter_skia_font_demo).

We also provide a pre-compile `flutter_web_sdk` and a pre-built `build/web` product in demo repo.

## How to build it?

After your setup Flutter engine building environment, and build with felt, execute the following command in demo directory.

`flutter build web --profile --dart-define=FLUTTER_WEB_USE_SKIA=true`
