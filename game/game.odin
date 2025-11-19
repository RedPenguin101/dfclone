package game

import "../common"
import "core:fmt"
import "core:log"

DBG :: log.debug
INFO :: log.info

GameInput :: common.GameInput
Color :: common.Color

TEMP_MOVE_COST :: 0.25
TEMP_BUILD_COST :: 1
TEMP_MINE_COST :: 1

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
green := Color{0,1,0,1}
blue  := Color{0,0,1,1}
pink  := Color{ 1, 109.0/255, 194.0/255, 1 }

stone_grey := Color{0.6,0.6,0.6,1}
tree_brown := Color{0.7608, 0.4431, 0.1294, 1}

/**************************
 * SEC: Gamestate structs *
 **************************/

Camera :: struct {
	center : V3i,
	dims   : V3i,
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

/**********************
 * Game API functions *
 **********************/

@(export)
game_state_init :: proc(platform_api:common.PlatformAPI) -> rawptr {
	game_memory := new(GameMemory)
	game_memory.platform = platform_api
	return game_memory
}

/* SEC: GS Destroy */

@(export)
game_state_destroy :: proc(memory:^GameMemory) {
	destroy_map(&memory.game_state.m)
	destroy_order_queue(&memory.game_state.oq)
	tear_down_menus(&memory.game_state.menus)

	for e in memory.game_state.e {
		delete(e.inventory)
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
	plot_tile := memory.platform.plot_tile
	flip :: proc(tile:[2]int) -> [2]int {
		t := tile
		t.y = common.ROWS - t.y
		return t
	}

/*****************
 * SEC: MEM INIT *
 *****************/

	if !memory.initialized {
		add_entity(entities, .Null, {0,0,0})
		add_order(&s.oq, .Null, {})

		s.cam.center = {0,0,1}
		s.m = init_map({20, 20, 3})
		INIT_DUMMY_MAP(&s.m)

		add_creature(entities, .Dwarf, {5, 10, 1}, fmt.tprint("Iton"))

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

		setup_menus(&s.menus)
		memory.initialized = true
	}

	dbg_dwarf := &entities[1]

/*******************
 * SEC: DRAW MAP *
 *******************/

	{
		z_level := s.cam.center.z

		for y in 0..<m.dim.y {
			for x in 0..<m.dim.x {
				tile := get_map_tile(m, {x,y,z_level})
				color:Color
				if tile.order_idx > 0 {
					color = black
				} else if tile.content.shape == .Solid {
					color = stone_grey
				} else {
					color = green
				}
				screen_tile := flip({x,y})
				if screen_tile.y < common.ROWS {
					plot_tile(screen_tile, black, color, .BLANK)
				}
				/* fill_tile_with_color(r, {x,y,z_level}, color) */
			}
		}
	}

/********************
 * SEC: Entity Loop *
 ********************/

	for &e, my_idx in entities {
		type := e.type
		if type == .Creature {
			e.action_ticker += time_delta
			e.action_ticker = min(e.action_ticker, time_delta)
			MAX_ITS :: 10
			its := 0
			for e.action_ticker > 0 && its < MAX_ITS {
				its += 1
				/* SEC: Creature Pickup Order */
				if e.current_order_idx == 0 {
					i, o := get_unassigned_order(order_queue)
					if i > 0 {
						e.current_order_idx = i
						INFO("Picked up order", o.type, o.pos)
						o.status = .Assigned
					}
				}

				/* SEC: Creature Decide new task */
				switch e.creature.task.type {
				case .None:  {
					order := &order_queue.orders[e.current_order_idx]
					switch order.type {
					case .Null: {
						// NOTE: Nothing to do, quit out of loop
						e.action_ticker = 0
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
							e.current_order_idx = 0
							order.status = .Suspended
						}
					}
					case .CutTree, .Deconstruct: {
						reachable := find_path(&s.m, e.pos, order.pos, &e.creature.path)
						if reachable
						{
							e.creature.task.type = .DeconstructBuilding
							e.creature.task.entity_idx_1 = order.target_entity_idx
							DBG("task assign", e.creature.task.type, e.creature.task.loc_1)
						}
						else
						{
							e.current_order_idx = 0
							order.status = .Suspended
							INFO("Can't reach deconstruction location, looking for another job")
						}
					}
					case .Construct: {
						b_idx := order.target_entity_idx
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
									e.current_order_idx = 0
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
						e.action_ticker -= TEMP_MOVE_COST
					} else {
						mat := mine_tile(m, target_pos)
						e.action_ticker -= TEMP_MINE_COST
						DBG("Finished mining", target_pos)
						complete_order(order_queue, e.current_order_idx)
						e.current_order_idx = 0
						get_map_tile(m, target_pos).order_idx = 0
						i := add_entity(entities, .Material, target_pos)
						entities[i].material = mat
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
						e.action_ticker -= TEMP_MOVE_COST
					} else {
						building.building.deconstruction_percentage += 0.2
						e.action_ticker -= TEMP_BUILD_COST
						if building.building.deconstruction_percentage > 1 {
							DBG("Finished deconstructing", target_pos)
							for material_index in building.inventory {
								entities[material_index].in_inventory_of = 0
								entities[material_index].in_building = 0
								entities[material_index].pos = building.pos
							}
							remove_entity(entities, b_idx)

							complete_order(order_queue, e.current_order_idx)
							e.current_order_idx = 0
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
						e.action_ticker -= TEMP_MOVE_COST
					} else {
						building.building.deconstruction_percentage -= 0.2
						e.action_ticker -= TEMP_BUILD_COST
						if building.building.deconstruction_percentage < 0 {
							DBG("Finished constructing", target_pos)
							building.building.deconstruction_percentage = 0
							building.building.status = .Normal
							for m_idx in building.inventory {
								entities[m_idx].in_building = b_idx
							}

							complete_order(order_queue, e.current_order_idx)
							e.current_order_idx = 0
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
						e.action_ticker -= TEMP_MOVE_COST
					} else {
						if picking_up {
							reachable := find_path(&s.m, e.pos, ety.pos, &e.creature.path)
							if reachable
							{
								e.action_ticker -= TEMP_MOVE_COST
								append(&e.inventory, mat_idx)
								mat.in_inventory_of = my_idx
								DBG("Task step completed", e.creature.task.type)
							}
							else
							{
								order_queue.orders[e.current_order_idx].status = .Suspended
								e.current_order_idx = 0
								INFO("Can't reach construction location, looking for another job")
								e.creature.task.type = .None
							}
						} else {
							DBG("Task completed", e.creature.task.type)
							e.action_ticker -= TEMP_MOVE_COST
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
		if e.pos.z == s.cam.center.z {
			switch e.type {
			case .Null: {}
			case .Creature: {
				plot_tile(flip(e.pos.xy), white, blue, .AT)
			}
			case .Building: {
				if e.building.type == .Tree {
					plot_tile(flip(e.pos.xy), tree_brown, black, .O)
				} else if e.building.type == .StoneMason {
					background := black
					fg1 := white
					fg2 := Color{1, 186.0/255, 0, 1}

					if e.building.status == .PendingMaterialAssignment || e.building.status == .PendingConstruction {
						alpha := 1-(e.building.deconstruction_percentage/2)
						background.a = alpha
						fg1.a = alpha
						fg2.a = alpha
					}

					e_def := B_PROTOS[.StoneMason]

					plot_tile(flip(e.pos.xy+{0,0}), fg1, background, .X)
					plot_tile(flip(e.pos.xy+{0,1}), fg1, background, .X)
					plot_tile(flip(e.pos.xy+{2,0}), fg1, background, .X)
					plot_tile(flip(e.pos.xy+{1,0}), fg1, background, .X)
					plot_tile(flip(e.pos.xy+{2,1}), fg1, background, .X)
					plot_tile(flip(e.pos.xy+{1,1}), fg1, background, .X)
					plot_tile(flip(e.pos.xy+{0,2}), fg1, background, .X)
					plot_tile(flip(e.pos.xy+{1,2}), fg1, background, .X)
					plot_tile(flip(e.pos.xy+{2,2}), fg2, background, .X)

				}
			}
			case .Material: {
				if e.in_inventory_of == 0 && e.in_building == 0 {
					color := tree_brown if e.material.type in is_wood else stone_grey
					plot_tile(flip(e.pos.xy), color, black, .M)
					/* fill_tile_with_circle(r, e.pos, color) */
				}
			}

			}
		}
	}

/**************
 * SEC: Menus *
 **************/

	{
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

			}
			case .Text: {

			}
			}
		}

		pressed :: proc(btn:common.ButtonState) -> bool {return false}

		if hot == NULL_UIID {
			// Hovered Tile render and handling
			s.hovered_tile = v2_to_v3i((input.mouse.position-{map_start, map_start})/tile_size, s.cam.center.z)
			lmb := pressed(input.mouse.lmb)

			switch s.interaction_mode {
			case .EntityInteract, .Stockpile: {}
			case .Map: {
				// TODO: Fix mouse handlin
				/* plot_tile(s.hovered_tile.xy, black, red, .BLANK) */

				if lmb {
					entities_at_cursor := get_entities_at_pos(entities, s.hovered_tile)
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
				/* fill_tile_with_color(r, s.hovered_tile, red) */
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
					/* fill_tile_with_color(r, s.hovered_tile, red) */
				} else {
					v_min := vec_min(s.im_ref_pos, s.hovered_tile)
					v_max := vec_max(s.im_ref_pos, s.hovered_tile)
					assert(v_min.z==v_max.z)
					for x in v_min.x..=v_max.x {
						for y in v_min.y..=v_max.y {
							tile := get_map_tile(m, {x,y,v_min.z})
							if tile.content.shape == .Solid {
								if lmb do tile.order_idx = add_order(order_queue, .Mine, {x,y,v_min.z})
								/* fill_tile_with_color(r, {x,y,v_min.z}, blue) */
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
							/* fill_tile_with_color(r, s.hovered_tile+{x,y,0}, red) */
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
