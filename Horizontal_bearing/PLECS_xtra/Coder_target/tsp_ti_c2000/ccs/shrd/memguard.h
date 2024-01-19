/*
   Copyright (c) 2019 by Plexim GmbH
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

#include <stdlib.h>
#include <stdint.h>
#include <stdbool.h>

#ifndef SHARED_DATA_H_
#define SHARED_DATA_H_

typedef enum
{
    MEMGRD_DIR_HI_TO_LOW_PRIORITY = 0,
    MEMGRD_DIR_LOW_TO_HI_PRIORITY
} MEMGRD_Direction_t;

#include "plx_memguard_impl.h" // implementation specific

extern MEMGRD_Handle_t MEMGRD_init(void *aMemory, const size_t aNumBytes);

extern void MEMGRD_configure(MEMGRD_Handle_t aHandle, MEMGRD_Direction_t aDir);

extern bool MEMGRD_beginWrite(MEMGRD_Handle_t aHandle);
extern void MEMGRD_completeWrite(MEMGRD_Handle_t aHandle);

extern bool MEMGRD_beginRead(MEMGRD_Handle_t aHandle);
extern void MEMGRD_completeRead(MEMGRD_Handle_t aHandle);

#endif /* SHARED_DATA_H_ */

