package game

import "core:math/rand"

Tile :: struct {
	pos:V3i,
	content : Terrain,
	order_idx:int,
	exposed:bool,
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
			drops := rand.float32() < 0.3
			if x > 10 {
				t = get_map_tile(m, {x,y,1})
				t.content = make_terrain(.Stone_Limestone, .Solid, drops)
				if x == 11 do t.exposed = true
			}
		}
	}
}

get_map_tile :: proc(m:^Map, i:V3i) -> ^Tile {
	dim := m.dim
	z_stride := dim.x * dim.y
	y_stride := dim.x
	idx := i.z*z_stride + i.y*y_stride + i.x
	if idx < len(m.tiles)-1 {
		return &m.tiles[idx]
	}
	return nil
}

mine_tile :: proc(m:^Map, i:V3i) -> Material {
	tile := get_map_tile(m, i)
	assert(tile.content.shape == .Solid)
	tile.content.shape = .Floor

	neighbours := get_neighbours(i)

	for n in neighbours {
		get_map_tile(m, n).exposed = true
	}

	return tile.content.made_of
}
