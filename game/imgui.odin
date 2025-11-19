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
