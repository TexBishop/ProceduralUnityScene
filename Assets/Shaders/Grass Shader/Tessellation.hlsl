
//=========================================================================
// A bit of versioning code that I probably don't need right now, but
// may be useful in the future.
//=========================================================================
#if defined(SHADER_API_D3D11) || defined(SHADER_API_GLES3) || defined(SHADER_API_GLCORE) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL) || defined(SHADER_API_PSSL)
#define UNITY_CAN_COMPILE_TESSELLATION 1
#   define UNITY_domain                 domain
#   define UNITY_partitioning           partitioning
#   define UNITY_outputtopology         outputtopology
#   define UNITY_patchconstantfunc      patchconstantfunc
#   define UNITY_outputcontrolpoints    outputcontrolpoints
#endif

//=========================================================================
// Incoming data structure from the vertex shader
//=========================================================================
struct TessellationFactors
{
	float edge[3] : SV_TessFactor;
	float inside : SV_InsideTessFactor;
};

//=========================================================================
// Function constant that determines the triangle divisions.
// _TessellationUniform is the number of divisions per edge, set in the
// material inspector settings.
//=========================================================================
TessellationFactors patchConstantFunction(InputPatch<GeomData, 3> patch)
{
	//===================================================================
	// Get the distance of the triangle from the camera.  Use this value
	// to attenuate the number of tessellations based on the distance
	// from the camera.  If the triangle is behind the player, leave
	// the tesselation value at 1 (no tessellation).
    //===================================================================
	float tessels = 1;
	float z = (TransformWorldToView(patch[0].positionWS)).z * -1;
	if (z > 0)
	{
		if (z < 1)
			z = 1;

		tessels = _TessellationUniform / (z * _TessellationCulling);
		if (_TessellationUniform < tessels)
			tessels = _TessellationUniform;
	}

	TessellationFactors f;
	f.edge[0] = tessels;
	f.edge[1] = tessels;
	f.edge[2] = tessels;
	f.inside = tessels;
	return f;
}

//=========================================================================
// Hull shader.  Determines the patch divisions using the patch constant
// function, then forwards the data.  The tessellatiion stage between
// the hull shader and the domain shader will determine where the vertexes
// will be placed, and pass that data into the domain shader as
// barycentric coordinates.
//=========================================================================
[UNITY_domain("tri")]
[UNITY_outputcontrolpoints(3)]
[UNITY_outputtopology("triangle_cw")]
[UNITY_partitioning("integer")]
[UNITY_patchconstantfunc("patchConstantFunction")]
GeomData hull(InputPatch<GeomData, 3> patch, uint id : SV_OutputControlPointID)
{
	return patch[id];
}

//=========================================================================
// Domain shader.  Uses the barycentric coordinates to initialize the new
// vertex data, stores it into a GeomData object and passes the patch to
// the geometry shader.
//=========================================================================
[UNITY_domain("tri")]
GeomData domain(TessellationFactors factors, OutputPatch<GeomData, 3> patch, float3 barycentricCoords : SV_DomainLocation)
{
	GeomData g;

	#define DOMAIN_INTERPOLATE(fieldName) g.fieldName = \
		patch[0].fieldName * barycentricCoords.x + \
		patch[1].fieldName * barycentricCoords.y + \
		patch[2].fieldName * barycentricCoords.z;

	DOMAIN_INTERPOLATE(positionCS)
	DOMAIN_INTERPOLATE(positionWS)
	DOMAIN_INTERPOLATE(normalWS)
	DOMAIN_INTERPOLATE(tangentWS)
	DOMAIN_INTERPOLATE(viewDirectionWS)
	DOMAIN_INTERPOLATE(lightmapUV)
	DOMAIN_INTERPOLATE(sh)
	DOMAIN_INTERPOLATE(fogFactorAndVertexLight)
	DOMAIN_INTERPOLATE(shadowCoord)

	return g;
}

