# 쌓임쌓임 로고 v1 생성 기록

내장 image_gen 도구로 제작했습니다. 최종 파일은 `window-weather-logo-v1.png`입니다. 흰 배경 PNG 원본을 보존하며, 0.7.1에서는 크기만 변환한 `Resources/AppIcon.icns`를 앱 아이콘으로 사용했습니다. 현재 아이콘은 v2 원본을 사용합니다.

## 기본 디자인 프롬프트

```text
Use case: logo-brand.
Asset type: final standalone logo and macOS app icon artwork for the Korean open-source desktop app "쌓임쌓임" (Window Weather).
Primary request: create one beautiful, memorable, professionally finished app logo. The app makes snow, rain, leaves and petals fall and accumulate on the top edges of desktop windows. Distill that idea into a very simple icon of two slightly overlapping rounded desktop windows, with a soft, sculptural cap of white snow accumulating along the curved top edge of the foreground window. Three small white falling snow dots above the window suggest gentle motion.
Composition: a single centered macOS-style rounded-square app icon tile, straight-on, square canvas 1024 by 1024; the tile occupies about 88% of the canvas with a consistent transparent margin. The window silhouettes are broad, compact, and legible at tiny Dock sizes. Foreground window faces straight forward; rear window is slightly offset upward. The snow cap must conform exactly to the rounded top corners of the foreground window and feel naturally resting on it. Use generous negative space, a small number of bold shapes, carefully balanced optical proportions.
Style: refined contemporary macOS icon design, soft dimensional vector-like shapes, crisp silhouette, restrained depth, gentle highlights, clean matte surfaces, no busy glass textures. Delightful and calm, not childish. The existing app's icy blue and cyan color family should inform the palette: rich blue to turquoise tile, lighter blue rear window, deep blue front window, snow white. Strong contrast and clean readable window geometry. A subtle internal shadow separates the layers.
Text: no letters, no words, no initials, no numbers.
Constraints: a single complete final icon, no presentation board, no multiple alternatives, no device mockup, no app screenshot, no surrounding scenery, no watermark. No cloud or snowflake symbol. No red-yellow-green traffic-light dots. Real transparent background outside the rounded-square tile; no checkerboard drawn into the image. No external drop shadow extending into the transparent margin.
```

## 외곽 정리 시도

투명 출력의 가장자리 잔여 픽셀이 남아 이 출력은 최종 파일로 선택하지 않았습니다.

```text
Use case: precise-object-edit / logo-brand.
Edit the supplied icon. Preserve the entire interior artwork, exact two overlapping window shapes, snow cap, three falling dots, blue/cyan colors, proportions and positions.
Make exactly one correction: professionally clean the OUTER SILHOUETTE and transparent background. Remove every stray blue or cyan speck, streak, fuzzy patch, residue or glow outside the rounded-square tile, especially above its top edge and below its bottom edge. The tile perimeter must be a perfectly smooth, symmetric, precisely defined rounded rectangle with crisp antialiasing. Beyond that perimeter every pixel should be fully transparent, including the clean equal-width margin on all four sides. No exterior shadow or glow at all. Do not change the internal design. Output one finished square PNG with genuine alpha transparency, no checkerboard, no text, no mockup.
```

## 최종 흰 배경 버전 프롬프트

```text
Use case: precise-object-edit / logo-brand.
Preserve this supplied logo's entire interior artwork: the blue-to-cyan rounded square, two overlapping rounded windows, curved white snow cap, and three white falling dots. Keep the colors, layout and proportions.
Change only the OUTSIDE of the rounded square to perfectly clean, pure opaque white (#FFFFFF). Remove all stray blue specks, streaks and fuzzy fragments beyond the rounded-square border. The perimeter should be smooth with professionally clean antialiasing and no external drop shadow. Keep a generous even white margin on every side. This is a final logo on a solid white background, NOT a transparent cutout. All pixels in the finished image must be fully opaque; do not remove the white background. No new text, no watermarks, no mockup. Square canvas.
```

