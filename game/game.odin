package game

import "../common"
import "core:fmt"
import "core:log"

DBG :: log.debug
INFO :: log.info

GameInput :: common.GameInput
ButtonState :: common.ButtonState
Color :: common.Color
COLS :: common.COLS
ROWS :: common.ROWS
Glyph :: common.DisplayGlyph

TEMP_MOVE_COST :: 0.1
TEMP_BUILD_COST :: 0.1
TEMP_MINE_COST :: 0.1

/******************
 * SEC: Constants *
 ******************/

NONE :: -1
map_start :: 0.0
tile_size :: 0.04

/* Colors */

black := Color{0,0,0,1}
white := Color{1,1,1,1}
red   := Color{1,0,0,1}
green := Color{122.0/255,226.0/255,125.0/255,1}
blue  := Color{0,0,1,1}
yellow := Color{1,1,0,1}
grey := Color{0.3,0.3,0.3,1}
pink  := Color{ 1, 109.0/255, 194.0/255, 1 }

stone_grey := Color{0.6,0.6,0.6,1}
tree_brown := Color{0.7608, 0.4431, 0.1294, 1}

/**************************
 * SEC: Gamestate structs *
 **************************/

plot_tile : common.PlatformPlotTileFn

pressed :: proc(b:ButtonState) -> bool {return b.is_down && !b.was_down}
held :: proc(b:ButtonState) -> bool {return b.repeat > 30}
pressed_or_held :: proc(b:ButtonState) -> bool {return pressed(b) || held(b)}

V2i :: [2]int
TileRect :: [4]int

Camera :: struct {
	focus  : V3i,
	dims   : V3i,
}


Basis :: struct {
    origin,x,y:V2i
}

dot :: proc(v,w:V2i) -> int {
	return v.x*w.x + v.y*w.y
}

basis_xform_point :: proc(b:Basis, v:V2i) -> V2i {
    v_b := -b.origin + V2i{dot(v, b.x), dot(v, b.y)}
    return v_b
}

camera_xform :: proc(cam:Camera, tile:V3i) -> (on_screen:bool, screen_tile:V2i) {
	// takes a map tile location and transforms it the screen tile location
	if tile.z != cam.focus.z do return false, {}

	rect := tile_rect_from_center_and_dim(cam.focus.xy, cam.dims.xy)

	if !in_rect(tile.xy, rect) do return false, {}

	camera_basis := Basis{
		origin = {rect.x, -rect.w},
		x = {1, 0},
		y = {0, -1}
	}

	xformed_tile := basis_xform_point(camera_basis, tile.xy)

	if !in_rect(xformed_tile, {0,0,COLS,ROWS}) do return false, {}
	return true, xformed_tile
}

map_xform :: proc(cam:Camera, tile:V2i) -> V3i {
	rect := tile_rect_from_center_and_dim(cam.focus.xy, cam.dims.xy)

	map_basis := Basis{
		origin = -rect.xw,
		x = {1, 0},
		y = {0, -1}
	}

	xformed_tile := basis_xform_point(map_basis, tile)

	xformed_tile3 := V3i{xformed_tile.x, xformed_tile.y, cam.focus.z}

	return xformed_tile3
}

InteractionMode :: enum {
	Map, Mine, CutTrees, Build, EntityInteract, Stockpile,
}

GameState :: struct {
	m:Map,
	e:[dynamic]Entity,
	oq:OrderQueue,

	cam:Camera,
	hovered_tile:V3i,
	menus:MenuState,

	interaction_mode:InteractionMode,
	im_building_selection:BuildingType,
	im_selected_entity_idx:int,
	im_toggle:bool,
	im_ref_pos:V3i,
	im_temp_entity_buffer:[]int,
}

GameMemory :: struct {
	game_state : GameState,
	initialized : bool,
	platform : common.PlatformAPI,
}

/********************
 * Render Utilities *
 ********************/

write_string_to_screen :: proc(loc:V2i, str:string, text_col, bg_col:Color) {
	for x in 0..<len(str) {
		plot_loc := loc+{x, 0}
		if !in_rect(plot_loc, {0,0,COLS, ROWS}) do continue
		rune := str[x]
		glyph := Glyph(int(rune))
		plot_tile(plot_loc, text_col, bg_col, glyph)
	}
}


/**********************
 * Game API functions *
 **********************/

@(export)
game_state_init :: proc(platform_api:common.PlatformAPI) -> rawptr {
	game_memory := new(GameMemory)
	game_memory.platform = platform_api
	plot_tile = platform_api.plot_tile
	return game_memory
}

@(export)
reinit :: proc(platform_api:common.PlatformAPI) {
	plot_tile = platform_api.plot_tile
}

/* SEC: GS Destroy */

@(export)
game_state_destroy :: proc(memory:^GameMemory) {
	destroy_map(&memory.game_state.m)
	destroy_order_queue(&memory.game_state.oq)
	tear_down_menus(&memory.game_state.menus)

	for e in memory.game_state.e {
		delete(e.inventory)
		if e.type == .Creature {
			delete(e.creature.path)
			delete(e.creature.name)
		}
	}

	delete(memory.game_state.e)
	delete(E_FREE_STACK)
	delete(ME_FREE_STACK)

	free(memory)
}

@(export)
game_update :: proc(time_delta:f32, memory:^GameMemory, input:GameInput) -> bool {

/**************
 * LOOP LOCAL *
 **************/

	s := &memory.game_state
	m := &s.m
	entities := &s.e
	order_queue := &s.oq

/*****************
 * SEC: MEM INIT *
 *****************/

	if !memory.initialized {
		// NULL entries
		add_entity(entities, .Null, {0,0,0})
		add_order(&s.oq, .Null, {})

		s.cam.focus = {5,10,1}
		s.cam.dims  = {COLS, ROWS, 1}

		s.m = init_map({20, 20, 3})
		INIT_DUMMY_MAP(&s.m)

		add_creature(entities, .Dwarf, {5, 10, 1}, fmt.aprint("Iton"))

		add_tree(entities, .Wood_Oak, {4,4,1}, 3)

		t := add_entity(entities, .Material, {9, 4, 1})
		entities[t].material = {
			type = .Stone_Limestone,
			form = .Natural,
			quantity = 1,
			earmarked_for_use = false
		}

		t = add_entity(entities, .Material, {9, 5, 1})
		entities[t].material = Material{
			type = .Stone_Magnetite,
			form = .Natural,
			quantity = 1,
			earmarked_for_use = false
		}

		t = add_entity(entities, .Material, {9, 6, 1})
		entities[t].material = Material{
			type = .Wood_Oak,
			form = .Natural,
			quantity = 1,
			earmarked_for_use = false
		}

		add_order(order_queue, .Produce, idx = int(ProductionType.Bed), count=25)
		add_order(order_queue, .Produce, idx = int(ProductionType.Door), count=10)

		setup_menus(&s.menus)
		memory.initialized = true
	}

	dbg_dwarf := &entities[1]

	// clear screen
	for col in 0..<common.COLS {
		for row in 0..<common.ROWS {
			plot_tile({col, row}, black, black, .BLANK)
		}
	}

/***********************
 * SEC: INPUT HANDLING *
 ***********************/

	s.hovered_tile = map_xform(s.cam, input.mouse.tile)
	lmb := pressed(input.mouse.lmb)
	rmb := pressed(input.mouse.rmb)

	// SEC: Keyboard

	{
		if pressed(input.keyboard[.UP])    do s.cam.focus.y += 1
		if pressed(input.keyboard[.DOWN])  do s.cam.focus.y -= 1
		if pressed(input.keyboard[.LEFT])  do s.cam.focus.x -= 1
		if pressed(input.keyboard[.RIGHT]) do s.cam.focus.x += 1
	}

/*******************
 * SEC: DRAW MAP *
 *******************/

	{
		z_level := s.cam.focus.z

		for y in 0..<m.dim.y {
			for x in 0..<m.dim.x {
				tile := get_map_tile(m, {x,y,z_level})
				fg,bg:Color
				glyph:Glyph
				if tile.order_idx > 0 {
					glyph = .SIG
					fg = yellow
					bg = grey
				} else if tile.content.shape == .Wall {
					if tile.exposed {
						bg = stone_grey
						fg = Color{136.0/255,136.0/255,61.0/255,1}
						glyph = .PERCENT
					}
				} else {
					fg = green
					glyph = .D_QUOTE
				}
				visible, screen_tile := camera_xform(s.cam, {x,y,z_level})
				if visible {
					plot_tile(screen_tile, fg, bg, glyph)
				}
			}
		}
	}

/********************
 * SEC: Entity Loop *
 ********************/

	has_creature := make([]bool, COLS*ROWS, context.temp_allocator)

	for &e, my_idx in entities {
		type := e.type
		if type == .Creature {
			e.creature.action_ticker += time_delta
			e.creature.action_ticker = min(e.creature.action_ticker, time_delta)
			MAX_ITS :: 10
			its := 0
			for e.creature.action_ticker > 0 && its < MAX_ITS {
				its += 1
				/* SEC: Creature Pickup Order */
				if e.creature.current_order_idx == 0 {
					i, o := get_unassigned_order(order_queue)
					if i > 0 {
						e.creature.current_order_idx = i
						INFO("Picked up order", o.type, o.pos)
						o.status = .Assigned
						o.assigned_creature_idx = my_idx
					}
				}

				/* SEC: Creature Decide new task */
				switch e.creature.task.type {
				case .None:  {
					order := &order_queue.orders[e.creature.current_order_idx]
					switch order.type {
					case .Null: {
						// NOTE: Nothing to do, quit out of loop
						e.creature.action_ticker = 0
						continue
					}
					case .Mine: {
						reachable := find_path(&s.m, e.pos, order.pos, &e.creature.path)
						if reachable
						{
							e.creature.task.type = .MineTile
							e.creature.task.loc_1 = order.pos
							DBG("task assign", e.creature.task.type, e.creature.task.loc_1)
						}
						else
						{
							INFO("Can't reach mining location, looking for another job")
							e.creature.current_order_idx = 0
							order.status = .Suspended
						}
					}
					case .CutTree, .Deconstruct: {
						building := entities[order.target_idx]
						reachable := find_path(&s.m, e.pos, building.pos, &e.creature.path)
						if reachable
						{
							e.creature.task.type = .DeconstructBuilding
							e.creature.task.entity_idx_1 = order.target_idx
							DBG("task assign", e.creature.task.type, e.creature.task.loc_1)
						}
						else
						{
							e.creature.current_order_idx = 0
							order.status = .Suspended
							INFO("Can't reach deconstruction location, looking for another job")
						}
					}
					case .Produce: {}
					case .Construct: {
						b_idx := order.target_idx
						b := &entities[b_idx]
						switch b.building.status {
						case .Null, .PendingMaterialAssignment: panic("unreachable")
						case .PendingConstruction: {
							// TODO: Extend to buildings with multiple objects in construction
							mat_idx := b.inventory[0]
							mat := entities[mat_idx]
							if mat.in_inventory_of == b_idx {
								e.creature.task.type = .ConstructBuilding
								e.creature.task.entity_idx_1 = b_idx
							} else {
								reachable := find_path(&s.m, e.pos, mat.pos, &e.creature.path)
								if reachable
								{
									e.creature.task.type = .MoveMaterialFromLocationToEntity
									e.creature.task.entity_idx_1 = mat_idx
									e.creature.task.entity_idx_2 = b_idx
									DBG("task assign", e.creature.task.type)
								}
								else
								{
									e.creature.current_order_idx = 0
									order.status = .Suspended
									INFO("Can't reach material location, looking for another order")
								}
							}
						}
						case .Normal: {
							// TODO: if building status is Normal, finish the order
						}
						case .PendingDeconstruction: {
							// TODO: If building has been changed to pending decontruction, finish the task and complete the order
						}
						}
					}
					}
				}
					/* SEC: Creature Execute Task */
				case .MineTile: {
					target_pos := e.creature.task.loc_1
					if !are_adjacent(e.pos, target_pos) {
						e.pos = pop(&e.creature.path)
						e.creature.action_ticker -= TEMP_MOVE_COST
					} else {
						mat := mine_tile(m, target_pos)
						e.creature.action_ticker -= TEMP_MINE_COST
						DBG("Finished mining", target_pos)
						complete_order(order_queue, e.creature.current_order_idx)
						e.creature.current_order_idx = 0
						tile := get_map_tile(m, target_pos)
						tile.order_idx = 0
						if tile.content.drops {
							i := add_entity(entities, .Material, target_pos)
							entities[i].material = mat
						}
						e.creature.task.type = .None
						assert(e.creature.task.type == dbg_dwarf.creature.task.type)
						make_suspended_mine_orders_available(order_queue)
					}
				}
				case .DeconstructBuilding:{
					b_idx := e.creature.task.entity_idx_1
					building := &entities[b_idx]
					target_pos := building.pos
					if !are_adjacent(e.pos, target_pos) {
						e.pos = pop(&e.creature.path)
						e.creature.action_ticker -= TEMP_MOVE_COST
					} else {
						building.building.deconstruction_percentage += 0.2
						e.creature.action_ticker -= TEMP_BUILD_COST
						if building.building.deconstruction_percentage > 1 {
							DBG("Finished deconstructing", target_pos)
							for material_index in building.inventory {
								entities[material_index].in_inventory_of = 0
								entities[material_index].in_building = 0
								entities[material_index].pos = building.pos
							}
							remove_entity(entities, b_idx)

							complete_order(order_queue, e.creature.current_order_idx)
							e.creature.current_order_idx = 0
							get_map_tile(m, building.pos).order_idx = 0
							e.creature.task = {}
						}
					}
				}
				case .MoveMaterialFromEntityToLocation: panic("unimplemented")
				case .ConstructBuilding: {
					b_idx := e.creature.task.entity_idx_1
					building := &entities[b_idx]
					target_pos := building.pos
					if !are_adjacent(e.pos, target_pos) {
						e.pos = pop(&e.creature.path)
						e.creature.action_ticker -= TEMP_MOVE_COST
					} else {
						building.building.deconstruction_percentage -= 0.2
						e.creature.action_ticker -= TEMP_BUILD_COST
						if building.building.deconstruction_percentage < 0 {
							DBG("Finished constructing", target_pos)
							building.building.deconstruction_percentage = 0
							building.building.status = .Normal
							for m_idx in building.inventory {
								entities[m_idx].in_building = b_idx
							}

							complete_order(order_queue, e.creature.current_order_idx)
							e.creature.current_order_idx = 0
							get_map_tile(m, building.pos).order_idx = 0
							e.creature.task = {}
						}
					}

				}
				case .MoveMaterialFromLocationToEntity: {
					mat_idx := e.creature.task.entity_idx_1
					ety_idx := e.creature.task.entity_idx_2
					mat := &entities[mat_idx]
					ety := &entities[ety_idx]
					target_pos : V3i
					picking_up := false
					if mat.in_inventory_of == my_idx {
						target_pos = ety.pos
					} else if mat.in_inventory_of == 0 {
						picking_up = true
						target_pos = mat.pos
					} else do panic("unreachable")

					if !are_adjacent(e.pos, target_pos) {
						e.pos = pop(&e.creature.path)
						e.creature.action_ticker -= TEMP_MOVE_COST
					} else {
						if picking_up {
							reachable := find_path(&s.m, e.pos, ety.pos, &e.creature.path)
							if reachable
							{
								e.creature.action_ticker -= TEMP_MOVE_COST
								append(&e.inventory, mat_idx)
								mat.in_inventory_of = my_idx
								DBG("Task step completed", e.creature.task.type)
							}
							else
							{
								order_queue.orders[e.creature.current_order_idx].status = .Suspended
								e.creature.current_order_idx = 0
								INFO("Can't reach construction location, looking for another job")
								e.creature.task.type = .None
							}
						} else {
							DBG("Task completed", e.creature.task.type)
							e.creature.action_ticker -= TEMP_MOVE_COST
							remove_from_inventory(&e.inventory, mat_idx)
							mat.in_inventory_of = ety_idx
							append(&ety.inventory, mat_idx)
							e.creature.task.type = .None
						}
					}
				}
				}
			}
		}

		/* SEC: Entity Render */
		if e.pos.z == s.cam.focus.z {
			switch e.type {
			case .Null: {}
			case .Production: {}
			case .Creature: {
				visible, screen_tile := camera_xform(s.cam, e.pos)
				if visible {
					plot_tile(screen_tile, white, black, .AT)
					has_creature[screen_tile.x + (screen_tile.y * COLS)] = true
				}
			}
			case .Building: {
				if e.building.type == .Tree {
					visible, screen_tile := camera_xform(s.cam, e.pos)
					if visible && !has_creature[screen_tile.x + (screen_tile.y * COLS)] {
						plot_tile(screen_tile, white, black, .O)
					}
				} else if e.building.type in is_workshop {
					background := black
					fg1 := white
					fg2 := Color{1, 186.0/255, 0, 1}

					if e.building.status == .PendingMaterialAssignment || e.building.status == .PendingConstruction {
						alpha := 1-(e.building.deconstruction_percentage/2)
						fg1 = change_lightness(fg1, alpha)
						fg2 = change_lightness(fg2, alpha)
					}

					offset := [9]V3i{{0,2,0},{1,2,0},{2,2,0},
									 {0,1,0},{1,1,0},{2,1,0},
									 {0,0,0},{1,0,0},{2,0,0}}
					glyphs := B_PROTOS[e.building.type].glyphs
					for o, i in offset {
						tile := e.pos + o
						fg := fg2 if o.xy == {2,2} else fg1
						visible, screen_tile := camera_xform(s.cam, tile)
						if visible && !has_creature[screen_tile.x + (screen_tile.y * COLS)] {
							plot_tile(screen_tile, fg, background, glyphs[i])
						}
					}
				}
			}
			case .Material: {
				if e.in_inventory_of == 0 && e.in_building == 0 {
					visible, screen_tile := camera_xform(s.cam, e.pos)
					if visible && !has_creature[screen_tile.x + (screen_tile.y * COLS)] {
						color := tree_brown if e.material.type in is_wood else stone_grey
						plot_tile(screen_tile, color, black, .M)
					}
				}
			}

			}
		}
	}

/**************
 * SEC: Menus *
 **************/

	{
		// NOTE: Maybe make this into a bitset
		rebuild_work_order_menu := false

		hot = NULL_UIID
		for &element in s.menus.elements {
			id := element.id
			el_idx := element.id.element_idx
			// TODO: ID Should just store the menu index?
			menu_name := MenuName(id.menu_idx)
			menu := &s.menus.menus[menu_name]
			if !menu.visible do continue
			rect := rect_adjust(element.rect, menu.rect.xy)
			switch element.type {
			case .Null: {}
			case .Button: {
				if do_button(id, input.mouse, rect, element.text, element.state == .Depressed) {
					switch menu_name {
					case .Null: {}
					case .MainBar: {
						if element.state == .None {
							null_menu_state(&s.menus)
							element.state = .Depressed
							s.interaction_mode = InteractionMode(id.element_idx+1)
							if element.submenu != .Null {
								switch element.submenu {
								case .Null, .MainBar, .BuildingSelector, .MaterialSelection, .EntityMenu, .AddWorkOrderMenu: {}
								case .WorkOrderMenu: {
									s.im_temp_entity_buffer = populate_order_menu(&s.menus, order_queue)
								}
								}
								s.menus.menus[element.submenu].visible = true
							}
						} else if element.state == .Depressed {
							// Deactivate the related interaction mode
							null_menu_state(&s.menus)
							s.interaction_mode = .Map
						}
					}
					case .BuildingSelector: {
						if el_idx == len(menu.element_idx)-1 {
							// CLOSE
							s.interaction_mode = .Map
							menu.visible = false
							s.im_building_selection = .Null
							for other_idx in 0..<len(s.menus.menus[.MainBar].element_idx) {
								get_element_by_menu_idx(&s.menus, .MainBar, other_idx).state = .None
							}
						} else {
							if element.state == .Depressed {
								s.im_building_selection = .Null
								element.state = .None
							} else {
								i := -1
								c := -1
								for btype in BuildingType {
									if btype in is_workshop do i+=1
									c += 1
									if i == el_idx do break
								}
								s.im_building_selection = BuildingType(c)
								s.menus.menus[.BuildingSelector].visible = false
								s.interaction_mode = .Build
							}
						}
					}
					case .MaterialSelection: {
						if el_idx == len(s.im_temp_entity_buffer) {
							// cancel
							delete(s.im_temp_entity_buffer)
							clear_menu(&s.menus, .MaterialSelection)
							s.interaction_mode = .Map
							null_menu_state(&s.menus)
							remove_entity(entities, s.im_selected_entity_idx)
							s.im_selected_entity_idx = 0
						} else {
							e_idx := s.im_selected_entity_idx
							e := &entities[e_idx]
							e.building.status = .PendingConstruction
							mat_idx := s.im_temp_entity_buffer[el_idx]
							// NOTE: Doesn't actually put the mat in the inv, just a 'placeholder'
							// for indicating that the material needs to be fetched to construct the building.
							// This is possible a silly idea
							append(&e.inventory, mat_idx)
							add_order(order_queue, .Construct, e.pos, e_idx)
							delete(s.im_temp_entity_buffer)
							clear_menu(&s.menus, .MaterialSelection)
							s.interaction_mode = .Map
							null_menu_state(&s.menus)
						}
					}
					case .EntityMenu: {
						if el_idx == len(menu.element_idx)-1 // Close is last element
						{
							s.interaction_mode = .Map
							menu.visible = false
						}
						else if el_idx == len(menu.element_idx)-2 // deconstruct
						{
							b_idx := s.im_selected_entity_idx
							// TODO: BUG this doesn't work, needs V3i to be set, apparently
							add_order(order_queue, .Deconstruct, {0,0,0}, b_idx)
							s.interaction_mode = .Map
							menu.visible = false
						}
					}
					case .WorkOrderMenu: {
						if el_idx == 0 // cancel
						{
							s.interaction_mode = .Map
							delete(s.im_temp_entity_buffer)
							null_menu_state(&s.menus)
						} else if el_idx == len((menu.element_idx))-1 // last button is new
						{
							// TODO: Implement new work order
						} else if el_idx > 1 // 2nd element is a header label
						{
							// each 'row' has 5 elements: Type, Qty, Plus, Minus, Cancel
							tmp_idx := (el_idx-2)/5
							action := (el_idx-2)%5 - 2 // 0: add, 1: decrease, 2: cancel
							order_idx := s.im_temp_entity_buffer[tmp_idx]
							order := &order_queue.orders[order_idx]
							if action == 0 {
								order.target_count += 1
							} else if action == 1 && order.target_count > 0 {
								order.target_count -= 1
							} else if action == 2 {
								assigned_to := order.assigned_creature_idx
								if assigned_to > 0 {
									entities[assigned_to].creature.current_order_idx = 0
								}
								complete_order(order_queue, order_idx)
							}
							rebuild_work_order_menu = true
						}
					}
					case .AddWorkOrderMenu: {}
					}
				}
			}
			case .Text: {
				do_text(id, rect, element.text)
			}
			}
		}

		if rebuild_work_order_menu {
			delete(s.im_temp_entity_buffer)
			s.im_temp_entity_buffer = populate_order_menu(&s.menus, order_queue)
		}

		if hot == NULL_UIID {

			switch s.interaction_mode {
			case .EntityInteract, .Stockpile: {}
			case .Map: {
				// NOTE: Not sure if I want to do hover visibility just in normal map mode
				/* plot_tile(flip(s.hovered_tile.xy), black, red, .BLANK) */

				tile := get_map_tile(m, s.hovered_tile)
				entities_at_cursor := get_entities_at_pos(entities, s.hovered_tile)
				y_start := 1
				if tile.content.shape != .Wall || tile.exposed {
					write_string_to_screen({0,y_start}, fmt.tprint(tile.content.made_of.type, tile.content.shape), white, black)
					y_start += 1
				}

				for e, i in entities_at_cursor {
					entity := entities[e]
					str : string
					if entity.type == .Creature {
						str = fmt.tprint(entity.creature.type, entity.creature.name)
					} else if entity.type == .Building {
						str = fmt.tprint(entity.building.type)
					} else if entity.type == .Material {
						str = fmt.tprint(entity.material.type)
					}
					write_string_to_screen({0, y_start+i}, str, yellow, black)
				}

				if lmb {
					if len(entities_at_cursor) > 0 {
						eidx := entities_at_cursor[0]
						s.im_selected_entity_idx = eidx
						s.interaction_mode = .EntityInteract
						populate_entity_menu(&s.menus, entities[s.im_selected_entity_idx])
						s.menus.menus[.EntityMenu].visible = true
					}
				}
			}
			case .CutTrees: {
				visible, screen_tile := camera_xform(s.cam, s.hovered_tile)
				if visible {
					plot_tile(screen_tile, black, red, .BLANK)
				}
				if lmb {
					es := get_entities_at_pos(entities, s.hovered_tile)
					for e_i in es {
						if entities[e_i].type == .Building {
							add_order(order_queue, .CutTree, s.hovered_tile, e_i)
						}
					}
				}
			}
			case .Mine: {
				if !s.im_toggle {
					if lmb {
						s.im_toggle = true
						s.im_ref_pos = s.hovered_tile
					}
					visible, screen_tile := camera_xform(s.cam, s.hovered_tile)
					if visible {
						plot_tile(screen_tile, black, red, .BLANK)
					}
				} else {
					v_min := vec_min(s.im_ref_pos, s.hovered_tile)
					v_max := vec_max(s.im_ref_pos, s.hovered_tile)
					assert(v_min.z==v_max.z)
					for x in v_min.x..=v_max.x {
						for y in v_min.y..=v_max.y {
							tile := get_map_tile(m, {x,y,v_min.z})
							if tile.content.shape == .Wall {
								if lmb do tile.order_idx = add_order(order_queue, .Mine, {x,y,v_min.z})
								visible, screen_tile := camera_xform(s.cam, {x,y,v_min.z})
								if visible {
									plot_tile(screen_tile, black, red, .BLANK)
								}
							}
						}
					}
					if lmb do s.im_toggle = false
				}
			}
			case .Build: {
				if s.im_building_selection != .Null {
					e_def := B_PROTOS[s.im_building_selection]
					for x in 0..<e_def.dims.x {
						for y in 0..<e_def.dims.y {
							tile := s.hovered_tile + {x,y,0}
							visible, screen_tile := camera_xform(s.cam, tile)
							if visible {
								plot_tile(screen_tile, white, black, .X)
							}
						}
					}
				}

				if lmb {
					if s.im_building_selection != .Null {
						s.im_ref_pos = s.hovered_tile
						idx := building_construction_request(entities, s.im_building_selection, s.hovered_tile)
						s.im_selected_entity_idx = idx
						s.im_temp_entity_buffer = get_construction_materials(entities[:])
						populate_material_selector(&s.menus, entities[:], s.im_temp_entity_buffer)
						s.menus.menus[.MaterialSelection].visible = true
						s.interaction_mode = .Map
					}

				}
			}
			}
		}
	}

/*******************
 * SEC: Draw Debug *
 *******************/

	return true
}
