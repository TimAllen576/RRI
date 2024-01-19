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

#include "plx_pwm.h"

#pragma diag_suppress 112 // ASSERT(0) in switch statements

void PLX_PWM_sinit()
{
	EALLOW;
	SysCtrlRegs.PCLKCR1.bit.EPWM1ENCLK = 1; // ePWM1
	SysCtrlRegs.PCLKCR1.bit.EPWM2ENCLK = 1; // ePWM1
	SysCtrlRegs.PCLKCR1.bit.EPWM3ENCLK = 1; // ePWM1
	SysCtrlRegs.PCLKCR1.bit.EPWM4ENCLK = 1; // ePWM4
	SysCtrlRegs.PCLKCR1.bit.EPWM5ENCLK = 1;	// ePWM5
	SysCtrlRegs.PCLKCR1.bit.EPWM6ENCLK = 1;	// ePWM6
	EDIS;
}

void PLX_PWM_getRegisterBase(PLX_PWM_Unit_t aPwmChannel, volatile struct EPWM_REGS** aReg)
{
	switch(aPwmChannel)
	{
		default:
			PLX_ASSERT(0);
			break;
		case PLX_PWM_EPWM1:
			*aReg = &EPwm1Regs;
			break;
		case PLX_PWM_EPWM2:
			*aReg = &EPwm2Regs;
			break;
		case PLX_PWM_EPWM3:
			*aReg = &EPwm3Regs;
			break;
		case PLX_PWM_EPWM4:
			*aReg = &EPwm4Regs;
			break;
		case PLX_PWM_EPWM5:
			*aReg = &EPwm5Regs;
			break;
		case PLX_PWM_EPWM6:
			*aReg = &EPwm6Regs;
			break;
	}
}

void PLX_PWM_setDefaultParams(PLX_PWM_Params_t *aParams)
{
    aParams->outMode = PLX_PWM_OUTPUT_MODE_DUAL;

	aParams->reg.TBPRD = 0;
	aParams->reg.DBFED = 0;
	aParams->reg.DBRED = 0;

	aParams->reg.TBPHS.half.TBPHS = 0; // set Phase register to zero
	aParams->reg.TBCTL.bit.CTRMODE = TB_COUNT_UPDOWN; // symmetrical mode
	aParams->reg.TBCTL.bit.PHSEN = TB_DISABLE; // master module
	aParams->reg.TBCTL.bit.PRDLD = TB_SHADOW;
	aParams->reg.CMPCTL.bit.SHDWAMODE = CC_SHADOW;
	aParams->reg.CMPCTL.bit.SHDWBMODE = CC_SHADOW;
	aParams->reg.CMPCTL.bit.LOADAMODE = CC_CTR_ZERO; // load on CTR=Zero
	aParams->reg.CMPCTL.bit.LOADBMODE = CC_CTR_ZERO; // load on CTR=Zero
	aParams->reg.AQCTLA.bit.CAU = AQ_SET;
	aParams->reg.AQCTLA.bit.CAD = AQ_CLEAR;
    aParams->reg.AQCTLA.bit.PRD = AQ_NO_ACTION;
    aParams->reg.AQCTLA.bit.ZRO = AQ_NO_ACTION;
	aParams->reg.DBCTL.bit.OUT_MODE = DB_FULL_ENABLE; // enable Dead-band module
	aParams->reg.DBCTL.bit.POLSEL = DB_ACTV_HIC; // active Hi complementary
	aParams->reg.TZCTL.bit.TZA = TZ_NO_CHANGE;
	aParams->reg.TZCTL.bit.TZB = TZ_NO_CHANGE;
    aParams->reg.ETSEL.bit.INTSEL = ET_CTR_ZERO;

    aParams->reg.ETSEL.bit.SOCASEL = ET_CTR_ZERO;
    aParams->reg.ETSEL.bit.SOCAEN = 0;
    aParams->reg.ETPS.bit.SOCAPRD = 1;
}

PLX_PWM_Handle_t PLX_PWM_init(void *aMemory, const size_t aNumBytes)
{
	PLX_PWM_Handle_t handle;

	if(aNumBytes < sizeof(PLX_PWM_Obj_t))
		return((PLX_PWM_Handle_t)NULL);

	// set handle
	handle = (PLX_PWM_Handle_t)aMemory;

	return handle;
}

void PLX_PWM_configure(PLX_PWM_Handle_t aHandle, uint16_t aModulator, const PLX_PWM_Params_t *aParams)
{
	PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;

	PLX_ASSERT(aModulator >= 1);
	PLX_ASSERT(aModulator <= 6);

	// TODO: Use PLX_PWM_getRegisterBase
	switch(aModulator)
	{
		default:
		case 1:
			obj->pwm = &EPwm1Regs;
			break;
		case 2:
			obj->pwm = &EPwm2Regs;
			break;
		case 3:
			obj->pwm = &EPwm3Regs;
			break;
		case 4:
			obj->pwm = &EPwm4Regs;
			break;
		case 5:
			obj->pwm = &EPwm5Regs;
			break;
		case 6:
			obj->pwm = &EPwm6Regs;
			break;
	}

	EALLOW;

	obj->pwm->TBPRD = aParams->reg.TBPRD;
	obj->nomTBPRD = aParams->reg.TBPRD;
	obj->pwm->DBFED = aParams->reg.DBFED;
	obj->pwm->DBRED = aParams->reg.DBRED;

	obj->pwm->TBPHS.half.TBPHS = aParams->reg.TBPHS.half.TBPHS;
	obj->pwm->TBCTL.bit.CTRMODE = aParams->reg.TBCTL.bit.CTRMODE;
	obj->pwm->TBCTL.bit.PHSEN = aParams->reg.TBCTL.bit.PHSEN;
	obj->pwm->TBCTL.bit.PRDLD = aParams->reg.TBCTL.bit.PRDLD;
	obj->pwm->CMPCTL.bit.SHDWAMODE = aParams->reg.CMPCTL.bit.SHDWAMODE;
	obj->pwm->CMPCTL.bit.SHDWBMODE = aParams->reg.CMPCTL.bit.SHDWBMODE;
	obj->pwm->CMPCTL.bit.LOADAMODE = aParams->reg.CMPCTL.bit.SHDWAMODE;
	obj->pwm->CMPCTL.bit.LOADBMODE = aParams->reg.CMPCTL.bit.SHDWBMODE;
	obj->pwm->AQCTLA.bit.CAU = aParams->reg.AQCTLA.bit.CAU;
	obj->pwm->AQCTLA.bit.CAD = aParams->reg.AQCTLA.bit.CAD;
	obj->pwm->AQCTLA.bit.PRD = aParams->reg.AQCTLA.bit.PRD;
	obj->pwm->AQCTLA.bit.ZRO = aParams->reg.AQCTLA.bit.ZRO;
	obj->pwm->DBCTL.bit.OUT_MODE = aParams->reg.DBCTL.bit.OUT_MODE;
	obj->pwm->DBCTL.bit.POLSEL = aParams->reg.DBCTL.bit.POLSEL;
	obj->pwm->TZCTL.bit.TZA = aParams->reg.TZCTL.bit.TZA;
	obj->pwm->TZCTL.bit.TZB = aParams->reg.TZCTL.bit.TZB;

	obj->pwm->TZSEL.bit.CBC1 = aParams->reg.TZSEL.bit.CBC1;
	obj->pwm->TZSEL.bit.CBC2 = aParams->reg.TZSEL.bit.CBC2;
	obj->pwm->TZSEL.bit.CBC3 = aParams->reg.TZSEL.bit.CBC3;
	obj->pwm->TZSEL.bit.OSHT1 = aParams->reg.TZSEL.bit.OSHT1;
	obj->pwm->TZSEL.bit.OSHT2 = aParams->reg.TZSEL.bit.OSHT2;
	obj->pwm->TZSEL.bit.OSHT3 = aParams->reg.TZSEL.bit.OSHT3;

	obj->pwm->ETSEL.bit.INTSEL = aParams->reg.ETSEL.bit.INTSEL;

    obj->pwm->ETSEL.bit.SOCASEL = aParams->reg.ETSEL.bit.SOCASEL;
    obj->pwm->ETSEL.bit.SOCAEN = aParams->reg.ETSEL.bit.SOCAEN;
    obj->pwm->ETPS.bit.SOCAPRD = aParams->reg.ETPS.bit.SOCAPRD;

    // make sure all is off
    obj->pwm->TZFRC.bit.OST=1;

    if(aParams->outMode != PLX_PWM_OUTPUT_MODE_DISABLED)
    {
        switch(aModulator)
        {
            default:
            case 1:
                GpioCtrlRegs.GPAMUX1.bit.GPIO0 = 1;
                break;
            case 2:
                GpioCtrlRegs.GPAMUX1.bit.GPIO2 = 1;
                break;
            case 3:
                GpioCtrlRegs.GPAMUX1.bit.GPIO4 = 1;
                break;
            case 4:
                GpioCtrlRegs.GPAMUX1.bit.GPIO6 = 1;
                break;
            case 5:
                GpioCtrlRegs.GPAMUX1.bit.GPIO8 = 1;
                break;
            case 6:
                GpioCtrlRegs.GPAMUX1.bit.GPIO10 = 1;
                 break;
        }
    }

    if(aParams->outMode == PLX_PWM_OUTPUT_MODE_DUAL)
    {
        switch(aModulator)
        {
            default:
            case 1:
                GpioCtrlRegs.GPAMUX1.bit.GPIO1 = 1;
                break;
            case 2:
                GpioCtrlRegs.GPAMUX1.bit.GPIO3 = 1;
                break;
            case 3:
                GpioCtrlRegs.GPAMUX1.bit.GPIO5 = 1;
                break;
            case 4:
                GpioCtrlRegs.GPAMUX1.bit.GPIO7 = 1;
                break;
            case 5:
                GpioCtrlRegs.GPAMUX1.bit.GPIO9 = 1;
                break;
            case 6:
                GpioCtrlRegs.GPAMUX1.bit.GPIO11 = 1;
                break;
        }
    }

    EDIS;
    obj->sequence = 1;
}

void PLX_PWM_scalePeriod(PLX_PWM_Handle_t aHandle, float aScalingFactor)
{
    PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;

    PLX_ASSERT(aScalingFactor > 0.0);

    float newTBPRD;
    if(obj->pwm->TBCTL.bit.CTRMODE == TB_COUNT_UPDOWN)
    {
        // up-down
        newTBPRD = (float)(obj->nomTBPRD)*aScalingFactor;
    }
    else
    {
        // saw-tooth
        newTBPRD = (float)(obj->nomTBPRD+1)*aScalingFactor - 1.0;
    }
    if(newTBPRD < 1.0)
    {
        newTBPRD = 1.0;
    }
    else if(newTBPRD > 65535.0)
    {
        newTBPRD = 65535.0;
    }
    obj->pwm->TBPRD = (uint16_t)newTBPRD;
}

void PLX_PWM_setPhase(PLX_PWM_Handle_t aHandle, float aPhase)
{
    PLX_PWM_Obj_t *obj = (PLX_PWM_Obj_t *)aHandle;

    if((aPhase < 0) || (aPhase >= 1.0))
    {
        aPhase = 0;
    }

    uint16_t phase;
    uint16_t dir;
    if(obj->pwm->TBCTL.bit.CTRMODE == TB_COUNT_UPDOWN)
    {
        // up-down
        if (aPhase <= 0.5)
        {
            phase = (uint16_t)((float)(obj->pwm->TBPRD) * (aPhase) * 2);
            dir = 0;
        }
        else
        {
            phase = (uint16_t)((float)(obj->pwm->TBPRD) * (1-aPhase) * 2);
            dir = 1;
        }
    }
    else
    {
        // saw-tooth
        phase = (uint16_t)(((float)obj->pwm->TBPRD+1) * (1-aPhase));
        if(phase > obj->pwm->TBPRD)
        {
            phase = 0;
        }
        dir = 0;
    }
    obj->pwm->TBPHS.half.TBPHS = phase;
    obj->pwm->TBCTL.bit.PHSDIR = dir;
}
