package game

v2_to_v3i :: proc(v:V2, z:=0) -> V3i {
    return {int(v.x), int(v.y), z}
}

are_adjacent :: proc(a,b:V3i) -> bool {
    return abs(a.x-b.x) <= 1 && abs(a.y-b.y) <= 1 && abs(a.z-b.z) <= 1
}
