/*
   Copyright (c) 2014-2021 by Plexim GmbH
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
   BEGIN           	: origin = 0x000000, length = 0x000002
   PRAMGS      		: origin = 0x00C000, length = 0x006000
   RESET           	: origin = 0x3FFFC0, length = 0x000002

   BOOT_RSVD    : origin = 0x000002, length = 0x0000F3     /* Part of M0, BOOT rom will use this for stack */
   RAMM0        : origin = 0x0000F5, length = 0x00030B

   RAMM1        : origin = 0x000400, length = 0x000400     /* on-chip RAM block M1 */

   //RAMLS0       : origin = 0x008000, length = 0x000800
   //RAMLS2       : origin = 0x008000, length = 0x000800
   //RAMLS2       : origin = 0x008800, length = 0x000800
   //RAMLS2       : origin = 0x009000, length = 0x000800
   //RAMLS3       : origin = 0x009800, length = 0x000800
   //RAMLS4       : origin = 0x00A000, length = 0x000800
   //RAMLS5       : origin = 0x00A800, length = 0x000800
   //RAMLS6       : origin = 0x00B000, length = 0x000800
   //RAMLS7      : origin = 0x00B800, length = 0x000800
   RAMLS7_RSVD   : origin = 0x00BF00, length = 0x000100  // JTAG communication buffer

   RAMGS3          : origin = 0x012000, length = 0x002000
}

SECTIONS
{
   scope            : > RAMGS3
   step             : > PRAMGS
   dispatch         : > PRAMGS

   codestart        : > BEGIN
   .text            : > PRAMGS
   .cinit           : > PRAMGS
   .switch          : > PRAMGS

   .stack           : > RAMM1

#if defined(__TI_EABI__)
   .init_array      : > PRAMGS
   .const           : > PRAMGS
   .bss             : > RAMGS3
   .bss:output      : > RAMGS3
   .bss:cio         : > RAMGS3
   .data            : > RAMGS3
   .sysmem          : > RAMGS3
#else
   .cio         	: > PRAMGS
   .econst          : > PRAMGS
   .pinit           : > PRAMGS
   .ebss            : > RAMGS3
   .esysmem         : > RAMGS3
#endif

   GROUP: > PRAMGS
   {
      ramfuncs
      .TI.ramfunc
   }

   .reset           : > RESET, TYPE = DSECT /* not used, */
 }

