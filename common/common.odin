package common

V2    :: [2]f32
V3    :: [3]f32
V2i   :: [2]int
V3i   :: [3]int
Rect  :: [4]f32
Color :: [4]f32

PlatformReadFileFn   :: proc(string)-> []u8
PlatformLoadTexFn    :: proc([]Color, int, int)-> Texture
PlatformUnloadTexFn  :: proc(Texture)
PlatformLoadSpriteFn :: proc(path:string, lines:int, frames_per_line:int) -> Texture

PlatformApi :: struct {
    read_file :      PlatformReadFileFn,
    load_texture :   PlatformLoadTexFn,
    load_sprite :    PlatformLoadSpriteFn,
    unload_texture : PlatformUnloadTexFn,
}

ButtonState :: struct {
    is_down: bool,
    was_down: bool,
    frames_down: f32,
}

MouseInput :: struct {
    position : V2,
    lmb : ButtonState,
    rmb : ButtonState,
    mmb : ButtonState,
}

GameInput :: struct {
    mouse : MouseInput,
    pan_left, pan_right, pan_up, pan_down : ButtonState,
    zoom_in, zoom_out : ButtonState,
    cancel: ButtonState,
}
