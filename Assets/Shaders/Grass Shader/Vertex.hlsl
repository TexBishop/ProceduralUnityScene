
struct Attributes 
{
	float4 positionOS   : POSITION;
	float3 normal		: NORMAL;
	float4 tangent		: TANGENT;
	float2 uv			: TEXCOORD0;
};

GeomData vert(Attributes input) 
{
	GeomData output = (GeomData)0;

	VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
	// Seems like GetVertexPositionInputs doesn't work with SRP Batcher inside geom function?
	// Had to move it here, in order to obtain positionWS and pass it through the GeomData output.

	// object space / model matrix doesn't seem to work in geom shader? Using world instead.
	output.positionWS = vertexInput.positionWS;
	//output.positionVS = vertexInput.positionVS;

	output.normalWS = TransformObjectToWorldNormal(input.normal);
	output.tangentWS = float4(TransformObjectToWorldNormal(input.tangent.xyz), input.tangent.w);
	// or maybe
	// output.tangent = float4(TransformObjectToWorldNormal(input.tangent.xyz), input.tangent.w);
	// doesn't seem to make much of a difference though

	output.uv = input.uv;
	return output;
}