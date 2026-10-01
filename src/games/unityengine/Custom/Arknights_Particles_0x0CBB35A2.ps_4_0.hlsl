#include "../common.hlsl"

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

void main(
  float4 v0 : SV_Position0,
  float2 v1 : TEXCOORD0,
  float4 v2 : COLOR0,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r1.xyzw = t0.Sample(s0_s, v1.xy).xyzw;
  r0.xyzw = v2.xyzw + v2.xyzw;
  r0.xyzw = r0.xyzw * r1.xyzw;
  // Hue correction pulls the boosted particle color back toward the texture's
  // native hue; no-op at the default slider value of 0.
  r0.xyz = renodx::color::correct::Hue(r0.xyz, r1.xyz, injectedData.toneMapHueCorrection);
  o0.w = saturate(r0.w);
  o0.xyz = r0.xyz;
  return;
}
