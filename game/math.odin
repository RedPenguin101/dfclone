package game

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

in_rect :: proc(v:V2,r:Rect) -> bool {
    return v.x > r.x && v.x <= r.z && v.y > r.y && v.y <= r.w
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
