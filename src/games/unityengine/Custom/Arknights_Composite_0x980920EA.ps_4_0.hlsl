#include "../common.hlsl"

Texture2D<float4> t1 : register(t1);

Texture2D<float4> t0 : register(t0);

SamplerState s1_s : register(s1);

SamplerState s0_s : register(s0);

cbuffer cb0 : register(b0){
  float4 cb0[5];
}

void main(
  float4 v0 : SV_POSITION0,
  float2 v1 : TEXCOORD0,
  out float4 o0 : SV_TARGET0)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = t0.Sample(s1_s, v1.xy).xyzw;
  r1.xyzw = t1.Sample(s0_s, v1.xy).xyzw;
  r0.xyz = cb0[4].xyz * r0.xyz;
  // Original composited with an LDR screen blend (1-(1-a)*(1-b)) that breaks above 1.0; add bloom instead.
  float3 scene = r1.xyz + r0.xyz;
  // Scene-final pass before UI: user color grading, then film grain, then the
  // game-brightness (nits) scale the final blit expects.
  scene = grading(scene);
  if (injectedData.fxFilmGrainType != 0.f) {
    scene = applyFilmGrain(scene, v1);
  }
  if (injectedData.countOld == injectedData.countNew) {
    scene = PostToneMapScale(scene, injectedData.gammaSpace != 0.f);
  }
  o0.xyz = scene;
  o0.w = r1.w + r0.w - r1.w * r0.w;
  return;
}
