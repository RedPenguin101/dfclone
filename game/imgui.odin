package game

import "../common"

UIID :: struct {
    menu_idx: int,
    element_idx : int
}

ElementType :: enum { Null, Button, Text }

active : UIID
hot : UIID
NULL_UIID :: UIID{0,0}

do_text :: proc(id:UIID, plot_fn:common.PlatformPlotTileFn, rect:TileRect, text:string) {
    rect := rect
    main :: Color{0.81, 0.81, 0.81, 1}

	dims := rect_dims(rect)
	l_pad := (dims.x-len(text))/2

	for x in 0..<dims.x {
		for y in 0..<dims.y {
			loc := V2i{x+rect.x, y+rect.y}
			text_x := x-l_pad
			if text_x >= 0 && text_x < len(text) {
				rune := text[text_x]
				glyph := common.DisplayGlyph(int(rune))
				plot_fn(loc, black, main, glyph)
			} else {
				plot_fn(loc, black, main, .BLANK)
			}
		}
	}
}

do_button :: proc(id:UIID, plot_fn:common.PlatformPlotTileFn, mouse:common.MouseInput, rect:TileRect, text:string, depressed:bool) -> bool {
	result := false

	if in_rect(mouse.tile, rect) {
        hot = id
    }

	if id == active {
        result = true
        active = NULL_UIID
    } else if id == hot {
        if pressed(mouse.lmb) {
            active = id
        }
    }

	main :: Color{0.81, 0.81, 0.81, 1}
    dark :: Color{0.51, 0.51, 0.51, 1}
    background := main
    text_col := black
	if depressed {
        background = dark
		text_col = white
    }
    if id == hot && !depressed {
        background = Color{0,0,0.5,1}
        text_col = white
    }

	dims := rect_dims(rect)
	l_pad := (dims.x-len(text))/2

	for x in 0..<dims.x {
		for y in 0..<dims.y {
			loc := V2i{x+rect.x, y+rect.y}
			text_x := x-l_pad
			if text_x >= 0 && text_x < len(text) {
				rune := text[text_x]
				glyph := common.DisplayGlyph(int(rune))
				plot_fn(loc, text_col, background, glyph)
			} else {
				plot_fn(loc, text_col, background, .BLANK)
			}
		}
	}

	return result
}
