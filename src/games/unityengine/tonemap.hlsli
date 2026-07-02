#include "./shared.h"
#include "./aces.hlsli"
#include "./custom.hlsli"
#include "./neutral.hlsli"
#include "./uc2.hlsli"

static const float MID_GRAY_LINEAR = 1 / (pow(10, 0.75));                          // ~0.18f
static const float MID_GRAY_PERCENT = 0.5f;                                        // 50%
static const float MID_GRAY_GAMMA = log(MID_GRAY_LINEAR) / log(MID_GRAY_PERCENT);  // ~2.49f

void GamutCompression(inout float3 color, inout float compression_scale, bool srgb = false) {
  if (injectedData.toneMapType == 0.f) { return;
  } else {
    float encode_gamma = MID_GRAY_GAMMA;
    if (srgb) {
      color = renodx::color::srgb::DecodeSafe(color);  
    }
  float3 current_adaptive_state_lms = renodx::color::lms::from::BT709(0.18f);
  compression_scale = renodx::color::gamut::ComputeGamutCompressionScaleBT709AdaptiveD65(color, current_adaptive_state_lms);
  color = renodx::color::gamut::GamutCompressBT709AdaptiveD65(color, current_adaptive_state_lms, compression_scale);
  if (srgb) {
    color = renodx::color::srgb::EncodeSafe(color);
  }
  }
}

void GamutDecompression(inout float3 color, float compression_scale, bool srgb = false) {
  if (injectedData.toneMapType == 0.f) { return;
  } else {
    float encode_gamma = MID_GRAY_GAMMA;
    if (srgb) {
      color = renodx::color::srgb::DecodeSafe(color);
    }
  float3 current_adaptive_state_lms = renodx::color::lms::from::BT709(0.18f);
  color = renodx::color::gamut::GamutDecompressBT709AdaptiveD65(color, current_adaptive_state_lms, compression_scale);
  //color = renodx::color::bt709::clamp::AP1(color);
  if (srgb) {
    color = renodx::color::srgb::EncodeSafe(color);
  }
  }
}

void NeutwoMaxCh(inout float3 color, inout float max_channel_scale) {
  if (injectedData.toneMapType == 0.f) { return;
  } else {
    max_channel_scale = renodx::tonemap::neutwo::ComputeMaxChannelScale(color);
    color *= max_channel_scale;
  }
}

void NeutwoMaxChInverse(inout float3 color, float max_channel_scale) {
  if (injectedData.toneMapType == 0.f) { return;
  } else {
    color = renodx::math::DivideSafe(color, max_channel_scale, color);
  }
}

float3 rolloff(float3 color, float ratio = 0.97f, bool UI = false) {
  if (injectedData.toneMapType <= 1.f) { return color;}
  float y_max = injectedData.toneMapPeakNits;
  if(UI){
    if (injectedData.countOld > injectedData.countNew) {
      return color;
    }
    y_max /= injectedData.toneMapUINits;
  } else {
    y_max /= injectedData.toneMapGameNits;
  }
  float old_y = renodx::color::y::from::BT709(color);
  if (injectedData.toneMapGammaCorrection != 0.f) {
    y_max = renodx::color::correct::Gamma(y_max, true, injectedData.toneMapGammaCorrection == 1.f ? 2.2f : 2.4f);
  }
  float new_y = renodx::tonemap::ExponentialRollOff(old_y, y_max * ratio, y_max); 
float3 output = color * renodx::math::DivideSafe(new_y, old_y, 1.f);
return output;
}

float3 rolloffSdr(float3 color, float ratio = 0.85f) {
  if (injectedData.toneMapType == 0.f) { return saturate(color);}
  float old_y = renodx::color::y::from::BT709(color);
  float y_max = 1.f;
  float new_y = renodx::tonemap::ExponentialRollOff(old_y, y_max * ratio, y_max); 
return saturate(color * renodx::math::DivideSafe(new_y, old_y));
}

//-----TONEMAP-----//
float3 CorrectHueAndChrominanceOKLAB(float3 input_color, float3 target_color, float hue_restore, float blowout_restore){
  //float3 final_bt709 = input_color;
    if (hue_restore <= 0.f && blowout_restore <= 0.f) {
      return input_color;
    } else {
  float3 current_adaptive_state_lms = renodx::color::lms::from::BT709(0.18f);
  float compression_scale = renodx::color::gamut::ComputeGamutCompressionScaleBT709AdaptiveD65(target_color, current_adaptive_state_lms);
  target_color = max(0.f, target_color);
  compression_scale = renodx::color::gamut::ComputeGamutCompressionScaleBT709AdaptiveD65(input_color, current_adaptive_state_lms);
  input_color = renodx::color::gamut::GamutCompressBT709AdaptiveD65(input_color, current_adaptive_state_lms, compression_scale);
  float max_channel_scale = renodx::tonemap::neutwo::ComputeMaxChannelScale(input_color);
  input_color *= max_channel_scale;
  float clamp_chrominance_loss = 0.1f;
    /*//GamutCompress
      final_bt709 = renodx::color::correct::Hue(final_bt709, target_color, hue_restore);
    }
    if (blowout_restore > 0.f) {
      final_bt709 = renodx::color::correct::Chrominance(final_bt709, target_color, blowout_restore);
    }*/
    // Hue
  float3 incorrect_lab = renodx::color::oklab::from::BT709(input_color);
  float3 correct_lab = renodx::color::oklab::from::BT709(target_color);

  float2 incorrect_ab = incorrect_lab.yz;
  float2 correct_ab = correct_lab.yz;

  // Preserve original chrominance (magnitude of the a–b vector)
  float chrominance_pre_adjust = length(incorrect_ab);

  // Blend chrominance and hue by interpolating (a, b) components
  float2 blended_ab = lerp(incorrect_ab, correct_ab, hue_restore);

  // Rescale to original chrominance to avoid saturation shift
  float chrominance_post_adjust = length(blended_ab);
  blended_ab *= renodx::math::DivideSafe(chrominance_pre_adjust, chrominance_post_adjust, 1.f);

  incorrect_lab.yz = blended_ab;
    // Chrominance
  //float2 incorrect_ab = incorrect_lab.yz;
  //float2 reference_ab = reference_lab.yz;

  // Compute chrominance (magnitude of the a–b vector)
  float incorrect_chrominance = length(blended_ab);
  float correct_chrominance = length(correct_ab);

  // Scale original chrominance vector toward target chrominance
  float chrominance_ratio = renodx::math::DivideSafe(correct_chrominance, incorrect_chrominance, 1.f);
  float scale = lerp(1.f, chrominance_ratio, blowout_restore);

  float t = 1.0f - step(1.0f, scale);  // t = 1 when scale < 1, 0 when scale >= 1
  scale = lerp(scale, 1.0f, t * clamp_chrominance_loss);

  incorrect_lab.yz *= scale;

  float3 result = renodx::color::bt709::from::OkLab(incorrect_lab);
  
  result = renodx::math::DivideSafe(result, max_channel_scale, result);
  result = renodx::color::gamut::GamutDecompressBT709AdaptiveD65(result, current_adaptive_state_lms, compression_scale);
  return result;
}
}

float HDRBoost(float color, float power = 0.f, float3 normalization_point = 0.04f) {
  if (power == 0.f) return color;
  float3 LMS_WHITE = renodx::color::lms::from::BT709(float3(1, 1, 1));
  float3 lms_color = renodx::color::lms::from::BT709(color);
  lms_color /= LMS_WHITE;
  normalization_point /= LMS_WHITE;
  const float smoothing = power * 2.f;
  float boosted = max(lms_color, lerp(lms_color, normalization_point * pow(lms_color / normalization_point, 1.f + power), renodx::tonemap::Reinhard(lms_color, smoothing)));
  return boosted * LMS_WHITE;
}

float3 HDRBoost(float3 color, float power = 0.f, float3 normalization_point = 0.04f) {
  return float3(
      HDRBoost(color.r, power, normalization_point),
      HDRBoost(color.g, power, normalization_point),
      HDRBoost(color.b, power, normalization_point)
  );
}

// Narkowicz
float3 Bt709AcesTonemap(float3 color, float exposure = 1.f) {
  const float a = 2.51f;
  const float b = 0.03f;
  const float c = 2.43f;
  const float d = 0.59f;
  const float e = 0.14f;
  bool extended = injectedData.toneMapType != 0.f;
  float3 exposed_color = color * exposure;
  float3 sdr_color = (exposed_color * (a * exposed_color + b)) / (exposed_color * (c * exposed_color + d) + e);
  float3 output_color;
  [branch]
  if (!extended) {
    output_color = saturate(sdr_color);
  } else {
    float compression_scale;
    GamutCompression(exposed_color, compression_scale);
    float3 hdr_color = exposed_color > 0.230976 ?
    1.46658788438 * exposed_color + 0.00821561635884 :
     (exposed_color * (a * exposed_color + b)) / (exposed_color * (c * exposed_color + d) + e);
    GamutDecompression(hdr_color, compression_scale);
    output_color = CorrectHueAndChrominanceOKLAB(hdr_color, sdr_color, injectedData.toneMapHueShift, injectedData.toneMapSDRBlowout);
  }
  return output_color;
}

float3 Uncharted2Tonemap(float3 color, float A, float B, float C, float D, float E, float F, float W){
  bool extended = injectedData.toneMapType != 0.f;
  float3 sdr_color = uncharted2(color, A, B, C, D, E, F, W);
  float3 output_color;
  [branch]
  if (!extended) {
    output_color = saturate(sdr_color);
  } else {
    float compression_scale;
    GamutCompression(color, compression_scale);
    float3 hdr_color = uncharted2Extended(color, A, B, C, D, E, F, W);
    GamutDecompression(hdr_color, compression_scale);
    output_color = CorrectHueAndChrominanceOKLAB(hdr_color, sdr_color, injectedData.toneMapHueShift, injectedData.toneMapSDRBlowout);
}
return output_color;
}

float3 NeutralTonemap(float3 color,  float A = 0.2f, float B = 0.29f, float C = 0.24f, float D = 0.272f, float E = 0.02f, float F = 0.3f, float whiteLevel = 5.3f, float whiteClip = 1.f){
  bool extended = injectedData.toneMapType != 0.f;
  float3 sdr_color = Neutral(color, A, B, C, D, E, F, whiteLevel, whiteClip);
  float3 output_color;
  [branch]
  if (!extended) {
    output_color = saturate(sdr_color);
  } else {
    float compression_scale;
    GamutCompression(color, compression_scale);
    float3 hdr_color = NeutralExtended(color, A, B, C, D, E, F, whiteLevel, whiteClip);
    GamutDecompression(hdr_color, compression_scale);
    output_color = CorrectHueAndChrominanceOKLAB(hdr_color, sdr_color, injectedData.toneMapHueShift, injectedData.toneMapSDRBlowout);
}
return output_color;
}

float3 CustomTonemap(float3 color, float3 curve, float4 toeSegmentA, float2 toeSegmentB, float4 midSegmentA, float2 midSegmentB, float4 shoSegmentA, float2 shoSegmentB){
  bool extended = injectedData.toneMapType != 0.f;
  float3 sdr_color = Custom(color, curve, toeSegmentA, toeSegmentB, midSegmentA, midSegmentB, shoSegmentA, shoSegmentB);
  float3 output_color;
  [branch]
  if (!extended) {
    output_color = saturate(sdr_color);
  } else {
    float compression_scale;
    GamutCompression(color, compression_scale);
    float3 hdr_color = CustomExtended(color, curve, toeSegmentA, toeSegmentB, midSegmentA, midSegmentB, shoSegmentA, shoSegmentB);
    GamutDecompression(hdr_color, compression_scale);
    output_color = CorrectHueAndChrominanceOKLAB(hdr_color, sdr_color, injectedData.toneMapHueShift, injectedData.toneMapSDRBlowout);
}
return output_color;
}

float3 Ap1AcesTonemap(float3 ap0_untonemapped, float3 bt709_vanilla){
  bool extended = injectedData.toneMapType != 0.f;
  float3 outputColor;
    if (extended) {
    static const float ACES_MIN = 0.0001f;
    float aces_min = ACES_MIN / 203.f;
    float aces_max = (10000.f / 203.f);
    float3 hdr_color = RRT(ap0_untonemapped);
    hdr_color = renodx::tonemap::aces::ODT(hdr_color, aces_min * 48.f, aces_max * 48.f);
    hdr_color /= 48.f;
    outputColor = hdr_color;
    } else {
  outputColor = saturate(bt709_vanilla);
    }
  return outputColor;
}

// 0 = UnityCES * 100, 1 = UnityCES, 2 = Stephen Hill, 3 = Narkowicz
float3 Ap1AcesTonemap(float3 color, int curve = 0, float DSG = 0.9811f) {
  bool extended = injectedData.toneMapType != 0.f;
  float3 sdr_color = Ap1Aces(color, curve, DSG);
  float3 output_color;
  [branch]
  if (!extended) {
    output_color = saturate(sdr_color);
  } else {
    float3 hdr_color = Ap1AcesExtended(color, curve, DSG);
    output_color = CorrectHueAndChrominanceOKLAB(hdr_color, sdr_color, injectedData.toneMapHueShift, injectedData.toneMapSDRBlowout);
  }
  return output_color;
}