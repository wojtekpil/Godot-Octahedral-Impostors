
# Godot Octahedral Impostors

Simple implementation of octahedral impostors in Godot. Inspired by [shaderbits article](https://www.shaderbits.com/blog/octahedral-impostors) and this [Unity implementation](https://github.com/xraxra/IMP).
This implementation uses only one plane to imitate a three-dimensional object from multiple angles.

# Installation

Clone git repository:
 > git clone -b v2.0-new-baker --single-branch https://github.com/wojtekpil/Godot-Octahedral-Impostors.git

Or just download a source code zip file and copy addons/octahedral_impostors to your own project.
Go to Project -> Project Settings... -> Plugins and enable "Octahedral Impostors"

# Overview

Features:

- Full & Hemi Sphere mode impostors
- Depth based frame blending
- Paraller baking alghorithm
- Shadow mesh baking
- Dynamic lightning support
- Builtin Light & Standandard (ORM) profiles
- Custom image atlas resolution and frames number
- Image atlas dimmensions size optimalisation for selected maps
- Alpha Cut (Scizzors) or Dither
- Atlas Covarage ratio (WIP)
- Extensible profiles and map baking algorithms
- Atlas texture post dilatation


+ Batch impostor baker:
   - Automatic scene baking & basic LOD using OctaImpostor Node
   - Selective baking
   - Settings per OctaImpostor node ovewrittable in baker window


+ VisualShader Nodes:
   - Create custom shaders using octahedral impostor nodes
   - Additional Atlas Texture Sampling Node


# Texture Baker


The user interface is integrated with the editor. Just select any `GeometryInstance` (MeshInstance, ImmediateGeometry, etc..) and a button called `Octahedral Impostor` will show up. Selecting a node tree with a `GeometryInstance` will also work. CSG nodes aren't supported and would have to be converted. You can also use new batch baking mode described below.


# Bake an asset to impostor


1. Once you're in the baking window, you will have access to the following controls.

   * Atlas Coverage - How much of each atlas tile the geometry will take up. Useful for if you want to add some margin to the tiles.
   * Grid size - A root value of number of images taken from different angles of baked model. 16 is recommended value
   * Atlas resolution - Resolution of atlas images created during baking. Its recommended to use 2048 in most cases.
   * Full sphere - Full sphere allows to use full octahedral sphere for baking. Only useful when the object is visible from below. For standard foliage a hemisphere should be better, because it increase resolution from the side views.
   * Profile - Select baking profile. In case of `Standard` baker will generate additional textures. Use `Light` for better performance.
   * Optimize Size - Some types of textures can be used with lower resolution. This settings decrease VRAM usage at cost of some quality loss.
   * Export with shadow mesh - By default bilboards in Godot suffers from self shadowing problem. This setting generates additional offseted mesh used only for shadows.

2. Click `Generate` and select where you want to save the impostor and its images; preferably inside their own folder. Wait until the progress bar gets to 100%. It should automatically (re)import the generated textures:

   * result_albedo.png
   * result_depth.png
   * result_normal.png
   * (result_orm.png)
   * Any other custom baked map

   Tips:

   * It's recommended to manually check the generated textures for bleeding and other artifacts.
   * Make sure that your 3D editor is running smoothly before baking. The slower the graphics processing, the longer the baking time.


# Shader parameters:

* Albedo, Specular, Roughness, Metallic - standard PBR material parameters, it should be setup similar to baked model
* Imposter Frames - X and Y value should be setup to the same value as in "Grid size" parameter in baking process.
* Position Offset - Offsets image texture from origin. Useful when using with for example, `MultimeshInstances`
* Is Full Sphere - Should be setup to the same value as in "Use full sphere " parameter in baking process
* Alpha Clamp - Minimum alpha value to show. Usufull for a better frames blending
* Dither - Use dithering instead of cuting off alpha channel
* Scale - Scale of impostor
* Depth Scale - Depth texture parallax influence
* Normalmap Depth - Sometimes baked normals are too rough. You can change the influence of light on the impostor here.
* AABB Max - bounding box based impostor offset. Can be increased to fix order and shadow problems.

In a generated shader, sometimes the parameters should be changed to achieve better results.


# Baking Profiles

Its new type of resource storing a list of atlas maps to be baked together with
desired impostor shader & shadow impostor shader. User can create custom profiles
with new map baking scripts (check `/plugins/octahedra_impostors/scripts/baking/maps`) and shader (can be created using provided VisualShader nodes).

# Shaders

There are currently two builtin versions of shaders:

Shader       | Standard         | Light
------------ | ------------- | -------------
Sphere mapping | :heavy_check_mark:        | :heavy_check_mark:
Hemisphere mapping | :heavy_check_mark:        | :heavy_check_mark:
Grid blending  | :heavy_check_mark:        | :heavy_check_mark:
Depth maps  | :heavy_check_mark:        |   :heavy_check_mark:
Shadows  | :heavy_check_mark:*        |    :heavy_check_mark:*
Metallic textures  | :heavy_check_mark:        |   :x:
Roughness textures  | :heavy_check_mark:        |   :x:
AO textures   | :heavy_check_mark:        |   :x:
Alpha cutoff  | :heavy_check_mark:        |   :heavy_check_mark:
Alpha dither  | :heavy_check_mark:        |   :heavy_check_mark:
Mipmaps        | :x:                       | :x:


Custom shaders can be easly added using custom baking profiles.

# Batch baking mode

1. To create scene with automatic impostors LOD system each mesh object (or a group of objects) intented to be baked must be a child of OctaImpostor node.

   Impostor can be configurable in Inpsector Property panel:

   * Baking Profile
   * Atlas Image resolution
   * Imposter Frames
   * Full & Hemi Sphere mode
   * Size atlas optimalisation
   * Shadow mesh generation
   * LOD distance switching between impostor & real gemetry mesh

   Remember to postion the OctaImpostor node on the scene, try to keep child nodes translation close to [0,0,0].

2. After all desired meshes (with OctaImpostor parents) are placed on the scene Go to `Project -> Tools -> Scene Octahedral Impostor Baking`. Select `Settings` tab and choose directory to save all of the generated impostors. Its recommended to select empty directory. You can also overwritte some per impostor settings here.

3. Go back to `QueuedScenes` tab. Select all OctaImpostor nodes you want to bake.
4. Click `Generate` and close baking window after its done.
5. You can experiment with `Lod Distance` settings in each of the OctaImpostor nodes for best results.

