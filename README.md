
# Godot Octahedral Impostors

Simple implementation of octahedral impostors in Godot. Inspired by [shaderbits article](https://www.shaderbits.com/blog/octahedral-impostors) and this [Unity implementation](https://github.com/xraxra/IMP). Still work in progress but should be usable. 

I was fed up with poor quality of impostors based on traditional billboards in Godot. This implementation uses only one plane to imitate a three-dimensional object from multiple angles. Tree with 5k vertices vs one plane:

![alt text](/screenshots/rotate.gif?raw=true "Rotate impostors")




![alt text](/screenshots/plane.png?raw=true "Rotate impostors")



# Texture Baker
Camera size parameter is used to setup a distance beetween ray from octahedral sphere and world origin. Please use larger value to prevent texture bleeding. 

Full sphere allows to use full octaherdal sphere for baking. Only useful when the object is visible from below. For standard foliage a hemisphere should be better.

User interface is poor at the moment and some options must be setup from editor. (Like baking image reslution and number of frames)
![alt text](/screenshots/baker.png?raw=true "Rotate impostors")


