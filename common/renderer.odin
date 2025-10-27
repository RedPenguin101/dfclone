package common

import la "core:math/linalg"
dot :: la.dot

Texture :: struct {
    id:      uint,
    width:   int,
    height:  int,
    mipmaps: int,
    format:  int,
    frame_width, frame_height:int,
}

Basis :: struct {
    origin,x,y:V2
}

basis_xform_point :: proc(b:Basis, v:V2) -> V2 {
    v_b := -b.origin + V2{dot(v, b.x), dot(v, b.y)}
    return v_b
}

basis_scale_number :: proc(b:Basis, n:f32) -> f32 {
    return n * b.x.x
}

basis_xform_rect :: proc(b:Basis, r:Rect) -> Rect {
    start := basis_xform_point(b, r.xy)
    end := basis_xform_point(b, r.zw)
    return {start.x, start.y, end.x, end.y}
}

RenderType :: enum {
    Rectangle, Circle, TriangleInRect, Text, Line, Texture, TextureRotated,
    Triangle,
}

RenderTriangle :: struct {
    a,b,c:V2,
    color:Color,
}

RenderRect :: struct {
    rect : Rect,
    color : Color,
}

queue_rect :: proc(r:^Renderer, rect:Rect, color:Color) {
    append(&r.queue, RenderRequest{.Rectangle, RenderRect{rect, color}, r.current_basis})
}

RenderCircle :: struct {
    center : V2,
    radius : f32,
    color : Color,
    lines: bool,
}

queue_circle :: proc(r:^Renderer, center:V2, radius:f32, color:Color) {
    append(&r.queue, RenderRequest{.Circle, RenderCircle{center, radius, color, false}, r.current_basis})
}

RenderText :: struct {
    text:string,
    font:rawptr,
    rect:Rect,
    color:Color,
}

queue_text :: proc(r:^Renderer, text:string, font:rawptr, rect:Rect, color:Color) {
    append(&r.queue, RenderRequest{.Text, RenderText{text, font, rect, color}, r.current_basis})
}

RenderLine :: struct {
    from,to:V2,
    width:f32,
    color:Color,
}

RenderTexture :: struct {
    dest:Rect,
    tex:Texture,
    sprite_idx:int,
    tint:Color,
    rotation:f32,
}

RenderRequest :: struct {
    type : RenderType,
    render : union {
        RenderRect,
        RenderText,
        RenderCircle,
        RenderTriangle,
        RenderLine,
        RenderTexture,
    },
    basis:RenderBasisName
}

RenderBasisName :: enum {screen, menus}

Renderer :: struct {
    queue : [dynamic]RenderRequest,
    current_basis : RenderBasisName,
    bases : [RenderBasisName]Basis,
}
