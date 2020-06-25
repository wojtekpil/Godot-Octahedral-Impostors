
# Godot Octahedral Impostors

Simple implementation of octahedral impostors in Godot. Inspired by [shaderbits article](https://www.shaderbits.com/blog/octahedral-impostors) and this [Unity implementation](https://github.com/xraxra/IMP). **Still work in progress** but should be usable.

I was fed up with poor quality of impostors based on traditional billboards in Godot. This implementation uses only one plane to imitate a three-dimensional object from multiple angles. Trees with ~30k vertices vs theirs planes impostors:

![alt text](/screenshots/rotate2.gif?raw=true "Rotate impostors")



This forest (1400 trees) only uses impostors planes:

![alt text](/screenshots/forest.gif?raw=true "Rotate impostors")

Tree with 5k vertices vs one plane:

![alt text](/screenshots/rotate.gif?raw=true "Rotate impostors")


# Shaders

![alt text](/screenshots/quality.png?raw=true "Rotate impostors")

There are currently two versions of shaders:

Shader       | Standard         | Light
------------ | ------------- | -------------
Sphere mapping | :heavy_check_mark:        | :heavy_check_mark:
Hemisphere mapping | :heavy_check_mark:        | :heavy_check_mark:
Grid blending  | :heavy_check_mark:        | :heavy_check_mark:
Depth maps  | :heavy_check_mark:        |   :x:
Shadows  | :heavy_check_mark:        |    :x:
Metallic textures  | :heavy_check_mark:        |   :x:
Roughness textures  | :heavy_check_mark:        |   :x:
Alpha prepass  | :heavy_check_mark:        |   :x:
Vertices*      | 36                        | 12

Vertices count was calculated by the Godot engine in the "Information" table

# Texture Baker




User interface is poor at the moment and some options must be setup from editor. (Like baking image reslution)
![alt text](/screenshots/baker.png?raw=true "Rotate impostors")

# Bake an asset to impostor

1. Open the TestScene.tscn file and replace the asset in ViewportBaking/BakedContainer/ with the model for baking.
2. Run project scene and setup:
   * Camera size - Camera size parameter is used to setup a distance beetween ray from octahedral sphere and world origin. Please use larger value to prevent texture bleeding.  Increase this value until the model fits perfectly into baking window.
   * Grid size - A root value of number of images taken from different angles of baked model. 16 is recommended value
   * Use full sphere - Full sphere allows to use full octaherdal sphere for baking. Only useful when the object is visible from below. For standard foliage a hemisphere should be better, becouse it increase resolution from the side views.
   * Generarte Standard Shader - generates additional textures required by a standard version of a shader. Should be enabled for better quality.
3. Click "Generate" and wait until progress bar shows 100%. Godot should reimport generated textures:
   * result.png
   * result_depth.png
   * result_metallic.png
   * result_normal.png
4. You can preview the result by toggling visibility of "Impostor" object in TestScene.
5. It's recommended to manually check generated textures for bleedeing and other artifacts.
6. For better normal textures its possible to setup custom material (with ALBEDO equal to NORMAL) to an asset and baking it again. (in this case we need to use result.png as normal texture)

# Shader parameters:
* Albedo, Specular, Roughness, Metallic - standard PBR material parameters, it should be setup similar to baked model
* Imposter Frames - X and Y value should be setup to the same value as in "Grid size" parameter in baking process.
* Position Offset - Ofssets image texture from origin. Usefull when using with for example, MultimeshInstances
* Is Full Sphere - Should be setup to the same value as in "Use full sphere " parameter in baking process
* is Transparent - Allow transparancy in impostor
* Scale - Scale of impostor
* Depth Scale - Dept texture influence
* Normalmap Depth - Sometimes baked normals  are too rough. You can change the influence of light on the impostor here.
* Impostor Base Texture, Impostor Normal Texture, Impostor Depth Texture, Impostor Metallic Texture - Ue textures genereted by the baker.