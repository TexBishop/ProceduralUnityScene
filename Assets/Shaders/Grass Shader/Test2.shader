Shader "Grass Custom"
{
    Properties
    {
        [Header(Light)]
        _Specular("Specular Color", Color) = (0.5, 1, 0.5, 1)
        _SpecularStrength("Smoothness", Range(0.1, 2)) = 1

        [Header(Color)]
        _TopColor("Top Color", Color) = (0.0005980707, 0.4716981, 0, 1)
        _BottomColor("Bottom Color", Color) = (0.000836957, 0.1132075, 0, 1)
        _DeadColor("Dead Color", Color) = (0.5843138, 0.4814073, 0.1294118, 1)
        _ColorNoiseScale("Color Noise Scale", Range(0, 1)) = 0.05
        _ColorNoiseStrength("Color Noise Strength", Float) = 1

        [Header(Blade Thickness)]
        _BladeWidth("Blade Width", Float) = 0.05
        _BladeWidthRandom("Blade Width Variance", Float) = 0.02

        [Header(Blade Length)]
        _BladeHeight("Blade Height", Float) = 0.5
        _BladeHeightNoise("Blade Height Noise", Range(0, 1)) = 0.05
        _BladeNoiseScale("Blade Noise Scale", Float) = 1
        _BladeHeightRandom("Blade Height Variance", Float) = 0.3

        [Header(Blade Bend)]
        _BladeForward("Blade Forward", Float) = 0.38
        _BladeCurve("Blade Curvature", Range(1, 4)) = 2
        _BendRotationRandom("Bend Rotation Random", Range(0, 1)) = 0.2

        [Header(Blade Density)]
        _TessellationUniform("Tessellation Uniform", Range(1, 10)) = 1
        _TessellationCulling("Tessellation Culling", Range(0.01, 0.2)) = 0.05

        [Header(Wind Movement)]
        _WindDistortionMap("Wind Map", 2D) = "white" {}
        _WindFrequency("Wind Frequency", Vector) = (0.05, 0.05, 0, 0)
        _WindStrength("Wind Strength", Range(0.01,2)) = 0.5
        _WindCulling("Wind Culling Distance", Range(1, 100)) = 50

        [Header(Second Plant)]
        _StemPlacementNoise("Stem Placement Noise", Range(0, 1)) = 0.05
        _StemPlacementEdge("Stem Placement Edge", Range(0.1, 1.5)) = 1

        [Header(Colors)]
        _TopColorStem("Top Color of Stem", Color) = (0.0005980707, 0.4716981, 0, 1)
        _BottomColorStem("Bottom Color of Stem", Color) = (0.000836957, 0.1132075, 0, 1)
        _DeadColorStem("Color of Dead Stem", Color) = (0.000836957, 0.1132075, 0, 1)

        [Header(Stem Thickness)]
        _StemWidth("Stem Width", Float) = 0.05
        _StemWidthRandom("Stem Width Variance", Float) = 0.02

        [Header(Stem Length)]
        _StemHeight("Stem Height", Float) = 0.5
        _StemHeightNoise("Stem Height Noise", Range(0, 1)) = 0.05
        _StemNoiseScale("Stem Noise Scale", Float) = 1
        _StemHeightRandom("Stem Height Variance", Float) = 0.3

        [Header(Stem Bend)]
        _StemForward("Stem Forward", Float) = 0.38
        _StemCurve("Stem Curvature", Range(1, 4)) = 2
        _StemRotationRandom("Stem Rotation Random", Range(0, 1)) = 0.2
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Opaque"
            "Queue"="Geometry+0"
        }

        Pass // UniversalForward
        {
            Name "Universal Forward"
            Tags 
            { 
                "LightMode" = "UniversalForward"
            }
       
            // Render State
            Blend One Zero, One Zero
            Cull Off
            ZTest LEqual
            ZWrite On
        

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma require geometry
            #pragma geometry geom

            #pragma require tessellation
            #pragma hull hull
            #pragma domain domain

            // Pragmas
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 4.5
            #pragma multi_compile_instancing

            // Keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS _ADDITIONAL_OFF
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
        
            // Defines
            #define SHADERPASS_FORWARD

            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
            #include "GeometryC.hlsl"
            #include "TessellationC.hlsl"
            #include "Vertex.hlsl"

            float4 frag(GeomData input, bool isFrontFace : SV_IsFrontFace) : SV_Target 
            {
                //===================================================================
                // Render both front and back
                //===================================================================
                input.normalWS = isFrontFace ? input.normalWS : -input.normalWS;

                //===================================================================
                // Calculate the shadow coordinates for receiving shadows
                //===================================================================
                #if SHADOWS_SCREEN
                    float4 clipPos = TransformWorldToHClip(input.positionWS);
                    float4 shadowCoord = ComputeScreenPos(clipPos);
                #else
                    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);
                #endif

                //===================================================================
                // Calculate lighting
                //===================================================================
                float3 ambient = SampleSH(input.normalWS);

                Light mainLight = GetMainLight(shadowCoord);
                float NdotL = saturate(saturate(dot(input.normalWS, mainLight.direction)) + 0.8);
                float up = saturate(dot(float3(0,1,0), mainLight.direction) + 0.5);

                float3 viewDir = normalize(_WorldSpaceCameraPos - input.positionWS);
                float3 specular = LightingSpecular(mainLight.color, mainLight.direction, input.normalWS, viewDir, _Specular, _SpecularStrength);

                float3 shading = NdotL * up * mainLight.shadowAttenuation * mainLight.color + ambient;

                //===================================================================
                // Calculate fragment color
                //===================================================================
                float noiseValue;
                Unity_GradientNoise_float(input.positionWS.xz, _ColorNoiseScale, noiseValue);
                float4 color = lerp(lerp(input.bottomColor, input.topColor, input.uv.y), input.deadColor, noiseValue * _ColorNoiseStrength) * float4(shading, 1);

                return color + float4(specular, 0);
            }

            ENDHLSL
        }

        Pass // ShadowCaster
        {
            Name "ShadowCaster"
            Tags 
            { 
                "LightMode" = "ShadowCaster"
            }
       
            // Render State
            Blend One Zero, One Zero
            Cull Off
            ZTest LEqual
            ZWrite On
            ColorMask 0        

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment emptyFrag

            #pragma require geometry
            #pragma geometry geom

            #pragma require tessellation
            #pragma hull hull
            #pragma domain domain

            // Pragmas
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 4.5
            #pragma multi_compile_instancing
        
            // Defines
            #define SHADERPASS_SHADOWCASTER

            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariablesFunctions.hlsl"
            #include "GeometryC.hlsl"
            #include "TessellationC.hlsl"
            #include "Vertex.hlsl"

            half4 emptyFrag(GeomData input) : SV_TARGET
            {
                return 0;
            }

            ENDHLSL
        }

        Pass // DepthOnly
        {
            Name "DepthOnly"
            Tags 
            { 
                "LightMode" = "DepthOnly"
            }
       
            // Render State
            Blend One Zero, One Zero
            Cull Off
            ZTest LEqual
            ZWrite On
            ColorMask 0
        

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment emptyFrag

            #pragma require geometry
            #pragma geometry geom

            #pragma require tessellation
            #pragma hull hull
            #pragma domain domain

            // Pragmas
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 4.5
            #pragma multi_compile_instancing
        
            // Defines
            #define SHADERPASS_DEPTHONLY

            // Includes
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "GeometryC.hlsl"
            #include "Tessellationc.hlsl"
            #include "Vertex.hlsl"

            half4 emptyFrag(GeomData input) : SV_TARGET
            {
                return 0;
            }
            ENDHLSL
        }
    }
}
