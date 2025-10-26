package game

import c "../common"

UserAction :: enum { None, Mine, CutTrees }

UIButtonBoxName :: enum { OrderSelector }

UI :: struct {
    boxes : [UIButtonBoxName]UIButtonBox,
    selected_action : UserAction,
}

UIButtonState :: enum { None, Depressed,}
UIButtonType :: enum { OrderSelector }

UIButtonBox :: struct {
    rect:Rect,
    size:V2i,
    visible:bool,
    buttons:[dynamic]UIButton,
}

UIButton :: struct {
    rect:Rect,
    type:UIButtonType,
    back_reference:int,
    label:string,
    state:UIButtonState,
    box_name:UIButtonBoxName,
}

setup_ui :: proc(ui:^UI) {
    // TODO: All this stuff should be in centimeters, as should the basis
    os := &ui.boxes[.OrderSelector]
    os.rect = {0,0,800,50}
    os.size = {6, 1}
    os.visible = true

    margins := Rect{2,2,-2,-2}

    mining_button := UIButton{
        rect = Rect{0,0,50,50}+margins,
        type = .OrderSelector,
        back_reference = int(UserAction.Mine),
        label = "M",
        state = .None,
        box_name = .OrderSelector,
    }
    cut_trees_button := UIButton{
        rect = Rect{50,0,100,50}+margins,
        type = .OrderSelector,
        back_reference = int(UserAction.CutTrees),
        label = "T",
        state = .None,
        box_name = .OrderSelector,
    }
    append(&os.buttons, mining_button)
    append(&os.buttons, cut_trees_button)
}

tear_down_ui :: proc(ui:^UI) {
    for &box in ui.boxes {
        delete(box.buttons)
    }
}

render_ui :: proc(r:^Renderer, ui:UI) {
    for box in ui.boxes {
        c.queue_rect(r, box.rect, pink)
        for btn in box.buttons {
            c.queue_rect(r, btn.rect, blue if btn.state == .None else red)
            c.queue_text(r, btn.label, btn.rect.xy+{15,15}, white)
        }
    }
}

handle_button_press :: proc(ui:^UI, btn:^UIButton) {
    if btn.state == .Depressed {
        btn.state = .None
        ui.selected_action = .None
        return
    }
    box := btn.box_name
    for &other_b in ui.boxes[box].buttons {
        if other_b.state == .Depressed && other_b.back_reference != btn.back_reference {
            other_b.state = .None
        }
    }
    if box == .OrderSelector {
        ui.selected_action = UserAction(btn.back_reference)
    }
    btn.state = .Depressed
}

handle_ui_click :: proc(ui:^UI, pos:V2) -> bool {
    for box in ui.boxes {
        if in_rect(pos, box.rect) {
            for &btn in box.buttons {
                if in_rect(pos, btn.rect) {
                    handle_button_press(ui, &btn)
                    return true
                }
            }
        }
    }
    return false
}
