package game

EntityType :: enum {
	Null,
	Creature,
	Building,
	Material,
	Production,
}

Entity :: struct {
	type : EntityType,
	in_inventory_of:int,
	in_building:int,
	pos : V3i, // NOTE: south west lower corner for multi-tile entities
	dim : V3i,
	building:Building,
	material:Material,
	creature:Creature,
	production:Production,
	inventory:[dynamic]int,
}

building_construction_request :: proc(es:^[dynamic]Entity, type:BuildingType, pos:V3i) -> int {
	building := Building{
		type = type,
		status = .PendingMaterialAssignment,
		deconstruction_percentage = 1,
	}
	i := add_entity(es, .Building, pos)
	es[i].building = building
	es[i].dim = B_PROTOS[type].dims
	return i
}

add_entity :: proc(es:^[dynamic]Entity, type:EntityType, pos:V3i) -> int {
	new_entity := Entity{
		type              = type,
		pos               = pos,
		dim               = {1,1,1},
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
		action_ticker = 0.2
	}
	i := add_entity(es, .Creature, pos)
	es[i].creature = c
	return i
}

add_tree :: proc(es:^[dynamic]Entity, mat:MaterialType, pos:V3i, height:int) -> int {
	i := add_entity(es, .Building, pos)
	es[i].building = {.Tree, .Normal, 0}

	for idx in 0..<height {
		j := add_entity(es, .Material, pos+{0,0,idx})
		es[j].material.type = mat
		es[j].material.form = .Natural
		es[j].in_building = i
		append(&es[i].inventory, j)
	}

	return i
}

E_FREE_STACK : [dynamic]int

remove_entity :: proc(es:^[dynamic]Entity, idx:int) {
	clear(&es[idx].inventory)
	if es[idx].type == .Creature {
		delete(es[idx].creature.path)
		delete(es[idx].creature.name)
	}
	es[idx].type = .Null
	append(&E_FREE_STACK, idx)
}

remove_from_inventory :: proc(es:^[dynamic]int, ety_idx:int) {
	for e, i in es {
		if e == ety_idx {
			unordered_remove(es, i)
		}
	}
}

deconstruct_entity :: proc(es:^[dynamic]Entity, idx:int) {
	ety := es[idx]
	remove_entity(es, idx)
	// When the entity is made_of materials, put the made_of materials around the object
	if ety.type == .Building {
		for inv_idx in ety.inventory {
			inv := &es[inv_idx]
			inv.in_inventory_of = 0
			inv.in_building = 0
			inv.pos = ety.pos
		}
	}
}

// TODO: Maybe replace this with Odin's Small buffer thing
E_BUFF_SIZE :: 10
E_BUFF : [E_BUFF_SIZE]int

get_entities_at_pos :: proc(es:^[dynamic]Entity, pos:V3i) -> []int {
	idx := 0
	for e, i in es {
		if idx >= E_BUFF_SIZE do break
		cube := tile_cube_from_min_and_dim(e.pos, e.dim)
		if in_cube(pos, cube) {
			E_BUFF[idx] = i
			idx += 1
		}
	}
	return E_BUFF[:idx]
}

get_construction_materials :: proc(es:[]Entity) -> []int {
	mats := make([dynamic]int)
	for e, i in es {
		if e.type == .Material && e.in_inventory_of == 0 && e.in_building == 0 {
			append(&mats, i)
		}
	}
	return mats[:]
}
