package game

ENTITY_ACTION_FREQ :: 0.2

EntitySuperType :: enum { Null, Creature, Construction, Material }

EntityType :: enum {
    Null,
    Dwarf,
    Stone,
    Wood,
    Tree,
    Workshop,
}

EntityTableEntry :: struct {
    dims:V3i,
    buildable:bool,
    super_type:EntitySuperType,
    action_frequency:f32,
}

ENTITY_TABLE := [EntityType]EntityTableEntry {
        .Null =     { {},      false, .Null,     0 },
        .Dwarf =    { {1,1,1}, false, .Creature, 0.2},
        .Stone =    { {1,1,1}, false, .Material, 0},
        .Wood =     { {1,1,1}, false, .Material, 0},
        .Tree =     { {1,1,1}, false, .Construction, 0},
        .Workshop = { {2,2,1}, true,  .Construction, 0},
}

entity_dims :: proc(type:EntityType) -> V3i {
    #partial switch type {
    case .Null: return {}
    case .Tree: return {1,1,3}
    }
    return {1,1,1}
}

Entity :: struct {
    type : EntityType,
    pos : V3i, // south west lower corner for multi-tile entities
    dim : V3i,
    current_order_idx: int,
    action_ticker : f32,
    deconstruction_percentage: f32,
}

add_entity :: proc(es:^[dynamic]Entity, type:EntityType, pos:V3i) -> int {
    new_entity := Entity{type, pos, entity_dims(type), 0, ENTITY_ACTION_FREQ, 0}
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

E_FREE_STACK : [dynamic]int

remove_entity :: proc(es:^[dynamic]Entity, idx:int) {
    es[idx] = {}
    append(&E_FREE_STACK, idx)
}

deconstruct_entity :: proc(es:^[dynamic]Entity, idx:int) {
    ety := es[idx]
    remove_entity(es, idx)
    if ety.type == .Tree {
        add_entity(es, .Wood, ety.pos)
    }
}

// TODO: Maybe replace this with Odin's Small buffer thing
E_BUFF_SIZE :: 10
E_BUFF : [E_BUFF_SIZE]int

get_entities_at_pos :: proc(es:^[dynamic]Entity, pos:V3i) -> []int {
    idx := 0
    for e, i in es {
        if e.pos == pos {
            E_BUFF[idx] = i
            idx += 1
        }
    }
    return E_BUFF[:idx]
}

