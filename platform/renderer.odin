package platform

import c "../common"
import "core:strings"
import rl "vendor:raylib"

/*************
 * Rendering *
 *************/

color_to_rl :: proc(c:c.Color) -> rl.Color {
    ret : rl.Color
    ret.r = u8(c.r * 255)
    ret.g = u8(c.g * 255)
    ret.b = u8(c.b * 255)
    ret.a = u8(c.a * 255)
    return ret
}

rect_to_rl :: proc(r:c.Rect) -> rl.Rectangle {
    start := r.xy
    end := r.zw
    dims := end-start
    ret := rl.Rectangle{
        x = min(start.x, end.x),
        y = min(start.y, end.y),
        width = abs(dims.x),
        height = abs(dims.y),
    }
    return ret
}

SCREEN_WIDTH :: 800
SCREEN_HEIGHT :: 640

render :: proc(item:^c.RenderRequest, basis:c.Basis) {
    switch item.type {
    case .Texture: {
        r := item.render.(c.RenderTexture)
        frame_width := r.tex.frame_width
        frame_height := r.tex.frame_height

        row := r.sprite_idx % r.tex.sprites_per_row
        col := r.sprite_idx / r.tex.sprites_per_row

        frame_x_start := row * frame_width
        frame_y_start := col * frame_height

        tex2 := rl.Texture2D{
            id=u32(r.tex.id),
            width=i32(r.tex.width),
            height=i32(r.tex.height),
            mipmaps=i32(r.tex.mipmaps),
            format=rl.PixelFormat(r.tex.format)
        }

        // TODO: Multi-row sprites
        source_rec := rl.Rectangle{f32(frame_x_start),f32(frame_y_start), f32(frame_width), f32(frame_height)}
        dest_rec := rect_to_rl(c.basis_xform_rect(basis, r.dest))
        rl.DrawTexturePro(tex2, source_rec, dest_rec, {0,0}, 0, color_to_rl(r.tint))
    }
    case .TextureRotated: {
        r := item.render.(c.RenderTexture)
        frame_width := r.tex.frame_width
        frame_height := r.tex.frame_height
        tex2 := rl.Texture2D{
            id=u32(r.tex.id),
            width=i32(r.tex.width),
            height=i32(r.tex.height),
            mipmaps=i32(r.tex.mipmaps),
            format=rl.PixelFormat(r.tex.format)
        }

        // TODO: Multi-row sprites
        frame_x_start := r.sprite_idx * frame_width
        source_rec := rl.Rectangle{f32(frame_x_start),0,
                                   f32(frame_width), f32(frame_height)}
        dest_rec := rect_to_rl(c.basis_xform_rect(basis, r.dest))
        // No idea why I need to divide this by 0.8 - something to do with the aspect ratio?
        sprite_center := rl.Vector2{f32(frame_width)/(0.8*2), f32(frame_height)/(0.8*2)}
        rl.DrawTexturePro(tex2, source_rec, dest_rec, sprite_center, r.rotation, color_to_rl(r.tint))
    }
    case .Line: {
        r := item.render.(c.RenderLine)
        from := c.basis_xform_point(basis, r.from)
        to := c.basis_xform_point(basis, r.to)
        width := basis.x.x * r.width
        rl.DrawLineEx(from, to, width, color_to_rl(r.color))
    }
    case .Rectangle: {
        r := item.render.(c.RenderRect)
        rect := r.rect
        r2 := rect_to_rl(c.basis_xform_rect(basis, rect))
        rl.DrawRectangleRec(r2, color_to_rl(r.color))
    }
    case .Triangle: {
        r := item.render.(c.RenderTriangle)
        v1 := c.basis_xform_point(basis, r.a)
        v2 := c.basis_xform_point(basis, r.b)
        v3 := c.basis_xform_point(basis, r.c)

        orient2d :: proc(a,b,c:V2) -> f32 {
            det_left  := (a.y-c.y)*(b.x-c.x)
            det_right := (a.x-c.x)*(b.y-c.y)
            det := det_left-det_right
            return det
        }

        if orient2d(v1,v2,v3) < 0 {
            temp_v := v1
            v1 = v2
            v2 = temp_v
        }

        rl.DrawTriangle(v1,v2,v3, color_to_rl(r.color))
    }
    case .TriangleInRect: {
        r := item.render.(c.RenderRect)
        rect := r.rect
        v1 := V2{rect.x, rect.y}
        v2 := V2{rect.z, rect.y}
        v3 := V2{(rect.z+rect.x)/2, rect.w}
        rl.DrawTriangle(c.basis_xform_point(basis, v1),
                        c.basis_xform_point(basis, v2),
                        c.basis_xform_point(basis, v3),
                        color_to_rl(r.color))
    }
    case .Circle: {
        r := item.render.(c.RenderCircle)
        center_px := c.basis_xform_point(basis, r.center)
        rad := basis.x.x * r.radius
        if r.lines {
            rl.DrawCircleLinesV(center_px, rad, color_to_rl(r.color))
        } else {
            rl.DrawCircleV(center_px, rad, color_to_rl(r.color))
        }
    }
    case .Text: {
        r := item.render.(c.RenderText)
        font : rl.Font
        font = (cast(^rl.Font)r.font)^
        pos := c.basis_xform_point(basis, r.rect.xy)
        max_char_per_line := max_characters_in_space(r.text, font, 20, 2, r.rect.z-r.rect.x)
        line_count := int(f32(len(r.text)) / f32(max_char_per_line))+1
        for l in 0..<line_count {
            from := l*max_char_per_line
            to := min(len(r.text), (1+l)*max_char_per_line)
            cstr := strings.clone_to_cstring(r.text[from:to], context.temp_allocator)
            pos.y += (20*f32(l))
            rl.DrawTextEx(font, cstr, pos, 20, 2, color_to_rl(r.color))
        }
    }
    }
}

/******************
 * Text Utilities *
 ******************/

max_characters_in_space :: proc(text:string, font:rl.Font, font_size, spacing, box_width:f32) -> int {
    cstr := strings.clone_to_cstring(text, context.temp_allocator)
    max_chars := len(text)
    size := rl.MeasureTextEx(font, cstr, font_size, spacing).x
    for size > box_width {
        ratio := size / box_width
        max_chars = int(f32(max_chars) / ratio)
        cstr = strings.clone_to_cstring(text[:max_chars], context.temp_allocator)
        size = rl.MeasureTextEx(font, cstr, font_size, spacing).x

    }

    return max_chars
}
