package game

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
