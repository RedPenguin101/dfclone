package game

TerrainShape :: enum { Nothing, Wall, Ramp, Stair, Floor }

Terrain :: struct {
    made_of: Material,
    shape:TerrainShape,
    deconstruction_percentage: f32,
	drops:bool,
}

make_terrain :: proc(material:MaterialType, shape:TerrainShape, drops:=false) -> Terrain {
    terrain := Terrain{
        made_of = Material{
            type = material,
            form = .Natural,
            quantity = 1,
        },
        shape = shape,
		drops = drops,
    }
    return terrain
}
