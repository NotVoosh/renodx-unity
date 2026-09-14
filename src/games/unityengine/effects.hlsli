#include "./shared.h"

float3 applyFilmGrain(float3 outputColor, float2 screen, float intensity = -1) {
  if (intensity == -1) {
    intensity = injectedData.fxFilmGrain;
  } else {}
  float3 grainedColor = renodx::effects::ApplyFilmGrain(
        outputColor,
        screen,
        injectedData.random,
        intensity * 0.03f,
        1.f);
  return grainedColor;
}

// 0 = srgb, 1 = linear
float3 applyDither(float3 linear_input, float3 dither, int encoding = 0){
  if(injectedData.fxNoise == 0.f){return linear_input;} else {
  float3 encoded_color;
  float3 dithered_color;
  float3 output_color;
  float3 scaled_dither = dither * injectedData.fxNoise;
  float compression_scale = 1.f;
  [branch]
  if(injectedData.toneMapType == 0.f){
    encoded_color = encoding == 0 ? renodx::color::srgb::EncodeSafe(linear_input) : linear_input;
    dithered_color = encoded_color + scaled_dither;
    output_color = encoding == 0 ? renodx::color::srgb::DecodeSafe(dithered_color) : dithered_color;
  } else {
    float3 bt2020_color = renodx::color::bt2020::from::BT709(linear_input);
    encoded_color = renodx::color::pq::EncodeSafe(bt2020_color, injectedData.toneMapGameNits);
    dithered_color = encoded_color + scaled_dither;
    bt2020_color = renodx::color::pq::DecodeSafe(dithered_color, injectedData.toneMapGameNits);
    output_color = renodx::color::bt709::from::BT2020(bt2020_color);
  }
  return output_color;
  }
}