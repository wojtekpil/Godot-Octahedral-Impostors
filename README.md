
# Godot Octahedral Impostors

Simple implementation of octahedral impostors in Godot. Inspired by [shaderbits article](https://www.shaderbits.com/blog/octahedral-impostors) and this [Unity implementation](https://github.com/xraxra/IMP).

**You can watch the video tutorial [here](https://www.youtube.com/watch?v=4YhwXGbbabg).**

I was fed up with poor quality of impostors based on traditional billboards in Godot. This implementation uses only one plane to imitate a three-dimensional object from multiple angles. Trees with ~30k vertices vs theirs planes impostors:

![alt text](/screenshots/rotate2.gif?raw=true "Rotate impostors")



This forest (1400 trees) only uses impostors planes:

![alt text](/screenshots/forest.gif?raw=true "Rotate impostors")

Tree with 5k vertices vs one plane:

![alt text](/screenshots/rotate.gif?raw=true "Rotate impostors")

# Installation

Clone git repository:
 > git clone  --depth 1 https://github.com/wojtekpil/Godot-Octahedral-Impostors.git

Or just download a source code zip file and copy addons/octahedral_impostors to your own project.
Go to Project -> Project Settings... -> Plugins and enable "Octahedral Impostors"


# Shaders

![alt text](/screenshots/quality.png?raw=true "Rotate impostors")

There are currently three versions of shaders:

Shader       | Standard         | Light       | TextureArray
------------ | ------------- | ------------- | -------------
Sphere mapping | :heavy_check_mark:        | :heavy_check_mark: | :heavy_check_mark:
Hemisphere mapping | :heavy_check_mark:        | :heavy_check_mark: | :heavy_check_mark:
Grid blending  | :heavy_check_mark:        | :heavy_check_mark:  | :heavy_check_mark:
Depth maps  | :heavy_check_mark:        |   :x:  | :heavy_check_mark:
Shadows  | :heavy_check_mark:        |    :x:  | :heavy_check_mark:
Metallic textures  | :heavy_check_mark:        |   :x: | :heavy_check_mark:
Roughness textures  | :heavy_check_mark:        |   :x: | :heavy_check_mark:
Alpha prepass  | :heavy_check_mark:        |   :x: | :heavy_check_mark:
Vertices*      | 36                        | 12  | 36
Mipmaps        | :x:                       | :x: | :heavy_check_mark:

Vertices count was calculated by the Godot engine in the "Information" table

# Texture Baker



The user interface is integrated with the editor. Just select any `GeometryInstance` (MeshInstance, ImmediateGeometry, etc..) and a button called `Octahedral Impostor` will show up. Selecting a node tree with a `GeometryInstance` will also work. CSG nodes aren't supported and would have to be converted. When the button's pressed, the following window will popup.
![alt text](/screenshots/baker.png?raw=true "Baker")

# Bake an asset to impostor

![alt text](/screenshots/baking.gif?raw=true "Baking giff")

1. Once you're in the window, you will have access to the following controls.

   * Atlas Coverage - How much of each atlas tile the geometry will take up. Useful for if you want to add some margin to the tiles.
   * Grid size - A root value of number of images taken from different angles of baked model. 16 is recommended value
   * Full sphere - Full sphere allows to use full octahedral sphere for baking. Only useful when the object is visible from below. For standard foliage a hemisphere should be better, because it increase resolution from the side views.
   * Shader Type - Select shader type to generete. In case of `Standard` or `TextureArray` baker will generate additional textures. Use `Light` for better performance.

2. Click `Generate` and select where you want to save the impostor and its images; preferably inside their own folder. Wait until the progress bar gets to 100%. It should automatically (re)import the generated textures:

   * base.png
   * norm_depth.png
   * orm.png

   Tips:

   * It's recommended to manually check the generated textures for bleeding and other artifacts.
   * Make sure that your 3D editor is running smoothly before baking. The slower the graphics processing, the longer the baking time.

3. For better normal textures its possible to setup custom material (with ALBEDO equal to NORMAL) to an asset and baking it again. (in this case we need to use result.png as normal texture)

# Shader parameters:

* Albedo, Specular, Roughness, Metallic - standard PBR material parameters, it should be setup similar to baked model
* Imposter Frames - X and Y value should be setup to the same value as in "Grid size" parameter in baking process.
* Position Offset - Offsets image texture from origin. Useful when using with for example, `MultimeshInstances`
* Is Full Sphere - Should be setup to the same value as in "Use full sphere " parameter in baking process
* Is Transparent - Allow transparency in impostor
* Alpha Clamp - Minimum alpha value to show. Usufull for a better frames blending
* Scale - Scale of impostor
* Depth Scale - Depth texture influence
* Normalmap Depth - Sometimes baked normals are too rough. You can change the influence of light on the impostor here.
* Impostor Base Texture, Impostor Normal Texture, Impostor ORM Texture - Use the textures generated by the baker.

In a generated shader, sometimes the parameters aren't changed properly, so you'll need to change them manually.
