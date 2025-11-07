package game

BuildingType :: enum { Null, Tree, StoneMason }

BuildingStatus :: enum { Null, PendingMaterialAssignment, PendingConstruction, Normal, PendingDeconstruction, }

is_workshop := bit_set[BuildingType] {
    .StoneMason,
}

BuildingPrototype :: struct {
    dims:V3i,
}

B_PROTOS := [BuildingType]BuildingPrototype {
        .Null = {},
        .Tree = {},
        .StoneMason = {{3,3,1}},
}

Building :: struct {
    type : BuildingType,
    status : BuildingStatus,
    deconstruction_percentage: f32,
}

make_tree :: proc() -> Building {
    building := Building{
        type   = .Tree,
        status = .Normal,
    }
    return building
}
