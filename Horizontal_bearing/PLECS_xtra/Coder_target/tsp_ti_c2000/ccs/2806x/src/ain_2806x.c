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

#include "plx_ain.h"

#pragma diag_suppress 112 // PLX_ASSERT(0) in switch statements

#define PLX_AIN_ADC_msDELAY 10L

static void PLX_AIN_powerupAdc(PLX_AIN_Handle_t aHandle, const PLX_AIN_AdcParams_t *aParams);

static uint32_t PLX_AIN_DelayCountsPerMs;
static float PLX_AIN_VoltsPerAdcBit;

void DSP28x_usDelay(long LoopCount);

void PLX_AIN_sinit(float aVref, uint32_t aSysClkHz)
{
	// Configure ADC pins using AIO regs
	// This specifies which of the possible AIO pins will be Analog input pins.
	// NOTE: AIO1,3,5,7-9,11,13,15 are analog inputs in all AIOMUX1 configurations.
	EALLOW;
	GpioCtrlRegs.AIOMUX1.bit.AIO2 = 2;    // Configure AIO2 for A2 (analog input) operation
	GpioCtrlRegs.AIOMUX1.bit.AIO4 = 2;    // Configure AIO4 for A4 (analog input) operation
	GpioCtrlRegs.AIOMUX1.bit.AIO6 = 2;    // Configure AIO6 for A6 (analog input) operation
	GpioCtrlRegs.AIOMUX1.bit.AIO10 = 2;   // Configure AIO10 for B2 (analog input) operation
	GpioCtrlRegs.AIOMUX1.bit.AIO12 = 2;   // Configure AIO12 for B4 (analog input) operation
	GpioCtrlRegs.AIOMUX1.bit.AIO14 = 2;   // Configure AIO14 for B6 (analog input) operation
	EDIS;
    PLX_AIN_DelayCountsPerMs = (uint32_t)(((float)aSysClkHz/1000.0F-0.9F)/5.0F);
    PLX_AIN_VoltsPerAdcBit = aVref/4096.0F;
}

void PLX_AIN_getRegisterBase(PLX_AIN_Unit_t aAdcUnit, volatile struct ADC_REGS** aReg){
	switch(aAdcUnit)
	{
		default:
			PLX_ASSERT(0);
			break;
		case PLX_AIN_ADC:
			*aReg = &AdcRegs;
			break;
	}
}

void PLX_AIN_setDefaultAdcParams(PLX_AIN_AdcParams_t *aParams)
{
   aParams->INTSEL1N2.all = 0;
   aParams->ADCCTL1.bit.ADCREFSEL = 0; // Select internal BG
   aParams->ADCCTL2.bit.CLKDIV2EN = 1; // CLKDIV2EN=1, CLKDIV4EN=0 -> ADCCLK=SYSCLK/2 (max is 45 MHz)
   aParams->ADCCTL2.bit.CLKDIV4EN = 0;
   aParams->ADCCTL2.bit.ADCNONOVERLAP = 1; // enable non-overlap mode
   aParams->SOCPRICTL.bit.SOCPRIORITY = 0; // round-robin - no high priority channels
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
		case PLX_AIN_ADC:
			obj->adc = &AdcRegs;
			obj->results = (uint16_t *)&AdcResult;
			SysCtrlRegs.PCLKCR0.bit.ADCENCLK = 1;
			break;
	}
	EDIS;

	obj->socCtrl = (union ADCSOCxCTL_REG *)&obj->adc->ADCSOC0CTL;
	PLX_AIN_powerupAdc(aHandle, aParams);
	EALLOW;
	obj->adc->ADCCTL2.bit.ADCNONOVERLAP = aParams->ADCCTL2.bit.ADCNONOVERLAP;
	obj->adc->SOCPRICTL.bit.SOCPRIORITY = aParams->SOCPRICTL.bit.SOCPRIORITY;
	obj->adc->INTSEL1N2.all = aParams->INTSEL1N2.all;
	EDIS;
	PLX_AIN_resetChannelSetup(aHandle);
}

void PLX_AIN_setDefaultChannelParams(PLX_AIN_ChannelParams_t *aParams)
{
	aParams->ADCSOCxCTL.bit.TRIGSEL = 1; // trigger on CpuTimer0
	aParams->ADCSOCxCTL.bit.ACQPS = 6; // minimal value, max = 64-1, S+H in ADC clocks
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
	obj->adc->ADCSAMPLEMODE.all = 0; // no simultaneous sampling
	EDIS;
}

void PLX_AIN_setupChannel(PLX_AIN_Handle_t aHandle, uint16_t aChannel, uint16_t aSource, const PLX_AIN_ChannelParams_t *aParams)
{
	PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;

	PLX_ASSERT(aChannel < PLX_AIN_NUM_CHANNELS);
	PLX_ASSERT(aParams->ADCSOCxCTL.bit.TRIGSEL <= 0x14);

	EALLOW;
	obj->socCtrl[aChannel].bit.CHSEL = aSource;
	obj->socCtrl[aChannel].bit.TRIGSEL = aParams->ADCSOCxCTL.bit.TRIGSEL;
	obj->socCtrl[aChannel].bit.ACQPS = aParams->ADCSOCxCTL.bit.ACQPS;
	EDIS;

	obj->scale[aChannel] = aParams->scale*PLX_AIN_VoltsPerAdcBit;
    obj->offset[aChannel] = aParams->offset;
}


static void PLX_AIN_powerupAdc(PLX_AIN_Handle_t aHandle, const PLX_AIN_AdcParams_t *aParams)
{
	PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;

	//PLX_DELAY_US(PLX_AIN_ADC_usDELAY);
	obj->adc->ADCCTL1.all = 0x4000; // Reset ADC
	asm(" NOP ");
	asm(" NOP ");
	EDIS;

	// To powerup the ADC the ADCENCLK bit should be set first to enable
	// clocks, followed by powering up the bandgap, reference circuitry, and ADC core.
	// Before the first conversion is performed a 5ms delay must be observed
	// after power up to give all analog circuits time to power up and settle

	// Please note that for the delay function below to operate correctly the
	// CPU_RATE define statement in the F2806x_Examples.h file must
	// contain the correct CPU clock period in nanoseconds.
	EALLOW;
	obj->adc->ADCCTL1.bit.ADCBGPWD  = 1;      // Power ADC BG
	obj->adc->ADCCTL1.bit.ADCREFPWD = 1;      // Power reference
	obj->adc->ADCCTL1.bit.ADCPWDN   = 1;      // Power ADC
	obj->adc->ADCCTL1.bit.ADCENABLE = 1;      // Enable ADC
	obj->adc->ADCCTL1.bit.ADCREFSEL = aParams->ADCCTL1.bit.ADCREFSEL; // Select interal BG
	EDIS;

    DSP28x_usDelay(PLX_AIN_ADC_msDELAY * PLX_AIN_DelayCountsPerMs); // Delay before converting ADC channels

	EALLOW;
	obj->adc->ADCCTL2.bit.CLKDIV2EN = aParams->ADCCTL2.bit.CLKDIV2EN;
	obj->adc->ADCCTL2.bit.CLKDIV4EN = aParams->ADCCTL2.bit.CLKDIV4EN;
	EDIS;

    DSP28x_usDelay(PLX_AIN_ADC_msDELAY * PLX_AIN_DelayCountsPerMs); // Delay before converting ADC channels
}
