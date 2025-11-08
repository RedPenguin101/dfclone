package game

OrderType :: enum { Null, Mine, CutTree, Construct, Deconstruct }
OrderStatus :: enum { Unassigned, Assigned, Completed }

Order :: struct {
    type : OrderType,
    status : OrderStatus,
    pos : V3i,
    target_entity_idx: int,
    creation_time:f32,
}

OrderQueue :: struct {
    orders : [dynamic]Order
}

destroy_order_queue :: proc(q:^OrderQueue) {
    delete(q.orders)
}

add_order :: proc(q:^OrderQueue, type:OrderType, pos:V3i, entity_idx:=0) -> int {
    if type == .CutTree {
        assert(entity_idx != 0)
    }
    order := Order{type, .Unassigned, pos, entity_idx, 0.0}
    existing, _ := get_order_at_position(q^, pos)

    if existing > 0 {
        // TODO: Should check if something else has been assigned this and cancel it if so
        // replace the existing order
        q.orders[existing] = order
        return existing
    }
    l := len(q.orders)
    append(&q.orders, order)
    return l
}

get_order_at_position :: proc(q:OrderQueue, pos:V3i) -> (int, Order) {
    // TODO: Probably should make more efficient lookup - hash?
    for order, i in q.orders {
        if order.pos == pos {
            return i, order
        }
    }
    return 0, {}
}

get_unassigned_order :: proc(q:^OrderQueue) -> (int, ^Order) {
    for &order, i in q.orders {
        if order.type != .Null && order.status == .Unassigned {
            return i, &order
        }
    }
    return 0, nil
}

complete_order :: proc(q:^OrderQueue, i:int) {
    unordered_remove(&q.orders, i)
}
