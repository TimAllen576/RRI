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
   ZONE0       : origin = 0x004000, length = 0x001000     /* XINTF zone 0 */
   ZONE6       : origin = 0x0100000, length = 0x100000    /* XINTF zone 6 */
   ZONE7A      : origin = 0x0200000, length = 0x00FC00    /* XINTF zone 7 - program space */

   OTP         : origin = 0x380400, length = 0x000400     /* on-chip OTP */

   PRAML       : origin = 0x008000, length = 0x005000
   //RAML0       : origin = 0x008000, length = 0x001000     /* on-chip RAM block L0 */
   //RAML1       : origin = 0x009000, length = 0x001000     /* on-chip RAM block L1 */
   //RAML2       : origin = 0x00A000, length = 0x001000     /* on-chip RAM block L2 */
   //RAML3       : origin = 0x00B000, length = 0x001000     /* on-chip RAM block L3 */
   //RAML4       : origin = 0x00C000, length = 0x001000     /* on-chip RAM block L1 */

   CSM_RSVD    : origin = 0x33FF80, length = 0x000076     /* Part of FLASHA.  Program with all 0x0000 when CSM is in use. */
   BEGIN       : origin = 0x33FFF6, length = 0x000002     /* Part of FLASHA.  Used for "boot to Flash" bootloader mode. */
   CSM_PWL     : origin = 0x33FFF8, length = 0x000008     /* Part of FLASHA.  CSM password locations in FLASHA */
   RAMM0       : origin = 0x000050, length = 0x0003B0     /* on-chip RAM block M0 */

   ROM         : origin = 0x3FF27C, length = 0x000D44     /* Boot ROM */
   RESET       : origin = 0x3FFFC0, length = 0x000002     /* part of boot ROM  */
   VECTORS     : origin = 0x3FFFC2, length = 0x00003E     /* part of boot ROM  */

   IQTABLES    : origin = 0x3FE000, length = 0x000b50     /* IQ Math Tables in Boot ROM */
   IQTABLES2   : origin = 0x3FEB50, length = 0x00008c     /* IQ Math Tables in Boot ROM */
   FPUTABLES   : origin = 0x3FEBDC, length = 0x0006A0     /* FPU Tables in Boot ROM */

   ADC_CAL     : origin = 0x380080, length = 0x000009     /* ADC_cal function in Reserved memory */

   BOOT_RSVD   : origin = 0x000000, length = 0x000050     /* Part of M0, BOOT rom will use this for stack */
   RAMM1       : origin = 0x000400, length = 0x000400     /* on-chip RAM block M1 */

   RAML       : origin = 0x00D000, length = 0x002F00

   //RAML5       : origin = 0x00D000, length = 0x001000     /* on-chip RAM block L1 */
   //RAML6       : origin = 0x00E000, length = 0x001000     /* on-chip RAM block L1 */
   //RAML7       : origin = 0x00F000, length = 0x001000     /* on-chip RAM block L1 */

   RAML7_RSVD    : origin = 0x00FF00, length = 0x000100   /* JTAG communication buffer */

   ZONE7B      : origin = 0x20FC00, length = 0x000400     /* XINTF zone 7 - data space */
}

SECTIONS
{
   scope            : > RAML
   step             : > PRAML
   dispatch         : > PRAML

   codestart        : > BEGIN
   .text            : > PRAML
   .cinit           : > PRAML
   .switch          : > PRAML

   .stack           : > RAMM1 { _stack_start = .; }

#if defined(__TI_EABI__)
   .init_array      : > PRAML
   .const           : > PRAML
   .bss             : > RAML
   .bss:cio         : > RAML
   .bss:output      : > RAML
   .data            : > RAML
   .sysmem          : > RAML
#else
   .cio         	: > PRAML
   .econst          : > PRAML
   .pinit           : > PRAML
   .ebss            : > RAML
   .esysmem         : > RAML
#endif

   GROUP: > PRAML
   {
      ramfuncs
      .TI.ramfunc
   }

   .reset           : > RESET, TYPE = DSECT
   vectors          : > VECTORS, TYPE = DSECT
   FPUmathTables    : > FPUTABLES, TYPE = NOLOAD
   .adc_cal         : load = ADC_CAL, TYPE = NOLOAD
}
