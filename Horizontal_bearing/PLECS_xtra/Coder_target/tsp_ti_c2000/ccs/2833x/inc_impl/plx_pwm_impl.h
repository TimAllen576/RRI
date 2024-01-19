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

#ifndef PLX_PWM_IMPL_H_
#define PLX_PWM_IMPL_H_

typedef enum PLX_PWM_UNIT {
    PLX_PWM_EPWM_NONE=0,
	PLX_PWM_EPWM1,
	PLX_PWM_EPWM2,
	PLX_PWM_EPWM3,
	PLX_PWM_EPWM4,
	PLX_PWM_EPWM5,
	PLX_PWM_EPWM6,
	PLX_PWM_EPWM7,
	PLX_PWM_EPWM8,
	PLX_PWM_EPWM_MAX_PLUS_ONE
} PLX_PWM_Unit_t;

typedef struct PLX_PWM_REG_PARAMS {
    Uint16 TBPRD;
    union TBPHS_HRPWM_GROUP TBPHS;
    union TBCTL_REG TBCTL;
    union CMPCTL_REG CMPCTL;
    union AQCTL_REG AQCTLA;
    union DBCTL_REG DBCTL;
    Uint16 DBFED;
    Uint16 DBRED;
    union TZCTL_REG TZCTL;
    union ETSEL_REG ETSEL;
    union TZSEL_REG TZSEL;
    union ETPS_REG ETPS;
} PLX_PWM_RegParams_t;

typedef enum PLX_PWM_OUTPUT_MODE {
    PLX_PWM_OUTPUT_MODE_DUAL=0,
    PLX_PWM_OUTPUT_MODE_SINGLE,
    PLX_PWM_OUTPUT_MODE_DISABLED
} PLX_PWM_OutputMode_t;

typedef struct PLX_PWM_PARAMS {
    PLX_PWM_RegParams_t reg;
    PLX_PWM_OutputMode_t outMode;
} PLX_PWM_Params_t;

typedef struct PLX_PWM_OBJ
{
	volatile struct EPWM_REGS *pwm;
	uint16_t nomTBPRD;
    uint16_t sequence;
} PLX_PWM_Obj_t;

typedef PLX_PWM_Obj_t *PLX_PWM_Handle_t;

extern void PLX_PWM_getRegisterBase(PLX_PWM_Unit_t aPwmChannel, volatile struct EPWM_REGS** aReg);

inline uint32_t PLX_PWM_getFullDutyCompare(PLX_PWM_Handle_t aHandle)
{
    PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
    if(obj->pwm->TBCTL.bit.CTRMODE == TB_COUNT_UPDOWN)
    {
        // up-down
        return obj->pwm->TBPRD;
    }
    else
    {
        // triangle
        return (uint32_t)obj->pwm->TBPRD+1;
    }
}

inline uint32_t PLX_PWM_getCounter(PLX_PWM_Handle_t aHandle)
{
	PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
	return obj->pwm->TBCTR;
}

inline bool PLX_PWM_getCountDirection(PLX_PWM_Handle_t aHandle)
{
	PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
	return obj->pwm->TBSTS.bit.CTRDIR;
}

inline void PLX_PWM_enableOut(PLX_PWM_Handle_t aHandle)
{
	PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
	EALLOW;
	obj->pwm->TZCLR.bit.OST=1;
	EDIS;
}

inline bool PLX_PWM_pwmOutputIsEnabled(PLX_PWM_Handle_t aHandle)
{
    PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
    return (obj->pwm->TZFLG.bit.OST == 0);
}

inline void PLX_PWM_disableOut(PLX_PWM_Handle_t aHandle)
{
	PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
	EALLOW;
	obj->pwm->TZFRC.bit.OST=1;
	EDIS;
}

inline void PLX_PWM_setCompare(PLX_PWM_Handle_t aHandle, uint16_t aCompare)
{
    PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
    obj->pwm->CMPA.half.CMPA = aCompare;
}

inline void PLX_PWM_setTZSafe(PLX_PWM_Handle_t aHandle, uint16_t aSafe)
{
	PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
	obj->pwm->TZCTL.bit.TZA = aSafe;
	obj->pwm->TZCTL.bit.TZB = aSafe;
}

inline void PLX_PWM_setComparePh(PLX_PWM_Handle_t aHandle, uint16_t aCompare, uint16_t aPh, uint16_t aDir)
{
    PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
    obj->pwm->CMPA.half.CMPA = aCompare;
    obj->pwm->TBPHS.half.TBPHS = aPh;
    obj->pwm->TBCTL.bit.PHSDIR = aDir;
}

inline void PLX_PWM_setDeadTimeCounts(PLX_PWM_Handle_t aHandle, uint16_t aRisingEdgeDelay, uint16_t aFallingEdgeDelay)
{
    PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
    obj->pwm->DBFED = aFallingEdgeDelay;
    obj->pwm->DBRED = aRisingEdgeDelay;
}

inline void PLX_PWM_setOutToPassive(PLX_PWM_Handle_t aHandle)
{
    PLX_ASSERT(0);
}

inline void PLX_PWM_setOutToOperational(PLX_PWM_Handle_t aHandle)
{
    PLX_ASSERT(0);
}

inline void PLX_PWM_prepareSetOutToXTransition(PLX_PWM_Handle_t aHandle)
{
    PLX_ASSERT(0); // not supported by this chip
}

inline void PLX_PWM_setSequence(PLX_PWM_Handle_t aHandle, uint16_t aSequence)
{
    PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
    switch(aSequence)
    {
        case 0: //negative sequence w/ forcing ZERO/PRD state
            obj->pwm->AQCTLA.bit.CAU = 2;
            obj->pwm->AQCTLA.bit.CAD = 1;
            obj->pwm->AQCTLA.bit.ZRO = 1;
            obj->pwm->AQCTLA.bit.PRD = 2;
            break;

        case 1: //positive sequence w/ forcing ZERO/PRD state
            obj->pwm->AQCTLA.bit.CAU = 1;
            obj->pwm->AQCTLA.bit.CAD = 2;
            obj->pwm->AQCTLA.bit.ZRO = 2;
            obj->pwm->AQCTLA.bit.PRD = 1;
            break;

        case 2: //negative sequence w/o forcing ZERO/PRD state
            obj->pwm->AQCTLA.bit.CAU = 2;
            obj->pwm->AQCTLA.bit.CAD = 1;
            obj->pwm->AQCTLA.bit.ZRO = 0;
            obj->pwm->AQCTLA.bit.PRD = 0;
            break;

        case 3: //positive sequence w/o forcing ZERO/PRD state
            obj->pwm->AQCTLA.bit.CAU = 1;
            obj->pwm->AQCTLA.bit.CAD = 2;
            obj->pwm->AQCTLA.bit.ZRO = 0;
            obj->pwm->AQCTLA.bit.PRD = 0;
            break;

        default:
            PLX_ASSERT(0);
    }
    obj->sequence = aSequence;
 }

inline uint16_t PLX_PWM_getSequence(PLX_PWM_Handle_t aHandle)
{
    PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;
    return obj->sequence;
}

inline void PLX_PWM_setPwmDuty(PLX_PWM_Handle_t aHandle, float aDuty)
{
   float duty = aDuty;

   if (duty > 1.0)
   {
      duty = 1.0;
   }
   else if(duty < 0.0)
   {
      duty = 0.0;
   }

   if((PLX_PWM_getSequence(aHandle) & 1) == 0)
   {
      duty = 1.0 - duty;
   }

   float cmpF = duty * (float)PLX_PWM_getFullDutyCompare(aHandle);
   if(cmpF > 65535.0){
       cmpF = 65535.0;
   }
   PLX_PWM_setCompare(aHandle, (uint16_t)cmpF);
}

inline void PLX_PWM_enableAllClocks()
{
    EALLOW;
    SysCtrlRegs.PCLKCR1.bit.EPWM1ENCLK = 1;
    SysCtrlRegs.PCLKCR1.bit.EPWM2ENCLK = 1;
    SysCtrlRegs.PCLKCR1.bit.EPWM3ENCLK = 1;
    SysCtrlRegs.PCLKCR1.bit.EPWM4ENCLK = 1;
    SysCtrlRegs.PCLKCR1.bit.EPWM5ENCLK = 1;
    SysCtrlRegs.PCLKCR1.bit.EPWM6ENCLK = 1;
    EDIS;
}

inline void PLX_PWM_disableAllClocks()
{
    EALLOW;
    SysCtrlRegs.PCLKCR1.bit.EPWM1ENCLK = 0;
    SysCtrlRegs.PCLKCR1.bit.EPWM2ENCLK = 0;
    SysCtrlRegs.PCLKCR1.bit.EPWM3ENCLK = 0;
    SysCtrlRegs.PCLKCR1.bit.EPWM4ENCLK = 0;
    SysCtrlRegs.PCLKCR1.bit.EPWM5ENCLK = 0;
    SysCtrlRegs.PCLKCR1.bit.EPWM6ENCLK = 0;
    EDIS;
}

#endif /* PLX_PWM_IMPL_H_ */
