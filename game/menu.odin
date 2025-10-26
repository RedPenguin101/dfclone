package game

import c "../common"

MenuName :: enum { Null, InteractionModeSelector, BuildingSelector }

UI :: struct {
    boxes : [MenuName]Menu,
}

UIButtonState :: enum { None, Depressed,}

Menu :: struct {
    rect:Rect,
    size:V2i,
    active:bool,
    buttons:[dynamic]UIButton,
}

UIButton :: struct {
    rect:Rect,
    back_reference:int,
    label:string,
    state:UIButtonState,
    menu_name:MenuName,
    sub_menu:MenuName,
}

setup_ui :: proc(ui:^UI) {
    // TODO: All this stuff should be in centimeters, as should the basis
    {
        os := &ui.boxes[.InteractionModeSelector]
        os.rect = {0,0,800,50}
        os.size = {6, 1}
        os.active = true

        margins := Rect{2,2,-2,-2}

        mining_button := UIButton{
            rect = Rect{0,0,50,50}+margins,
            back_reference = int(InteractionMode.Mine),
            label = "M",
            state = .None,
            menu_name = .InteractionModeSelector,
        }
        cut_trees_button := UIButton{
            rect = Rect{50,0,100,50}+margins,
            back_reference = int(InteractionMode.CutTrees),
            label = "T",
            state = .None,
            menu_name = .InteractionModeSelector,
        }
        build_button := UIButton{
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
        bs := &ui.boxes[.BuildingSelector]
        bs.rect = {100,50,300,100}
        bs.size = {1, 5}
        bs.active = false

        margins := Rect{2,2,-2,-2}

        workshop_button := UIButton{
            rect = Rect{100,50,300,100}+margins,
            back_reference = int(EntityType.Workshop),
            label = "Workshop",
            state = .None,
            menu_name = .BuildingSelector,
        }
        append(&bs.buttons, workshop_button)
    }
}

tear_down_ui :: proc(ui:^UI) {
    for &box in ui.boxes {
        delete(box.buttons)
    }
}

reset_ui :: proc(ui:^UI) {
    ui.boxes[.BuildingSelector].active = false
    for &box in ui.boxes {
        for &btn in box.buttons {
            btn.state = .None
        }
    }
}

render_ui :: proc(r:^Renderer, ui:UI) {
    for box in ui.boxes {
        if !box.active do continue
        c.queue_rect(r, box.rect, pink)
        for btn in box.buttons {
            c.queue_rect(r, btn.rect, blue if btn.state == .None else red)
            c.queue_text(r, btn.label, btn.rect.xy+{15,15}, white)
        }
    }
}

handle_button_press :: proc(ui:^UI, btn:^UIButton) -> (InteractionMode, int){
    switch btn.menu_name {
    case .Null: {}
    case .InteractionModeSelector: {
        if btn.state == .Depressed {
            btn.state = .None
            if btn.sub_menu != .Null {
                ui.boxes[btn.sub_menu].active = false
            }
            return .Map, 0
        } else {
            for &other_b in ui.boxes[btn.menu_name].buttons {
                if other_b.state == .Depressed && other_b.back_reference != btn.back_reference {
                    other_b.state = .None
                    if other_b.sub_menu != .Null {
                        ui.boxes[other_b.sub_menu].active = false
                    }
                }
            }
            btn.state = .Depressed
            if btn.sub_menu != .Null {
                ui.boxes[btn.sub_menu].active = true
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

handle_ui_click :: proc(ui:^UI, pos:V2) -> (bool, InteractionMode, int) {
    for box in ui.boxes {
        if !box.active do continue
        if in_rect(pos, box.rect) {
            for &btn in box.buttons {
                if in_rect(pos, btn.rect) {
                    im, qual := handle_button_press(ui, &btn)
                    return true, im, qual
                }
            }
        }
    }
    return false, .Map, 0
}
