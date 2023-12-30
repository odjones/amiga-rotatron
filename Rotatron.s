;
; Cool demo based on Rotatron on the C64!
;
; Written by Oliver D. Jones (Chainsaw Baron) - September 1995.
;
; Copyright © 1995 by Funny Farm Software
;                 and The Chainsaw Baron.
;
; You can alter the number of rings, and the degree step for all rings drawn
; by modifying the lines below in the Program setup section. But when adding
; rings, make sure you add the Speed and Offset data for each ring, this can
; be found in the Ring data section.
;
; ** Warning: It takes over your machine - so watch out!! **
;
; -- Program setup: -----------------------------------------------------------

rings     = 4                           Four rings on screen
step      = 12                          12° step (Warning: Must go into 360°)

          include   hardware/custom.i   Hardware include file

          move.l    4.w,a6              Get Exec library base
          move.l    #$dff000,a5         Get custom chips base

; -- Allocate memory for the screen and copperlist: ---------------------------

          move.l    #$280c,d0           Memory size to allocate
          move.l    #$10002,d1          Cleared chip memory
          jsr       _LVOAllocMem(a6)    Allocate it
          move.l    d0,a6               Keep it (O/S no longer required)
          bne.s     memory_ok           Memory allocation successful
          rts                           Return to caller

; -- Kill operating system and initialise hardware: ---------------------------

memory_ok move.w    #$7fff,d0           Value to disable all bits
          move.w    d0,dmacon(a5)       Disable DMA
          move.w    d0,intena(a5)       Disable interrupts
          moveq     #0,d0               Value to disable all bits
          move.w    d0,bplcon3(a5)      << AGA specific disable
          move.w    d0,bplcon4(a5)      << AGA specific disable
          move.w    d0,clxcon2(a5)      << AGA specific disable
          move.w    d0,fmode(a5)        << AGA specific disable

; -- Initialise the screen display: -------------------------------------------

          move.w    #$1200,bplcon0(a5)  Low-resolution, monochrome screen
          move.w    d0,bplcon1(a5)      Reset horizontal scroll
          move.w    d0,bpl1mod(a5)      Reset odd  modulo
          move.w    d0,bpl2mod(a5)      Reset even modulo
          move.w    #$0038,ddfstrt(a5)  Data-fetch-start for low-resolution
          move.w    #$00d0,ddfstop(a5)  Data-fetch-stop  for low-resolution
          move.w    #$2881,diwstrt(a5)  Display window start
          move.w    #$28c1,diwstop(a5)  Display window stop

; -- Initialise the copperlist: -----------------------------------------------

          lea       clist(pc),a0        Get copperlist
          move.l    a6,d0               Get screen memory
          move.w    d0,2(a0)            Fill in the lo-word
          swap.w    d0                  Get the hi-word
          move.w    d0,6(a0)            Fill in the hi-word
          lea       10240(a6),a1        Copperlist is after 10K screen memory
          moveq     #0,d0               Zero the offset
copyclist move.w    (a0,d0),(a1,d0)     Copy it into chip memory
          addq.l    #2,d0               Move onto next word
          cmp.b     #12,d0              Finished?
          bne.s     copyclist           No, copy next word

; -- Initialise copper chip, set colours and start DMA: -----------------------

          move.l    a1,cop1lc(a5)       Point to copperlist
          move.w    copjmp1(a5),d0      Start copper
          move.w    #$0012,color+0(a5)  Blue background
          move.w    #$0fc0,color+2(a5)  Gold foreground
          move.w    #$8380,dmacon(a5)   Enable screen and copper DMA

; -- Set up variables: --------------------------------------------------------

          lea       trigdata(pc),a1     Get x-rotation offset
          lea       360(a1),a2          Get y-rotation offset
resetvars lea       speeds(pc),a4       Get speeds

; -- Main program loop: -------------------------------------------------------

          moveq     #rings,d7           Initialise ring counter
          lea       offsets(pc),a3      Get offsets
drawdots  bsr.s     calculate           Calculate and plot ring
          subq.l    #1,d7               Decrement ring counter
          bne.s     drawdots            Draw next ring
waitvbl   btst.b    #5,intreqr+1(a5)    Is vertical blank interrupt active?
          beq.s     waitvbl             No, wait for it
          move.w    #32,intreq(a5)      Reset vertical blank interrupt bit
          moveq     #rings,d7           Initialise ring counter
          lea       offsets(pc),a3      Get offsets
wipedots  bsr.s     calculate           Wipe ring
          subq.l    #1,d7               Decrement ring counter
          bne.s     wipedots            Wipe next ring
          lea       offsets(pc),a3      Get offsets
addspeed  move.w    (a3),d0             Get offset
          move.w    (a4)+,d1            Get speed
          add.w     d1,d0               Add speed to offset
          cmp.w     #359,d0             Is offset >359?
          ble.s     nextspeed           No, update offset
          sub.w     #360,d0             Validate offset
nextspeed move.w    d0,(a3)+            Update offset
          cmp.l     a3,a1               End of offsets?
          bne.s     addspeed            No, add next speed
          bra.s     resetvars           Start all over again

; -- Ring calculation: --------------------------------------------------------

calculate moveq     #0,d6               Initialise degree counter
calc_next moveq     #0,d3               Initialise x-position total
          moveq     #0,d4               Initialise y-position total
          moveq     #0,d5               Initialise table offset counter
add_axes  move.w    (a3)+,d1            Get x-offset
          move.w    (a3)+,d2            Get y-offset
          add.w     d6,d1               Add current degree to x-offset
          add.w     d6,d2               Add current degree to y-offset
          cmp.w     #359,d1             Is x-offset >359?
          ble.s     x_valid             No, x-offset is valid
          sub.w     #360,d1             Validate x-offset
x_valid   cmp.w     #359,d2             Is y-offset >359?
          ble.s     y_valid             No, y-offset is valid
          sub.w     #360,d2             Validate y-offset
y_valid   add.w     d5,d1               Add table offset to x-offset
          add.w     d5,d2               Add table offset to y-offset
          move.b    (a1,d1),d1          Get x-position
          ext.w     d1                  Sign-extend x-offset
          add.w     d1,d3               Add to x-position total
          move.b    (a2,d2),d2          Get y-position
          ext.w     d2                  Sign-extend y-offset
          add.w     d2,d4               Add to y-position total
          add.w     #720,d5             Update table offset counter
          cmp.w     #2160,d5            All three axes complete?
          bne.s     add_axes            No, add next axis
          add.w     #160,d3             Centre x-position
          add.w     #128,d4             Centre y-position

; -- Plot a dot on the screen: ------------------------------------------------

          move.w    d3,d0               Copy the x-position
          and.w     #$1f8,d0            Get modulo 8
          move.b    #128,d1             Initialise the plotting bit
          eor.w     d0,d3               Mask off the modulo
          beq.s     aligned             Plotting bit is already aligned
shift_bit lsr.b     #1,d1               Shift it to the right one bit
          subq.w    #1,d3               Decrement alignment counter
          bne.s     shift_bit           Not aligned yet, shift some more
aligned   lsr.w     #3,d0               Divide x-position by 8
          mulu.w    #40,d4              Multiply y-position by 40
          add.w     d4,d0               Add to get final plot address
          eor.b     d1,(a6,d0)          Plot/unplot the pixel

; -- Update degree counter: ---------------------------------------------------

          add.w     #step,d6            Update degree counter
          cmp.w     #360,d6             Finished ring?
          beq.s     ring_done           Yes, return to caller
          lea       -12(a3),a3          Reset offset address
          bra.s     calc_next           Calculate and plot next dot
ring_done rts                           Return to caller

; -- Program copperlist: ------------------------------------------------------

clist     dc.w      $00e2,$0000,$00e0   Copperlist for single bitplane
          dc.w      $0000,$ffff,$fffe   ;

; -- Ring data: ---------------------------------------------------------------

speeds    dc.w      1,2,3,4,5,6         Ring speed data
          dc.w      2,4,6,1,3,5         ;
          dc.w      6,5,4,3,2,1         ;
          dc.w      5,3,1,6,4,2         ;
offsets   dc.w      0,0,0,0,0,0         Ring offset data
          dc.w      1,1,1,1,1,1         ;
          dc.w      1,1,2,2,2,2         ;
          dc.w      3,3,3,3,3,3         ;

; -- Precalculated rotation tables: -------------------------------------------

trigdata  incbin    Rotation_Data       Primary, secondary and tertiary data