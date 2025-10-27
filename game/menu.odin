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
            label = "M",
            state = .None,
            menu_name = .InteractionModeSelector,
        }
        cut_trees_button := Button{
            rect = Rect{50,0,100,50}+margins,
            back_reference = int(InteractionMode.CutTrees),
            label = "T",
            state = .None,
            menu_name = .InteractionModeSelector,
        }
        build_button := Button{
            rect = Rect{100,0,150,50}+margins,
            back_reference = int(InteractionMode.Build),
            label = "B",
            state = .None,
            menu_name = .InteractionModeSelector,
            sub_menu = .BuildingSelector,
        }
        append(&os.buttons, mining_button)
        append(&os.buttons, cut_trees_button)
        append(&os.buttons, build_button)
    }

    {
        bs := &menus.boxes[.BuildingSelector]
        bs.rect = {100,50,300,100}
        bs.size = {1, 5}
        bs.active = false

        workshop_button := Button{
            rect = Rect{100,50,300,100}+margins,
            back_reference = int(EntityType.Workshop),
            label = "Workshop",
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
            label = "Close",
            state = .None,
            menu_name = .EntityMenu,
        }
        append(&em.buttons, close)
        te := TextElement {
            rect = Rect{500, 100, 800, 250}+margins,
            text = "This is a test of the menu text rendering",
            menu_name = .EntityMenu,
        }
        append(&em.text_elements, te)

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

render_menus :: proc(r:^Renderer, menus:MenuState) {
    for box in menus.boxes {
        if !box.active do continue
        c.queue_rect(r, box.rect, pink)
        for text_el in box.text_elements {
            c.queue_rect(r, text_el.rect, blue)
            c.queue_text(r, text_el.text, text_el.rect, white)
        }
        for btn in box.buttons {
            c.queue_rect(r, btn.rect, blue if btn.state == .None else red)
            c.queue_text(r, btn.label, btn.rect+{15,15,0,0}, white)
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
