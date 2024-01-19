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

#ifndef PLX_PWR_IMPL_H_
#define PLX_PWR_IMPL_H_

#include "plx_pwm.h"
#define PLX_PWR_MAX_PWM_CHANNELS (PLX_PWM_EPWM_MAX_PLUS_ONE-1)

typedef enum
{
    PLX_PWR_STATE_POWERUP,
    PLX_PWR_STATE_DISABLED,
    PLX_PWR_STATE_ENABLING,
    PLX_PWR_STATE_ENABLED,
    PLX_PWR_STATE_FAULT,
    PLX_PWR_STATE_FAULT_ACKN,
    PLX_PWR_STATE_CRITICAL_FAULT
} PLX_PWR_FsmState_t;

typedef enum
{
    PLX_PWR_ERR_NONE,
    PLX_PWR_GDRV_ERROR,
    PLX_PWR_ERR_UNKNOWN
} PLX_PWR_Error_t;

typedef struct PLX_PWR_OBJ
{
    PLX_DIO_Handle_t gdrvEnableHandle;
    uint16_t timer;
    uint16_t fsmExecRateHz;
    uint16_t enableDelayInTicks;

    uint16_t numRegisteredPwmChannels;
    PLX_PWM_Handle_t pwmChannels[PLX_PWR_MAX_PWM_CHANNELS];

    uint16_t enableSwitchingReq;
    int16_t pilMode;
    int16_t state;

    uint16_t enableReq;
    uint16_t gatesActive;

} PLX_PWR_Obj_t;

typedef PLX_PWR_Obj_t *PLX_PWR_Handle_t;
extern PLX_PWR_Handle_t PLX_PWR_SHandle;

inline void PLX_PWR_setEnableDelay(int16_t aDelayInMs){
    PLX_PWR_Obj_t *obj = (PLX_PWR_Obj_t *)PLX_PWR_SHandle;
    obj->enableDelayInTicks = obj->fsmExecRateHz/1000 * aDelayInMs;
}

inline void PLX_PWR_syncdSwitchingEnable()
{
    PLX_PWR_Obj_t *obj = (PLX_PWR_Obj_t *)PLX_PWR_SHandle;
    if(obj->enableSwitchingReq)
    {
        if(obj->pilMode == false)
        {
         // enable actuators
            int i;
            for(i=0; i< obj->numRegisteredPwmChannels; i++)
            {
                PLX_PWM_enableOut(obj->pwmChannels[i]);
            }
        }
        obj->gatesActive = true;
        obj->enableSwitchingReq = false;
    }
}

inline void PLX_PWR_configureTZGpio(uint16_t aTzId, uint16_t aGpio)
{
    EALLOW;
    if(aTzId == 1)
    {
        switch(aGpio)
        {
            case 12:
                GpioCtrlRegs.GPAMUX1.bit.GPIO12 = 1;
                GpioCtrlRegs.GPADIR.bit.GPIO12 = 0;
                break;
            case 42:
                GpioCtrlRegs.GPBMUX1.bit.GPIO42 = 2;
                GpioCtrlRegs.GPBDIR.bit.GPIO42 = 0;
                break;
            case 50:
                GpioCtrlRegs.GPBMUX2.bit.GPIO50 = 3;
                GpioCtrlRegs.GPBDIR.bit.GPIO50 = 0;
                break;
            default:
                break;
        }
    }
    else if(aTzId == 2)
    {
        switch(aGpio)
        {
            case 13:
                GpioCtrlRegs.GPAMUX1.bit.GPIO13 = 1;
                GpioCtrlRegs.GPADIR.bit.GPIO13 = 0;
                break;
            case 16:
                GpioCtrlRegs.GPAMUX2.bit.GPIO16 = 3;
                GpioCtrlRegs.GPADIR.bit.GPIO16 = 0;
                break;
            case 28:
                GpioCtrlRegs.GPAMUX2.bit.GPIO28 = 3;
                GpioCtrlRegs.GPADIR.bit.GPIO28 = 0;
                break;
            case 43:
                GpioCtrlRegs.GPBMUX1.bit.GPIO43 = 2;
                GpioCtrlRegs.GPBDIR.bit.GPIO43 = 0;
                break;
            case 51:
                GpioCtrlRegs.GPBMUX2.bit.GPIO51 = 3;
                GpioCtrlRegs.GPBDIR.bit.GPIO51 = 0;
                break;
            default:
                break;
        }
    }
    else if(aTzId == 3)
    {
        switch(aGpio)
        {
            case 14:
                GpioCtrlRegs.GPAMUX1.bit.GPIO14 = 1;
                GpioCtrlRegs.GPADIR.bit.GPIO14 = 0;
                break;
            case 17:
                GpioCtrlRegs.GPAMUX2.bit.GPIO17 = 3;
                GpioCtrlRegs.GPADIR.bit.GPIO17 = 0;
                break;
            case 29:
                GpioCtrlRegs.GPAMUX2.bit.GPIO29 = 3;
                GpioCtrlRegs.GPADIR.bit.GPIO29 = 0;
                break;
            default:
                break;
        }
    }
    else
    {

    }

    EDIS;
}

#endif /* PLX_PWR_IMPL_H_ */
