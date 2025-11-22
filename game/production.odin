package game

ProductionType :: enum { Bed, Door }

AttributeName :: enum {
	SleepIn,
	SitAt,
	Openable,
}

ProductionTemplate :: struct {
	glyph:Glyph,
	made_from: bit_set[MaterialType],
	made_at:   bit_set[BuildingType],
	attributes:bit_set[AttributeName]
}

production_template := [ProductionType]ProductionTemplate {
		.Bed = {
				.B, is_wood, {.Carpenter}, {.SleepIn},
		},
		.Door = {
				.D, is_stone, {.StoneMason}, {.Openable},
		}
}

Production :: struct {
	type : ProductionType,
}
