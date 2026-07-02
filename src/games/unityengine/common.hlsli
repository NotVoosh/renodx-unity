#include "./shared.h"
#include "./lut.hlsli"
#include "./tonemap.hlsli"
#include "./effects.hlsli"

float3 GradeAndDisplayMap(float3 color) {
  float3 outputColor;
  renodx::tonemap::Config config = renodx::tonemap::config::Create();
  config.type = injectedData.toneMapType = 2.f ? 3.f : injectedData.toneMapType;
  config.peak_nits = injectedData.toneMapPeakNits;
  config.game_nits = injectedData.toneMapGameNits;
  config.gamma_correction = injectedData.toneMapGammaCorrection;
  config.exposure = injectedData.colorGradeExposure;
  config.highlights = injectedData.colorGradeHighlights;
  config.shadows = injectedData.colorGradeShadows;
  config.contrast = injectedData.colorGradeContrast;
  config.saturation = injectedData.colorGradeSaturation;
  config.reno_drt_dechroma = injectedData.colorGradeDechroma;
  config.reno_drt_flare = 0.10f * pow(injectedData.colorGradeFlare, 5.f);
  /*config.hue_correction_type = renodx::tonemap::config::hue_correction_type::CUSTOM;
  config.hue_correction_type = injectedData.toneMapPerChannel != 0.f
                                   ? renodx::tonemap::config::hue_correction_type::INPUT
                                   : renodx::tonemap::config::hue_correction_type::CUSTOM;*/
  config.hue_correction_strength = 0.f;
  //config.hue_correction_color = lerp(untonemapped, renodx::tonemap::renodrt::NeutralSDR(untonemapped, true), injectedData.toneMapHueShift);
  config.reno_drt_tone_map_method = renodx::tonemap::renodrt::config::tone_map_method::NEUTWO;
  config.reno_drt_clamp_color_space = -1;
  config.reno_drt_clamp_peak = -1.f;
  //config.reno_drt_hue_correction_method = injectedData.toneMapHueProcessor;
  config.reno_drt_blowout = 1.f - injectedData.colorGradeBlowout;
  //config.reno_drt_per_channel = injectedData.toneMapPerChannel != 0.f;
  config.reno_drt_working_color_space = 1;
  config.reno_drt_white_clip = injectedData.colorGradeClip;
  config.reno_drt_scaling_method = injectedData.toneMapScalingMethod;
  if (injectedData.toneMapType == 0.f) {
    outputColor = max(0.f, color);
  } else {
    if(injectedData.isTonemapped == 0.f){
    color = CorrectHueAndChrominanceOKLAB(color, renodx::tonemap::renodrt::NeutralSDR(color, true), injectedData.toneMapHueShift, injectedData.toneMapSDRBlowout);
    }
    outputColor = HDRBoost(color, injectedData.fxHdrBoost);
  }
  outputColor = renodx::tonemap::config::Apply(outputColor, config);
return outputColor;
}

//-----SCALING-----//
float3 PostToneMapScale(float3 color, bool gamma = false) {
  if (gamma) {
    [branch]
    if (injectedData.toneMapGammaCorrection == 2.f) {
      color = renodx::color::srgb::EncodeSafe(color);
      color = renodx::color::gamma::DecodeSafe(color, 2.4f);
      color *= injectedData.toneMapGameNits / injectedData.toneMapUINits;
      color = renodx::color::gamma::EncodeSafe(color, 2.4f);
    } else if (injectedData.toneMapGammaCorrection == 1.f) {
      color = renodx::color::srgb::EncodeSafe(color);
      color = renodx::color::gamma::DecodeSafe(color, 2.2f);
      color *= injectedData.toneMapGameNits / injectedData.toneMapUINits;
      color = renodx::color::gamma::EncodeSafe(color, 2.2f);
    } else {
      color *= injectedData.toneMapGameNits / injectedData.toneMapUINits;
      color = renodx::color::srgb::EncodeSafe(color);
    }
  } else {
    [branch]
    if (injectedData.toneMapGammaCorrection == 2.f) {
      color = renodx::color::correct::GammaSafe(color, false, 2.4f);
      color *= injectedData.toneMapGameNits / injectedData.toneMapUINits;
      color = renodx::color::correct::GammaSafe(color, true, 2.4f);
    } else if (injectedData.toneMapGammaCorrection == 1.f) {
      color = renodx::color::correct::GammaSafe(color, false, 2.2f);
      color *= injectedData.toneMapGameNits / injectedData.toneMapUINits;
      color = renodx::color::correct::GammaSafe(color, true, 2.2f);
    } else {
      color *= injectedData.toneMapGameNits / injectedData.toneMapUINits;
    }
  }
  return color;
}

float3 InvertToneMapScale(float3 color, bool gamma = false) {
  if(gamma){
    if (injectedData.toneMapGammaCorrection == 2.f) {
      color = renodx::color::gamma::DecodeSafe(color, 2.4f);
      color *= injectedData.toneMapUINits / injectedData.toneMapGameNits;
      color = renodx::color::gamma::EncodeSafe(color, 2.4f);
      color = renodx::color::srgb::DecodeSafe(color);
    } else if (injectedData.toneMapGammaCorrection == 1.f) {
      color = renodx::color::gamma::DecodeSafe(color, 2.2f);
      color *= injectedData.toneMapUINits / injectedData.toneMapGameNits;
      color = renodx::color::gamma::EncodeSafe(color, 2.2f);
      color = renodx::color::srgb::DecodeSafe(color);
    } else {
      color = renodx::color::srgb::DecodeSafe(color);
      color *= injectedData.toneMapUINits / injectedData.toneMapGameNits;
    }
  } else {
    [branch]
    if (injectedData.toneMapGammaCorrection == 2.f) {
      color = renodx::color::correct::GammaSafe(color, false, 2.4f);
      color *= injectedData.toneMapUINits / injectedData.toneMapGameNits;
      color = renodx::color::correct::GammaSafe(color, true, 2.4f);
    } else if (injectedData.toneMapGammaCorrection == 1.f) {
      color = renodx::color::correct::GammaSafe(color, false, 2.2f);
      color *= injectedData.toneMapUINits / injectedData.toneMapGameNits;
      color = renodx::color::correct::GammaSafe(color, true, 2.2f);
    } else {
      color *= injectedData.toneMapUINits / injectedData.toneMapGameNits;
    }
  }
  return color;
}