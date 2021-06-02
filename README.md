# **Procedural Grass Shader**

### 1 **Introduction**

  1.1 **Overview**

This implementation uses a geometry shader in tandem with a tessellation shader to draw individual grass blades procedurally. The grass is capable of drawing on any mesh that is set with a material which utilizes the grass shaders.

  1.2 **Purpose**

The purpose of this project is to explore the geometry shader to gain an understanding of its capabilities and garner some hands-on experience at the same time. The tessellation shader turned out to be very useful for creating a grass shader, so exploration of this portion of the shader pipeline was added to the project. This was a welcome addition, as my general purpose was to increase my knowledge of shaders, rather than specifically the geometry shader.

  1.3 **Assets**
  
  1.3.1 Unity -  This project was developed using the Unity game engine, version 2020.3.5f1.
  
  1.3.2 Shader Pipeline – Unity offers three different pipeline options: Default, Universal Render Pipeline (URP), and High-Definition Render Pipeline (HDRP).

- Default – Fully functional, basic pipeline that will be removed/replaced sometime within the next few years.
- Universal Rendering Pipeline (URP) – Also sometimes referred to as Lightweight Rendering Pipeline (LWRP). The pipeline being developed to replace the current default. It&#39;s unfinished, but able to be used currently by installing the in-progress package. Faster and more robust than the default, though it&#39;s still missing some features. Functions on all platforms.
- High-Definition Rendering Pipeline (HDRP) – The option to take if wanting high quality graphics. Will not function on mobile platforms.

With the deprecation of the default pipeline in favor of URP on the horizon, default isn&#39;t a strong option for the future. The capabilities of HDRP aren&#39;t needed for this project and having a shader that works on all platforms is more desirable. Thus, I chose to use URP on this project.

This is the decision that I made at the outset of the project. In retrospect, with the things that I have learned, I would potentially choose HDRP if doing this over again. The issue is that geometry shaders aren&#39;t an option for apple products and are discouraged on mobile platforms due to extremely poor performance (high strain on fps and battery drain). Thus, the primary use-case for geometry shaders is on PC, which is also the platform that supports HDRP.

  1.3.3 Shader Language – Unity supports most shader languages, but the default is DirectX. When deciding which shader language to use, those that are specific to a platform (such as Metal) aren&#39;t in consideration. That leaves DirectX, OpenGL and Vulcan.

- DirectX – Uses HLSL, the default for Unity. DirectX functions only on windows machines, but Unity has built-in converters to allow all shaders written in HLSL to be cross compiled into whatever is needed by the target API (OpenGL, OpenGL ES, Metal, Vulkan).
- OpenGL – Uses GLSL. It&#39;s widely used, and I&#39;m personally more familiar with it. However, Unity won&#39;t convert it to other target APIs for you. I believe this would require manual ports for shaders if intending to publish on iPhone (Metal) or consoles (Each of which use custom APIs).
- Vulkan – Unity supports it, but it&#39;s difficult to find information about it. It doesn&#39;t seem to offer any advantages at this point in time (within the Unity implementation) other than possibly a lower power usage on the hardware.

I already have experience with OpenGL, so choosing DirectX or Vulkan has merit from a learning standpoint. Since DirectX is the default in Unity and supports conversion of GLSL to the other languages, it has added value for future work in Unity. Thus, DirectX was used for this project.

  1.4 **Resources**

[1] was my primary resource for this project. It&#39;s the tutorial that I began with and continued to reference. Unfortunately, it&#39;s written using DX9 rather than DX11, which lead to quite a few issues that needed to be resolved.

[2] was simply used as an extra point of reference

[3] provided a methodology for utilizing generated code from a shader graph

[4] was used for general problem solving and troubleshooting versioning issues

[5] provided the tutorial for working with tessellation shaders

1. Ross, Erik Roystan. &quot;Unity Grass Geometry Shader Tutorial at Roystan.&quot; _Roystan.net_, 31 Mar. 2019, roystan.net/articles/grass-shader.html
2. Alisavakis, Harry, et al. &quot;My Take on Shaders: Grass Shader (Part I).&quot; _HAlisavakis.com_, 20 Oct. 2019, halisavakis.com/my-take-on-shaders-grass-shader-part-i/
3. Bill, Game Dev. &quot;Geometry Shaders in URP.&quot; Game Dev Bill, 22 Oct. 2020, gamedevbill.com/geometry-shaders-in-urp/
4. Cyan. &quot;Writing Shader Code for the Universal RP.&quot; _Cyan: Game Development Blog_, 27 July 2020, cyangamedev.wordpress.com/2020/06/05/urp-shader-code/
5. Flick, Jasper. &quot;Tessellation: Subdividing Triangles.&quot; _Catlike Coding_, 30 Nov. 2017, catlikecoding.com/unity/tutorials/advanced-rendering/tessellation/.


### 2 **Implementation**

  2.1 **Setup**

To begin with, I didn&#39;t want to simply create the shader in a void. I wanted to implement it into the procedural scene created through the first two assignments. To do that, I first needed a mesh to attach it to. Simply attaching it to the ground mesh didn&#39;t turn out to be a good option, as I only wanted to draw the grass in certain places which didn&#39;t turn out to be as easy as I thought it might. Thus, I decided to give it its own mesh.

One concern I had with this approach, was that the newly generated vertices that are between the vertices of the existing mesh may appear above or below the flat triangle drawn for the ground mesh, rather than on it, which would result in the grass being above or below the ground plane. I solved this simply.

Rather than generating a new set of vertices based off of the Perlin noise map used for the grass placement, I used the existing ground vertices. In the loop that creates the index array for the ground mesh, I generate a second index array for the grass mesh, adding any triangle that falls within the parameters for grass placement. With this method, the grass mesh triangles match the base ground mesh exactly.

  2.2 **Shaders**
  
  2.2.1 Tessellation – this shader turned out to be much simpler to implement than I imagined it would be, at least for my use-case. It pretty much follows the tutorial in [5] exactly aside from adjusting the variables passed through to my own needs. The only additions I made were a couple of culling techniques for a performance boost. Any triangles that are behind the view camera have the tessellation value set to 1 (no tessellation).

There&#39;s also a value adjustor calculated into the tessellation value that uses view distance from the camera along with a value set by the user in the inspector that determines the distance to use. If this value is set low, so that the attenuation of the tessellation is easily visible, it can cause some pop-in when using an integer type for partitioning. This is due to the tessellation value abruptly changing from one value to another (say 2 to 3) at intervals. I experimented with using a floating-point type to get rid of this pop-in, but the result was that with every step the player takes the number of blades of grass are changing for every triangle beyond the point of attenuation. This resulted in a constant shuffling/dancing of the grass blades that was unpleasant. Using integer does not cause this; the blades stay static. Since the pop-in is only visible if the attenuation is set to be heavy/near, this is acceptable.

What the tessellation is doing is providing a method for controlling the number of grass blades to be drawn. Each triangle draws one grass blade (unless the second plant type is used, in which case there are two blades). The density of grass blades being drawn can then be controlled by changing the tessellation value.

  2.2.2 Geometry – The majority of the work/code happens here. The tutorial in [1] was the primary source for the work here, despite it being written for DX9 (DX11 was used for this project). [4] was a great resource for resolving the versioning issues I encountered. Initially, I started by utilizing the techniques from [3] to circumvent the need to code the lighting and shadows and tie them into Unity&#39;s control system. This involved beginning from machine generated code produced by the shader graph in Unity. It was a very difficult process due to low readability of the code and many functions being hidden in other libraries. I never did find where the vertex and fragment shaders were located. I eventually had to abandon this workflow due to time constraints. I did have it working for lighting and receiving shadows but was struggling to get the grass blades to cast shadows.

Abandoning this involved writing custom vertex and fragment shaders. Things went much more smoothly once I did this, but it resulted in simpler models for lighting and shadows being used. I was already late in my time-frame for this project and didn&#39;t have the time to devote to figure out how to tie these models into Unity&#39;s systems and controls properly.

One thing to note within the geometry shader is that the original mesh triangles used to place grass blades are being discarded. The only vertex/triangle data passed on to the fragment shader are the grass blades. The reason for this is to allow the ground mesh to show through/between the grass blades, as seen here:

![](RackMultipart20210602-4-iqprec_html_a34010a9b3a8fac1.jpg)

There are two optimizations used for performance gain here. First, any grass blades that are behind the user&#39;s camera are not drawn. Second, if the distance from the camera is greater than a particular threshold set in the inspector, the grass will not be animated using the wind map.

  2.2.3 Vertex and Fragment – The vertex shader is very basic, simply taking the needed values and packing them into a GeomData object to pass through to the Tessellation shader.

The fragment shader is fairly basic as well. It just uses a simple ambient/diffuse/specular lighting model utilizing some of the Unity library functions. The colors used for the blades are calculated through linear interpolation using the color values provided by the user in the inspector. A noise value is used to determine color shifts based on location. Both the front and back of the blades are rendered by inverting the normal when drawing the back-face.


### 3 **Results**

 3.1 **Positive**

I accomplished my basic goals; I learned quite a bit about Unity and Geometry/Tessellation shaders. All of the goals set out in my roadmap located in the project proposal have been implemented and work well for the most part. The shader is capable of creating grass of varying heights, widths, angles, and colors. The heights and colors can be perturbed using noise maps. The blades cast and receive shadows and can simulate movement in the wind using a wind map. A secondary plant/grass type is implemented and can be controlled separately from the primary type.

The following images are of various types of grass built using this shader. These all use the same shader, adjusting the controllable parameters located within the inspector to achieve the different forms/visuals.

![](RackMultipart20210602-4-iqprec_html_f2c22bdc1717b035.jpg)

_This shows a basic grass type. My intention here was to simply make a nice-looking normal grass type. This is the included material called &#39;original&#39;._

![](RackMultipart20210602-4-iqprec_html_c4009afd434c5ac5.jpg)

_This shows a taller type of grass along with a secondary plant type. The taller grass is a bit thinner. The secondary plant is set to long, wide blades with a lot of lean/bend using the same methods as the grass. This material is included as &#39;TallGrass&#39;._

![](RackMultipart20210602-4-iqprec_html_116fb142bc36af77.jpg)

_This shows an attempt to make grass that is flat to the ground. The shadows and lighting start to break down a bit when the blade&#39;s lean is turned to an extreme angle, so getting this to look good was difficult. The brown blades flat against the ground are the base plant type, while the taller tufts of grass are the secondary plant type, placed in a patchy patter using a noise map._

In all three of these examples the color variations can be seen, and height variations are visible in the first two. Upon initially completing the implementation of the drawing of the grass blades with height/width/angle control and shadows, there was a sameness that didn&#39;t feel natural. All blades were the exact same color, and all of the grass was roughly the same height across the entire map. I solved both of these issues using the same technique, and I feel that it was quite successful. A noise map is generated using a strength value set in the inspector, and the color/height is adjusted using the y value for the noise map at that particular location. For the color, this provides a value to use when doing linear interpolation between the live grass color and dead grass color.

  3.2 **Negative**

The primary issue currently is with the shadows. Received shadows work well, but aliasing issues arise around the edges when the blades are made large. Increasing the number of triangles in the blade may solve this. Cast shadows are much more of a problem. In general, the issue isn&#39;t noticeable for typical grass, but it can become very ugly once you start pushing the limits of the potential values of the parameters. Large blades show the issues starkly. The shadows are highly pixelated and it&#39;s unclear if every blade is properly casting a shadow. Also, take note of the two blades that are covered with black lines. This is an issue that seems to happen when you have too many blades within the same area. I&#39;m not sure of the details behind why this happens, but it needs to be investigated.

![](RackMultipart20210602-4-iqprec_html_2d7a9afcfff37e0.jpg)

_A close up of a plant made with large blades. Notice the poor quality of the cast shadows._

Also visible in this image, once blades start becoming large, they look overly flat/monotone. Increasing the triangle count to split the blade down the middle for internal curvature would be an obvious step but could be expensive. Using a texture instead could be a cheaper alternative that may solve the problem.

I&#39;m also not 100% satisfied with the wind movement. It&#39;s fairly decent but doesn&#39;t always look naturalistic. More exploration is needed here.

  3.3 **Future Work**

Based on this, these are the areas currently identified for future work:

- Investigate improved aliasing for received shadows
- Investigate issues with cast shadows
- Tie into Unity&#39;s default lighting/shadows settings
- Add option to texture grass blades
- Add a third plant type
- Refine value relationships between plant types (separate value control where needed)
- Investigate options for building a cleaner parameter interface (ability to collapse sections is highly desirable).


### 4 **User&#39;s Guide**

  4.1 **File Setup**

Requires the Universal Render Pipeline (URP), which has to be installed as a package in Unity.

Drop the provided folder containing the shader/files/materials somewhere into the Assets folder for the project. There are three materials present that contain the settings for the previously shown grass examples. It may be necessary to set the shader being used after copying. When the material is selected, in the inspector, if the shader is not set to &quot;Grass Custom&quot;, set it to be so.

  4.2 **Application of Shader**

Drag and drop a material using the grass shader onto a mesh object in the viewer, or into the &quot;Material&quot; field in the mesh renderer for the mesh within the inspector. You could also use that same field to search through all available materials rather than dragging and dropping.

The settings/adjustments for the material/shader are located in the inspector for the material when selected. When applied to a mesh, they can also be found within the mesh filter for that mesh in the inspector.

If you wish to create a new material with different setting for this shader, right click on the shader &quot;GrassShader&quot; and select CreateMaterial. When using a newly created material, it will draw the grass flat against the ground. This happens because no wind map normal has been specified yet. In the inspector for the material, set a texture for the wind map and this will correct itself.

  4.3 **Parameter Controls**
  
  4.3.1 **Color Parameters**

![](RackMultipart20210602-4-iqprec_html_dad369e86b810e83.png)

***Light***

- **Specular Color**: The color of light used for specular highlights.

- **Smoothness**: Focuses the strength of the specular highlights.

***Color***

- **Top Color**: The color used at the tip of live, healthy grass.

- **Bottom Color**: The color used at the base of live, healthy grass.

- **Dead Color Top**: The color used at the tip of dead grass.

- **Dead Color Bottom**: The color used at the base of dead grass.

- **Color Noise Scale**: Adjusts the frequency of the noise map used to determine whether grass located at a particular spot is healthy or dead. Low values will result in gradual, rolling transitions. High values will result in numerous small patches.

- **Color Noise Strength**: Adjusts the amplitude of the noise map. Causes areas of dead grass to grow/shrink. Can effect the saturation and hue of colors if set to extreme values.

4.3.2 **Sizing**

![](RackMultipart20210602-4-iqprec_html_b3e2231108f5881a.png)

***Blade Thickness***

- **Blade Width**: The default width of the grass blades at the base.

- **Blade Width Variance**: The randomization value for the blade width of individual blades. The actual blade width will be set to Blade Width ± random value between 0 and this value.

***Blade Length***

- **Blade Height**: The base height/length of a blade of grass.

- **Blade Height Noise**: Adjusts the frequency of the noise map used to create height variance between areas of grass. Low values will result in gradual, rolling transitions. High values will result in numerous short transitions.

- **Blade Noise Scale**: Adjusts the amplitude of the noise map. Results in noticeable changes in the height of the grass, with larger numbers resulting in larger differences between the high/low areas. Use in combination with the Blade Height value to place the grass at the correct length while creating height variance with the noise map.

- **Blade Height Variance**: The randomization value for the blade height of individual blades. The actual blade height will be set to Blade Height ± random value between 0 and this value.

4.3.3 **Tessellation**

![](RackMultipart20210602-4-iqprec_html_b2851a4d033dc459.png)

***Blade Density***

- **Tessellation Uniform**: Sets the tessellation value for the mesh the shader is attached to. A value of 1 is no tessellation, higher numbers increase tessellation. The higher the tessellation, the denser the placement of grass blades will be. While this value slider shows a float value, the actual tessellation is using integers, so changes will only occur when the whole integer changes (i.e. 5.06 and 5.88 both have a tessellation value of 5).

- **Tessellation Culling**: This is a modifier for the tessellation value that attenuates the amount of tessellation based on the view distance from the viewer. The higher the value, the stronger/nearer the attenuation occurs. If lag due to the number of grass blades is occurring, raising this value can help.

4.3.4 **Wind Map**

![](RackMultipart20210602-4-iqprec_html_5f2521507d12ecad.png)

***Wind Movement***

- **Use Wind Map**: This toggle switches between using the trigonometric wind and the wind map. When it is on (checkmark), it uses the wind map. When it is off (no checkmark), it uses the trigonometric wind.

- **Wind Culling Distance**: Sets a distance from the camera at which the grass no longer simulates animated wind movement. Lower value is nearer the camera, higher value further.

***Trigonometric Wind***

- **Time Adjustment**: This method of wind animation uses the passage of time in its calculation. This slider will adjust that time, essentially resulting in &#39;slow motion&#39; for lower values and &#39;fast forward&#39; for higher values.

- **Wind Strength**: Adjusts how strong the wind is blowing / strength of the bend caused in the grass.

***Wind Map***

- **Wind Map**: The texture is the map used for the wind movement. This has to have a texture set for the grass to draw correctly when the wind map is active.

- **Tiling**: For the purposes of this wind map, this setting has no particular use.

- **Offset**: For the purposes of this wind map, this setting has no particular use.
  _(I should probably hide the Tiling and Offset. There is a tag that can be used within the shader to cause it to do so.)_

- **Wind Frequency**: Adjust the speed at which the movement occurs.

- **Wind Strength**: Adjusts how strong the wind is blowing / strength of the bend caused in the grass.

4.3.5 **Second Plant** – The second plant section is labeled using the &#39;Stem&#39; keyword

![](RackMultipart20210602-4-iqprec_html_f44dba53e54b5d39.png)

- **Stem Placement Noise**: Adjusts the frequency of the noise map used to create height variance between areas of plants. Low values will result in gradual, rolling transitions. High values will result in numerous short transitions.

- **Stem Placement Edge**: Sets a cut-off value which prevents the plant blades that fall below the cut-off from drawing. Use this in tandem with the Stem Placement Noise to cull and control placement of this second plant.

- **Rest of the Parameters**: The rest of the parameters located within the second plant section mirror those of the primary plant.
