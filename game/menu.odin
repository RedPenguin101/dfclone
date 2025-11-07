package game

import "core:fmt"

MenuName :: enum {
    Null,
    MainBar,
    BuildingSelector,
    MaterialSelection,
    EntityMenu,
}

ME_FREE_STACK : [dynamic]int

ButtonState :: enum { None, Depressed, }

MenuElement :: struct {
    id   : UIID,
    type : ElementType,
    rect : Rect,
    text : string,
    state : ButtonState,
    submenu : MenuName,
}

Menu :: struct {
    name : MenuName,
    rect : Rect,
    visible: bool,
    element_idx : [dynamic]int,
}

MenuState :: struct {
    menus : [MenuName]Menu,
    elements : [dynamic]MenuElement,
}

add_element :: proc(m:^MenuState, m_name:MenuName, el:MenuElement) {
    el := el
    current_els_in_menu := len(m.menus[m_name].element_idx)
    el.id = {int(m_name), current_els_in_menu}

    free_size := len(ME_FREE_STACK)
    idx : int
    if free_size > 0 {
        idx = ME_FREE_STACK[free_size-1]
        unordered_remove(&ME_FREE_STACK, free_size-1)
        m.elements[idx] = el
    } else {
        idx = len(m.elements)
        append(&m.elements, el)
    }
    append(&m.menus[m_name].element_idx, idx)
}

remove_element :: proc(m:^MenuState, menu_name:MenuName, idx:int) {
    me_idx := m.menus[menu_name].element_idx[idx]
    m.elements[me_idx] = {}
    append(&ME_FREE_STACK, me_idx)
    ordered_remove(&m.menus[menu_name].element_idx, idx)
}

clear_menu :: proc(m:^MenuState, menu_name:MenuName) {
    for el_idx in m.menus[menu_name].element_idx {
        m.elements[el_idx] = {}
        append(&ME_FREE_STACK, el_idx)
    }
    clear(&m.menus[menu_name].element_idx)
}

get_element_by_menu_idx :: proc(m:^MenuState, menu_name:MenuName, idx:int) -> ^MenuElement {
    i := m.menus[menu_name].element_idx[idx]
    return &m.elements[i]
}

update_text :: proc(el:^MenuElement, text:string) {
    el.text = text
}

setup_menus :: proc(m:^MenuState) {
    {
        main := &m.menus[.MainBar]
        main.name = .MainBar
        main.rect = {0, 0, 800, 50}
        main.visible = true
        btn_start := Rect{0,0,50,50}
        btn_delta := Rect{50,0,50,0}
        btn := MenuElement{
            type = .Button,
            rect = btn_start,
            text = fmt.tprint("M"),
        }
        add_element(m, .MainBar, btn)

        btn.rect += btn_delta
        btn.text = fmt.tprint("T")
        add_element(m, .MainBar, btn)

        btn.rect += btn_delta
        btn.text = fmt.tprint("B")
        btn.submenu = .BuildingSelector
        add_element(m, .MainBar, btn)

        btn.rect += btn_delta
        btn.text = fmt.tprint("S")
        btn.submenu = .Null
        add_element(m, .MainBar, btn)
    }
    {
        main := &m.menus[.BuildingSelector]
        main.name = .BuildingSelector
        main.rect = {200, 100, 600, 600}
        main.visible = false
        btn_start := Rect{0,0,300,50}
        btn_delta := Rect{0,50,0,50}
        btn := MenuElement{
            type = .Button,
            rect = btn_start,
            text = fmt.tprint("WORKSHOP"),
        }
        btn_start += btn_delta
        add_element(m, .BuildingSelector, btn)
        btn = MenuElement{
            type = .Button,
            rect = btn_start,
            text = fmt.tprint("CLOSE"),
        }
        add_element(m, .BuildingSelector, btn)
    }
    {
        main := &m.menus[.EntityMenu]
        main.name = .EntityMenu
        main.rect = {600, 0, 800, 640}
        main.visible = false
    }
    {
        main := &m.menus[.MaterialSelection]
        main.name = .MaterialSelection
        main.rect = {300, 200, 600, 640}
        main.visible = false
    }
}

populate_entity_menu :: proc(m:^MenuState, e:Entity) {
    clear_menu(m, .EntityMenu)
    btn_start := Rect{0,0,300,50}
    btn_delta := Rect{0,50,0,50}

    first := fmt.tprint(e.type)
    second : string
    third : string
    if e.type == .Building {
        second = fmt.tprint(e.building.status)
        third = fmt.tprint(e.building.deconstruction_percentage)
    } else if e.type == .Creature {
        second = fmt.tprint(e.creature.type)
        third = e.creature.name
    } else if e.type == .Material {
        second = fmt.tprint(e.material.type)
        third = ""
    }

    btn := MenuElement{
        type = .Text,
        rect = btn_start,
        text = first
    }
    add_element(m, .EntityMenu, btn)
    btn_start += btn_delta


    btn = MenuElement{
        type = .Text,
        rect = btn_start,
        text = second
    }
    add_element(m, .EntityMenu, btn)
    btn_start += btn_delta

    btn = MenuElement{
        type = .Text,
        rect = btn_start,
        text = third
    }
    add_element(m, .EntityMenu, btn)
    btn_start += btn_delta

    btn = MenuElement{
        type = .Button,
        rect = btn_start,
        text = fmt.tprint("CLOSE"),
    }
    add_element(m, .EntityMenu, btn)
}

all_buttons_up :: proc(m:^MenuState, name:MenuName) {
    for el_i in m.menus[name].element_idx {
        m.elements[el_i].state = .None
    }
}

tear_down_menus :: proc(m:^MenuState) {
    for &men in m.menus {
        delete(men.element_idx)
    }
    delete(m.elements)
}

null_menu_state :: proc(m:^MenuState) {
    for &menu in m.menus {
        if menu.name == .MainBar do continue
        menu.visible = false
    }
    all_buttons_up(m, .MainBar)
}

populate_material_selector :: proc(m:^MenuState, entities:[]Entity, indices:[]int) {
    btn_start := Rect{0,0,300,50}
    btn_delta := Rect{0,50,0,50}
    btn : MenuElement

    for idx in indices {
        type := entities[idx].material.type
        btn = MenuElement{
            type = .Button,
            rect = btn_start,
            text = fmt.tprintf("%v", type),
        }
        add_element(m, .MaterialSelection, btn)
        btn_start += btn_delta
    }

    btn.rect = btn_start
    btn.text = "Cancel"
    add_element(m, .MaterialSelection, btn)
}
