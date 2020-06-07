//
// Gameplay-related hacks.
//


// Make "EXIT" always work.
{savepc}
	{reorg $00CEF4}
	// Nothing fancy here; just return 40 and make sure zero flag is clear.
	lda.b #$40
	and.b #$40
	rts
{loadpc}


// Disable interstage password screen.
{savepc}
	// Always use password screen state 3, which is used to exit to stage select.
	// States are offsets into a jump table, so they're multiplied by 2.
	{reorg $00EEF6}
	ldx.b #3 * 2
	// Disable fadeout, speeding this up.
	{reorg $00EFB1}
	nop
	nop
	nop
{loadpc}


// Disable stage intros.
{savepc}
	// beq 9A53 -> bra 9A53
	{reorg $009A60}
	bra $009A53
{loadpc}


// Disable weapon get screen.
{savepc}
	// Delete a conditional branch on skipping the "weapon get" scene.
	// beq 9DD5 -> bra 9DD5
	{reorg $009DD0}
	bra $009DD5
{loadpc}


// Disable several cutscenes.
// * Bit/Byte cutscene after beating two Mavericks.
// * Dr. Cain cutscene after beating all eight Mavericks.
// * Ending.
{savepc}
	// Skip over a bunch of checks and go to the simple case.
	{reorg $009DD8}
	bra $009E02
{loadpc}

// Hold L after entering midboss door to load Bit.
{savepc}
	{reorg $078F85}
	lda.l {controller_1_current}
	and.b #$10
	bne $078FB4
	lda.l {controller_1_current}
	and.b #$20
	beq $078FB4
	bra $078FB8
{loadpc}

// Hold R after entering midboss door to load Byte.
{savepc}
	{reorg $3CC486}
	lda.l {controller_1_current}
	and.b #$20
	bne $3CC4BE
	lda.l {controller_1_current}
	and.b #$10
	beq $3CC4BE
	bra $3CC4C2
{loadpc}

// Always allow player to exit capsule room in Doppler 3, regardless of mavs defeated.
{savepc}
	{reorg $39A2D5}
	nop
	nop
{loadpc}

// Do not set defeated bit for each maverick after finishing a refight.
{savepc}
	// Hornet
	{reorg $39A159}
	nop
	nop
	nop
	// Buffalo
	{reorg $03CDAA}
	nop
	nop
	nop
	// Seahorse
	{reorg $13E9D5}
	nop
	nop
	nop
	// Tiger
	{reorg $13E3B8}
	nop
	nop
	nop
	// Catfish
	{reorg $13F0CC}
	nop
	nop
	nop
	// Beetle
	{reorg $13F7CF}
	nop
	nop
	nop
	// Rhino
	{reorg $3FEB20}
	nop
	nop
	nop
	// Crawfish
	{reorg $03D5C1}
	nop
	nop
	nop
{loadpc}

// Reinitialize the stage timer and missile spawn type
// using RNG when Kaiser Sigma's state is changed to 02 on load (attack mode)
// to allow random patterns when loading state. This is because Kaiser Sigma uses the stage timer to
// decide when to shoot missiles (AND #$7F against it.), and RNG to decide which bullet to spawn first.
// The bullet spawn decision usually happens before X even starts walking during black screen.
{savepc}
	{reorg $859B2E}
	jsl reinit_kaiser_vals
{loadpc}
reinit_kaiser_vals:
	// Deleted code
	lda.b #$02
	sta.b $01

	// Honestly not really sure if this is called exclusively for Kaiser sigma's loading,
	// So I'm going to check the stage and not run this if not in Doppler 4
	lda.l {current_level}
	cmp.b #$0D // Doppler 4
	bne .done

	lda.l {rng_value}
	sta.l {stage_timer}
	and.b #$03
	sta.b $35 // Bullet type to spawn next, relative to kaiser enemy slot
.done:
	rtl
