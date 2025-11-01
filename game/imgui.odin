package game

import c "../common"

UIID :: struct {
    menu_idx: int,
    element_idx : int
}

ElementType :: enum { Null, Button, Text }

active : UIID
hot : UIID
NULL_UIID :: UIID{0,0}

do_text :: proc(id:UIID, r:^Renderer, font:rawptr, rect:Rect, text:string) {
    rect := rect
    main :: Color{0.81, 0.81, 0.81, 1}
    dark_border :: Color{0.51, 0.51, 0.51, 1}
    light_border :: Color{1,1,1,1}
    r.current_basis = .menus
    {
        c.queue_rect(r, rect, main)
        rect.x += 3
        c.queue_text(r, text, font, rect, black)
    }
    r.current_basis = .screen
}

do_button :: proc(id:UIID, mouse:c.MouseInput, r:^Renderer, font:rawptr, rect:Rect, text:string, depressed:=false) -> bool {
    result := false
    rect := rect

    if in_rect(mouse.raw, rect) {
        hot = id
    }

    if id == active {
        result = true
        active = NULL_UIID
    } else if id == hot {
        if c.pressed(mouse.lmb) {
            active = id
        }
    }

    main :: Color{0.81, 0.81, 0.81, 1}
    dark_border :: Color{0.51, 0.51, 0.51, 1}
    light_border :: Color{1,1,1,1}
    top_col := light_border
    btm_col := dark_border
    background := main
    text_col := black
    if depressed {
        top_col = dark_border
        btm_col = light_border
    }
    if id == hot && !depressed {
        background = Color{0,0,0.5,1}
        text_col = white
    }

    r.current_basis = .menus
    {
        c.queue_rect(r, rect, btm_col)
        rect += {0,0,-2,-2}
        c.queue_rect(r, rect, top_col)
        rect += {2,2,0,0}
        c.queue_rect(r, rect, background)
        // TODO: Button Text centering
        rect.x += 3
        c.queue_text(r, text, font, rect, text_col)
    }
    r.current_basis = .screen

    return result
}
