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

#include "f28004x_adc_defines.h"
#include "plx_ain.h"

#pragma diag_suppress 112 // PLX_ASSERT(0) in switch statements

/* Note:
 * No power-up delay implemented. Assuming system-level delay will allow ADC to settle
 */

static float PLX_AIN_VoltsPerAdcBit;
static uint32_t PLX_AIN_SysClkHz;

extern void SetVREF(int module, int mode, int ref);

void PLX_AIN_sinit(float aVref, uint32_t aSysClkHz)
{
    PLX_ASSERT(aVref == (float)3.3);
    PLX_AIN_VoltsPerAdcBit = 3.3/4096.0;
    PLX_AIN_SysClkHz = aSysClkHz;

    // lower-pin-count parts have shared reference pins
    // it is therefore important that all ADCs are configured for the same reference.
    SetVREF(ADC_ADCA, ADC_INTERNAL, ADC_VREF3P3);
    SetVREF(ADC_ADCB, ADC_INTERNAL, ADC_VREF3P3);
    SetVREF(ADC_ADCC, ADC_INTERNAL, ADC_VREF3P3);
}

void PLX_AIN_getRegisterBase(PLX_AIN_Unit_t aAdcUnit, volatile struct ADC_REGS** aReg){
	switch(aAdcUnit)
	{
	default:
		PLX_ASSERT(0);
		break;

	case PLX_AIN_ADC_A:
		*aReg = &AdcaRegs;
		break;

	case PLX_AIN_ADC_B:
		*aReg = &AdcbRegs;
		break;

	case PLX_AIN_ADC_C:
		*aReg = &AdccRegs;
		break;
	}
}

void PLX_AIN_setDefaultAdcParams(PLX_AIN_AdcParams_t *aParams)
{
    aParams->ADCCTL1.bit.INTPULSEPOS = 1; // set pulse positions to late
    // max allowable ADC clock is 50 MHz (min 5 MHz)
    if(PLX_AIN_SysClkHz <= 50000000L){
        aParams->ADCCTL2.bit.PRESCALE = 0; //set ADCCLK divider to /1.0
    } else if(PLX_AIN_SysClkHz <= 75000000L){
        aParams->ADCCTL2.bit.PRESCALE = 1; //set ADCCLK divider to /2.0
    } else if(PLX_AIN_SysClkHz <= 100000000L){
        aParams->ADCCTL2.bit.PRESCALE = 2; //set ADCCLK divider to /2.0
    } else if(PLX_AIN_SysClkHz <= 125000000L){
        aParams->ADCCTL2.bit.PRESCALE = 3; //set ADCCLK divider to /2.5
    } else if(PLX_AIN_SysClkHz <= 150000000L){
        aParams->ADCCTL2.bit.PRESCALE = 4; //set ADCCLK divider to /3.0
    } else if(PLX_AIN_SysClkHz <= 175000000L){
        aParams->ADCCTL2.bit.PRESCALE = 5; //set ADCCLK divider to /3.5
    } else {
        aParams->ADCCTL2.bit.PRESCALE = 6; //set ADCCLK divider to /4.0
    }
    aParams->ADCSOCPRICTL.bit.SOCPRIORITY = 0; // round-robin - no high priority channels
    aParams->ADCINTSEL1N2.bit.INT1SEL = 0;
}

PLX_AIN_Handle_t PLX_AIN_init(void *aMemory, const size_t aNumBytes)
{
	PLX_AIN_Handle_t handle;

	if(aNumBytes < sizeof(PLX_AIN_Obj_t))
		return((PLX_AIN_Handle_t)NULL);

	// set handle
	handle = (PLX_AIN_Handle_t)aMemory;

	return handle;
}

void PLX_AIN_configure(PLX_AIN_Handle_t aHandle, PLX_AIN_Unit_t aUnit, const PLX_AIN_AdcParams_t *aParams)
{
	PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;

	EALLOW;
	switch(aUnit)
	{
		default:
			PLX_ASSERT(0);
			break;

		case PLX_AIN_ADC_A:
			obj->adc = &AdcaRegs;
			obj->results = (uint16_t *)&AdcaResultRegs;
			CpuSysRegs.PCLKCR13.bit.ADC_A = 1;
			break;

		case PLX_AIN_ADC_B:
			obj->adc = &AdcbRegs;
			obj->results = (uint16_t *)&AdcbResultRegs;
			CpuSysRegs.PCLKCR13.bit.ADC_B = 1;
			break;

		case PLX_AIN_ADC_C:
			obj->adc = &AdccRegs;
			obj->results = (uint16_t *)&AdccResultRegs;
			CpuSysRegs.PCLKCR13.bit.ADC_C = 1;
			break;
	}
	EDIS;

	obj->socCtrl = (union ADCSOC0CTL_REG *)&obj->adc->ADCSOC0CTL;

	EALLOW;
	obj->adc->ADCCTL1.bit.ADCPWDNZ = 1; // power up the ADC
	obj->adc->ADCCTL1.bit.INTPULSEPOS = aParams->ADCCTL1.bit.INTPULSEPOS;
	obj->adc->ADCCTL2.bit.PRESCALE = aParams->ADCCTL2.bit.PRESCALE;
	obj->adc->ADCSOCPRICTL.bit.SOCPRIORITY = aParams->ADCSOCPRICTL.bit.SOCPRIORITY;
	obj->adc->ADCINTSEL1N2.bit.INT1SEL = aParams->ADCINTSEL1N2.bit.INT1SEL;
	EDIS;
	PLX_AIN_resetChannelSetup(aHandle);
}

void PLX_AIN_setDefaultChannelParams(PLX_AIN_ChannelParams_t *aParams)
{
	aParams->ADCSOCxCTL.bit.TRIGSEL = 1; // trigger on CpuTimer0
	// minimal sample window is for single-ended is 75 ns, determined by SYSCLK
    if(PLX_AIN_SysClkHz <= 100000000L){
        aParams->ADCSOCxCTL.bit.ACQPS = 7;
    } else if(PLX_AIN_SysClkHz <= 120000000L){
        aParams->ADCSOCxCTL.bit.ACQPS = 8;
    } else if(PLX_AIN_SysClkHz <= 150000000L){
        aParams->ADCSOCxCTL.bit.ACQPS = 11;
    } else if(PLX_AIN_SysClkHz <= 175000000L){
        aParams->ADCSOCxCTL.bit.ACQPS = 13;
    } else {
        aParams->ADCSOCxCTL.bit.ACQPS = 14;
    }
    aParams->scale=1.0;
    aParams->offset=0.0;
}

void PLX_AIN_resetChannelSetup(PLX_AIN_Handle_t aHandle)
{
	PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;

	int i;
	EALLOW;
	for(i=0; i<PLX_AIN_NUM_CHANNELS; i++)
	{
		obj->socCtrl[i].bit.TRIGSEL = 0;
	}
	EDIS;
}

void PLX_AIN_setupChannel(PLX_AIN_Handle_t aHandle, uint16_t aChannel, uint16_t aSource, const PLX_AIN_ChannelParams_t *aParams)
{
	PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;

	PLX_ASSERT(aChannel < PLX_AIN_NUM_CHANNELS);
	PLX_ASSERT(aParams->ADCSOCxCTL.bit.TRIGSEL <= 0x1C);

	EALLOW;
	obj->socCtrl[aChannel].bit.CHSEL = aSource;
	obj->socCtrl[aChannel].bit.TRIGSEL = aParams->ADCSOCxCTL.bit.TRIGSEL;
	obj->socCtrl[aChannel].bit.ACQPS = aParams->ADCSOCxCTL.bit.ACQPS;
	EDIS;
    obj->scale[aChannel] = aParams->scale*PLX_AIN_VoltsPerAdcBit;
    obj->offset[aChannel] = aParams->offset;
}
