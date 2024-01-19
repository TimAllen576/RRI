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
   BEGIN       : origin = 0x008800, length = 0x000002
   PRAML       : origin = 0x008802, length = 0x0057FE     /* on-chip RAM block L1 */
   //RAML0       : origin = 0x008000, length = 0x000800     /* on-chip RAM block L0 */
   //RAML1       : origin = 0x008800, length = 0x000400     /* on-chip RAM block L1 */
   //RAML2       : origin = 0x008C00, length = 0x000400     /* on-chip RAM block L2 */
   //RAML3       : origin = 0x009000, length = 0x001000     /* on-chip RAM block L3 */
   //RAML4       : origin = 0x00A000, length = 0x002000     /* on-chip RAM block L4 */
   //RAML5       : origin = 0x00C000, length = 0x002000     /* on-chip RAM block L5 */

   RAMM0       : origin = 0x000050, length = 0x0003B0     /* on-chip RAM block M0 */

   ROM         : origin = 0x3FF3B0, length = 0x000C10     /* Boot ROM */
   RESET       : origin = 0x3FFFC0, length = 0x000002     /* part of boot ROM  */
   VECTORS     : origin = 0x3FFFC2, length = 0x00003E     /* part of boot ROM  */

   BOOT_RSVD   : origin = 0x000000, length = 0x000050     /* Part of M0, BOOT rom will use this for stack */
   RAMM1       : origin = 0x000400, length = 0x000400     /* on-chip RAM block M1 */

   RAML        : origin = 0x00E000, length = 0x004700
   //RAML6       : origin = 0x00E000, length = 0x002000     /* on-chip RAM block L6 */
   //RAML78      : origin = 0x010000, length = 0x003800

   RAML8_RSVD1  : origin = 0x013700, length = 0x000100     /* JTAG communication buffer */
   RAML8_RSVD2  : origin = 0x013800, length = 0x000800     /* reserved for InstaSPIN */
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

   .stack           : > RAMM1

#if defined(__TI_EABI__)
   .init_array      : > PRAML
   .const           : > PRAML
   .bss             : > RAML
   .bss:output      : > RAML
   .bss:cio         : > RAML
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
}


