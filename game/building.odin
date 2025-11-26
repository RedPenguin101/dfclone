package game

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
