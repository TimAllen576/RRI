/*
   Copyright (c) 2014-2016 by Plexim GmbH
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

#include "plx_dio.h"

#pragma diag_suppress 112 // PLX_ASSERT(0) in switch statements

typedef struct PLX_DIO_CONF_REGS
{
    volatile uint32_t *dir;
    volatile uint32_t *mux;
    volatile uint32_t *pud;
    volatile uint32_t *ctrl;
    volatile uint32_t *qsel;
    uint32_t muxMask;
    uint16_t groupIndex;
} PLX_DIO_ConfRegs_t;

typedef struct PLX_DIO_SOBJ
{
	volatile uint32_t dummyWriteVar;
	volatile uint32_t dummyReadAllwaysHighVar;
	volatile uint32_t dummyReadAllwaysLowVar;

	PLX_DIO_Obj_t dummyWriteObj;
	PLX_DIO_Obj_t dummyReadAllwaysHighObj;
	PLX_DIO_Obj_t dummyReadAllwaysLowObj;
} PLX_DIO_SObj_t;

static PLX_DIO_SObj_t PLX_DIO_SObj;

void PLX_DIO_sinit()
{
	PLX_DIO_SObj.dummyWriteObj.dat = &PLX_DIO_SObj.dummyWriteVar;
	PLX_DIO_SObj.dummyWriteObj.mask = 0;

	PLX_DIO_SObj.dummyReadAllwaysHighObj.dat = &PLX_DIO_SObj.dummyReadAllwaysHighVar;
	PLX_DIO_SObj.dummyReadAllwaysHighObj.mask = 1;

	PLX_DIO_SObj.dummyReadAllwaysLowObj.dat = &PLX_DIO_SObj.dummyReadAllwaysLowVar;
	PLX_DIO_SObj.dummyReadAllwaysLowObj.mask = 1;

	PLX_DIO_SObj.dummyReadAllwaysHighVar = 1;
	PLX_DIO_SObj.dummyReadAllwaysLowVar = 0;
}

PLX_DIO_Handle_t PLX_DIO_obtainDummyWrite()
{
	return (PLX_DIO_Handle_t)&PLX_DIO_SObj.dummyWriteObj;
}

PLX_DIO_Handle_t PLX_DIO_obtainDummyRead(bool aReadValue)
{
	if(aReadValue)
	{
		return (PLX_DIO_Handle_t)&PLX_DIO_SObj.dummyReadAllwaysHighObj;
	}
	else
	{
		return (PLX_DIO_Handle_t)&PLX_DIO_SObj.dummyReadAllwaysLowObj;
	}
}

PLX_DIO_Handle_t PLX_DIO_init(void *aMemory, const size_t aNumBytes)
{
	PLX_DIO_Handle_t handle;

	if(aNumBytes < sizeof(PLX_DIO_Obj_t))
		return((PLX_DIO_Handle_t)NULL);

	// set handle
	handle = (PLX_DIO_Handle_t)aMemory;

	return handle;
}

static void PLX_DIO_getRegistersAndMasks(PLX_DIO_Handle_t aHandle, uint16_t aChannel, PLX_DIO_ConfRegs_t *aConfRegs)
{
    PLX_DIO_Obj_t *obj = (PLX_DIO_Obj_t *)aHandle;

    // determine registers and masks
    uint16_t group = aChannel / 32;
    aConfRegs->groupIndex = aChannel % 32;
    uint16_t mux = aConfRegs->groupIndex / 16;
    uint16_t muxIndex = aConfRegs->groupIndex % 16;

    obj->mask = 1L << aConfRegs->groupIndex;
    aConfRegs->muxMask = 3L << (muxIndex * 2);

    switch(group)
    {
        default:
            PLX_ASSERT(0);
            break;
        case 0:
            aConfRegs->dir = (uint32_t *)&GpioCtrlRegs.GPADIR.all;
            obj->dat = &GpioDataRegs.GPADAT.all;
            obj->toggle = &GpioDataRegs.GPATOGGLE.all;
            aConfRegs->pud = (uint32_t *)&GpioCtrlRegs.GPAPUD.all;
            aConfRegs->ctrl = (uint32_t *)&GpioCtrlRegs.GPACTRL.all;
            switch(mux)
            {
                default:
                    PLX_ASSERT(0);
                    break;
                case 0:
                    aConfRegs->mux = (uint32_t *)&GpioCtrlRegs.GPAMUX1.all;
                    aConfRegs->qsel= (uint32_t *)&GpioCtrlRegs.GPAQSEL1.all;
                    break;
                case 1:
                    aConfRegs->mux = (uint32_t *)&GpioCtrlRegs.GPAMUX2.all;
                    aConfRegs->qsel= (uint32_t *)&GpioCtrlRegs.GPAQSEL2.all;
                    break;
            }
            break;

        case 1:
            aConfRegs->dir = (uint32_t *)&GpioCtrlRegs.GPBDIR.all;
            obj->dat = &GpioDataRegs.GPBDAT.all;
            obj->toggle = &GpioDataRegs.GPBTOGGLE.all;
            aConfRegs->pud = (uint32_t *)&GpioCtrlRegs.GPBPUD.all;
            aConfRegs->ctrl = (uint32_t *)&GpioCtrlRegs.GPBCTRL.all;
            switch(mux)
            {
                default:
                    PLX_ASSERT(0);
                    break;
                case 0:
                    aConfRegs->mux = (uint32_t *)&GpioCtrlRegs.GPBMUX1.all;
                    aConfRegs->qsel= (uint32_t *)&GpioCtrlRegs.GPBQSEL1.all;
                    break;
                case 1:
                    aConfRegs->mux = (uint32_t *)&GpioCtrlRegs.GPBMUX2.all;
                    aConfRegs->qsel= (uint32_t *)&GpioCtrlRegs.GPBQSEL2.all;
                    break;
            }
            break;
    }
}

void PLX_DIO_configureIn(PLX_DIO_Handle_t aHandle, uint16_t aChannel, PLX_DIO_InputProperties_t * const aProperties)
{
    PLX_DIO_Obj_t *obj = (PLX_DIO_Obj_t *)aHandle;

    obj->activeHigh = !aProperties->enableInvert;
    PLX_DIO_ConfRegs_t confRegs;
    PLX_DIO_getRegistersAndMasks(aHandle, aChannel, &confRegs);

    EALLOW;
    PLX_ASSERT(aProperties->qualPeriodInSysClk == 0);
    {
        uint16_t index = (confRegs.groupIndex / 8) * 8;
        *confRegs.ctrl &= ~(255L << index);
        *confRegs.ctrl |= (aProperties->qualPeriodInSysClk << index);
    }
    PLX_ASSERT(aProperties->qualType == 0);
    {
        uint16_t index = (confRegs.groupIndex % 16) * 2;
        *confRegs.qsel &= ~(3L << index);
        *confRegs.qsel |= (aProperties->qualType << index);
    }
    if(aProperties->type == PLX_DIO_NOPULL)
    {
        *confRegs.pud |= (1 << confRegs.groupIndex);
    }
    else
    {
        *confRegs.pud &= ~(1 << confRegs.groupIndex);
    }
    *confRegs.dir &= ~obj->mask;
    *confRegs.mux &= ~confRegs.muxMask;
    EDIS;
}

void PLX_DIO_configureOut(PLX_DIO_Handle_t aHandle, uint16_t aChannel, PLX_DIO_OutputProperties_t * const aProperties)
{
    PLX_DIO_Obj_t *obj = (PLX_DIO_Obj_t *)aHandle;

    obj->activeHigh = !aProperties->enableInvert;
    PLX_DIO_ConfRegs_t confRegs;
    PLX_DIO_getRegistersAndMasks(aHandle, aChannel, &confRegs);

    // set to passive
    if(obj->activeHigh)
    {
        *obj->dat &= ~obj->mask;
    }
    else
    {
        *obj->dat |= obj->mask;
    }

    EALLOW;
    PLX_ASSERT(aProperties->type == PLX_DIO_PUSHPULL);
    *confRegs.dir |= obj->mask;
    *confRegs.mux &= ~confRegs.muxMask;
    EDIS;
}

