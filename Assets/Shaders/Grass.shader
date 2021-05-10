Shader "Roystan/Grass"
{
    Properties
    {
		[Header(Shading)]
		_TopColor("Top Color", Color) = (0.2,0.8,0.5,1)
		_BottomColor("Bottom Color", Color) = (0.5,0.9,0.6,1)
		_TranslucentGain("Translucent Gain", Range(0,1)) = 0.5
	}

	HLSLINCLUDE
	#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

	CBUFFER_START(UnityPerMaterial)
	float4 _TopColorST;
	float4 _BottomColorST;
	float _TranslucentGainST;
	CBUFFER_END

	// Simple noise function, sourced from http://answers.unity.com/answers/624136/view.html
	// Extended discussion on this function can be found at the following link:
	// https://forum.unity.com/threads/am-i-over-complicating-this-random-function.454887/#post-2949326
	// Returns a number in the 0...1 range.
	float rand(float3 co)
	{
		return frac(sin(dot(co.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
	}

	// Construct a rotation matrix that rotates around the provided axis, sourced from:
	// https://gist.github.com/keijiro/ee439d5e7388f3aafc5296005c8c3f33
	float3x3 AngleAxis3x3(float angle, float3 axis)
	{
		float c, s;
		sincos(angle, s, c);

		float t = 1 - c;
		float x = axis.x;
		float y = axis.y;
		float z = axis.z;

		return float3x3(
			t * x * x + c, t * x * y - s * z, t * x * z + s * y,
			t * x * y + s * z, t * y * y + c, t * y * z - s * x,
			t * x * z - s * y, t * y * z + s * x, t * z * z + c
			);
	}

	float4 vert(float4 vertex : POSITION) : SV_POSITION
	{
		//return UnityObjectToClipPos(vertex);
		return vertex;
	}
/*
	struct GeometryOutput
	{
		float4 positionCS : SV_POSITION;
	};

	[maxvertexcount(3)]
	void geo(triangle float4 IN[3] : SV_POSITION, inout TriangleStream<GeometryOutput> triStream)
	{
		GeometryOutput o = (GeometryOutput) 0;

		o.positionCS = UnityObjectToClipPos(pos + float3(0.5, 0, 0));
		triStream.Append(o);
		o.positionCS = UnityObjectToClipPos(pos + float3(-0.5, 0, 0));
		triStream.Append(o);
		o.positionCS = UnityObjectToClipPos(pos + float3(0, 1, 0));
		triStream.Append(o);
	}*/

	ENDHLSL

    SubShader
    {
		Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }
		LOD 300

		Cull Off

        Pass
        {
			Name "ForwardLit"
			Tags
			{ "LightMode" = "UniversalForward" }

            HLSLPROGRAM
			// Required to compile gles 2.0 with standard srp library, (apparently)
			//#pragma prefer_hlslcc gles
			//#pragma exclude_renderers d3d11_9x gles
			#pragma target 4.5

            #pragma vertex vert
            #pragma fragment frag

			//#pragma require geometry
			//#pragma geometry geo
            
			//#include "Lighting.cginc"

			float4 _TopColor;
			float4 _BottomColor;
			float _TranslucentGain;

			float4 frag (float4 vertex : SV_POSITION, bool isFrontFace : SV_IsFrontFace) : SV_Target
            {	
				return float4(1, 1, 1, 1);
            }
            ENDHLSL
        }
    }
}