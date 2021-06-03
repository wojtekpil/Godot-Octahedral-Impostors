tool

extends Spatial
# Abstract class for scene bakers

# emitted when Image Atlas is ready to read
signal atlas_ready

#baked atlas image will be read from here after signal
var atlas_image: Image


func get_pivot_translation() -> Vector3:
    return Vector3.ZERO


func set_atlas_image(img: Image) -> void:
    atlas_image = img


func cleanup() -> void:
    pass


func get_camera() -> Camera:
    return null