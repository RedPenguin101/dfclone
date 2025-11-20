package game

ProductionType :: enum { Bed }

AttributeName :: enum {
	SleepIn,
	SitAt,
}

ProductionTemplate :: struct {
	glyph:Glyph,
	made_from:bit_set[MaterialType],
	made_at:bit_set[BuildingType],
	attributes:bit_set[AttributeName]
}

Production :: struct {
	type : ProductionType,
}
