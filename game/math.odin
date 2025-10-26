package game

v2_to_v3i :: proc(v:V2, z:=0) -> V3i {
    return {int(v.x), int(v.y), z}
}
