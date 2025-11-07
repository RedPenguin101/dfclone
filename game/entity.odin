package game

EntityType :: enum {
    Null,
    Creature,
    Building,
    Material,
}

Entity :: struct {
    type : EntityType,
    pos : V3i, // south west lower corner for multi-tile entities
    dim : V3i,
    current_order_idx: int,
    action_ticker : f32,
    building:Building,
    material:Material,
    creature:Creature,
}

building_construction_request :: proc(es:^[dynamic]Entity, type:BuildingType, pos:V3i) -> int {
    building := Building{
        type = type,
        status = .PendingMaterialAssignment,
        deconstruction_percentage = 1,
    }
    i := add_entity(es, .Building, pos)
    es[i].building = building
    return i
}

add_entity :: proc(es:^[dynamic]Entity, type:EntityType, pos:V3i) -> int {
    new_entity := Entity{
        type              = type,
        pos               = pos,
        dim               = {1,1,1},
        current_order_idx = 0,
        action_ticker     = 0.2
    }
    free_size := len(E_FREE_STACK)
    idx : int
    if free_size > 0 {
        idx = E_FREE_STACK[free_size-1]
        unordered_remove(&E_FREE_STACK, free_size-1)
        es[idx] = new_entity
    } else {
        idx = len(es)
        append(es, new_entity)

    }
    return idx
}

add_creature :: proc(es:^[dynamic]Entity, type:CreatureType, pos:V3i, name:string) -> int {
    c := Creature{
        type = type,
        name = name,
        task = {},
    }
    i := add_entity(es, .Creature, pos)
    es[i].creature = c
    return i
}

E_FREE_STACK : [dynamic]int

remove_entity :: proc(es:^[dynamic]Entity, idx:int) {
    es[idx] = {}
    append(&E_FREE_STACK, idx)
}

deconstruct_entity :: proc(es:^[dynamic]Entity, idx:int) {
    ety := es[idx]
    remove_entity(es, idx)
    // When the entity is made_of materials, put the made_of materials around the object
    if ety.type == .Building {
        for mat in ety.building.made_of {
            for _ in 0..<mat.quantity {
                i := add_entity(es, .Material, ety.pos)
                new_mat := Material{
                    type = mat.type,
                    form = mat.form,
                    quantity = 1,
                }
                es[i].material = new_mat
            }
        }
    }
}

// TODO: Maybe replace this with Odin's Small buffer thing
E_BUFF_SIZE :: 10
E_BUFF : [E_BUFF_SIZE]int

get_entities_at_pos :: proc(es:^[dynamic]Entity, pos:V3i) -> []int {
    idx := 0
    for e, i in es {
        cube := tile_cube_from_min_and_dim(e.pos, e.dim)
        if in_cube(pos, cube) {
            E_BUFF[idx] = i
            idx += 1
        }
    }
    return E_BUFF[:idx]
}

get_construction_materials :: proc(es:[]Entity) -> []Material {
    mat_map : [MaterialType]int
    for e in es {
        if e.type == .Material {
            mat_map[e.material.type] += 1
        }
    }
    mats := make([dynamic]Material)
    for m in MaterialType {
        q := mat_map[m]
        if q == 0 do continue
        append(&mats, Material{
            type = m,
            form = .Natural,
            quantity = q,
        })
    }
    return mats[:]
}
