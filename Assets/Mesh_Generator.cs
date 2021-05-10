using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class TerrainMesh
{
    public int xSize = 20;
    public int zSize = 20;
    public int octaves = 3;
    public float uPersistence = 2f;
    public float uLacunarity = 0.5f;
    public float uScale = 5;
    public float dPersistence = 2f;
    public float dLacunarity = 0.5f;
    public float dScale = 5;
    public float depth = 1;
    public float moveSample = 0;
}

[System.Serializable]
public struct TerrainType
{
    public string name;
    public float height;
    public Color color;
}

[System.Serializable]
public class GrassMap
{
    public float upperRange = 0.1f;
    public float lowerRange = -2.0f;
    public float perlinLevel = 2.0f;
    public int octaves = 3;
    public float persistence = 2f;
    public float lacunarity = 0.5f;
    public float scale = 5;
    public float moveSample = 0;
}

[RequireComponent(typeof(MeshFilter))]
public class Mesh_Generator : MonoBehaviour
{
    //=====================================================================
    // Object variables / parameter categories
    //=====================================================================
    public Material[] material;
    public TerrainMesh terrain;
    public TerrainType[] regions;
    public GrassMap grassMap;

    //=====================================================================
    // Terrain mesh variables
    //=====================================================================
    [HideInInspector]
    public Mesh mesh;

    [HideInInspector]
    public Vector3[] vertices;

    [HideInInspector]
    public List<int> grassTriangles;

    int[] triangles;
    Vector2[] uv;
    Color[] colors;

    //=====================================================================
    // Start is called before the first frame update
    //=====================================================================
    void Start()
    {
        mesh = new Mesh();
        GetComponent<MeshFilter>().mesh = mesh;

        mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
        mesh.Clear();

        CreateShape();
        UpdateMesh();
    }

    //=====================================================================
    // Update is called once per frame
    //=====================================================================
    void Update()
    {
       
    }

    void CreateShape()
    {
        //=====================================================================
        // Generate the vertex values using Perlin noise.
        //=====================================================================
        vertices = new Vector3[(terrain.xSize + 1) * (terrain.zSize + 1)];
        for (int i = 0, z = 0; z <= terrain.zSize; z++)
        {
            for (int x = 0; x <= terrain.xSize; x++)
            {
                //=====================================================================
                // Assign values based on Perlin noise, using the U parameters assigned
                // in the Unity editor.
                //=====================================================================
                float y = 0;
                float amplitude = 1f;
                float frequency = 1f;

                for (int c = 0; c < terrain.octaves; c++)
                {
                    float perlin = Mathf.PerlinNoise(x / terrain.uScale * frequency, z / terrain.uScale * frequency) * 2f - 1;
                    y += perlin * amplitude;

                    amplitude *= terrain.uPersistence;
                    frequency *= terrain.uLacunarity;
                }

                //=====================================================================
                // If this vertex is below ground level, recalculate using the D
                // parameters assigned in the Unity editor.
                //=====================================================================
                if (y < 0)
                {
                    y = 0;
                    amplitude = 1f;
                    frequency = 1f;
                    for (int c = 0; c < terrain.octaves; c++)
                    {
                        float perlin = Mathf.PerlinNoise((x + terrain.moveSample) / terrain.dScale * frequency, (z + terrain.moveSample) / terrain.dScale * frequency) * 2f - 1;
                        y += perlin * amplitude;

                        amplitude *= terrain.dPersistence;
                        frequency *= terrain.dLacunarity;
                    }

                    //=====================================================================
                    // Adjust the depth value of this vertex.  This is used to create flat
                    // areas of terrain.
                    //=====================================================================
                    y += terrain.depth;
                    if (y > 0)
                        y = 0;
                }

                vertices[i] = new Vector3(x, y, z);
                i++;
            }
        }

        //=====================================================================
        // Build the index array for the triangles
        //=====================================================================
        triangles = new int[terrain.xSize * terrain.zSize * 6];
        grassTriangles = new List<int>();
        //uv = new Vector2[vertices.Length];
        int quad = 0, vert = 0;
        for (int z = 0; z < terrain.zSize; z++)
        {
            for (int x = 0; x < terrain.xSize; x++)
            {
                triangles[vert] = quad;
                triangles[vert + 1] = quad + terrain.xSize + 1;
                triangles[vert + 2] = quad + 1;
                triangles[vert + 3] = quad + terrain.xSize + 1;
                triangles[vert + 4] = quad + terrain.xSize + 2;
                triangles[vert + 5] = quad + 1;
                /*
                if (quad % terrain.xSize == 0)
                    uv[quad] = new Vector2(terrain.zSize % 2, terrain.xSize % 2);
                uv[quad + 1] = new Vector2(terrain.zSize % 2, terrain.xSize % 2);
                if (z == terrain.zSize - 1)
                {
                    if (quad % terrain.xSize == 0)
                        uv[quad + terrain.xSize + 1] = new Vector2((terrain.zSize + 1) % 2, terrain.xSize % 2);
                    uv[quad + terrain.xSize + 2] = new Vector2((terrain.zSize + 1) % 2, terrain.xSize % 2);
                }*/

                //=====================================================================
                // Build the list of triangles for the grass mesh.
                // Handled per quad, two triangles per square.
                // If the center of the triangle's perlin value is within the range
                // where grass can grow, add it to the grass triangle index.
                //=====================================================================
                Vector3 tri1 = getCentroid(vertices[quad], vertices[quad + terrain.xSize + 1], vertices[quad + 1]);
                Vector3 tri2 = getCentroid(vertices[quad + terrain.xSize + 1], vertices[quad + terrain.xSize + 2], vertices[quad + 1]);
                float tri1perlin = calculatePerlin(tri1);
                float tri2perlin = calculatePerlin(tri2);
                if (grassMap.lowerRange < tri1.y && tri1.y < grassMap.upperRange && grassMap.perlinLevel < tri1perlin)
                {
                    grassTriangles.Add(quad);
                    grassTriangles.Add(quad + terrain.xSize + 1);
                    grassTriangles.Add(quad + 1);
                }
                if (grassMap.lowerRange < tri2.y && tri2.y < grassMap.upperRange && grassMap.perlinLevel < tri2perlin)
                {
                    grassTriangles.Add(quad + terrain.xSize + 1);
                    grassTriangles.Add(quad + terrain.xSize + 2);
                    grassTriangles.Add(quad + 1);
                }
                
                quad++;
                vert += 6;
            }
            quad++;
        }

        //=====================================================================
        // Assign each vertex a color based on the terrain values set up in
        // the Unity editor.
        //=====================================================================
        colors = new Color[vertices.Length];
        for (int i = 0; i < vertices.Length; i++)
        {
            float height = vertices[i].y;
            for (int j = 0; j < regions.Length; j++)
            {
                if (height <= regions[j].height)
                    colors[i] = regions[j].color;
            }
        }
    }

    void UpdateMesh()
    {
        if (mesh == null)
        {
            mesh = new Mesh();
            GetComponent<MeshFilter>().mesh = mesh;

            mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
            mesh.Clear();
        }

        mesh.vertices = vertices;
        mesh.triangles = triangles;
        //mesh.uv = uv;
        mesh.colors = colors;
        mesh.RecalculateNormals();
        mesh.Optimize();
    }

    private void OnValidate()
    {
        CreateShape();
        UpdateMesh();
    }

    private void OnDrawGizmos()
    {
        /*   if (vertices == null || this.plantMap.Draw)
               return;

           for (int i = 0; i < vertices.Length; i++)
           {
               if (this.perlinValue[i].x == 1)
               {
                   if (this.perlinValue[i].y < this.plantMap.mediumBoundary)
                       Gizmos.color = Color.yellow;
                   else if (this.perlinValue[i].y < this.plantMap.denseBoundary)
                       Gizmos.color = new Color(1.0F, 0.5F, 0.0F);
                   else
                       Gizmos.color = Color.red;

                   Gizmos.DrawSphere(vertices[i], 0.2f);
               }
           }*/
    }

    public float calculatePerlin(Vector3 point)
    {
        //=====================================================================
        // Assign value based on Perlin noise, using the parameters assigned
        // in the Unity editor.
        //=====================================================================
        float y = 0;
        float amplitude = 1f;
        float frequency = 1f;

        for (int c = 0; c < grassMap.octaves; c++)
        {
            float perlin = Mathf.PerlinNoise(point.x / grassMap.scale * frequency, point.z / grassMap.scale * frequency) * 2f - 1;
            y += perlin * amplitude;

            amplitude *= grassMap.persistence;
            frequency *= grassMap.lacunarity;
        }

        return y;
    }

    private Vector3 getCentroid(Vector3 one, Vector3 two, Vector3 tre)
    {
        Vector3 centroid = new Vector3(0, 0, 0);

        centroid.x = (one.x + two.x + tre.x) / 3;
        centroid.y = (one.y + two.y + tre.y) / 3;
        centroid.z = (one.z + two.z + tre.z) / 3;

        return centroid;
    }
}
