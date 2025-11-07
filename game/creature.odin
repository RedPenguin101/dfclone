package game

CreatureType :: enum {
    Dwarf,
}

Creature :: struct {
    type: CreatureType,
    name: string,
    task: Task,
}

TaskType :: enum {
    None,

    Idle,

    MoveMaterialFromLocationToEntity,
    MoveMaterialFromEntityToLocation,

    ConstructBuilding,
    MineTile,
    CutTree,
}

Task :: struct {
    type:TaskType,
    entity_idx_1: int,
    loc_1: V3i,
}
