/*
   Copyright (c) 2021 by Plexim GmbH
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
   BEGIN            : origin = 0x000000, length = 0x000002
   RAMM0            : origin = 0x0001B0, length = 0x000250

   RESET            : origin = 0x3FFFC0, length = 0x000002

   PRAMGS           : origin = 0x00D000, length = 0x0010000

   /* Flash sectors */
//   FLASH0           : origin = 0x080002, length = 0x003FFE  /* on-chip Flash */
//   FLASH1           : origin = 0x082000, length = 0x002000  /* on-chip Flash */
//   FLASH2           : origin = 0x084000, length = 0x002000  /* on-chip Flash */
//   FLASH3           : origin = 0x086000, length = 0x002000  /* on-chip Flash */
//   FLASH4           : origin = 0x088000, length = 0x008000  /* on-chip Flash */
//   FLASH5           : origin = 0x090000, length = 0x008000  /* on-chip Flash */
//   FLASH6           : origin = 0x098000, length = 0x008000  /* on-chip Flash */
//   FLASH7           : origin = 0x0A0000, length = 0x008000  /* on-chip Flash */
//   FLASH8           : origin = 0x0A8000, length = 0x008000  /* on-chip Flash */
//   FLASH9           : origin = 0x0B0000, length = 0x008000  /* on-chip Flash */
//   FLASH10          : origin = 0x0B8000, length = 0x002000  /* on-chip Flash */
//   FLASH11          : origin = 0x0BA000, length = 0x002000  /* on-chip Flash */
//   FLASH12          : origin = 0x0BC000, length = 0x002000  /* on-chip Flash */
//   FLASH13          : origin = 0x0BE000, length = 0x002000  /* on-chip Flash */

   BOOT_RSVD        : origin = 0x000002, length = 0x0001AE     /* Part of M0, BOOT rom will use this for stack */
   RAMM1            : origin = 0x000400, length = 0x000400     /* on-chip RAM block M1 */

   RAMLS	       : origin = 0x008000, length = 0x004F00
//   RAMLS0           : origin = 0x008000, length = 0x000800
//   RAMLS1           : origin = 0x008800, length = 0x000800
//   RAMLS2           : origin = 0x009000, length = 0x000800
//   RAMLS3           : origin = 0x009800, length = 0x000800
//   RAMLS4           : origin = 0x00A000, length = 0x000800
//   RAMLS5           : origin = 0x00A800, length = 0x000800
//   RAMLS6           : origin = 0x00B000, length = 0x000800
//   RAMLS7           : origin = 0x00B800, length = 0x000800
//   RAMD0            : origin = 0x00C000, length = 0x000800
//   RAMD1            : origin = 0x00C800, length = 0x000800
   RAMD1_RSVD       : origin = 0x00CF00, length = 0x000100  // JTAG communication buffer

   CPU1TOCPU2RAM   : origin = 0x03A000, length = 0x000800
   CPU2TOCPU1RAM   : origin = 0x03B000, length = 0x000800
   CPUTOCMRAM      : origin = 0x039000, length = 0x000800
   CMTOCPURAM      : origin = 0x038000, length = 0x000800

   CANA_MSG_RAM     : origin = 0x049000, length = 0x000800
   CANB_MSG_RAM     : origin = 0x04B000, length = 0x000800
}

SECTIONS
{
   scope            : > RAMLS
   step             : > PRAMGS
   dispatch         : > PRAMGS

   codestart        : > BEGIN
   .cinit           : > PRAMGS
   .pinit           : > PRAMGS
   .text            : > PRAMGS
   .switch          : > PRAMGS

   .stack           : > RAMM1

#if defined(__TI_EABI__)
   .init_array      : > PRAMGS
   .const           : > PRAMGS
   .bss             : > RAMLS
   .bss:output      : > RAMLS
   .bss:cio         : > RAMLS
   .data            : > RAMLS
   .sysmem          : > RAMLS
#else
   .pinit           : > PRAMGS
   .econst          : > PRAMGS
   .cio         	: > PRAMGS
   .ebss            : > RAMLS
   .esysmem         : > RAMLS
#endif

   GROUP: > PRAMGS
   {
      ramfuncs
      .TI.ramfunc
   }

   .reset              : > RESET, TYPE = DSECT

   MSGRAM_CPU1_TO_CPU2 : > CPU1TOCPU2RAM, type=NOINIT
   MSGRAM_CPU2_TO_CPU1 : > CPU2TOCPU1RAM, type=NOINIT
   MSGRAM_CPU_TO_CM    : > CPUTOCMRAM, type=NOINIT
   MSGRAM_CM_TO_CPU    : > CMTOCPURAM, type=NOINIT
}
