package game

ENTITY_ACTION_FREQ :: 0.2

EntitySuperType :: enum { Null, Creature, Construction, Material }

super_types := [EntityType]EntitySuperType {
        .Null = .Null,
        .Dwarf = .Creature,
        .Stone = .Material,
        .Wood = .Material,
        .Tree = .Construction,
}

EntityType :: enum {
    Null,
    Dwarf,
    Stone,
    Wood,
    Tree,
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
}

add_entity :: proc(es:^[dynamic]Entity, type:EntityType, pos:V3i) -> int {
    l := len(es)
    append(es, Entity{type, pos, entity_dims(type), 0, ENTITY_ACTION_FREQ})
    return l
}

// TODO: Maybe replace this with Odin's Small buffer thing
E_BUFF_SIZE :: 10
E_BUFF : [E_BUFF_SIZE]^Entity

get_entities_at_pos :: proc(es:^[dynamic]Entity, pos:V3i) -> []^Entity {
    idx := 0
    for &e in es {
        if e.pos == pos {
            E_BUFF[idx] = &e
            idx += 1
        }
    }
    return E_BUFF[:idx]
}
