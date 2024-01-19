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

#ifndef SHARED_DATA_IMPL_H_

#define SHARED_DATA_IMPL_H_

extern uint16_t MEMGRD_DisableInt(void);
extern void MEMGRD_RestoreInt(uint16_t Stat0);

typedef struct MEMGRD_OBJ
{
    uint16_t intFlag;
    MEMGRD_Direction_t dir;
    bool dataReady;
} MEMGRD_Obj_t;

typedef MEMGRD_Obj_t *MEMGRD_Handle_t;

#include "memguard_impl.h" // implementation specific

inline bool MEMGRD_beginWrite(MEMGRD_Handle_t aHandle){
    MEMGRD_Obj_t *obj = (MEMGRD_Obj_t *)aHandle;

    if(obj->dir == MEMGRD_DIR_LOW_TO_HI_PRIORITY){
        obj->intFlag = MEMGRD_DisableInt();
        bool dataReady = obj->dataReady;
        if(dataReady){
            MEMGRD_RestoreInt(obj->intFlag);
        }
        return(!dataReady);
    } else {
        return(!obj->dataReady);
    }
}

inline void MEMGRD_completeWrite(MEMGRD_Handle_t aHandle){
    MEMGRD_Obj_t *obj = (MEMGRD_Obj_t *)aHandle;

    obj->dataReady = true;
    if(obj->dir == MEMGRD_DIR_LOW_TO_HI_PRIORITY){
        MEMGRD_RestoreInt(obj->intFlag);
    }
}

inline bool MEMGRD_beginRead(MEMGRD_Handle_t aHandle){
    MEMGRD_Obj_t *obj = (MEMGRD_Obj_t *)aHandle;

    if(obj->dir == MEMGRD_DIR_HI_TO_LOW_PRIORITY){
        obj->intFlag = MEMGRD_DisableInt();
        bool dataReady = obj->dataReady;
        if(!dataReady){
            MEMGRD_RestoreInt(obj->intFlag);
        }
        return(dataReady);
    } else {
        return(obj->dataReady);
    }
}

inline void MEMGRD_completeRead(MEMGRD_Handle_t aHandle){
    MEMGRD_Obj_t *obj = (MEMGRD_Obj_t *)aHandle;

    obj->dataReady = false;
    if(obj->dir == MEMGRD_DIR_HI_TO_LOW_PRIORITY){
        MEMGRD_RestoreInt(obj->intFlag);
    }
}

#endif /* SHARED_DATA_IMPL_H_ */
