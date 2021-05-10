using System.Collections;
using System.Collections.Generic;
using UnityEngine;
/*
[System.Serializable]
public class GrassMap
{
    public int octaves = 3;
    public float persistence = 2f;
    public float lacunarity = 0.5f;
    public float scale = 5;
    public float moveSample = 0;
}*/
 
public class GrassMesh : MonoBehaviour
{
    //=====================================================================
    // Parent mesh variables
    //=====================================================================
    Vector3[] groundVertices;
    List<int> triangles;

    Mesh grassMesh;

    // Start is called before the first frame update
    void Start()
    {
        grassMesh = new Mesh();
        GetComponent<MeshFilter>().mesh = grassMesh;
        grassMesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;

        Mesh_Generator m = this.GetComponentInParent<Mesh_Generator>();
        groundVertices = m.vertices;
        triangles = m.grassTriangles;

        setGeometry();
    }

    // Update is called once per frame
    void Update()
    {
        
    }
    
    void setGeometry()
    {
        grassMesh.vertices = groundVertices;
        grassMesh.triangles = triangles.ToArray();
        grassMesh.RecalculateNormals();
    }

    private void OnValidate()
    {
        if (grassMesh == null)
        {
            grassMesh = new Mesh();
            GetComponent<MeshFilter>().mesh = grassMesh;
            grassMesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;

            Mesh_Generator m = this.GetComponentInParent<Mesh_Generator>();
            groundVertices = m.vertices;
            triangles = m.grassTriangles;
        }
        setGeometry();
    }
}
