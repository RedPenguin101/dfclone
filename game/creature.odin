package game

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
}

Task :: struct {
	type:TaskType,
	entity_idx_1: int,
	entity_idx_2: int,
	loc_1: V3i,
}
