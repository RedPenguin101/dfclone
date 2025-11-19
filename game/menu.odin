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

MenuButtonState :: enum { None, Depressed, }

MenuElement :: struct {
	id   : UIID,
	type : ElementType,
	rect : TileRect,
	text : string,
	state : MenuButtonState,
	submenu : MenuName,
}

Menu :: struct {
	name : MenuName,
	rect : TileRect,
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
		delete(m.elements[el_idx].text)
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
		main.rect = {0, 0, COLS-1, 1}
		main.visible = true
		btn_start := TileRect{0,0,4,1}
		btn_delta := TileRect{5,0,5,0}
		btn := MenuElement{
			type = .Button,
			rect = btn_start,
			text = fmt.aprint("Mine"),
		}
		add_element(m, .MainBar, btn)

		btn.rect += btn_delta
		btn.text = fmt.aprint("Tree")
		add_element(m, .MainBar, btn)

		btn.rect += btn_delta
		btn.text = fmt.aprint("Bld")
		btn.submenu = .BuildingSelector
		add_element(m, .MainBar, btn)

		btn.rect += btn_delta
		btn.text = fmt.aprint("Stck")
		btn.submenu = .Null
		add_element(m, .MainBar, btn)
	}
	{
		main := &m.menus[.BuildingSelector]
		main.name = .BuildingSelector
		main.rect = {30, 5, 60, 20}
		main.visible = false
		btn_start := TileRect{0,0,30,1}
		btn_delta := TileRect{0,1,0,1}

		btn : MenuElement

		for buildable in is_workshop {
			btn = MenuElement{
				type = .Button,
				rect = btn_start,
				text = fmt.aprint(buildable),
			}
			btn_start += btn_delta
			add_element(m, .BuildingSelector, btn)
		}

		btn = MenuElement{
			type = .Button,
			rect = btn_start,
			text = fmt.aprint("CLOSE"),
		}
		add_element(m, .BuildingSelector, btn)
	}
	{
		main := &m.menus[.MaterialSelection]
		main.name = .MaterialSelection
		main.rect = {30, 5, 60, 20}
		main.visible = false
	}
	{
		main := &m.menus[.EntityMenu]
		main.name = .EntityMenu
		main.rect = {30, 5, 60, 20}
		main.visible = false
	}
}

populate_building_menu :: proc(m:^MenuState, e:Entity) {
	clear_menu(m, .EntityMenu)
	btn_start := TileRect{0,0,30,1}
	btn_delta := TileRect{0,1,0,1}

	first := fmt.aprint(e.type)
	second := fmt.aprint(e.building.status)
	third := fmt.aprint(e.building.deconstruction_percentage)

	btn := MenuElement{
		type = .Text,
		rect = btn_start,
		text = first
	}
	add_element(m, .EntityMenu, btn)
	btn_start += btn_delta

	btn.rect = btn_start
	btn.text = second
	add_element(m, .EntityMenu, btn)

	btn_start += btn_delta
	btn.rect = btn_start
	btn.text = third
	add_element(m, .EntityMenu, btn)
	btn_start += btn_delta

	btn.type = .Button
	btn.rect = btn_start
	btn.text = fmt.aprint("DECONSTRUCT")
	add_element(m, .EntityMenu, btn)
	btn_start += btn_delta

	btn.rect = btn_start
	btn.text = fmt.aprint("CLOSE")
	add_element(m, .EntityMenu, btn)
	btn_start += btn_delta
}

populate_entity_menu :: proc(m:^MenuState, e:Entity) {
	if e.type == .Building {
		populate_building_menu(m, e)
		return
	}
	clear_menu(m, .EntityMenu)
	btn_start := TileRect{0,0,30,1}
	btn_delta := TileRect{0,1,0,1}

	first := fmt.aprint(e.type)
	second : string
	third : string
	if e.type == .Creature {
		second = fmt.aprint(e.creature.type)
		third = e.creature.name
	} else if e.type == .Material {
		second = fmt.aprint(e.material.type)
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
		text = fmt.aprint("CLOSE"),
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
	for el in m.elements {
		delete(el.text)
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
	btn_start := TileRect{0,0,30,1}
	btn_delta := TileRect{0,1,0,1}
	btn : MenuElement

	for idx in indices {
		type := entities[idx].material.type
		btn = MenuElement{
			type = .Button,
			rect = btn_start,
			text = fmt.aprintf("%v", type),
		}
		add_element(m, .MaterialSelection, btn)
		btn_start += btn_delta
	}

	btn.rect = btn_start
	btn.text = fmt.aprint("Cancel")
	add_element(m, .MaterialSelection, btn)
}
