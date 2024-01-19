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

#pragma diag_suppress 112 // ASSERT(0) in switch statements

#define PLX_AIN_ADC_msDELAY 10L

static void PLX_AIN_powerupAdc(PLX_AIN_Handle_t aHandle, const PLX_AIN_AdcParams_t *aParams);

uint16_t PLX_AIN_NUM_CHANNELS_USED;

static uint32_t PLX_AIN_DelayCountsPerMs;
static float PLX_AIN_VoltsPerAdcBit;

void DSP28x_usDelay(long LoopCount);

void PLX_AIN_sinit(float aVref, uint32_t aSysClkHz)
{
	AdcRegs.ADCTRL2.bit.RST_SEQ1 = 1;         // Reset SEQ1
	AdcRegs.ADCST.bit.INT_SEQ1_CLR = 1;       // Clear INT SEQ1 bit
	PLX_AIN_NUM_CHANNELS_USED = 0;
	PLX_AIN_DelayCountsPerMs = (uint32_t)(((float)aSysClkHz/1000.0-0.9)/5.0);
	PLX_AIN_VoltsPerAdcBit = aVref/4096.0;
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
	aParams->ADCTRL1.bit.SEQ_CASC = 1; // cascaded sequence mode
	aParams->ADCTRL3.bit.SMODE_SEL = 0; // no simultaneous sampling
	aParams->ADCTRL2.bit.INT_ENA_SEQ1 = 1;
	aParams->ADCTRL2.bit.INT_MOD_SEQ1 = 0;
	aParams->ADCTRL1.bit.CPS = 1; // clock prescaler 1/2
	aParams->ADCTRL1.bit.SEQ_OVRD = 0; // disable sequencer override
	aParams->ADCTRL2.bit.EPWM_SOCA_SEQ1 = 0;
	aParams->ADCREFSEL.bit.REF_SEL = 0;// Select internal BG
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
			SysCtrlRegs.PCLKCR0.bit.ADCENCLK = 1;
			break;
	}
	EDIS;

	//obj->socCtrl = (union ADCSOCxCTL_REG *)&obj->adc->ADCSOC0CTL;
	PLX_AIN_powerupAdc(aHandle, aParams);
	EALLOW;
	obj->adc->ADCTRL1.bit.SEQ_OVRD = aParams->ADCTRL1.bit.SEQ_OVRD;
	obj->adc->ADCTRL2.bit.INT_ENA_SEQ1 = aParams->ADCTRL2.bit.INT_ENA_SEQ1;
	obj->adc->ADCTRL2.bit.INT_MOD_SEQ1 = aParams->ADCTRL2.bit.INT_MOD_SEQ1;
	obj->adc->ADCTRL1.bit.SEQ_CASC = aParams->ADCTRL1.bit.SEQ_CASC; // cascaded sequence mode
	obj->adc->ADCTRL3.bit.SMODE_SEL = aParams->ADCTRL3.bit.SMODE_SEL; // no simultaneous sampling
	EDIS;
	PLX_AIN_resetChannelSetup(aHandle);
}

void PLX_AIN_setDefaultChannelParams(PLX_AIN_ChannelParams_t *aParams)
{
    aParams->trigsel = 0;
    aParams->scale=1.0;
    aParams->offset=0.0;
}

void PLX_AIN_resetChannelSetup(PLX_AIN_Handle_t aHandle)
{
	PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;

	EALLOW;
	obj->adc->ADCTRL3.bit.SMODE_SEL = 0; // no simultaneous sampling
	EDIS;
}

void PLX_AIN_setupChannel(PLX_AIN_Handle_t aHandle, uint16_t aChannel, uint16_t aSource, const PLX_AIN_ChannelParams_t *aParams)
{
	PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;

	PLX_ASSERT(aChannel < PLX_AIN_NUM_CHANNELS);

	EALLOW;
	// TRIGSEL is not a feature of this chip, but we are using the convention of newer MCUs
	if(aParams->trigsel >= 5)
	{
		obj->adc->ADCTRL2.bit.EPWM_SOCA_SEQ1 = 1;// Enable SOCA from ePWM to start SEQ1
	}
	if(aChannel>PLX_AIN_NUM_CHANNELS_USED)
	{
		obj->adc->ADCMAXCONV.all = aChannel;
	}

	switch(aChannel)
	{
		case 0:
			obj->adc->ADCCHSELSEQ1.bit.CONV00 = aSource;
			break;
		case 1:
			obj->adc->ADCCHSELSEQ1.bit.CONV01 = aSource;
			break;
		case 2:
			obj->adc->ADCCHSELSEQ1.bit.CONV02 = aSource;
			break;
		case 3:
			obj->adc->ADCCHSELSEQ1.bit.CONV03 = aSource;
			break;
		case 4:
			obj->adc->ADCCHSELSEQ2.bit.CONV04 = aSource;
			break;
		case 5:
			obj->adc->ADCCHSELSEQ2.bit.CONV05 = aSource;
			break;
		case 6:
			obj->adc->ADCCHSELSEQ2.bit.CONV06 = aSource;
			break;
		case 7:
			obj->adc->ADCCHSELSEQ2.bit.CONV07 = aSource;
			break;
		case 8:
			obj->adc->ADCCHSELSEQ3.bit.CONV08 = aSource;
			break;
		case 9:
			obj->adc->ADCCHSELSEQ3.bit.CONV09 = aSource;
			break;
		case 10:
			obj->adc->ADCCHSELSEQ3.bit.CONV10 = aSource;
			break;
		case 11:
			obj->adc->ADCCHSELSEQ3.bit.CONV11 = aSource;
			break;
		case 12:
			obj->adc->ADCCHSELSEQ4.bit.CONV12 = aSource;
			break;
		case 13:
			obj->adc->ADCCHSELSEQ4.bit.CONV13 = aSource;
			break;
		case 14:
			obj->adc->ADCCHSELSEQ4.bit.CONV14 = aSource;
			break;
		case 15:
			obj->adc->ADCCHSELSEQ4.bit.CONV15 = aSource;
			break;
		default:
			break;
	}
	EDIS;
    obj->scale[aChannel] = aParams->scale*PLX_AIN_VoltsPerAdcBit;
    obj->offset[aChannel] = aParams->offset;
}

static void PLX_AIN_powerupAdc(PLX_AIN_Handle_t aHandle, const PLX_AIN_AdcParams_t *aParams)
{
	PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;

	//PLX_DELAY_US(PLX_AIN_ADC_usDELAY);
	obj->adc->ADCTRL1.all = 0x4000; // Reset ADC
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
	obj->adc->ADCTRL3.bit.ADCBGRFDN  = 3;      // Power ADC BG
	obj->adc->ADCTRL3.bit.ADCPWDN   = 1;      // Power ADC
	obj->adc->ADCREFSEL.bit.REF_SEL = aParams->ADCREFSEL.bit.REF_SEL; // Select interal BG
	EDIS;

	DSP28x_usDelay(PLX_AIN_ADC_msDELAY * PLX_AIN_DelayCountsPerMs); // Delay before converting ADC channels

	EALLOW;
	obj->adc->ADCTRL1.bit.CPS = aParams->ADCTRL1.bit.CPS;
	EDIS;

	DSP28x_usDelay(PLX_AIN_ADC_msDELAY * PLX_AIN_DelayCountsPerMs); // Delay before converting ADC channels
}
