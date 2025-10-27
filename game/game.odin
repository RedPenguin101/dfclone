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
map_start :: 0.3
tile_size :: 0.02

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
    Map, Mine, CutTrees, Build, EntityInteract,
}

GameState :: struct {
    m:Map,
    e:[dynamic]Entity,
    oq:OrderQueue,

    cam:Camera,
    hovered_tile:V3i,
    menus:MenuState,

    interaction_mode:InteractionMode,
    im_building_selection:EntityType,
    im_toggle:bool,
    im_ref_pos:V3i,
}

GameMemory :: struct {
    game_state : GameState,
    initialized : bool,
    platform : c.PlatformApi,
    font: rawptr,
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

        s.cam.center = {0,0,1}
        s.m = init_map({20, 20, 3})
        INIT_DUMMY_MAP(&s.m)
        add_entity(&s.e, .Null, {0,0,0})
        add_entity(&s.e, .Dwarf, {5, 10, 1})
        add_entity(&s.e, .Tree, {4, 4, 1})
        add_order(&s.oq, .Null, {})
        setup_menus(&s.menus)
        memory.initialized = true
    }

    /**************
     * LOOP LOCAL *
     **************/

    m := &s.m
    menus := &s.menus
    entities := &s.e
    order_queue := &s.oq

    /*********************
     * SEC: HANDLE INPUT *
     *********************/

    {
        pressed :: proc(b:c.ButtonState) -> bool {return b.is_down && !b.was_down}
        held :: proc(b:c.ButtonState) -> bool {return b.frames_down > 30}
        pressed_or_held :: proc(b:c.ButtonState) -> bool {return pressed(b) || held(b)}

        s.hovered_tile = v2_to_v3i((input.mouse.position-{map_start, map_start})/tile_size, s.cam.center.z)

        if pressed(input.mouse.lmb) {
            // TODO: Do this properly
            SCREEN_WIDTH :: 800
            SCREEN_HEIGHT :: 640

            mouse_in_px_space := input.mouse.position
            mouse_in_px_space.y /= 0.8
            mouse_in_px_space.y -= 1.0
            mouse_in_px_space.y *= -SCREEN_HEIGHT
            mouse_in_px_space.x *= SCREEN_WIDTH

            menus_captured, im, qual := handle_menus_click(&s.menus, mouse_in_px_space)

            if menus_captured {
                s.interaction_mode = im
                s.im_building_selection = EntityType(qual)
            } else {
                switch s.interaction_mode {
                case .EntityInteract: {}
                case .Map: {
                    entities_at_cursor := get_entities_at_pos(entities, s.hovered_tile)
                    if len(entities_at_cursor) > 0 {
                        eidx := entities_at_cursor[0]
                        e := &entities[eidx]
                        setup_entity_menu(menus, e)
                        activate_menu(menus, .EntityMenu)
                        s.interaction_mode = .EntityInteract
                    }
                }
                case .Mine: {
                    if !s.im_toggle {
                        s.im_toggle = true
                        s.im_ref_pos = s.hovered_tile
                    } else {
                        v_min := vec_min(s.im_ref_pos, s.hovered_tile)
                        v_max := vec_max(s.im_ref_pos, s.hovered_tile)
                        assert(v_min.z==v_max.z)
                        for x in v_min.x..=v_max.x {
                            for y in v_min.y..=v_max.y {
                                tile := get_map_tile(m, {x,y,v_min.z})
                                if tile.content == .Filled {
                                    tile.order_idx = add_order(order_queue, .Mine, {x,y,v_min.z})
                                }
                            }
                        }
                        s.im_toggle = false
                    }
                }
                case .CutTrees: {
                    es := get_entities_at_pos(&s.e, s.hovered_tile)
                    for e_i in es {
                        if s.e[e_i].type == .Tree {
                            add_order(order_queue, .CutTree, s.hovered_tile, e_i)
                        }
                    }
                }
                case .Build: {
                    if s.im_building_selection != .Null {
                        idx := building_construction_request(entities, s.im_building_selection, s.hovered_tile)
                        /* add_order(order_queue, .Construct, s.hovered_tile, idx) */
                        s.interaction_mode = .EntityInteract
                        reset_menus(menus)
                        activate_menu(menus, .EntityMenu)
                        setup_entity_menu(menus, &entities[idx])
                        s.im_building_selection = .Null
                    }
                }
                }
            }
        }
    }

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
                } else if tile.content == .Filled {
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
        super_type := ENTITY_TABLE[e.type].super_type
        if super_type == .Creature {
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
                            mine_tile(m, target_pos)
                            complete_order(order_queue, e.current_order_idx)
                            e.current_order_idx = 0
                            get_map_tile(m, target_pos).order_idx = 0
                            add_entity(&s.e, .Stone, target_pos)
                        } else if o.type == .CutTree {
                            tree := &s.e[o.target_entity_idx]
                            assert(tree.type == .Tree)
                            tree.deconstruction_percentage += 0.2
                            if tree.deconstruction_percentage > 1 {
                                complete_order(order_queue, e.current_order_idx)
                                e.current_order_idx = 0
                                get_map_tile(m, target_pos).order_idx = 0
                                deconstruct_entity(&s.e, o.target_entity_idx)
                            }
                        } else if o.type == .Construct {
                            building := &s.e[o.target_entity_idx]
                            building.deconstruction_percentage -= 0.2
                            if building.deconstruction_percentage < 0 {
                                building.deconstruction_percentage = 0
                                complete_order(order_queue, e.current_order_idx)
                                e.current_order_idx = 0
                                get_map_tile(m, target_pos).order_idx = 0
                            }
                        }
                    }
                }
                e.action_ticker += ENTITY_ACTION_FREQ
            }
        }

        /* SEC: Entity Render */
        if e.pos.z == s.cam.center.z {
            switch e.type {
            case .Null: {}
            case .Dwarf: {
                fill_tile_with_color(r, e.pos, blue)
            }
            case .Tree: {
                fill_tile_with_color(r, e.pos, tree_brown)
            }
            case .Stone: {
                fill_tile_with_circle(r, e.pos, stone_grey)
            }
            case .Wood: {
                fill_tile_with_circle(r, e.pos, tree_brown)
            }
            case .Workshop: {
                e_def := ENTITY_TABLE[.Workshop]
                for x in 0..<e_def.dims.x {
                    for y in 0..<e_def.dims.y {
                        fill_tile_with_color(r, e.pos+{x,y,0}, black)
                    }
                }

            }
            }
        }
    }

    /***********************
     * SEC: Draw MenuState *
     ***********************/
    {
        /* Draw mouse hover */
        switch s.interaction_mode {
        case .EntityInteract: {}
        case .Map, .CutTrees: fill_tile_with_color(r, s.hovered_tile, red)
        case .Mine: {
            if s.im_toggle {
                {
                    v_min := vec_min(s.im_ref_pos, s.hovered_tile)
                    v_max := vec_max(s.im_ref_pos, s.hovered_tile)
                    assert(v_min.z==v_max.z)
                    for x in v_min.x..=v_max.x {
                        for y in v_min.y..=v_max.y {
                            tile := get_map_tile(m, {x,y,v_min.z})
                            if tile.content == .Filled {
                                fill_tile_with_color(r, {x,y,v_min.z}, blue)
                            }
                        }
                    }
                }
            } else {
                fill_tile_with_color(r, s.hovered_tile, red)
            }
        }
        case .Build: {
            if s.im_building_selection != .Null {
                e_def := ENTITY_TABLE[s.im_building_selection]
                for x in 0..<e_def.dims.x {
                    for y in 0..<e_def.dims.y {
                        fill_tile_with_color(r, s.hovered_tile+{x,y,0}, red)
                    }
                }
            }
        }

        }

        r.current_basis = .menus
        render_menus(r, s.menus, memory.font)
        r.current_basis = .screen
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
