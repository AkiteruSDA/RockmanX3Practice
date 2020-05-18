// Rockman X3 Practice ROM hack
// by Myria
//

arch snes.cpu

// LoROM org macro - see bass's snes-cpu.asm "seek" macro
macro reorg n
	org ((({n}) & 0x7f0000) >> 1) | (({n}) & 0x7fff)
	base {n}
endmacro

// Warn if the current address is greater than the specified value.
macro warnpc n
	{#}:
	if {#} > {n}
		warning "warnpc assertion failure"
	endif
endmacro

// Allows saving the current location and seeking somewhere else.
define savepc push origin, base
define loadpc pull base, origin

// Warn if the expression is false.
macro static_assert n
	if ({n}) == 0
		warning "static assertion failure"
	endif
endmacro


// Copy the original ROM to initialize the address space.
{reorg $008000}
incbin "RockmanX3-original.smc"


// Version tags
eval version_major 0
eval version_minor 8
eval version_revision 2
// Constants
eval stage_intro 0
eval stage_doppler1 9
eval stage_doppler2 10
eval stage_doppler3 11
eval stage_doppler4 12
eval game_config_size $1B
eval soundnum_cant_escape $5A
eval magic_sram_tag_lo $3358  // Combined, these say "X3PR"
eval magic_sram_tag_hi $5250
eval magic_config_tag_lo $3358  // Combined, these say "X3C1"
eval magic_config_tag_hi $3147
// RAM addresses
eval title_screen_option $7E003C
eval controller_1_current $7E00A8
eval controller_1_previous $7E00AA
eval controller_1_new $7E00AC
eval controller_2_current $7E00AE
eval controller_2_previous $7E00B0
eval controller_2_new $7E00B2
eval screen_control_shadow $7E00B4
eval nmi_control_shadow $7E00C3
eval hdma_control_shadow $7E00C4
eval rng_value $7E09D6
eval controller_1_disable $7E1F63
eval event_flags $7E1FB2
eval state_vars $7E1FA0
eval state_level_already_loaded $7E1FB6
//x3fixme eval current_level $7E1F7A
//x3fixme eval life_count $7E1F80
//x3fixme eval midpoint_flag $7E1F81
//x3fixme eval weapon_power $7E1F85
//x3fixme eval intro_completed $7E1F9B
eval config_selected_option $7EFF80
eval config_data $7EFFC0
eval config_shot $7EFFC0
eval config_jump $7EFFC1
eval config_dash $7EFFC2
eval config_select_l $7EFFC3
eval config_select_r $7EFFC4
eval config_menu $7EFFC5
eval config_bgm $7EFFC8   // unused in X2 and X3, but might as well reuse these
eval config_se $7EFFC9    // unused in X2 and X3, but might as well reuse these
eval config_sound $7EFFCA
eval spc_state_shadow $7EFFFE
// Temporary storage for load process.  Overlaps game use.
eval load_temporary_rng $7F0000
// ROM addresses
//x3fixme eval rom_play_music $80878B
eval rom_play_sound $01802B
//x3fixme eval rom_rtl_instruction $808798  // last instruction of rom_play_sound
//x3fixme eval rom_rts_instruction $8087D0  // last instruction of some part of rom_play_music
//x3fixme eval rom_nmi_after_pushes $808173
eval rom_nmi_after_controller $088621
eval ram_nmi_after_controller $7E2621  // RAM copy of rom_nmi_after_controller
//x3fixme eval rom_config_loop $80EAAA
//x3fixme eval rom_config_button $80EB55
//x3fixme eval rom_config_stereo $80EBE8
//x3fixme eval rom_config_bgm $80EC30
//x3fixme eval rom_config_se $80EC74
//x3fixme eval rom_config_exit $80ECC0
eval rom_default_config $06E0E4
eval rom_level_table $069C04
// SRAM addresses for saved states
eval sram_start $700000
eval sram_previous_command $700200
eval sram_wram_7E0000 $710000
eval sram_wram_7E8000 $720000
eval sram_wram_7F0000 $730000
eval sram_wram_7F8000 $740000
eval sram_vram_0000 $750000
eval sram_vram_8000 $760000
eval sram_cgram $772000
eval sram_oam $772200
eval sram_dma_bank $770000
eval sram_validity $774000
eval sram_saved_sp $774004
eval sram_saved_dp $774006
// SRAM addresses for general config.  These are at lower addresses to support
// emulators and cartridges that don't support 256 KB of SRAM.
eval sram_config_valid $700100
eval sram_config_game $700104   // Main game config.  game_config_size bytes.
eval sram_config_extra {sram_config_game} + {game_config_size}
eval sram_config_category {sram_config_extra} + 0
eval sram_config_route {sram_config_extra} + 1
eval sram_config_midpointsoff {sram_config_extra} + 2
eval sram_config_keeprng {sram_config_extra} + 3
eval sram_config_musicoff {sram_config_extra} + 4
eval sram_config_godmode {sram_config_extra} + 5
eval sram_config_extra_size 6   // adjust this as more are added
eval sram_banks $08
// Constants for categories and routing.
eval category_anyp 0
eval category_hundo 1 // change this to 1 when actual category selection implemented?
eval num_categories 2
eval route_anyp_default 0
eval route_hundo_default 0
eval num_routes_anyp 1
eval num_routes_hundo 1
// State table index offsets for special data.
eval state_entry_size 64
eval index_offset_vile_flag (10 * 2) + 0


// Header edits
{savepc}
	// Change SRAM size to 256 KB
	{reorg $00FFD8}
	db $08
{loadpc}


// Init hook
{savepc}
	{reorg $00800E}
	jml init_hook
{loadpc}

{savepc}
	{reorg $008ECC} // 216 diff
	// Change where Rockman starts on the title screen, which is hardcoded.
patch_title_rockman_default_location:
	lda.b #$A6
{loadpc}


{savepc}
	// Make the jump table for four options work correctly.
	// We delete the Password option, and the first three options all start
	// the game.  We simply read out title_screen_option later to distinguish
	// among those.  So a simple compare will suffice here!
	{reorg $008FE7}
patch_title_option_jump_table:
	cmp.b #2
	beq $009031 // options screen
	bra $008FF2 // game start
{loadpc}

{savepc}
	{reorg $008F55}
	// Call our routine when the title screen cursor moves.
patch_title_cursor_moved:
	jml title_cursor_moved
{loadpc}

{savepc}
	// 688 bytes available here
	{reorg $029D50}

// The player is moving the cursor on the title screen.  First things
// first: we now have a 4-element table instead of a 3-element table,
// so we have to move the table order to expand it.  As is typical, it's
// in bank 6, but it's only 4 bytes.
title_cursor_moved:
	lda.l title_rockman_location, x
	sta.w $7E09E0

	// Draw the currently-highlighted string.
	lda.b #$10  // Is this store required?
	sta.b $02

	lda.w {title_screen_option}
	rep #$20
	and.w #$00FF
	asl
	tax
	lda.l title_screen_string_table, x
	sta.b $10
	sep #$20

	// Engineer a near return to $008F63.
	pea ($008F63 - 1) & $FFFF
	// Jump to the middle of draw_string.
	jml $0086A3
{loadpc}
	
{savepc}
	// 640 bytes available in bank 6, an extremely-critical bank.
	{reorg $006FD80}

initial_menu_strings:
	// I'm too lazy to rework the compressed font, so I use this to overwrite
	// the ` character in VRAM.  The field used for the "attribute" of the
	// "text" just becomes the high byte of each pair of bytes.
	macro tilerow vrambase, rownum, col7, col6, col5, col4, col3, col2, col1, col0
		db 1, (({col7} & 2) << 6) | (({col6} & 2) << 5) | (({col5} & 2) << 4) | (({col4} & 2) << 3) | (({col3} & 2) << 2) | (({col2} & 2) << 1) | ({col1} & 2) | (({col0} & 2) >> 1)
		dw (({vrambase}) + (({rownum}) * 2)) >> 1
		db (({col7} & 1) << 7) | (({col6} & 1) << 6) | (({col5} & 1) << 5) | (({col4} & 1) << 4) | (({col3} & 1) << 3) | (({col2} & 1) << 2) | (({col1} & 1) << 1) | ({col0} & 1)
	endmacro

	macro optionset label, attrib1, attrib2, attrib3, attrib4
		db .option1_{label}_end - .option1_{label}_begin, {attrib1}
		// dw $1492 >> 1
		dw $1512 >> 1
	.option1_{label}_begin:
		db "ANY`"
	.option1_{label}_end:

		db .option2_{label}_end - .option2_{label}_begin, {attrib2}
		// dw $1512 >> 1
		dw $1592 >> 1
	.option2_{label}_begin:
		db "100`"
	.option2_{label}_end:

	// Readd once low% states added
	//	db .option3_{label}_end - .option3_{label}_begin, {attrib3}
	//	dw $1592 >> 1
	//.option3_{label}_begin:
	//	db "LOW`"
	//.option3_{label}_end:

		db .option4_{label}_end - .option4_{label}_begin, {attrib4}
		dw $1612 >> 1
	.option4_{label}_begin:
		db "OPTIONS"
	.option4_{label}_end:

		db 0
	endmacro

	{tilerow $0600, 0,   0,2,3,0,0,0,2,3}
	{tilerow $0600, 1,   2,3,2,3,0,2,3,0}
	{tilerow $0600, 2,   3,1,3,0,1,3,0,0}
	{tilerow $0600, 3,   0,3,0,1,3,0,0,0}
	{tilerow $0600, 4,   0,0,1,3,0,1,3,0}
	{tilerow $0600, 5,   0,2,3,0,2,3,2,3}
	{tilerow $0600, 6,   2,3,0,0,3,2,3,0}
	{tilerow $0600, 7,   3,0,0,0,0,3,0,0}

	// Menu text.  I've added an extra option versus the original and moved it
	// one tile to the left for better centering.  I also added the edition
	// text to the top.
	db .edition_end - .edition_begin, $28
	dw $138E >> 1
.edition_begin:
	db "- Practice Edition -"
.edition_end:

// Option set 1 can be overlapped with the tail of initial_menu_strings.
option_set_1:
	{optionset s1, $24, $20, $20, $20}
	db 0

option_set_2:
	{optionset s2, $20, $24, $20, $20}
	db 0
option_set_3:
	{optionset s3, $20, $20, $24, $20}
	db 0
option_set_4:
	{optionset s4, $20, $20, $20, $24}
	db 0

// Replacement copyright string.  @ in the X3 font is the copyright symbol.
copyright_string:
	db .rockman_x3_end - .rockman_x3_start, $20
	dw $1256 >> 1
.rockman_x3_start:
	db "ROCKMAN X3"
.rockman_x3_end:
	// The original drew a space then went back and drew a copyright symbol
	// over the space.  I don't see a need to do that - I'll draw a copyright
	// symbol in the first place.
	db .capcom_end - .capcom_start, $20
	dw $128C >> 1
.capcom_start:
	db "@ CAPCOM CO.,LTD.1995"
.capcom_end:
	// My custom message.  The opening quotation mark is flipped.
	db 1, $60
	dw $138E >> 1
	db '"'
	db .practice_end - .practice_start, $20
	dw $1390 >> 1
.practice_start:
	db "PRACTICE EDITION",'"'
.practice_end:
	db .credit_end - .credit_start, $20
	dw $144E >> 1
.credit_start:
	db "BY MYRIA, ECHOPIXEL,                AND AKITERU"
.credit_end:
	db .version_end - .version_start, $20
	dw $14CF >> 1
.version_start:
	db "2017-2020 Ver. "
	db $30 + {version_major}, '.', $30 + {version_minor}, $30 + {version_revision}
.version_end:
	// Terminates sequence of VRAM strings.
	db 0
{loadpc}

{savepc}
	// Overwrite the copyright string pointer.
	{reorg $068DA6}
	dw copyright_string

	// Overwrite the title screen string pointers with this one.
	{reorg $068DBA}
	dw initial_menu_strings
	dw initial_menu_strings
	dw initial_menu_strings
{loadpc}

{savepc}
	// 368 bytes available here
	{reorg $08DE90}

// Pointers to the option strings.
title_screen_string_table:
	dw option_set_1
	dw option_set_2
	//dw option_set_3
	dw option_set_4

// Y coordinates of Rockman corresponding to each option.
title_rockman_location:
	db $A6, $B6, $C6
{loadpc}
	
// Start of primary data bank (2B8000-2BE1FF)
{reorg $2B8000}


// Gameplay hacks.
incsrc "gameplay.asm"
// Stage select hacks.
incsrc "stageselect.asm"
// Config code.
incsrc "config.asm"
// Saved state code.
incsrc "savedstates.asm"


// The state table for each level is in statetable.asm.
incsrc "statetable.asm"

// End of primary data bank (2B8000-2BE1FF)
{warnpc $2BE200}
