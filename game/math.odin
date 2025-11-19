package game

import "core:math"

abs :: math.abs

V2 :: [2]f32
V3i :: [3]int

v2_to_v3i :: proc(v:V2, z:=0) -> V3i {
    return {int(v.x), int(v.y), z}
}

TileCube :: struct {
    min:V3i,
    max:V3i,
}

tile_cube_from_min_and_dim :: proc(pos,dim:V3i) -> TileCube {
    // TODO: Maybe better checking here - e.g. dim 0 should fail
    return {pos, pos+dim-{1,1,1}}
}

in_cube :: proc(v:V3i, cube:TileCube) -> bool {
    return v.x >= cube.min.x && v.x <= cube.max.x &&
        v.y >= cube.min.y && v.y <= cube.max.y &&
        v.z >= cube.min.z && v.z <= cube.max.z
}

are_adjacent :: proc(a,b:V3i) -> bool {
    return abs(a.x-b.x) <= 1 && abs(a.y-b.y) <= 1 && abs(a.z-b.z) <= 1
}

in_rect :: proc(v:V2i,r:TileRect) -> bool {
    return v.x >= r.x && v.x < r.z && v.y >= r.y && v.y < r.w
}

rect_adjust :: proc(r:TileRect, v:V2i) -> TileRect {
    return TileRect{
        r.x+v.x,
        r.y+v.y,
        r.z+v.x,
        r.w+v.y,
    }
}

rect_dims :: proc(r:TileRect) -> V2i {
	return {r.z-r.x, r.w-r.y}
}

vec_min :: proc(v,w:V3i) -> V3i {
    return {min(v.x,w.x),
            min(v.y,w.y),
            min(v.z,w.z)}
}

vec_max :: proc(v,w:V3i) -> V3i {
    return {max(v.x,w.x),
            max(v.y,w.y),
            max(v.z,w.z)}
}

mh_distance :: proc(v,w:V3i) -> int {
    u := v-w
    return abs(u.x)+abs(u.y)+abs(u.z)
}

get_neighbours :: proc(v:V3i) -> [8]V3i {
	ret : [8]V3i
	ret[0] = v + {-1, -1, 0}
	ret[1] = v + {-1,  0, 0}
	ret[2] = v + {-1,  1, 0}
	ret[3] = v + { 0, -1, 0}
	ret[4] = v + { 0,  1, 0}
	ret[5] = v + { 1, -1, 0}
	ret[6] = v + { 1,  0, 0}
	ret[7] = v + { 1,  1, 0}
	return ret
}

/**************
 * Color Math *
 **************/

hue_to_rbg :: proc()

hsl_to_rgb :: proc(hsl:[3]f32) -> Color {
	hue        := hsl[0]
	saturation := hsl[1]
	lightness  := hsl[2]

	c := (1-abs(2*lightness-1)) * saturation
	m := lightness - c/2

	h_mod := hue / 60
	for h_mod > 2 do h_mod -= 2
	x := c * f32(1 - abs(h_mod-1))

	color : Color

	if hue < 60 {
		color = {c, x, 0, 1}
	} else if hue < 120 {
		color = {x, c, 0, 1}
	}else if hue < 180 {
		color = {0, c, x, 1}
	}else if hue < 240 {
		color = {0, x, c, 1}
	}else if hue < 300 {
		color = {x, 0, c, 1}
	}else if hue < 360 {
		color = {c, 0, x, 1}
	} else do panic("invalid h prime value")

	color += {m,m,m,0}
	return color
}

rbg_to_hsl :: proc(c:Color) -> [3]f32 {
	c_max := max(c.r, c.g, c.b)
	c_min := min(c.r, c.g, c.b)
	chroma := c_max - c_min
	lightness := (c_max+c_min)/2
	saturation : f32

	if lightness == 0 {
		saturation = 0
	} else if lightness <= 0.5 {
		saturation = chroma / (c_max+c_min)
	} else if lightness < 1{
		saturation = chroma / (2-c_max-c_min)
	} else {
		saturation = 0
	}

	hue : f32
	if chroma == 0 {
		hue = 0
	} else if c_max == c.r {
		hue = (c.g-c.b)/chroma
	} else if c_max == c.g {
		hue = (c.b-c.r)/chroma + 2
	} else {
		hue = (c.r-c.g)/chroma + 4
	}
	if hue < 0 do hue += 6
	hue /= 6
	assert(hue >= 0 && hue <= 1)
	hue *= 360

	return {hue, saturation, lightness}
}

change_lightness :: proc(c:Color, percent:f32) -> Color {
	hsl := rbg_to_hsl(c)
	hsl[2] = clamp(hsl[2]*percent, 0, 1)
	return hsl_to_rgb(hsl)
}
