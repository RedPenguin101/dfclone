package game

TerrainShape :: enum { Nothing, Solid, Ramp, Stair, Floor }

Terrain :: struct {
    made_of: Material,
    shape:TerrainShape,
    deconstruction_percentage: f32,
}

make_terrain :: proc(material:MaterialType, shape:TerrainShape) -> Terrain {
    terrain := Terrain{
        made_of = Material{
            type = material,
            form = .Natural,
            quantity = 1,
        },
        shape = shape,
    }
    return terrain
}
