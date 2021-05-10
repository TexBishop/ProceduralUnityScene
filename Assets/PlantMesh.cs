using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class PlantMap
{
    public bool Draw = true;
    public float denseBoundary = 2;
    public float mediumBoundary = 1;
    public float lightBoundary = 0;
    public int octaves = 3;
    public float persistence = 2f;
    public float lacunarity = 0.5f;
    public float scale = 5;
    public float moveSample = 0;
    public PlantModel[] plantModels;
}

[System.Serializable]
public struct PlantModel
{
    public GameObject model;
    public Material material;
    public float radius;
    public Vector3 rotation;
}

public class PlantMesh : MonoBehaviour
{
    //=====================================================================
    // Object variables / parameter categories
    //=====================================================================
    //public TerrainMesh terrain;
    //public TerrainType[] regions;
    public PlantMap plantMap;

    //=====================================================================
    // Parent mesh variables
    //=====================================================================
    Vector3[] groundVertices;
    int xSize;
    int zSize;

    //=====================================================================
    // Plant placement variables
    //=====================================================================
    List<GameObject> plant;
    Vector2[] perlinValue;
    int count = 0;

    // Start is called before the first frame update
    void Start()
    {
        //if (this.plant != null)
        //    ResetModels();

        Mesh_Generator m = this.GetComponentInParent<Mesh_Generator>();
        groundVertices = m.vertices;
        xSize = m.terrain.xSize;
        zSize = m.terrain.zSize;

        PlacePlants();
    }

    // Update is called once per frame
    void Update()
    {

    }

    void PlacePlants()
    {
        //=====================================================================
        // Generate the vertex values using Perlin noise.
        //=====================================================================
        this.perlinValue = new Vector2[groundVertices.Length];
        for (int i = 0, z = 0; z < zSize; z++)
        {
            for (int x = 0; x < xSize; x++)
            {
                //=====================================================================
                // Assign values based on Perlin noise, using the parameters assigned
                // in the Unity editor.
                //=====================================================================
                float y = 0;
                float amplitude = 1f;
                float frequency = 1f;

                for (int c = 0; c < plantMap.octaves; c++)
                {
                    float perlin = Mathf.PerlinNoise(x / plantMap.scale * frequency, z / plantMap.scale * frequency) * 2f - 1;
                    y += perlin * amplitude;

                    amplitude *= plantMap.persistence;
                    frequency *= plantMap.lacunarity;
                }

                perlinValue[i] = new Vector2(0, y);
                i++;
            }
        }

        //=====================================================================
        // Instantiate the models
        //=====================================================================
        this.plant = new List<GameObject>();
        InstantiatePlants(this.plantMap.plantModels[0], this.plantMap.denseBoundary);
        InstantiatePlants(this.plantMap.plantModels[1], this.plantMap.mediumBoundary);
        InstantiatePlants(this.plantMap.plantModels[2], this.plantMap.lightBoundary);
    }

    void InstantiatePlants(PlantModel plantModel, float boundary)
    {
        for (int i = 0; i < this.groundVertices.Length; i++)
        {
            if (perlinValue[i].x == 0 && 0 < perlinValue[i].y && -0.5 < this.groundVertices[i].y && this.groundVertices[i].y < 2)
            {
                if (boundary < perlinValue[i].y)
                {
                    Vector3 plantPosition = this.groundVertices[i];
                    if (plantModel.model != null)
                    {
                        if (this.plantMap.Draw)
                        {
                            //this.plant.Add(Instantiate(plantModel.model, plantPosition, Quaternion.identity) as GameObject);
                            this.plant.Add(Instantiate(plantModel.model, plantPosition, Quaternion.identity, this.transform) as GameObject);
                            if (plantModel.material != null)
                                this.plant[count].GetComponent<Renderer>().material = plantModel.material;
                            if (plantModel.rotation != null)
                               this.plant[count].transform.Rotate(plantModel.rotation);

                            if (boundary == this.plantMap.denseBoundary)
                                this.plant[count].transform.Rotate(new Vector3(0, 0, Random.Range(0, 360)));
                            else
                                this.plant[count].transform.Rotate(new Vector3(0, Random.Range(0, 360), 0));

                            float scale = Random.Range(0.5f, 2.5f);
                            this.plant[count].transform.localScale = new Vector3(scale, scale, scale);
                            //this.plant[count].transform.SetParent(this.transform);
                            count++;
                        }

                        perlinValue[i].x = 1;
                    }

                    for (int j = 0; j < this.groundVertices.Length; j++)
                    {
                        if (Inside(this.groundVertices[i], this.groundVertices[j], plantModel.radius))
                            perlinValue[j].x = 1;
                    }
                }
            }
        }
    }

    private void ResetModels()
    {
        for (int i = this.plant.Count - 1; i >= 0; i--)
        {
            Destroy(this.plant[i]);
            this.plant.RemoveAt(i);
        }
        this.plant.Clear();
        count = 0;
    }
    
    private void OnValidate()
    {
        //=====================================================================
        // Destroy currently placed models before placing new models
        //=====================================================================
        if (this.plant != null)
            ResetModels();
        //this.plantMap.Draw = false;

        /*if (groundVertices == null)
        {
            Mesh_Generator m = this.GetComponentInParent<Mesh_Generator>();
            groundVertices = m.vertices;
            xSize = m.terrain.xSize;
            zSize = m.terrain.zSize;
        }*/
        PlacePlants();
    }

    private void OnDrawGizmos()
    {
        if (groundVertices == null || this.plantMap.Draw)
            return;

        for (int i = 0; i < groundVertices.Length; i++)
        {
            if (this.perlinValue[i].x == 1)
            {
                if (this.perlinValue[i].y < this.plantMap.mediumBoundary)
                    Gizmos.color = Color.yellow;
                else if (this.perlinValue[i].y < this.plantMap.denseBoundary)
                    Gizmos.color = new Color(1.0F, 0.5F, 0.0F);
                else
                    Gizmos.color = Color.red;

                Gizmos.DrawSphere(groundVertices[i], 0.2f);
            }
        }
    }

    public bool Inside(Vector3 current, Vector3 other, float radius)
    {
        //=============================================================================
        // Determine if the other vertex is in the radius of the current vertex
        //=============================================================================
        if (Mathf.Pow(current.x - other.x, 2) + Mathf.Pow(current.z - other.z, 2) < Mathf.Pow(radius, 2))
            return true;
        else
            return false;
    }
}
