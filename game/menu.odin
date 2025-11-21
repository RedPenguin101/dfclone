package game

import "core:fmt"

text :: fmt.aprint
textf :: fmt.aprintf

MenuName :: enum {
	Null,
	MainBar,
	BuildingSelector,
	MaterialSelection,
	EntityMenu,
	WorkOrderMenu,
	AddWorkOrderMenu,
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
			text = text("Mine"),
		}
		add_element(m, .MainBar, btn)

		btn.rect += btn_delta
		btn.text = text("Tree")
		add_element(m, .MainBar, btn)

		btn.rect += btn_delta
		btn.text = text("Bld")
		btn.submenu = .BuildingSelector
		add_element(m, .MainBar, btn)

		btn.rect += btn_delta
		btn.text = text("Stck")
		btn.submenu = .Null
		add_element(m, .MainBar, btn)

		btn.rect += btn_delta
		btn.text = text("Ord")
		btn.submenu = .WorkOrderMenu
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
				text = text(buildable),
			}
			btn_start += btn_delta
			add_element(m, .BuildingSelector, btn)
		}

		btn = MenuElement{
			type = .Button,
			rect = btn_start,
			text = text("CLOSE"),
		}
		add_element(m, .BuildingSelector, btn)
	}
	for name in MenuName {
		m.menus[name].name = name
	}
}

populate_building_menu :: proc(m:^MenuState, e:Entity) {
	clear_menu(m, .EntityMenu)
	m.menus[.EntityMenu].rect = {30, 5, 60, 20}
	btn_start := TileRect{0,0,30,1}
	btn_delta := TileRect{0,1, 0,1}

	first  := text(e.building.type)
	second := text(e.building.status)

	btn := MenuElement{
		type = .Text,
		rect = btn_start,
		text = first
	}
	// prevent overlap with cross
	btn.rect.z -= 1
	add_element(m, .EntityMenu, btn)
	btn.rect.z += 1
	btn_start += btn_delta

	btn.rect = btn_start
	btn.text = second
	add_element(m, .EntityMenu, btn)

	btn.type = .Button
	btn.rect = btn_start
	btn.text = text("Deconstruct")
	add_element(m, .EntityMenu, btn)
	btn_start += btn_delta

	btn.rect = {29,0,30,1}
	btn.text = text("X")
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

	first := text(e.type)
	second : string
	third : string
	if e.type == .Creature {
		second = text(e.creature.type)
		third = e.creature.name
	} else if e.type == .Material {
		second = text(e.material.type)
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
		text = text("CLOSE"),
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
	m.menus[.MaterialSelection].rect = {30, 5, 60, 20}
	btn_start := TileRect{0,0,30,1}
	btn_delta := TileRect{0,1,0,1}
	btn : MenuElement

	for idx in indices {
		type := entities[idx].material.type
		btn = MenuElement{
			type = .Button,
			rect = btn_start,
			text = textf("%v", type),
		}
		add_element(m, .MaterialSelection, btn)
		btn_start += btn_delta
	}

	btn.rect = btn_start
	btn.text = text("Cancel")
	add_element(m, .MaterialSelection, btn)
}

populate_order_menu :: proc(m:^MenuState, oq:^OrderQueue) -> []int {
	wom := MenuName.WorkOrderMenu
	clear_menu(m, wom)
	m.menus[wom].rect = {30, 5, 60, 20}

	add_element(m, wom, {type=.Button, rect={29,0,30,1}, text=text("X")})

	btn_start := TileRect{0, 0, 29, 1}
	next_row := TileRect{0,1,0,1}

	qty_btn := TileRect{25, 1, 27, 2}
	add_btn := TileRect{27, 1, 28, 2}
	dec_btn := TileRect{28, 1, 29, 2}
	cnl_btn := TileRect{29, 1, 30, 2}

	btn := MenuElement{
		type = .Text,
		rect = btn_start,
		text = text("Work Orders")
	}
	add_element(m, wom, btn)

	btn.rect.z -= 4

	ret := make([dynamic]int)
	for i in 0..<len(oq.orders)
	{
		order := &oq.orders[i]
		if order.type != .Produce do continue
		append(&ret, i)
		btn.rect += next_row
		btn.type = .Text
		btn.text = text(ProductionType(order.target_idx))
		add_element(m, wom, btn)
		add_element(m, wom, {type=.Text,   rect=qty_btn, text=text(order.target_count)})

		add_element(m, wom, {type=.Button, rect=add_btn, text=text("+")})
		add_element(m, wom, {type=.Button, rect=dec_btn, text=text("-")})
		add_element(m, wom, {type=.Button, rect=cnl_btn, text=text("x")})
		qty_btn += next_row
		add_btn += next_row
		dec_btn += next_row
		cnl_btn += next_row
	}

	btn.rect.z += 5
	btn.type = .Button
	btn.rect += next_row
	btn.text = text("New")
	add_element(m, wom, btn)
	m.menus[wom].visible = true
	return ret[:]
}

populate_place_order_menu :: proc(m:^MenuState) {
	pom := MenuName.AddWorkOrderMenu
	clear_menu(m, pom)
	m.menus[pom].rect = {30, 5, 60, 20}

	add_element(m, pom, {type=.Button, rect={29,0,30,1}, text=text("X")})

	btn_start := TileRect{0, 0, 29, 1}
	next_row := TileRect{0,1,0,1}

	btn := MenuElement{
		type = .Text,
		rect = btn_start,
		text = text("Add Work Order")
	}
	add_element(m, pom, btn)

	btn.type = .Button
	btn.rect.z += 1

	for pt in ProductionType
	{
		btn.rect += next_row
		btn.text = text(pt)
		add_element(m, pom, btn)
	}

	m.menus[pom].visible = true
}
