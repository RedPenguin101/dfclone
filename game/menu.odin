package game

import c "../common"
import "core:fmt"

MenuName :: enum { Null, InteractionModeSelector, BuildingSelector, EntityMenu }

MenuState :: struct {
    boxes : [MenuName]Menu,
}

ButtonState :: enum { None, Depressed,}

Menu :: struct {
    rect:Rect,
    size:V2i,
    active:bool,
    buttons:[dynamic]Button,
    text_elements:[dynamic]TextElement,
}

TextElement :: struct {
    rect:Rect,
    text:string,
    menu_name:MenuName,
}

Button :: struct {
    rect:Rect,
    back_reference:int,
    label:string,
    state:ButtonState,
    menu_name:MenuName,
    sub_menu:MenuName,
}

setup_menus :: proc(menus:^MenuState) {
    // TODO: All this stuff should be in centimeters, as should the basis
    margins := Rect{2,2,-2,-2}
    {
        os := &menus.boxes[.InteractionModeSelector]
        os.rect = {0,0,800,50}
        os.size = {6, 1}
        os.active = true

        mining_button := Button{
            rect = Rect{0,0,50,50}+margins,
            back_reference = int(InteractionMode.Mine),
            label = fmt.tprint("M"),
            state = .None,
            menu_name = .InteractionModeSelector,
        }
        cut_trees_button := Button{
            rect = Rect{50,0,100,50}+margins,
            back_reference = int(InteractionMode.CutTrees),
            label = fmt.tprint("T"),
            state = .None,
            menu_name = .InteractionModeSelector,
        }
        build_button := Button{
            rect = Rect{100,0,150,50}+margins,
            back_reference = int(InteractionMode.Build),
            label = fmt.tprint("B"),
            state = .None,
            menu_name = .InteractionModeSelector,
            sub_menu = .BuildingSelector,
        }
        stockpile_button := Button{
            rect = Rect{150,0,200,50}+margins,
            back_reference = int(InteractionMode.Stockpile),
            label = fmt.tprint("S"),
            state = .None,
            menu_name = .InteractionModeSelector,
        }
        append(&os.buttons, mining_button)
        append(&os.buttons, cut_trees_button)
        append(&os.buttons, build_button)
        append(&os.buttons, stockpile_button)
    }

    {
        bs := &menus.boxes[.BuildingSelector]
        bs.rect = {100,50,300,100}
        bs.size = {1, 5}
        bs.active = false

        workshop_button := Button{
            rect = Rect{100,50,300,100}+margins,
            back_reference = int(EntityType.Workshop),
            label = fmt.tprint("Workshop"),
            state = .None,
            menu_name = .BuildingSelector,
        }
        append(&bs.buttons, workshop_button)
    }

    {
        em := &menus.boxes[.EntityMenu]
        em.rect = {500, 50, 800, 640}
        em.active = false
        CLOSE :: 0
        close := Button {
            rect = Rect{500,50,800,100}+margins,
            back_reference = CLOSE,
            label = fmt.tprint("Close"),
            state = .None,
            menu_name = .EntityMenu,
        }
        append(&em.buttons, close)
    }
}

tear_down_menus :: proc(menus:^MenuState) {
    for &box in menus.boxes {
        delete(box.buttons)
        delete(box.text_elements)
    }
}

reset_menus :: proc(menus:^MenuState) {
    menus.boxes[.BuildingSelector].active = false
    menus.boxes[.EntityMenu].active = false
    for &box in menus.boxes {
        for &btn in box.buttons {
            btn.state = .None
        }
    }
}

render_menus :: proc(r:^Renderer, menus:MenuState, font:rawptr) {
    background :: Color{0.81, 0.81, 0.81, 1}
    dark_border :: Color{0.51, 0.51, 0.51, 1}
    light_border :: Color{1,1,1,1}
    for box in menus.boxes {
        if !box.active do continue
        c.queue_rect(r, box.rect, background)
        for text_el in box.text_elements {
            c.queue_text(r, text_el.text, font, text_el.rect, black)
        }
        for btn in box.buttons {
            if btn.state == .None {
                c.queue_rect(r, btn.rect, dark_border)
                c.queue_rect(r, btn.rect+{0,0,-2,-2}, light_border)
                c.queue_rect(r, btn.rect+{2,2,-2,-2}, background)
            } else {
                c.queue_rect(r, btn.rect, light_border)
                c.queue_rect(r, btn.rect+{0,0,-2,-2}, dark_border)
                c.queue_rect(r, btn.rect+{2,2,-2,-2}, background)
            }
            c.queue_text(r, btn.label, font, btn.rect+{15,15,0,0}, black)
        }
    }
}

handle_button_press :: proc(menus:^MenuState, btn:^Button) -> (InteractionMode, int){
    switch btn.menu_name {
    case .Null: {}
    case .EntityMenu: {
        CLOSE :: 0

        if btn.back_reference == CLOSE {
            reset_menus(menus)
            return .Map, 0
        }
    }
    case .InteractionModeSelector: {
        if btn.state == .Depressed {
            btn.state = .None
            if btn.sub_menu != .Null {
                menus.boxes[btn.sub_menu].active = false
            }
            return .Map, 0
        } else {
            for &other_b in menus.boxes[btn.menu_name].buttons {
                if other_b.state == .Depressed && other_b.back_reference != btn.back_reference {
                    other_b.state = .None
                    if other_b.sub_menu != .Null {
                        menus.boxes[other_b.sub_menu].active = false
                    }
                }
            }
            btn.state = .Depressed
            if btn.sub_menu != .Null {
                menus.boxes[btn.sub_menu].active = true
            }
            return InteractionMode(btn.back_reference), 0

        }
    }
    case .BuildingSelector: {
        btn.state = .Depressed
        return .Build, btn.back_reference
    }
    }
    panic("unreachable")
}

handle_menus_click :: proc(menus:^MenuState, pos:V2) -> (bool, InteractionMode, int) {
    for box in menus.boxes {
        if !box.active do continue
        if in_rect(pos, box.rect) {
            for &btn in box.buttons {
                if in_rect(pos, btn.rect) {
                    im, qual := handle_button_press(menus, &btn)
                    return true, im, qual
                }
            }
        }
    }
    return false, .Map, 0
}

setup_entity_menu :: proc(menus:^MenuState, e:^Entity) {
    em := &menus.boxes[.EntityMenu]
    clear(&em.text_elements)
    margins := Rect{2,2,-2,2}
    type := TextElement{
        rect = Rect{500, 100, 800, 250}+margins,
        text = fmt.tprint(e.type),
        menu_name = .EntityMenu
    }
    append(&em.text_elements, type)
}

activate_menu :: proc(menus:^MenuState, menu:MenuName) {
    menus.boxes[menu].active = true
}

deactivate_menu :: proc(menus:^MenuState, menu:MenuName) {
    menus.boxes[menu].active = false
}
