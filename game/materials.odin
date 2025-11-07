package game

MaterialType :: enum { Nothing, Stone_Limestone, Stone_Magnetite, Wood_Oak }
MaterialForm :: enum { Natural, }

Material :: struct {
    type:MaterialType,
    form:MaterialForm,
    quantity:int,
    earmarked_for_use: bool,
}

is_wood := bit_set[MaterialType] {
    .Wood_Oak,
}

get_material_in_inventory :: proc(inv:[]Material, type:MaterialType) -> int {
    count := 0
    for m in inv {
        if m.type == type do count += m.quantity
    }
    return count
}
