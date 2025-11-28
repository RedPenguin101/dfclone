package game

EntityType :: enum {
	Null,
	Creature,
	Building,
	Material,
	Production,
	Stockpile,
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
	stockpile:Stockpile,
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
	assert(es[idx].in_building == 0)

	in_inv_of := es[idx].in_inventory_of
	if in_inv_of != 0 {
		// remove from inventory of other entity
		inventory := es[in_inv_of].inventory
		remove_from_inventory(&inventory, idx)
	}

	clear(&es[idx].inventory)
	if es[idx].type == .Creature {
		delete(es[idx].creature.path)
		delete(es[idx].creature.name)
	}
	es[idx].type = .Null
	append(&E_FREE_STACK, idx)
}

remove_from_inventory :: proc(inventory:^[dynamic]int, ety_idx:int) {
	for e, i in inventory {
		if e == ety_idx {
			unordered_remove(inventory, i)
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
		if e.in_inventory_of != 0 || e.in_building != 0 do continue
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

get_production_items :: proc(es:[]Entity, types:bit_set[ProductionType]) -> []int {
	mats := make([dynamic]int)
	for e, i in es {
		if e.type == .Production && e.in_building == 0 && e.production.type in types {
			append(&mats, i)
		}
	}
	return mats[:]
}


/**************
 * Production *
 **************/

ProductionType :: enum { Null, Bed, Door }

AttributeName :: enum {
	SleepIn,
	SitAt,
	Openable,
	Placeable,
}

ProductionTemplate :: struct {
	glyph:Glyph,
	made_from: bit_set[MaterialType],
	made_at:   bit_set[BuildingType],
	attributes:bit_set[AttributeName]
}

production_template := [ProductionType]ProductionTemplate {
		.Null = {},
		.Bed = {
				.B, is_wood, {.Carpenter}, {.SleepIn, .Placeable},
		},
		.Door = {
				.D, is_stone, {.StoneMason}, {.Openable, .Placeable},
		}
}

Production :: struct {
	type : ProductionType,
}

add_production_item :: proc(es:^[dynamic]Entity, type:ProductionType, pos:V3i) -> int {
	i := add_entity(es, .Production, pos)
	es[i].production = {type}
	return i
}

/************
 * Creature *
 ************/

CreatureType :: enum {
	Dwarf,
}

Creature :: struct {
	type: CreatureType,
	name: string,
	task: Task,
	path: [dynamic]V3i,
	current_order_idx: int,
	action_ticker : f32,
}

TaskType :: enum {
	None,

	MoveMaterialFromLocationToEntity,
	MoveMaterialFromEntityToLocation,

	ConstructBuilding,
	DeconstructBuilding,
	MineTile,

	ProduceAtWorkshop,
}

// TODO: Maybe change over so building is always IDX1

/*					Idx1			Idx2			Loc				ProdType
MoveMatToEnt		Material		Building		N/A
MovematFromEnt		Material		Building		Target
Construct			Building		N/A				N/A
Deconstruct			Building		N/A				N/A
Mine				N/A				N/A				LocToMine
Produce				Material		Building		N/A				Produce
 */

Task :: struct {
	type:TaskType,
	entity_idx_1: int,
	entity_idx_2: int,
	loc_1: V3i,
	production_type: ProductionType,
}

/************
 * Material *
 ************/

MaterialType :: enum { Nothing, Stone_Limestone, Stone_Magnetite, Wood_Oak }
MaterialForm :: enum { Natural, }

Material :: struct {
    type:MaterialType,
    form:MaterialForm,
    quantity:int,
    earmarked_for_use: bool,
}

// TODO: maybe better to do this with an attribute system
is_wood := bit_set[MaterialType] {
    .Wood_Oak,
}

is_stone := bit_set[MaterialType] {
    .Stone_Limestone, .Stone_Magnetite
}

get_material_in_inventory :: proc(inv:[]Material, type:MaterialType) -> int {
    count := 0
    for m in inv {
        if m.type == type do count += m.quantity
    }
    return count
}

/************
 * Building *
 ************/

BuildingType :: enum { Null, Tree, StoneMason, Carpenter, PlacedProdItem }

BuildingStatus :: enum { Null, PendingMaterialAssignment, PendingConstruction, Normal, PendingDeconstruction, }

is_workshop := bit_set[BuildingType] {
		.StoneMason, .Carpenter,
}

BuildingPrototype :: struct {
    dims:V3i,
	glyphs:[9]Glyph,
}

B_PROTOS := [BuildingType]BuildingPrototype {
        .Null = {},
        .Tree = {},
	    .PlacedProdItem = {{1,1,1},{}},
        .StoneMason = {
			{3,3,1},
			{.EQ, .CDOT, .HAT2 ,
			 .EQ, .CDOT, .EQ,
			 .EQ, .CDOT, .OMEGA,}
		},
        .Carpenter = {
			{3,3,1},
			{.EQ, .CDOT, .TILDE ,
			 .EQ, .CDOT, .PIPE,
			 .EQ, .CDOT, .BRACKET_L,}
		},
}

Building :: struct {
    type : BuildingType,
    status : BuildingStatus,
    deconstruction_percentage: f32,
}

/**************
 * Stockpiles *
 **************/

Stockpile :: struct {
	
}
