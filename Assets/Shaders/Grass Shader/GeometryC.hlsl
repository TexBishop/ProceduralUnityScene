
#define BLADE_SEGMENTS 3
#define STEM_SEGMENTS 5
static int triangleCount = 0;

CBUFFER_START(UnityPerMaterial)
float4 _Specular;
float _SpecularStrength;
float4 _TopColor;
float4 _BottomColor;
float4 _DeadColor;
float _ColorNoiseScale;
float _ColorNoiseStrength;
float _BladeWidth;
float _BladeWidthRandom;
float _BladeHeight;
float _BladeHeightNoise;
float _BladeNoiseScale;
float _BladeHeightRandom;
float _BladeForward;
float _BladeCurve;
float _BendRotationRandom;
float _TessellationUniform;
float _TessellationCulling;
sampler2D _WindDistortionMap;
float4 _WindDistortionMap_ST;
float2 _WindFrequency;
float _WindStrength;
float _WindCulling;

float _StemPlacementNoise;
float _StemPlacementEdge;
float4 _TopColorStem;
float4 _BottomColorStem;
float4 _DeadColorStem;
float _StemWidth;
float _StemWidthRandom;
float _StemHeight;
float _StemHeightNoise;
float _StemNoiseScale;
float _StemHeightRandom;
float _StemForward;
float _StemCurve;
float _StemRotationRandom;
CBUFFER_END

struct GeomData
{
    float4 positionCS   : SV_POSITION;
    float3 positionWS   : TEXCOORD0;
    float3 normalWS     : TEXCOORD1;
    float4 tangentWS    : TEXCOORD2;
    float2 uv           : TEXCOORD3;
    float4 bottomColor  : TEXCOORD4;
    float4 topColor     : TEXCOORD5;
    float4 deadColor    : TEXCOORD6;
};

#ifdef SHADERPASS_SHADOWCASTER
float3 _LightDirection;

float4 GetShadowPositionHClip(float3 positionWS, float3 normalWS) 
{
    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));

    #if UNITY_REVERSED_Z
        positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
        positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif

    return positionCS;
}
#endif

float4 WorldToHClip(float3 positionWS, float3 normalWS) 
{
    #ifdef SHADERPASS_SHADOWCASTER
        return GetShadowPositionHClip(positionWS, normalWS);
    #else
        return TransformWorldToHClip(positionWS);
    #endif
}

float2 Unity_GradientNoise_Dir_float(float2 p)
{
    // Permutation and hashing used in webgl-nosie goo.gl/pX7HtC
    p = p % 289;
    float x = (34 * p.x + 1) * p.x % 289 + p.y;
    x = (34 * x + 1) * x % 289;
    x = frac(x / 41) * 2 - 1;
    return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
}

void Unity_GradientNoise_float(float2 UV, float Scale, out float Out)
{
    float2 p = UV * Scale;
    float2 ip = floor(p);
    float2 fp = frac(p);
    float d00 = dot(Unity_GradientNoise_Dir_float(ip), fp);
    float d01 = dot(Unity_GradientNoise_Dir_float(ip + float2(0, 1)), fp - float2(0, 1));
    float d10 = dot(Unity_GradientNoise_Dir_float(ip + float2(1, 0)), fp - float2(1, 0));
    float d11 = dot(Unity_GradientNoise_Dir_float(ip + float2(1, 1)), fp - float2(1, 1));
    fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
    Out = lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x) + 0.5;
}

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
    o.uv = uv;

    return o;
}

void buildGrassVertexes(GeomData input, inout GeomData geoms[BLADE_SEGMENTS * 2 + 1])
{
    //===================================================================
    // Calculate the tangent space to local space transformation matrix,
    // followed by the matrix for changing the facing direction of the
    // grass blade, and the transformation matrix for the tilt angle
    // of the grass blade.
    //===================================================================
    float3 normal = input.normalWS;
    float4 tangent = input.tangentWS;
    float3 binormal = cross(normal, tangent.xyz) * tangent.w;
    float3x3 tangentToLocal = float3x3(
        tangent.x, binormal.x, normal.x,
        tangent.y, binormal.y, normal.y,
        tangent.z, binormal.z, normal.z
        );
    float3x3 facingRotationMatrix = AngleAxis3x3(rand(input.positionWS.xyz) * TWO_PI, float3(0, 0, 1));
    float3x3 bendRotationMatrix = AngleAxis3x3(rand(input.positionWS.zzx) * _BendRotationRandom * TWO_PI * 0.5, float3(-1, 0, 0));

    //===================================================================
    // Wind calculations.  If distance from camera more than the value
    // of _WindCulling, then don't execute wind movement.
    //===================================================================
    float3x3 windMatrix; 
    float z = (TransformWorldToView(input.positionWS)).z * -1;
    if (z < _WindCulling)
    {
        float2 uv = input.positionWS.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
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

    //===================================================================
    // Get height/width/bend values
    //===================================================================
    float noiseValue;
    Unity_GradientNoise_float(input.positionWS.xz, _BladeHeightNoise, noiseValue);
    float width = (rand(input.positionWS.xyz) * 2 - 1) * _BladeWidthRandom + _BladeWidth;
    float height = (rand(input.positionWS.zyx) * 2 - 1) * _BladeHeightRandom + _BladeHeight + noiseValue * _BladeNoiseScale;
    float bend = rand(input.positionWS.xyz) * _BladeForward;

    //===================================================================
    // Initialize vertexes for grass blade
    //===================================================================
    geoms[0] = setVertex(geoms[0], transformBaseMatrix, float3(width, 0, 0), float2(0, 0));
    geoms[1] = setVertex(geoms[1], transformBaseMatrix, float3(-width, 0, 0), float2(1, 0));
    geoms[BLADE_SEGMENTS * 2] = setVertex(geoms[BLADE_SEGMENTS * 2], transformMatrix, float3(0, bend, height), float2(0.5, 1));

    for (int i = 1; i < BLADE_SEGMENTS; i++)
    {
        float t = i / (float)BLADE_SEGMENTS;
        float h = height * t;
        float w = width * t;
        float b = bend * pow(t, _BladeCurve);

        geoms[i * 2] = setVertex(geoms[i * 2], transformMatrix, float3(w, b, h), float2(0, t));
        geoms[i * 2 + 1] = setVertex(geoms[i * 2 + 1], transformMatrix, float3(-w, b, h), float2(0, t));
    }

    //===================================================================
    // Calculate surface normals
    //===================================================================
    const int numTriangles = BLADE_SEGMENTS * 2 - 1;
    float3 surfaceNormals[numTriangles];
    for (int i = 0; i < numTriangles; i++)
    {
        float3 U, V;
        if (i % 2)
        {
            U = geoms[i + 1].positionWS - geoms[i].positionWS;
            V = geoms[i + 2].positionWS - geoms[i].positionWS;
        }
        else
        {
            U = geoms[i + 2].positionWS - geoms[i].positionWS;
            V = geoms[i + 1].positionWS - geoms[i].positionWS;
        }
        surfaceNormals[i] = cross(U, V);
    }

    //===================================================================
    // Calculate vertex normals
    //===================================================================
    geoms[0].normalWS = geoms[1].normalWS = normalize(surfaceNormals[0]);
    for (int i = 2, j = 0; i < BLADE_SEGMENTS; i++, j++)
    {
        if (i < BLADE_SEGMENTS - 1)
            geoms[i].normalWS = normalize(surfaceNormals[j] + surfaceNormals[j + 2]);
        else
            geoms[i].normalWS = normalize(surfaceNormals[j] + surfaceNormals[j + 1]);
    }
    geoms[BLADE_SEGMENTS * 2].normalWS = normalize(surfaceNormals[numTriangles - 1]);
}

void buildStemVertexes(GeomData input, inout GeomData geoms[STEM_SEGMENTS * 2 + 1])
{
    //===================================================================
    // Calculate the tangent space to local space transformation matrix,
    // followed by the matrix for changing the facing direction of the
    // grass blade, and the transformation matrix for the tilt angle
    // of the grass blade.
    //===================================================================
    float3 normal = input.normalWS;
    float4 tangent = input.tangentWS;
    float3 binormal = cross(normal, tangent.xyz) * tangent.w;
    float3x3 tangentToLocal = float3x3(
        tangent.x, binormal.x, normal.x,
        tangent.y, binormal.y, normal.y,
        tangent.z, binormal.z, normal.z
        );
    float3x3 facingRotationMatrix = AngleAxis3x3(rand(input.positionWS.xyz) * TWO_PI, float3(0, 0, 1));
    float3x3 bendRotationMatrix = AngleAxis3x3(rand(input.positionWS.zzx) * _StemRotationRandom * TWO_PI * 0.5, float3(-1, 0, 0));

    //===================================================================
    // Wind calculations.  If distance from camera more than the value
    // of _WindCulling, then don't execute wind movement.
    //===================================================================
    float3x3 windMatrix;
    float z = (TransformWorldToView(input.positionWS)).z * -1;
    if (z < _WindCulling)
    {
        float2 uv = input.positionWS.xz * _WindDistortionMap_ST.xy + _WindDistortionMap_ST.zw + _WindFrequency * _Time.y;
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

    //===================================================================
    // Get height/width/bend values
    //===================================================================
    float noiseValue;
    Unity_GradientNoise_float(input.positionWS.xz, _StemHeightNoise, noiseValue);
    float width = (rand(input.positionWS.xyz) * 2 - 1) * _StemWidthRandom + _StemWidth;
    float height = (rand(input.positionWS.zyx) * 2 - 1) * _StemHeightRandom + _StemHeight + noiseValue * _StemNoiseScale;
    float bend = rand(input.positionWS.xyz) * _StemForward;

    //===================================================================
    // Initialize vertexes for stem
    //===================================================================
    geoms[0] = setVertex(geoms[0], transformBaseMatrix, float3(width, 0, 0), float2(0, 0));
    geoms[1] = setVertex(geoms[1], transformBaseMatrix, float3(-width, 0, 0), float2(1, 0));
    geoms[STEM_SEGMENTS * 2] = setVertex(geoms[STEM_SEGMENTS * 2], transformMatrix, float3(0, bend, height), float2(0.5, 1));

    for (int i = 1; i < STEM_SEGMENTS; i++)
    {
        float t = i / (float)STEM_SEGMENTS;
        float h = height * t;
        float w = width * t;
        float b = bend * pow(t, _StemCurve);

        geoms[i * 2] = setVertex(geoms[i * 2], transformMatrix, float3(w, b, h), float2(0, t));
        geoms[i * 2 + 1] = setVertex(geoms[i * 2 + 1], transformMatrix, float3(-w, b, h), float2(0, t));
    }

    //===================================================================
    // Calculate surface normals
    //===================================================================
    const int numTriangles = STEM_SEGMENTS * 2 - 1;
    float3 surfaceNormals[numTriangles];
    for (int i = 0; i < numTriangles; i++)
    {
        float3 U, V;
        if (i % 2)
        {
            U = geoms[i + 1].positionWS - geoms[i].positionWS;
            V = geoms[i + 2].positionWS - geoms[i].positionWS;
        }
        else
        {
            U = geoms[i + 2].positionWS - geoms[i].positionWS;
            V = geoms[i + 1].positionWS - geoms[i].positionWS;
        }
        surfaceNormals[i] = cross(U, V);
    }

    //===================================================================
    // Calculate vertex normals
    //===================================================================
    geoms[0].normalWS = geoms[1].normalWS = normalize(surfaceNormals[0]);
    for (int i = 2, j = 0; i < STEM_SEGMENTS; i++, j++)
    {
        if (i < STEM_SEGMENTS - 1)
            geoms[i].normalWS = normalize(surfaceNormals[j] + surfaceNormals[j + 2]);
        else
            geoms[i].normalWS = normalize(surfaceNormals[j] + surfaceNormals[j + 1]);
    }
    geoms[STEM_SEGMENTS * 2].normalWS = normalize(surfaceNormals[numTriangles - 1]);
}

[maxvertexcount((BLADE_SEGMENTS * 2 + 1) + (STEM_SEGMENTS * 2 + 1))]
void geom(triangle GeomData input[3], inout TriangleStream<GeomData> triStream)
{
    triangleCount++;

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
    // Initialize vertexes for grass blade
    //===================================================================
    GeomData blades[BLADE_SEGMENTS * 2 + 1];
    for (int i = 0; i < BLADE_SEGMENTS * 2 + 1; i++)
    {
        blades[i] = input[0];
        blades[i].bottomColor = _BottomColor;
        blades[i].topColor = _TopColor;
        blades[i].deadColor = _DeadColor;
    }

    buildGrassVertexes(input[0], blades);

    //===================================================================
    // Append all grass blade vertexes
    //===================================================================
    for (int i = 0; i < BLADE_SEGMENTS * 2 + 1; i++)
        triStream.Append(blades[i]);

    triStream.RestartStrip();

    //===================================================================
    // Initialize vertexes for stems
    //===================================================================
    float noiseValue;
    Unity_GradientNoise_float(input[1].positionWS.xz, _StemPlacementNoise, noiseValue);

    if (_StemPlacementEdge < noiseValue)
    {
        GeomData stems[STEM_SEGMENTS * 2 + 1];
        for (int i = 0; i < STEM_SEGMENTS * 2 + 1; i++)
        {
            stems[i] = input[1];
            stems[i].bottomColor = _BottomColorStem;
            stems[i].topColor = _TopColorStem;
            stems[i].deadColor = _DeadColorStem;
        }

        buildStemVertexes(input[1], stems);

        //===============================================================
        // Append all stem vertexes
        //===============================================================
        for (int i = 0; i < STEM_SEGMENTS * 2 + 1; i++)
            triStream.Append(stems[i]);

        triStream.RestartStrip();
    }
}