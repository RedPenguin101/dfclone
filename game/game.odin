package game

import c "../common"
import "core:fmt"

DBG :: fmt.println

GameInput :: c.GameInput
Renderer :: c.Renderer
RenderRequest :: c.RenderRequest
Color :: c.Color
Basis :: c.Basis
V3i :: c.V3i
V2 :: c.V2
V2i :: c.V2i
Rect :: c.Rect

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
    im_material_buffer:[]Material,
}

GameMemory :: struct {
    game_state : GameState,
    initialized : bool,
    platform : c.PlatformApi,
    font: rawptr,
    spritesheet:c.Texture,
    backup_spritesheet:c.Texture,
}

/******************
 * Render Helpers *
 ******************/

fill_tile_with_color :: proc(r:^Renderer, pos:V3i, color:Color) {
    x_s := map_start+f32(pos.x)*tile_size
    y_s := map_start+f32(pos.y)*tile_size
    c.queue_rect(r, {x_s, y_s, x_s+tile_size, y_s+tile_size}, color)
}

fill_tile_with_circle :: proc(r:^Renderer, pos:V3i, color:Color) {
    x_s := map_start+(f32(pos.x)+0.5)*tile_size
    y_s := map_start+(f32(pos.y)+0.5)*tile_size
    c.queue_circle(r, {x_s, y_s}, tile_size/2, color)
}

render_texture_in_tile :: proc(r:^Renderer, pos:V3i, tex:c.Texture, idx:int, tint:=white) {
    x_s := map_start+f32(pos.x)*tile_size
    y_s := map_start+f32(pos.y)*tile_size
    c.queue_texture(r, {x_s, y_s, x_s+tile_size, y_s+tile_size}, tex, idx, tint)
}

/**********************
 * Game API functions *
 **********************/

@(export)
game_state_init :: proc(platform_api:c.PlatformApi) -> rawptr {
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

    delete(memory.game_state.e)
    delete(E_FREE_STACK)
    free(memory)
}

@(export)
game_update :: proc(time_delta:f32, memory:^GameMemory, input:GameInput, r:^Renderer) {

    /*****************
     * SEC: MEM INIT *
     *****************/

    s := &memory.game_state

    if !memory.initialized {
        memory.font = memory.platform.load_font("./assets/fonts/InterVariable.ttf")
        memory.spritesheet = memory.platform.load_sprite("./assets/sprites/spritesheet.png", 1, 1)
        memory.backup_spritesheet = memory.platform.load_sprite("./assets/sprites/DF_sir_henry.png", 16, 16)

        add_entity(&s.e, .Null, {0,0,0})
        add_order(&s.oq, .Null, {})

        s.cam.center = {0,0,1}
        s.m = init_map({20, 20, 3})
        INIT_DUMMY_MAP(&s.m)
        add_entity(&s.e, .Creature, {5, 10, 1})

        t := add_entity(&s.e, .Building, {4, 4, 1})
        tree := make_tree(.Wood_Oak)
        s.e[t].building = tree

        t = add_entity(&s.e, .Material, {9, 4, 1})
        s.e[t].material = {
            type = .Stone_Limestone,
            form = .Natural,
            quantity = 1,
            earmarked_for_use = false
        }

        t = add_entity(&s.e, .Material, {9, 5, 1})
        s.e[t].material = Material{
            type = .Stone_Magnetite,
            form = .Natural,
            quantity = 1,
            earmarked_for_use = false
        }

        t = add_entity(&s.e, .Material, {9, 6, 1})
        s.e[t].material = Material{
            type = .Wood_Oak,
            form = .Natural,
            quantity = 1,
            earmarked_for_use = false
        }

        setup_menus(&s.menus)
        memory.initialized = true
    }

    /**************
     * LOOP LOCAL *
     **************/

    m := &s.m
    entities := &s.e
    order_queue := &s.oq

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
                fill_tile_with_color(r, {x,y,z_level}, color)
            }
        }
    }

    /********************
     * SEC: Entity Loop *
     ********************/

    for &e in s.e {
	type := e.type
        if type == .Creature {
            if e.current_order_idx == 0 {
                i, o := get_unassigned_order(order_queue)
                if i > 0 {
                    e.current_order_idx = i
                    o.status = .Assigned
                }
            }

            e.action_ticker -= time_delta
            if e.action_ticker < 0 {
                if e.current_order_idx > 0 {
                    o := s.oq.orders[e.current_order_idx]
                    target_pos := o.pos
                    if !are_adjacent(e.pos, target_pos) {
                        dx := 0 if e.pos.x == target_pos.x else 1 if e.pos.x < target_pos.x else -1
                        dy := 0 if e.pos.y == target_pos.y else 1 if e.pos.y < target_pos.y else -1
                        e.pos += {dx,dy,0}
                    } else {
                        if o.type == .Mine {
                            // TODO: Encapsulate order completion
                            mat := mine_tile(m, target_pos)
                            complete_order(order_queue, e.current_order_idx)
                            e.current_order_idx = 0
                            get_map_tile(m, target_pos).order_idx = 0
                            i := add_entity(&s.e, .Material, target_pos)
                            s.e[i].material = mat
                        } else if o.type == .CutTree {
                            tree := &s.e[o.target_entity_idx]
                            assert(tree.building.type == .Tree)
                            fmt.println("desconstructing building", tree.building.deconstruction_percentage)
                            tree.building.deconstruction_percentage += 0.2
                            if tree.building.deconstruction_percentage > 1 {
                                complete_order(order_queue, e.current_order_idx)
                                e.current_order_idx = 0
                                get_map_tile(m, target_pos).order_idx = 0
                                deconstruct_entity(&s.e, o.target_entity_idx)
                            }
                        } else if o.type == .Construct {
                            building := &s.e[o.target_entity_idx]
                            building.building.deconstruction_percentage -= 0.2
                            if building.building.deconstruction_percentage < 0 {
                                building.building.deconstruction_percentage = 0
                                complete_order(order_queue, e.current_order_idx)
                                e.current_order_idx = 0
                                get_map_tile(m, target_pos).order_idx = 0
                            }
                        }
                    }
                }
                e.action_ticker += 0.2
            }
        }

        /* SEC: Entity Render */
        if e.pos.z == s.cam.center.z {
            switch e.type {
            case .Null: {}
            case .Creature: {
                /* render_texture_in_tile(r, e.pos, memory.spritesheet, 0) */
                fill_tile_with_color(r, e.pos, blue)
                render_texture_in_tile(r, e.pos, memory.backup_spritesheet, 2)
            }
            case .Building: {
                if e.building.type == .Tree {
                    fill_tile_with_color(r, e.pos, tree_brown)
                } else if e.building.type == .StoneMason {
                    background := black
                    fg1 := white
                    fg2 := Color{1, 186.0/255, 0, 1}

                    if e.building.status == .PendingMaterialAssignment || e.building.status == .PendingConstruction {
                        background.a = 0.5
                        fg1.a = 0.5
                        fg2.a = 0.5
                    }

                    e_def := B_PROTOS[.StoneMason]
                    for x in 0..<e_def.dims.x {
                        for y in 0..<e_def.dims.y {
                            fill_tile_with_color(r, e.pos+{x,y,0}, background)
                        }
                    }
                    render_texture_in_tile(r, e.pos+{0,0,0}, memory.backup_spritesheet, 177, fg1)
                    render_texture_in_tile(r, e.pos+{0,1,0}, memory.backup_spritesheet, 177, fg1)
                    render_texture_in_tile(r, e.pos+{2,0,0}, memory.backup_spritesheet, 177, fg1)
                    render_texture_in_tile(r, e.pos+{1,0,0}, memory.backup_spritesheet, 93 , fg1)
                    render_texture_in_tile(r, e.pos+{2,1,0}, memory.backup_spritesheet, 39 , fg1)
                    render_texture_in_tile(r, e.pos+{1,1,0}, memory.backup_spritesheet, 96 , fg1)
                    render_texture_in_tile(r, e.pos+{0,2,0}, memory.backup_spritesheet, 96 , fg1)
                    render_texture_in_tile(r, e.pos+{1,2,0}, memory.backup_spritesheet, 34 , fg1)
                    render_texture_in_tile(r, e.pos+{2,2,0}, memory.backup_spritesheet, 61, fg2)

                }

                render_texture_in_tile(r, e.pos, memory.backup_spritesheet, 79)
            }
            case .Material: {
                color := tree_brown if e.material.type in is_wood else stone_grey
                fill_tile_with_circle(r, e.pos, color)
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
                if do_button(id, input.mouse, r, memory.font, rect, element.text, element.state == .Depressed) {
                    if menu_name == .MainBar {
                        if element.state == .None {
                            null_menu_state(&s.menus)
                            element.state = .Depressed
                            s.interaction_mode = InteractionMode(id.element_idx+1)
                            if element.submenu != .Null {
                                s.menus.menus[element.submenu].visible = true
                            }
                        } else if element.state == .Depressed {
                            // Deactivate the related interaction mode
                            null_menu_state(&s.menus)
                            s.interaction_mode = .Map
                        }
                    } else if menu_name == .BuildingSelector {
                        if el_idx == 0 {
                            if element.state == .Depressed {
                                s.im_building_selection = .Null
                                element.state = .None
                            } else {
                                s.im_building_selection = .StoneMason
                                s.menus.menus[.BuildingSelector].visible = false
                                s.interaction_mode = .Build
                            }
                        } else if el_idx == 1 {
                            // CLOSE
                            s.interaction_mode = .Map
                            menu.visible = false
                            s.im_building_selection = .Null
                            for other_idx in 0..<len(s.menus.menus[.MainBar].element_idx) {
                                get_element_by_menu_idx(&s.menus, .MainBar, other_idx).state = .None
                            }
                        }
                    } else if menu_name == .MaterialSelection {
                        if el_idx == len(s.im_material_buffer) {
                            // cancel
                            delete(s.im_material_buffer)
                            s.interaction_mode = .Map
                            null_menu_state(&s.menus)
                        } else {
                            chosen_material := s.im_material_buffer[el_idx]
                            chosen_material.quantity = 1
                            e_idx := s.im_selected_entity_idx
                            e := &entities[e_idx]
                            e.building.made_of[0] = chosen_material
                            e.building.status = .PendingConstruction
                            add_order(order_queue, .Construct, e.pos, e_idx)
                            delete(s.im_material_buffer)
                            s.interaction_mode = .Map
                            null_menu_state(&s.menus)
                        }
                    } else if menu_name == .EntityMenu {
                        if el_idx == 1 {
                            s.interaction_mode = .Map
                            menu.visible = false
                        }
                    }
                }
            }
            case .Text: {
                do_text(id, r, memory.font, rect, element.text)
            }
            }
        }

        if hot == NULL_UIID {
            // Hovered Tile render and handling
            s.hovered_tile = v2_to_v3i((input.mouse.position-{map_start, map_start})/tile_size, s.cam.center.z)
            lmb := c.pressed(input.mouse.lmb)

            switch s.interaction_mode {
            case .EntityInteract, .Stockpile: {}
            case .Map: {
                fill_tile_with_color(r, s.hovered_tile, red)

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
                fill_tile_with_color(r, s.hovered_tile, red)
                if lmb {
                    es := get_entities_at_pos(&s.e, s.hovered_tile)
                    for e_i in es {
                        if s.e[e_i].type == .Building {
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
                    fill_tile_with_color(r, s.hovered_tile, red)
                } else {
                    v_min := vec_min(s.im_ref_pos, s.hovered_tile)
                    v_max := vec_max(s.im_ref_pos, s.hovered_tile)
                    assert(v_min.z==v_max.z)
                    for x in v_min.x..=v_max.x {
                        for y in v_min.y..=v_max.y {
                            tile := get_map_tile(m, {x,y,v_min.z})
                            if tile.content.shape == .Solid {
                                if lmb do tile.order_idx = add_order(order_queue, .Mine, {x,y,v_min.z})
                                fill_tile_with_color(r, {x,y,v_min.z}, blue)
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
                            fill_tile_with_color(r, s.hovered_tile+{x,y,0}, red)
                        }
                    }
                }

                if lmb {
                    if s.im_building_selection != .Null {
                        s.im_ref_pos = s.hovered_tile
                        idx := building_construction_request(entities, s.im_building_selection, s.hovered_tile)
                        s.im_selected_entity_idx = idx
                        s.im_material_buffer = get_construction_materials(s.e[:])
                        populate_material_selection(&s.menus, s.im_material_buffer)
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
    if false {
        idx :f32= 0.0
        dbg :: proc(r:^Renderer, text:string, font:rawptr, idx:^f32) {
            TEXT_HEIGHT :: 0.03
            TEXT_START :: 0.28
            c.queue_text(r, text, font, {0.02, TEXT_START-(idx^*TEXT_HEIGHT), 1, 0.3}, white)
            idx^+=1
        }
        c.queue_rect(r, {0,0,1, 0.3}, blue)
        dbg(r, fmt.tprintf("Hov Tile: %d", s.hovered_tile), memory.font, &idx)
        dbg(r, fmt.tprintf("OQ Len: %v", len(s.oq.orders)), memory.font, &idx)

        es := get_entities_at_pos(&s.e, s.hovered_tile)

        if len(es) > 0 {
            e:= s.e[es[0]]
            dbg(r, fmt.tprintf("%v %v, %v", e.type, e.pos, e.current_order_idx), memory.font, &idx)
        }

        oix := get_map_tile(m, s.hovered_tile).order_idx
        if oix > 0 && len(s.oq.orders) > oix {
            dbg(r, fmt.tprintf("Order: %v", s.oq.orders[oix]), memory.font, &idx)
        }

        dbg(r, fmt.tprintf("IM: %v", s.interaction_mode), memory.font, &idx)
        dbg(r, fmt.tprintf("IM: %v", s.im_building_selection), memory.font, &idx)
    }
}
