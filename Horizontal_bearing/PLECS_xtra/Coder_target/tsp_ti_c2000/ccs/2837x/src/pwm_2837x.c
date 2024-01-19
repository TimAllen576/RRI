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

#include "F2837xD_EPwm_defines.h"
#include "plx_pwm.h"
#include "F2837xD_Gpio_defines.h"

/* TODO: Support all PWM channels! */

#pragma diag_suppress 112 // PLX_ASSERT(0) in switch statements

void PLX_PWM_sinit()
{
	EALLOW;
	CpuSysRegs.PCLKCR2.bit.EPWM1 = 1; // ePWM1
	CpuSysRegs.PCLKCR2.bit.EPWM2 = 1; // ePWM2
	CpuSysRegs.PCLKCR2.bit.EPWM3 = 1; // ePWM3
	CpuSysRegs.PCLKCR2.bit.EPWM4 = 1; // ePWM4
	CpuSysRegs.PCLKCR2.bit.EPWM5 = 1; // ePWM5
	CpuSysRegs.PCLKCR2.bit.EPWM6 = 1; // ePWM6
	CpuSysRegs.PCLKCR2.bit.EPWM7 = 1; // ePWM7
	CpuSysRegs.PCLKCR2.bit.EPWM8 = 1; // ePWM8
	CpuSysRegs.PCLKCR2.bit.EPWM9 = 1; // ePWM9
	CpuSysRegs.PCLKCR2.bit.EPWM10 = 1; // ePWM10
	CpuSysRegs.PCLKCR2.bit.EPWM11 = 1; // ePWM11
	CpuSysRegs.PCLKCR2.bit.EPWM12 = 1; // ePWM12

    // enable larger period counter
    EPwm1Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm2Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm3Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm4Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm5Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm6Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm7Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm8Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm9Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm10Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm11Regs.ETPS.bit.SOCPSSEL = 1;
    EPwm12Regs.ETPS.bit.SOCPSSEL = 1;

	EDIS;
}

void PLX_PWM_getRegisterBase(PLX_PWM_Unit_t aPwmChannel, volatile struct EPWM_REGS** aReg){
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
		case PLX_PWM_EPWM7:
			*aReg = &EPwm7Regs;
			break;
		case PLX_PWM_EPWM8:
			*aReg = &EPwm8Regs;
			break;
		case PLX_PWM_EPWM9:
			*aReg = &EPwm9Regs;
			break;
		case PLX_PWM_EPWM10:
			*aReg = &EPwm10Regs;
			break;
		case PLX_PWM_EPWM11:
			*aReg = &EPwm11Regs;
			break;
		case PLX_PWM_EPWM12:
			*aReg = &EPwm12Regs;
			break;
	}
}

void PLX_PWM_setDefaultParams(PLX_PWM_Params_t *aParams)
{
    aParams->outMode = PLX_PWM_OUTPUT_MODE_DUAL;

	aParams->reg.TBPRD = 0;
	aParams->reg.DBFED.all = 0;
	aParams->reg.DBRED.all = 0;
	aParams->reg.TBCTL.bit.SYNCOSEL = TB_SYNC_IN;

	aParams->reg.TBPHS.bit.TBPHS = 0; // set Phase register to zero
	aParams->reg.TBCTL.bit.CTRMODE = TB_COUNT_UPDOWN; // symmetrical mode
	aParams->reg.TBCTL.bit.PHSEN = TB_DISABLE; // master module
	aParams->reg.TBCTL.bit.PRDLD = TB_SHADOW;
	aParams->reg.CMPCTL.bit.SHDWAMODE = CC_SHADOW;
	aParams->reg.CMPCTL.bit.SHDWBMODE = CC_SHADOW;
    aParams->reg.CMPCTL.bit.LOADAMODE = CC_CTR_ZERO_PRD; // load on CTR=Zero and Prd
    aParams->reg.CMPCTL.bit.LOADBMODE = CC_CTR_ZERO_PRD; // load on CTR=Zero and Prd
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
    aParams->reg.ETSOCPS.bit.SOCAPRD2 = 1;
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
	PLX_ASSERT(aModulator <= 12);

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
		case 7:
			obj->pwm = &EPwm7Regs;
			break;
		case 8:
			obj->pwm = &EPwm8Regs;
			break;
		case 9:
			obj->pwm = &EPwm9Regs;
			break;
		case 10:
			obj->pwm = &EPwm10Regs;
			break;
		case 11:
			obj->pwm = &EPwm11Regs;
			break;
		case 12:
			obj->pwm = &EPwm12Regs;
			break;
	}

	EALLOW;

	obj->pwm->TBPRD = aParams->reg.TBPRD;
	obj->nomTBPRD = aParams->reg.TBPRD;
	obj->pwm->DBFED.all = aParams->reg.DBFED.all;
	obj->pwm->DBRED.all = aParams->reg.DBRED.all;

	obj->pwm->TBPHS.bit.TBPHS = aParams->reg.TBPHS.bit.TBPHS;
	obj->pwm->TBCTL.bit.CTRMODE = aParams->reg.TBCTL.bit.CTRMODE;
	obj->pwm->TBCTL.bit.PHSEN = aParams->reg.TBCTL.bit.PHSEN;
	obj->pwm->TBCTL.bit.PRDLD = aParams->reg.TBCTL.bit.PRDLD;
	obj->pwm->CMPCTL.bit.SHDWAMODE = aParams->reg.CMPCTL.bit.SHDWAMODE;
	obj->pwm->CMPCTL.bit.SHDWBMODE = aParams->reg.CMPCTL.bit.SHDWBMODE;
    obj->pwm->CMPCTL.bit.LOADAMODE = aParams->reg.CMPCTL.bit.LOADAMODE;
    obj->pwm->CMPCTL.bit.LOADBMODE = aParams->reg.CMPCTL.bit.LOADBMODE;

    // enable shadowing to allow synchronized PWM sequence modifications
    obj->pwm->AQCTL.bit.SHDWAQAMODE = 1; // action control A shadowed
    obj->pwm->AQCTL.bit.LDAQAMODE = 2; // action control A loaded at zero and period

    obj->pwm->AQCTLA.bit.CAU = aParams->reg.AQCTLA.bit.CAU;
	obj->pwm->AQCTLA.bit.CAD = aParams->reg.AQCTLA.bit.CAD;
	obj->pwm->AQCTLA.bit.PRD = aParams->reg.AQCTLA.bit.PRD;
	obj->pwm->AQCTLA.bit.ZRO = aParams->reg.AQCTLA.bit.ZRO;

	// shadowing to allow synchronized disabling of leg
	obj->pwm->DBCTL2.bit.SHDWDBCTLMODE = 1; // shadow [5:0]of the DBCTL
	obj->pwm->DBCTL2.bit.LOADDBCTLMODE = 0; // load at zero
	obj->pwm->AQSFRC.bit.RLDCSF = 0; // load software force on zero

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
    obj->pwm->ETSOCPS.bit.SOCAPRD2 = aParams->reg.ETSOCPS.bit.SOCAPRD2;

	// make sure all is off
	obj->pwm->TZFRC.bit.OST=1;

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
    obj->pwm->TBPHS.bit.TBPHS= phase;
    obj->pwm->TBCTL.bit.PHSDIR = dir;
}
