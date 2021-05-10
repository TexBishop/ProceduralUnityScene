
#define BLADE_SEGMENTS 3

CBUFFER_START(UnityPerMaterial)
float4 _TopColor;
float4 _BottomColor;
float _TranslucentGainST;
float _BendRotationRandom;
float _BladeWidth;
float _BladeWidthRandom;
float _BladeHeight;
float _BladeHeightRandom;
float _BladeForward;
float _BladeCurve;
float _TessellationUniform;
float _TessellationCulling;
sampler2D _WindDistortionMap;
float4 _WindDistortionMap_ST;
float2 _WindFrequency;
float _WindStrength;
float _WindCulling;
CBUFFER_END

struct GeomData
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
    float4 tangentWS : TEXCOORD2;
    float3 viewDirectionWS : TEXCOORD3;
    float2 lightmapUV : TEXCOORD4;
    float3 sh : TEXCOORD5;
    float4 fogFactorAndVertexLight : TEXCOORD6;
    float4 shadowCoord : TEXCOORD7;
};

float rand(float3 seed)
{
    return frac(sin(dot(seed.xyz, float3(12.9898, 78.233, 53.539))) * 43758.5453);
}

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

float3 calcNormal(float3 a, float3 b, float3 c)
{
    float3 edge_1 = b - a;
    float3 edge_2 = c - a;
    return normalize(cross(edge_1, edge_2));
}

//===================================================================
// Calculates the tangent.  
//===================================================================
float3 calcTangent(float3 a, float3 b, float3 c, float2 uv_0, float2 uv_1, float2 uv_2)
{
    float3 edge_1 = b - a;
    float3 edge_2 = c - a;
    float x1 = uv_1.x - uv_0.x;
    float x2 = uv_2.x - uv_0.x;
    float y1 = uv_1.y - uv_0.y;
    float y2 = uv_2.y - uv_0.y;
    float f = 1.0f / (x1 * y2 - x2 * y1);
    return (f * (edge_1 * y2 - edge_2 * y1));
}

GeomData setVertex(GeomData vert, float3x3 transform, float3 pos, float2 uv)
{
    GeomData o = vert;
    o.positionWS = vert.positionWS + mul(transform, pos);
    o.positionCS = TransformWorldToHClip(o.positionWS);
    o.normalWS = mul(transform, float3(0, -1, 0));
    //o.tangentWS = float4(getTangent(o.normalWS), /*mul(transform, vert.tangentWS.xyz),*/ vert.tangentWS.w);
    
    #if SHADOWS_SCREEN
        o.shadowCoord = ComputeScreenPos(o.positionCS);
    #else
        o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
    #endif

    #if defined(LIGHTMAP_ON)
        o.lightmapUV = uv;
    #endif
    #if !defined(LIGHTMAP_ON)
        o.sh = float3(uv, 0);
    #endif

    return o;
}

[maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
void geom(triangle GeomData input[3], inout TriangleStream<GeomData> triStream)
{
    //===================================================================
    // Renders the base/ground triangles.  Commented out because I don't
    // want these rendering at this time.  If activating, change
    // maxvertexcount to (BLADE_SEGMENTS * 2 + 4)
    //===================================================================
    //triStream.Append(input[0]);
    //triStream.Append(input[1]);
    //triStream.Append(input[2]);
    //triStream.RestartStrip();

    //===================================================================
    // Only render grass blades infront of camera (nothing behind)
    //===================================================================
    float z = (TransformWorldToView(input[0].positionWS)).z * -1;
    if (z < 0)
        return;

    //===================================================================
    // Calculate the tangent space to local space transformation matrix,
    // followed by the matrix for changing the facing direction of the
    // grass blade, and the transformation matrix for the tilt angle
    // of the grass blade.
    //===================================================================
    float3 normal = input[0].normalWS;
    float4 tangent = input[0].tangentWS;
    float3 binormal = cross(normal, tangent.xyz) * tangent.w;
    float3x3 tangentToLocal = float3x3(
        tangent.x, binormal.x, normal.x,
        tangent.y, binormal.y, normal.y,
        tangent.z, binormal.z, normal.z
        );
    float3x3 facingRotationMatrix = AngleAxis3x3(rand(input[0].positionWS.xyz) * TWO_PI, float3(0, 0, 1));
    float3x3 bendRotationMatrix = AngleAxis3x3(rand(input[0].positionWS.zzx) * _BendRotationRandom * TWO_PI * 0.5, float3(-1, 0, 0));

    //===================================================================
    // Wind calculations.  If distance from camera more than the value
    // of _WindCulling, then don't execute wind movement.
    //===================================================================
    float3x3 windMatrix;
    if (z < _WindCulling)
    {
        float2 uv = input[0].positionWS.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
        float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
        float3 wind = normalize(float3(windSample, 0));
        windMatrix = AngleAxis3x3(PI * windSample, wind);
    }
    else
    {
        windMatrix = float3x3(1, 0, 0, 0, 1, 0, 0, 0, 1); // Identity
    }

    //===================================================================
    // Multiply the various transforms to get the final transform matrix
    //===================================================================
    float3x3 transformMatrix = mul(mul(mul(tangentToLocal, windMatrix), facingRotationMatrix), bendRotationMatrix);
    float3x3 transformBaseMatrix = mul(tangentToLocal, facingRotationMatrix);

    float width = (rand(input[0].positionWS.xyz) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
    float height = (rand(input[0].positionWS.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
    float bend = rand(input[0].positionWS.xyz) * _BladeForward;

    triStream.Append(setVertex(input[0], transformBaseMatrix, float3(width, 0, 0), float2(0, 0)));
    triStream.Append(setVertex(input[0], transformBaseMatrix, float3(-width, 0, 0), float2(1, 0)));

    for (int i = 1; i < BLADE_SEGMENTS; i++)
    {
        float t = i / (float)BLADE_SEGMENTS;
        float h = height * t;
        float w = width * t;
        float b = bend * pow(t, _BladeCurve);

        triStream.Append(setVertex(input[0], transformMatrix, float3(w, b, h), float2(0, t)));
        triStream.Append(setVertex(input[0], transformMatrix, float3(-w, b, h), float2(0, t)));
    }
    triStream.Append(setVertex(input[0], transformMatrix, float3(0, bend, height), float2(0.5, 1)));

    triStream.RestartStrip();
}

GeomData setVertexTest(GeomData vert, float3x3 transform, float3 pos, float2 uv)
{
    GeomData o = vert;
    o.positionWS = vert.positionWS + mul(transform, pos);
    o.positionCS = TransformWorldToHClip(o.positionWS.xyz);
    o.normalWS = mul(transform, float3(0, -1, 0));
    //o.tangentWS = float4(getTangent(o.normalWS), /*mul(transform, vert.tangentWS.xyz),*/ vert.tangentWS.w);

    #if SHADOWS_SCREEN
    o.shadowCoord = ComputeScreenPos(o.positionCS);
    #else
    o.shadowCoord = TransformWorldToShadowCoord(o.positionWS);
    #endif

    #if defined(LIGHTMAP_ON)
    o.lightmapUV = uv;
    #endif
    #if !defined(LIGHTMAP_ON)
    o.sh = float3(uv, 0);
    #endif

    return o;
}

[maxvertexcount(BLADE_SEGMENTS * 2 + 1)]
void geomTest(triangle GeomData input[3], inout TriangleStream<GeomData> triStream)
{
    //===================================================================
    // Renders the base/ground triangles.  Commented out because I don't
    // want these rendering at this time.  If activating, change
    // maxvertexcount to (BLADE_SEGMENTS * 2 + 4)
    //===================================================================
    //triStream.Append(input[0]);
    //triStream.Append(input[1]);
    //triStream.Append(input[2]);
    //triStream.RestartStrip();

    //===================================================================
    // Only render grass blades infront of camera (nothing behind)
    //===================================================================
    float z = (TransformWorldToView(input[0].positionWS)).z * -1;
    if (z < 0)
        return;

    GeomData geo = input[0];

    float3 normal = geo.normalWS;
    float4 tangent = geo.tangentWS;
    float3 binormal = cross(normal, tangent.xyz) * tangent.w;
    float3x3 tangentToLocal = float3x3(
        tangent.x, binormal.x, normal.x,
        tangent.y, binormal.y, normal.y,
        tangent.z, binormal.z, normal.z
        );
    float3x3 facingRotationMatrix = AngleAxis3x3(rand(geo.positionWS.xyz) * TWO_PI, float3(0, 0, 1));
    float3x3 bendRotationMatrix = AngleAxis3x3(rand(geo.positionWS.zzx) * _BendRotationRandom * TWO_PI * 0.5, float3(-1, 0, 0));

    //===================================================================
    // Wind calculations.  If distance from camera more than the value
    // of _WindCulling, then don't execute wind movement.
    //===================================================================
    float3x3 windMatrix;
    if (z < _WindCulling)
    {
        float2 uv = input[0].positionWS.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
        float2 windSample = (tex2Dlod(_WindDistortionMap, float4(uv, 0, 0)).xy * 2 - 1) * _WindStrength;
        float3 wind = normalize(float3(windSample, 0));
        windMatrix = AngleAxis3x3(PI * windSample, wind);
    }
    else
    {
        windMatrix = float3x3(1, 0, 0, 0, 1, 0, 0, 0, 1); // Identity
    }

    //===================================================================
    // Multiply the various transforms to get the final transform matrix
    //===================================================================
    float3x3 transformMatrix = mul(mul(windMatrix, facingRotationMatrix), bendRotationMatrix);
    float3x3 transformBaseMatrix = facingRotationMatrix;

    float width = (rand(input[0].positionWS.xyz) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
    float height = (rand(input[0].positionWS.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight;
    float bend = rand(input[0].positionWS.xyz) * _BladeForward;

    //===================================================================
    // Vertex assignment/calculations
    //===================================================================
    GeomData a = geo; GeomData b = geo; GeomData c = geo;

    a.positionWS = geo.positionWS + float3(width, 0, 0);
    a.positionCS = TransformWorldToHClip(a.positionWS);
    a.lightmapUV = float2(0, 0);

    b.positionWS = geo.positionWS + float3(-width, 0, 0);
    b.positionCS = TransformWorldToHClip(b.positionWS);
    b.lightmapUV = float2(1, 0);

    c.positionWS = geo.positionWS + float3(0, height, 0);
    c.positionCS = TransformWorldToHClip(c.positionWS);
    c.lightmapUV = float2(0.5, 1);

    a.normalWS = b.normalWS = c.normalWS = float3(0, -1, 0);// calcNormal(a.positionWS, b.positionWS, c.positionWS);
    a.tangentWS = b.tangentWS = c.tangentWS = float4(calcTangent(a.positionWS, b.positionWS, c.positionWS, a.lightmapUV, b.lightmapUV, c.lightmapUV), 1);

    triStream.Append(a);
    triStream.Append(b);
    triStream.Append(c);
    triStream.RestartStrip();
}