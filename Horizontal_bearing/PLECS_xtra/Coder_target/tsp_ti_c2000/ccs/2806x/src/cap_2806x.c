/*
   Copyright (c) 2020 by Plexim GmbH
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

#include "plx_cap.h"

PLX_CAP_Handle_t PLX_CAP_init(void *aMemory, const size_t aNumBytes)
{
    PLX_CAP_Handle_t handle;

    if(aNumBytes < sizeof(PLX_CAP_Obj_t))
        return((PLX_CAP_Handle_t)NULL);

    // set handle
    handle = (PLX_CAP_Handle_t)aMemory;

    return handle;
}

void PLX_CAP_setDefaultParams(uint16_t aNumEvents, bool aSingleShotOperation, PLX_CAP_Params_t *aParams)
{
    PLX_ASSERT(aSingleShotOperation);

    aParams->reg.ECCTL1.all = 0; // init to reset value
    aParams->reg.ECCTL2.all = 0x000E; // init to reset value

    aParams->reg.ECCTL2.bit.STOP_WRAP = aNumEvents-1;

    aParams->reg.ECCTL2.bit.CONT_ONESHT = 1;   // one-shot
    aParams->reg.ECCTL2.bit.SYNCI_EN = 0;      // disable sync in
    aParams->reg.ECCTL2.bit.SYNCO_SEL = 0;     // pass through
}

void PLX_CAP_configure(PLX_CAP_Handle_t aHandle, uint16_t aUnit, uint16_t aGpio, const PLX_CAP_Params_t *aParams)
{
    PLX_CAP_Obj_t *obj = (PLX_CAP_Obj_t *)aHandle;

    EALLOW;
    switch(aUnit){
        case 1:
            obj->ecap = &ECap1Regs;
            SysCtrlRegs.PCLKCR1.bit.ECAP1ENCLK = 1;
            switch(aGpio)
            {
                case 5:
                    GpioCtrlRegs.GPAMUX1.bit.GPIO5 = 3;
                    break;
                case 11:
                    GpioCtrlRegs.GPAMUX1.bit.GPIO11 = 3;
                    break;
                case 19:
                    GpioCtrlRegs.GPAMUX2.bit.GPIO19 = 3;
                    break;
                case 24:
                    GpioCtrlRegs.GPAMUX2.bit.GPIO24 = 1;
                    break;
                default:
                    PLX_ASSERT(0);
            }
            break;

        case 2:
            obj->ecap = &ECap2Regs;
            SysCtrlRegs.PCLKCR1.bit.ECAP2ENCLK = 1;
            switch(aGpio)
            {
                case 7:
                    GpioCtrlRegs.GPAMUX1.bit.GPIO7 = 3;
                    break;
                case 15:
                    GpioCtrlRegs.GPAMUX1.bit.GPIO15 = 2;
                    break;
                case 25:
                    GpioCtrlRegs.GPAMUX2.bit.GPIO25 = 1;
                    break;
                default:
                    PLX_ASSERT(0);
            }
            break;

        case 3:
            obj->ecap = &ECap3Regs;
            SysCtrlRegs.PCLKCR1.bit.ECAP3ENCLK = 1;
            switch(aGpio)
            {
                case 9:
                   GpioCtrlRegs.GPAMUX1.bit.GPIO9 = 3;
                   break;
                case 26:
                   GpioCtrlRegs.GPAMUX2.bit.GPIO26 = 1;
                   break;
                default:
                   PLX_ASSERT(0);
             }
             break;

        default:
            PLX_ASSERT(0);
    }

    EDIS;

    obj->ecap->ECCTL1.bit.CAPLDEN = 0;  // disable CAP1-CAP3 register loads
    obj->ecap->ECCTL2.bit.TSCTRSTOP = 0;  // stop counter

    obj->ecap->ECEINT.all = 0x0000; // disable interrupts
    obj->ecap->ECCLR.all = 0xFFFF; // clear flags

    obj->ecap->ECCTL1.all = aParams->reg.ECCTL1.all;
    obj->ecap->ECCTL2.all = aParams->reg.ECCTL2.all;

    obj->ecap->ECCTL2.bit.STOP_WRAP = aParams->reg.ECCTL2.bit.STOP_WRAP; // when to stop
    obj->ecap->ECCTL1.bit.CAPLDEN = 1; // enable unit

    obj->ecap->ECCTL2.bit.TSCTRSTOP = 1; // start counter
    obj->ecap->ECCTL2.bit.REARM = 1; // arm one-shot

    obj->numEvents = aParams->reg.ECCTL2.bit.STOP_WRAP + 1;
    obj->eventMask = (1 << (obj->numEvents+1)) - 2;
}

bool PLX_CAP_getNewValues(PLX_CAP_Handle_t aHandle, uint16_t aNewPrescale, uint32_t *aValues, bool *aOverflowFlag)
{
    PLX_CAP_Obj_t *obj = (PLX_CAP_Obj_t *)aHandle;

    *aOverflowFlag = obj->ecap->ECFLG.bit.CTROVF;
    obj->ecap->ECCLR.bit.CTROVF = 1;

    if((obj->ecap->ECFLG.all & obj->eventMask) ==  obj->eventMask)
    {
        volatile uint32_t *cap = &obj->ecap->CAP1;
        int i;
        for(i=0; i<obj->numEvents; i++)
        {
            aValues[i] = cap[i];
        }
        obj->ecap->ECCTL1.bit.PRESCALE = (aNewPrescale >> 1) & 0x1F;
        obj->ecap->ECCLR.all = obj->eventMask;
        obj->ecap->ECCTL2.bit.REARM = 1; // effective in single-shot and continuous mode
        return true;
    }
    return false;
}
