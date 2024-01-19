/*
   Copyright (c) 2019-2021 by Plexim GmbH
   All rights reserved.

   A free license is granted to anyone to use this software for any legal
   non safety-critical purpose, including commercial applications, provided
   that:
   1) IT IS NOT USED TO DIRECTLY OR INDIRECTLY COMPETE WITH PLEXIM, and
   2) THIS COPYRIGHT NOTICE IS PRESERVED in its entirety.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.
 */

MEMORY
{
   /* BEGIN is used for the "boot to Flash" bootloader mode   */
   BEGIN           	: origin = 0x080000, length = 0x000002
   RAMM0        	: origin = 0x0000F5, length = 0x00030B
   RESET           	: origin = 0x3FFFC0, length = 0x000002

   /* Flash sectors */
   /* BANK 0 */
   FLASH_BANK0	    : origin = 0x080002, length = 0x00FFFE	/* on-chip Flash */
   //FLASH_BANK0_SEC1_RSVD  : origin = 0x081000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC2_RSVD  : origin = 0x082000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC3_RSVD  : origin = 0x083000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC4_RSVD  : origin = 0x084000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC5_RSVD  : origin = 0x085000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC6_RSVD  : origin = 0x086000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC7_RSVD  : origin = 0x087000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC8_RSVD  : origin = 0x088000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC9_RSVD  : origin = 0x089000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC10_RSVD : origin = 0x08A000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC11_RSVD : origin = 0x08B000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC12_RSVD : origin = 0x08C000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC13_RSVD : origin = 0x08D000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC14_RSVD : origin = 0x08E000, length = 0x001000	/* on-chip Flash */
   //FLASH_BANK0_SEC15_RSVD : origin = 0x08F000, length = 0x001000	/* on-chip Flash */

   /* BANK 1 */
   FLASH_BANK1_SEC0_RSVD  : origin = 0x090000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC1_RSVD  : origin = 0x091000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC2_RSVD  : origin = 0x092000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC3_RSVD  : origin = 0x093000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC4_RSVD  : origin = 0x094000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC5_RSVD  : origin = 0x095000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC6_RSVD  : origin = 0x096000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC7_RSVD  : origin = 0x097000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC8_RSVD  : origin = 0x098000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC9_RSVD  : origin = 0x099000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC10_RSVD : origin = 0x09A000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC11_RSVD : origin = 0x09B000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC12_RSVD : origin = 0x09C000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC13_RSVD : origin = 0x09D000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC14_RSVD : origin = 0x09E000, length = 0x001000	/* on-chip Flash */
   FLASH_BANK1_SEC15_RSVD : origin = 0x09F000, length = 0x001000	/* on-chip Flash */

   BOOT_RSVD    : origin = 0x000002, length = 0x0000F3     /* Part of M0, BOOT rom will use this for stack */
   RAMM1        : origin = 0x000400, length = 0x000400     /* on-chip RAM block M1 */

   RAMLS	      : origin = 0x008000, length = 0x003F00
   //RAMLS2       : origin = 0x008000, length = 0x000800
   //RAMLS2       : origin = 0x008800, length = 0x000800
   //RAMLS2       : origin = 0x009000, length = 0x000800
   //RAMLS3       : origin = 0x009800, length = 0x000800
   //RAMLS4       : origin = 0x00A000, length = 0x000800
   //RAMLS5       : origin = 0x00A800, length = 0x000800
   //RAMLS6       : origin = 0x00B000, length = 0x000800
   //RAMLS7       : origin = 0x00B800, length = 0x000800
    RAMLS7_RSVD   : origin = 0x00BF00, length = 0x000100  // JTAG communication buffer

   // we do not utilize any RAMGS RAM, as this memory is used for page 0
   // by the "ram_lnk" configuration
}

SECTIONS
{
   scope            : > RAMLS
   step             : > FLASH_BANK0, ALIGN(4)
   dispatch         : > FLASH_BANK0, ALIGN(4)

   codestart        : > BEGIN, ALIGN(4)
   .text            : > FLASH_BANK0, ALIGN(4)
   .cinit           : > FLASH_BANK0, ALIGN(4)
   .pinit           : > FLASH_BANK0, ALIGN(4)
   .switch          : > FLASH_BANK0, ALIGN(4)

   .stack           : > RAMM1

#if defined(__TI_EABI__)
    .init_array     : > FLASH_BANK0, ALIGN(4)
   .const           : > FLASH_BANK0, ALIGN(4)
   .bss             : > RAMLS
   .bss:output      : > RAMLS
   .bss:cio         : > RAMLS
   .data            : > RAMLS
   .sysmem          : > RAMLS
#else
   .pinit           : > FLASH_BANK0, ALIGN(4)
   .econst          : > FLASH_BANK0, ALIGN(4)
   .cio         	: > FLASH_BANK0, ALIGN(4)
   .ebss            : > RAMLS
   .esysmem         : > RAMLS
#endif

    GROUP      : LOAD = FLASH_BANK0,
                RUN = RAMM0,
#if defined(__TI_EABI__)
                LOAD_START(RamfuncsLoadStart),
                LOAD_END(RamfuncsLoadEnd),
                RUN_START(RamfuncsRunStart),
                LOAD_SIZE(RamfuncsLoadSize),
#else
                LOAD_START(_RamfuncsLoadStart),
                LOAD_END(_RamfuncsLoadEnd),
                RUN_START(_RamfuncsRunStart),
                LOAD_SIZE(_RamfuncsLoadSize),
#endif
                ALIGN(4)
   {
      ramfuncs
      .TI.ramfunc
   }
   .reset           : > RESET, TYPE = DSECT /* not used, */

 }
