#include "../common.hlsl"

Texture2D<float4> t0 : register(t0);

SamplerState s0_s : register(s0);

cbuffer cb0 : register(b0){
  float4 cb0[6];
}

void main(
  float4 v0 : SV_POSITION0,
  float4 v1 : TEXCOORD0,
  float4 v2 : TEXCOORD1,
  out float4 o0 : SV_Target0)
{
  float4 r0,r1;
  uint4 bitmask, uiDest;
  float4 fDest;

  r0.xyzw = t0.Sample(s0_s, v1.xy).xyzw;
  r1.xyzw = t0.Sample(s0_s, v1.zw).xyzw;
  r0.xyzw = r1.xyzw + r0.xyzw;
  r1.xyzw = t0.Sample(s0_s, v2.xy).xyzw;
  r0.xyzw = r1.xyzw + r0.xyzw;
  r1.xyzw = t0.Sample(s0_s, v2.zw).xyzw;
  r0.xyzw = r1.xyzw + r0.xyzw;
  r0.xyzw = r0.xyzw * float4(0.25,0.25,0.25,0.25) + -cb0[4].xyzw;
  r0.xyzw = max(float4(0,0,0,0), r0.xyzw);
  o0.xyzw = cb0[5].xxxx * injectedData.fxBloom * r0.xyzw;
  return;
}
