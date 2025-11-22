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
