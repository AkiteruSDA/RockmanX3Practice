//
// Configuration hacks
//

// New additions to string table.  This table has reserved entries not being used.
{savepc}
	{reorg {rom_bank84_string_table}}
string_table:
	macro stringtableentry label
		.idcalc_{label}:
			dw (string_{label}) & $FFFF
		eval stringid_{label} ((string_table.idcalc_{label} - string_table) / 2) + {num_used_string_table}
	endmacro

	{stringtableentry keeprng_normal}
	{stringtableentry keeprng_highlighted}
	{stringtableentry keeprng_off}
	{stringtableentry keeprng_on}
{loadpc}

{savepc}
	{reorg $80E9E4}
	jml config_menu_start_hook

	// Hack draw_string to use our custom table.
	{reorg $808691}
	jmp draw_string_hack

	// Use our alternate table for unhighlighted string IDs.
	//DB = 06 here, which is why config_unhighlighted_string_ids is in bank 86 (mirror)
	{reorg $80EA8F}
	lda.w config_unhighlighted_string_ids,x
	{reorg $80EAAC}
	lda.w config_unhighlighted_string_ids,x

	// 480 bytes available here
	// Putting config string shit here cause I don't wanna frig with banks too much.
	{reorg $86FBA0}
config_menu_start_hook:
	// We enter with A/X/Y 8-bit and bank set to $86 (our code bank)
	// Deleted code.  We need to do this first, or 8162 fails.
	lda.b #7
	tsb.w $7E00A3

	ldx.b #0
.string_loop:
	lda.w config_menu_extra_string_table, x
	phx
	beq .string_flush
	cmp.b #$FF
	beq .special
	jsl trampoline_808691
	bra .string_next
.special:
	// Call a function
	inx
	clc   // having carry clear is convenient for these functions
	jsr (config_menu_extra_string_table, x)
	jsl trampoline_808691
	plx
	inx
	inx
	bra .special_resume
.string_flush:
	jsl trampoline_808162
.string_next:
	plx
.special_resume:  // save 1 byte by using the extra inx here
	inx
	cpx.b #config_menu_extra_string_table.end - config_menu_extra_string_table
	bne .string_loop

	jml $80E9E9

// Table of static strings to render at config screen load time.
config_menu_extra_string_table:
	// Extra call to 8162 to execute and flush the draw buffer before our first
	// string, otherwise we end up drawing too much.
	db $00
	// Selectable option labels.
	db {stringid_keeprng_normal}
	//db $00  // flush
	// Extra option values.
	db $FF
	dw config_get_stringid_keeprng
	db $00  // flush
	db $27  // EXIT
	// We return to a flush call.
.end:

config_get_stringid_keeprng:
	lda.l {sram_config_keeprng}
	and.b #$01
	adc.b #{stringid_keeprng_off}
	rts

// Trampoline for calling $808162  (flush string draw buffer?)
trampoline_808162:
	pea ({rom_rtl_instruction} - 1) & 0xFFFF
	jml $808162
// Trampoline for calling $808691  (draw string)
trampoline_808691:
	pea ({rom_rtl_instruction} - 1) & 0xFFFF
	jml $808691

config_unhighlighted_string_ids:
	db $23 // SHOT
	db $25 // JUMP
	db $27 // DASH
	db $29 // SELECT_L
	db $2B // SELECT_R
	db $2D // MENU
	db $2F // STEREO/MONO
	db {stringid_keeprng_normal}
	db $2F // EXIT?? Not sure why this isn't different to stereo/mono.
{loadpc}


{savepc}
	// Increase number of options.
	{reorg $80EA6B}
	lda.b #((config_option_jump_table.end - config_option_jump_table) / 3) - 1
	{reorg $80EA73}
	cmp.b #(config_option_jump_table.end - config_option_jump_table) / 3

	// Use config_option_jump_table instead of the built-in one.
	// Note that we can overwrite the config table.
	{reorg $80EAD0}
	// clc not necessary because of asl of small value
	adc.l {config_selected_option}
	tax
	lda.l config_option_jump_table + 2, x
	pha
	rep #$20
	lda.l config_option_jump_table + 0, x
	pha
	sep #$20
	rtl
{loadpc}
{savepc}
	// Big ol block here. Big ol block
	{reorg $80FE00}
config_option_jump_table:
	// These are minus one due to using RTL to jump to them.
	dl {rom_config_button} - 1
	dl {rom_config_button} - 1
	dl {rom_config_button} - 1
	dl {rom_config_button} - 1
	dl {rom_config_button} - 1
	dl {rom_config_button} - 1
	dl {rom_config_stereo} - 1
	dl config_code_keeprng - 1
	dl {rom_config_exit} - 1
.end:

config_code_keeprng:
	lda.b #2
	ldx.b #{sram_config_keeprng} - {sram_config_extra}
	ldy.b #{stringid_keeprng_off}
	bra config_extra_toggle

// Shared routines for simple selections.
// A = number of options available.
// X = index into sram_config_extra.
// Y = string ID of default (zero) option.
config_extra_toggle:
	// Save A to give us room to work.
	pha
	// Was left or right pressed?
	lda.b {controller_1_new} + 1
	and.b #$03
	beq .no_change
	cmp.b #$03
	beq .no_change
	// Determine left versus right.
	lsr
	lda.l {sram_config_extra}, x
	bcc .left
.right:
	// Increment the setting.
	inc
	cmp 1, s
	bcc .right_no_overflow
	lda.b #0
.right_no_overflow:
	bra .left_no_underflow
.left:
	// Decrement the setting.
	dec
	bpl .left_no_underflow
	lda 1, s
	dec
.left_no_underflow:
	// Save the setting.
	sta.l {sram_config_extra}, x
	// Determine the string number by adding Y to A.
	sta 1, s
	tya
	clc
	adc 1, s
.draw_string:
	jsl trampoline_808691
.no_change:
	pla   // remove saved A
	jsl trampoline_808162
	jml {rom_config_loop}

// Helper pieces of code for config routines.
config_helpers:
.draw_string:
	jsl trampoline_808691
.no_change:
	jsl trampoline_808162
	jml {rom_config_loop}

draw_string_hack:
	// This assumes that we stay in bank 80.
	// Overwritten code
	sep #$30
	sta.b $02
	and.b #$7F    // might change this if we need more than 127 strings
	asl
	tay
	// Is this one of our extra strings?
	cpy.b #{num_used_string_table} * 2
	bcc .old_table
	// Switch to the other bank.
	phb
	pea ({rom_bank84_string_table} >> 16) * $0101
	plb
	plb
	// Refer to the new table instead.
	lda {rom_bank84_string_table} - ({num_used_string_table} * 2), y
	sta.b $10
	lda {rom_bank84_string_table} - ({num_used_string_table} * 2) + 1, y
	sta.b $11
	// Return to original code.
	plb
	jmp $8086A3
.old_table:
	// Use the original code.
	jmp $808699 + 0 // The "+ 0" was necessary to compile for some reason. bass bug?
{loadpc}

{savepc}
	// Option Mode position hacks

	// Do not draw borders, only draw highlighted menu headers, move SOUND MODE up
	{reorg $86917B}
	{option_string .key_config_normal, "KEY CONFIG", $11D6, $34, 1}
	{reorg $86919E}
	db $00 // Terminating the string sections immediately with these
	{reorg $8691EF}
	db $00
	{reorg $86920E}
	{option_string .key_config_highlighted, "KEY CONFIG", $11D6, $34, 1}
	{reorg $869231}
	db $00
	{reorg $869282}
	db $00
	{reorg $8692A1}
	{option_string .sound_mode_normal, "SOUND MODE", $1417, $34, 0}
	{option_string .misc_normal, "MISC", $151C, $34, 1}
	{reorg $8692C4}
	db $00
	{reorg $8692E3}
	db $00
	{reorg $869302}
	{option_string .sound_mode_highlighted, "SOUND MODE", $1417, $34, 0}
	{option_string .misc_highlighted, "MISC", $151C, $34, 1}
	{reorg $869325}
	db $00
	{reorg $869344}
	db $00

	//Move STEREO/MONAURAL and EXIT up
	// Stereo/Mono
	{reorg $8693F3}
	dw $1498 >> 1
	{reorg $869400}
	dw $1498 >> 1
	{reorg $86940D}
	dw $1498 >> 1
	{reorg $86941A}
	dw $1498 >> 1

	// Exit
	{reorg $8693E1}
	dw $165C >>1
	{reorg $8693EA}
	dw $165C >>1
{loadpc}

// Returns whether configuration is saved in the zero flag.
// Must be called with 16-bit A!
is_config_saved:
	// Check magic values.
	lda.l {sram_config_valid}
	cmp.w #{magic_config_tag_lo}
	bne .not_saved
	lda.l {sram_config_valid} + 2
	cmp.w #{magic_config_tag_hi}
	bne .not_saved

	// Check for bad extra configuration.
	// Loads both route and category since A is 16-bit.
	lda.l {sram_config_category}  // also sram_config_route
	sep #$20
	// Validate category.  XBA will get the route.
	cmp.b {num_categories}
	// beq .category_anyp
	beq .category_hundo
	bra .not_saved

// I think this code is for if there's a route select in the options menu.
// For this version (low% added) there is just a title option so I'm not changing anything here right now.

.category_anyp:
	xba
	cmp.b #{num_routes_anyp}
	bcc .not_saved
	bra .routing_ok
	
.category_hundo:
	xba
	cmp.b #{num_routes_hundo}
	bcc .not_saved
	bra .routing_ok

.routing_ok:
	// These are simple Boolean flags.
	rep #$20
	lda.l {sram_config_midpointsoff}  // also sram_config_keeprng
	and.w #~($0101)
	bne .not_saved
	lda.l {sram_config_musicoff}  // also sram_config_godmode
	and.w #~($0101)
	beq .saved
.not_saved:
	rep #$22  // clear zero flag in addition to setting A = 16-bit again.
.saved:
	rts


// Hook the initialization of the configuration data, to provide saving
// the configuration in SRAM.
{savepc}
	{reorg $0082FA}
	// config_init_hook changes the bank.
	phb
	jsl config_init_hook
	plb
	bra $008307
{loadpc}
config_init_hook:
	// Check for L + R on the controller as a request to wipe SRAM.
	lda.l {controller_1_current}
	and.b #$30
	cmp.b #$30
	bne .dont_wipe_sram
	jsr config_wipe_sram
.dont_wipe_sram:

	// The controller configuration was not in RAM, so initialize it.
	// We want to use the data from SRAM in this case - if any.
	rep #$30
	jsr is_config_saved
	bne .not_saved

	// Config was saved, so load from SRAM.
	lda.w #({sram_config_game} >> 16)
	ldy.w #{sram_config_game}
	bra .initialize

.not_saved:
	// Config was not saved, so set to default.
	// Set our extra config to default.
	sep #$30
	lda.b #0
	ldx.b #0
.extra_default_loop:
	sta.l {sram_config_extra}, x
	inx
	cpx.b #{sram_config_extra_size}
	bne .extra_default_loop
	rep #$30

	// Copy from ROM's default config to game config.
	lda.w #({rom_default_config} >> 16)
	ldy.w #{rom_default_config}

.initialize:
	// Keep X/Y at 16-bit for now.
	sep #$20
	// Set bank as specified.
	pha
	plb
	// Copy configuration from either ROM or SRAM.
	ldx.w #0
.initialize_loop:
	lda $0000, y
	sta.l {config_data}, x
	iny
	inx
	cpx.w #{game_config_size}
	bcc .initialize_loop

	// Save configuration if needed.
	sep #$30
	bra maybe_save_config


// Save configuration if different or unset.
// Called with JSL.
maybe_save_config:
	php

	// If config not saved at all, save now.
	rep #$20
	jsr is_config_saved
	sep #$30
	bne .do_save

	// Otherwise, check whether different.
	// It's bad to continuously write to SRAM because an SD2SNES will then
	// constantly write to the SD card.
	ldx.b #0
.check_loop:
	// Ignore changes to the BGM and SE values.  The game resets them anyway.
	cpx.b #{config_bgm} - {config_data}
	beq .check_skip
	cpx.b #{config_se} - {config_data}
	beq .check_skip
	lda.l {config_data}, x
	cmp.l {sram_config_game}, x
	bne .do_save
.check_skip:
	inx
	cpx.b #{game_config_size}
	bcc .check_loop

.return:
	plp
	rtl

	// We should save.
.do_save:
	// Clear the magic value during the save.
	rep #$20
	lda.w #0
	sta.l {sram_config_valid} + 0
	sta.l {sram_config_valid} + 2
	// Copy config to SRAM.
	sep #$30
	ldx.b #0
.save_loop:
	lda.l {config_data}, x
	sta.l {sram_config_game}, x
	inx
	cpx.b #{game_config_size}
	bcc .save_loop

	// Set the magic value.
	rep #$20
	lda.w #{magic_config_tag_lo}
	sta.l {sram_config_valid} + 0
	lda.w #{magic_config_tag_hi}
	sta.l {sram_config_valid} + 2

	// Done.
	bra .return


// Wipe SRAM on request.
config_wipe_sram:
	php
	phb
	rep #$30
	lda.w #0
	ldx.w #({sram_start} >> 16) * $0101
.outer_loop:
	phx
	plb
	plb
	ldy.w #0
	tya
.inner_loop:
	sta 0, y
	iny
	iny
	bpl .inner_loop
	txa
	clc
	adc.w #$0101
	tax
	cmp.w #(({sram_start} >> 16) + {sram_banks}) * $0101
	bne .outer_loop
	plb
	plp
	rts
