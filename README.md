
# Godot Octahedral Impostors

Simple implementation of octahedral impostors in Godot. Inspired by [shaderbits article](https://www.shaderbits.com/blog/octahedral-impostors) and this [Unity implementation](https://github.com/xraxra/IMP). Still work in progress but should be usable. 

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
Alpha prepass  | :heavy_check_mark:        |   :x:
Vertices*      | 36                        | 12

Vertices count was calculated by the Godot engine in the "Information" table

# Texture Baker
Camera size parameter is used to setup a distance beetween ray from octahedral sphere and world origin. Please use larger value to prevent texture bleeding. 

Full sphere allows to use full octaherdal sphere for baking. Only useful when the object is visible from below. For standard foliage a hemisphere should be better.

User interface is poor at the moment and some options must be setup from editor. (Like baking image reslution)
![alt text](/screenshots/baker.png?raw=true "Rotate impostors")


