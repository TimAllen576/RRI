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
   OTP         : origin = 0x3D7800, length = 0x000400     /* on-chip OTP */

   FLASH       : origin = 0x3D8000, length = 0x01FF80     /* A-H on-chip FLASH */
   CSM_RSVD    : origin = 0x3F7F80, length = 0x000076     /* Part of FLASHA.  Program with all 0x0000 when CSM is in use. */
   BEGIN       : origin = 0x3F7FF6, length = 0x000002     /* Part of FLASHA.  Used for "boot to Flash" bootloader mode. */
   CSM_PWL_P0  : origin = 0x3F7FF8, length = 0x000008     /* Part of FLASHA.  CSM password locations in FLASHA */
   RAMM0       : origin = 0x000050, length = 0x0003B0     /* on-chip RAM block M0 */

   ROM         : origin = 0x3FF3B0, length = 0x000C10     /* Boot ROM */
   RESET       : origin = 0x3FFFC0, length = 0x000002     /* part of boot ROM  */
   VECTORS     : origin = 0x3FFFC2, length = 0x00003E     /* part of boot ROM  */

   FPUTABLES   : origin = 0x3FD590, length = 0x0006A0	  /* FPU Tables in Boot ROM */
   IQTABLES    : origin = 0x3FDC30, length = 0x000B50     /* IQ Math Tables in Boot ROM */
   IQTABLES2   : origin = 0x3FE780, length = 0x00008C     /* IQ Math Tables in Boot ROM */
   IQTABLES3   : origin = 0x3FE80C, length = 0x0000AA	  /* IQ Math Tables in Boot ROM */

   BOOT_RSVD   : origin = 0x000000, length = 0x000050     /* Part of M0, BOOT rom will use this for stack */
   RAMM1       : origin = 0x000400, length = 0x000400     /* on-chip RAM block M1 */

   RAML        : origin = 0x008000, length = 0x00B700
   //RAML0       : origin = 0x008000, length = 0x000800     /* on-chip RAM block L0 */
   //RAML1       : origin = 0x008800, length = 0x000400     /* on-chip RAM block L1 */
   //RAML2       : origin = 0x008C00, length = 0x000400     /* on-chip RAM block L2 */
   //RAML3       : origin = 0x009000, length = 0x001000     /* on-chip RAM block L3 */
   //RAML4       : origin = 0x00A000, length = 0x002000     /* on-chip RAM block L4 */
   //RAML5       : origin = 0x00C000, length = 0x002000     /* on-chip RAM block L5 */
   //RAML6       : origin = 0x00E000, length = 0x002000     /* on-chip RAM block L6 */
   //RAML78      : origin = 0x010000, length = 0x003800

   RAML8_RSVD1  : origin = 0x013700, length = 0x000100     /* JTAG communication buffer */
   RAML8_RSVD2  : origin = 0x013800, length = 0x000800     /* reserved for InstaSPIN */
}

SECTIONS
{
   scope            : > RAML
   step             : > FLASH
   dispatch         : > FLASH

   codestart        : > BEGIN
   .text            : > FLASH
   .cinit           : > FLASH
   .switch          : > FLASH

   .stack           : > RAMM1

#if defined(__TI_EABI__)
   .init_array      : > FLASH
   .const           : > FLASH
   .bss             : > RAML
   .bss:output      : > RAML
   .bss:cio         : > RAML
   .data            : > RAML
   .sysmem          : > RAML
#else
   .cio         	: > FLASH
   .econst          : > FLASH
   .pinit           : > FLASH
   .ebss            : > RAML
   .esysmem         : > RAML
#endif


   GROUP      : LOAD = FLASH,
                RUN = RAMM0,
#if defined(__TI_EABI__)
                LOAD_START(RamfuncsLoadStart),
                LOAD_END(RamfuncsLoadEnd),
                RUN_START(RamfuncsRunStart),
                LOAD_SIZE(RamfuncsLoadSize)
#else
                LOAD_START(_RamfuncsLoadStart),
                LOAD_END(_RamfuncsLoadEnd),
                RUN_START(_RamfuncsRunStart),
                LOAD_SIZE(_RamfuncsLoadSize)
#endif
   {
      ramfuncs
      .TI.ramfunc
   }

   csmpasswds       : > CSM_PWL_P0
   csm_rsvd         : > CSM_RSVD

   .reset           : > RESET, TYPE = DSECT
   vectors          : > VECTORS, TYPE = DSECT
   IQmath           : > FLASH
   IQmathTables     : > IQTABLES, TYPE = NOLOAD
}

