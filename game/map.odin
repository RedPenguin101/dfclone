package game

Tile :: struct {
	pos:V3i,
	content : Terrain,
	order_idx:int,
}

Map :: struct {
	dim : V3i,
	tiles : []Tile
}

init_map :: proc(dims:V3i) -> Map {
	m:Map
	m.dim = dims
	m.tiles = make([]Tile, dims.x*dims.y*dims.z)
	return m
}

destroy_map :: proc(m:^Map) {
	delete(m.tiles)
}

INIT_DUMMY_MAP :: proc(m:^Map) {
	for y in 0..<m.dim.y {
		for x in 0..<m.dim.x {
			t := get_map_tile(m, {x,y,0})
			t.content = make_terrain(.Stone_Limestone, .Solid)
			t.pos = {x,y,1}
			if x > 10 {
				t = get_map_tile(m, {x,y,1})
				t.content = make_terrain(.Stone_Limestone, .Solid)
			}
		}
	}
}

get_map_tile :: proc(m:^Map, i:V3i) -> ^Tile {
	dim := m.dim
	z_stride := dim.x * dim.y
	y_stride := dim.x
	return &m.tiles[i.z*z_stride + i.y*y_stride + i.x]
}

mine_tile :: proc(m:^Map, i:V3i) -> Material {
	tile := get_map_tile(m, i)
	assert(tile.content.shape == .Solid)
	tile.content.shape = .Floor
	return tile.content.made_of
}
