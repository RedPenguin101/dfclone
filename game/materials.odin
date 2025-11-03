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
