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
    made_of: [3]Material,
    deconstruction_percentage: f32,
}

make_tree :: proc(mat:MaterialType) -> Building {
    assert(mat in is_wood)
    mat := Material{
        type = .Wood_Oak,
        form = .Natural,
        quantity = 3,
    }
    building := Building{
        type   = .Tree,
        status = .Normal,
    }
    building.made_of[0] = mat
    return building
}
