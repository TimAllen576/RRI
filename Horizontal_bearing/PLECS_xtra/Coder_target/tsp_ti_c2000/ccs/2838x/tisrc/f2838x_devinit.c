/*
   Copyright (c) 2021 by Plexim GmbH
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

#include "includes.h"
#include "debug.h"

#include "flash.h"

// Function prototypes
void ISR_ILLEGAL(void);

void PieCntlInit(void);
static void PieVectTableInit(void);

#ifdef CPU1
static void EnableUnbondedIOPullups(void);
#endif

#pragma diag_suppress 112 // PLX_ASSERT(0) in switch statements

#ifdef CPU1
void DevInit(uint32_t aDeviceClkConf, uint32_t aAuxClockConf){
#else
void DevInit(void){
#endif
    SysCtl_disableWatchdog();

	DINT;			// Global Disable all Interrupts
	IER = 0x0000;	// Disable CPU interrupts
	IFR = 0x0000;	// Clear all CPU interrupt flags

	// Initialise interrupt controller and Vector Table
	// to defaults for now. Application ISR mapping done later.
	PieCntlInit();
	PieVectTableInit();

#ifdef CPU1
    //
    //Disable pin locks
    //
    EALLOW;
    GpioCtrlRegs.GPALOCK.all = 0x00000000;
    GpioCtrlRegs.GPBLOCK.all = 0x00000000;
    GpioCtrlRegs.GPCLOCK.all = 0x00000000;
    GpioCtrlRegs.GPDLOCK.all = 0x00000000;
    GpioCtrlRegs.GPELOCK.all = 0x00000000;
    GpioCtrlRegs.GPFLOCK.all = 0x00000000;
    EDIS;

	//
	// Enable pull-ups on unbonded IOs as soon as possible to reduce power
	// consumption.
	//
	EnableUnbondedIOPullups();

	EALLOW;

	CpuSysRegs.PCLKCR13.bit.ADC_A = 1;
	CpuSysRegs.PCLKCR13.bit.ADC_B = 1;
	CpuSysRegs.PCLKCR13.bit.ADC_C = 1;
	CpuSysRegs.PCLKCR13.bit.ADC_D = 1;

	//
	// Check if device is trimmed
	//
	if(*((uint16_t *)0x5D736) == 0x0000){
	    //
	    // Device is not trimmed--apply static calibration values
	    //
	    AnalogSubsysRegs.ANAREFTRIMA.all = 31709;
	    AnalogSubsysRegs.ANAREFTRIMB.all = 31709;
	    AnalogSubsysRegs.ANAREFTRIMC.all = 31709;
	    AnalogSubsysRegs.ANAREFTRIMD.all = 31709;
	}

	CpuSysRegs.PCLKCR13.bit.ADC_A = 0;
	CpuSysRegs.PCLKCR13.bit.ADC_B = 0;
	CpuSysRegs.PCLKCR13.bit.ADC_C = 0;
	CpuSysRegs.PCLKCR13.bit.ADC_D = 0;
	EDIS;

	// workaround for driverlib bug
    EALLOW;
    HWREGH(CLKCFG_BASE + SYSCTL_O_CLKSRCCTL1) &= ~SYSCTL_CLKSRCCTL1_OSCCLKSRCSEL_M;
    EDIS;

    SysCtl_delay(12U);

    //
    // Set up PLL control and clock dividers
    //
    SysCtl_setClock(aDeviceClkConf);

    //
    // Set up AUXPLL control and clock dividers needed for CMCLK
    //
    SysCtl_setAuxClock(aAuxClockConf);

#if 0
#ifndef _FLASH
    //
    // Call Device_cal function when run using debugger
    // This function is called as part of the Boot code. The function is called
    // in the InitSysCtrl function since during debug time resets, the boot code
    // will not be executed and the gel script will reinitialize all the
    // registers and the calibrated values will be lost.
    //
    Device_cal();
#endif
#endif
#endif // CPU1
}

// This function initializes the PIE control registers to a known state.
//
void PieCntlInit(void)
{
    //
     // Disable Interrupts at the CPU level:
     //
     DINT;

     //
     // Disable the PIE
     //
     PieCtrlRegs.PIECTRL.bit.ENPIE = 0;

     //
     // Clear all PIEIER registers:
     //
     PieCtrlRegs.PIEIER1.all = 0;
     PieCtrlRegs.PIEIER2.all = 0;
     PieCtrlRegs.PIEIER3.all = 0;
     PieCtrlRegs.PIEIER4.all = 0;
     PieCtrlRegs.PIEIER5.all = 0;
     PieCtrlRegs.PIEIER6.all = 0;
     PieCtrlRegs.PIEIER7.all = 0;
     PieCtrlRegs.PIEIER8.all = 0;
     PieCtrlRegs.PIEIER9.all = 0;
     PieCtrlRegs.PIEIER10.all = 0;
     PieCtrlRegs.PIEIER11.all = 0;
     PieCtrlRegs.PIEIER12.all = 0;

     //
     // Clear all PIEIFR registers:
     //
     PieCtrlRegs.PIEIFR1.all = 0;
     PieCtrlRegs.PIEIFR2.all = 0;
     PieCtrlRegs.PIEIFR3.all = 0;
     PieCtrlRegs.PIEIFR4.all = 0;
     PieCtrlRegs.PIEIFR5.all = 0;
     PieCtrlRegs.PIEIFR6.all = 0;
     PieCtrlRegs.PIEIFR7.all = 0;
     PieCtrlRegs.PIEIFR8.all = 0;
     PieCtrlRegs.PIEIFR9.all = 0;
     PieCtrlRegs.PIEIFR10.all = 0;
     PieCtrlRegs.PIEIFR11.all = 0;
     PieCtrlRegs.PIEIFR12.all = 0;
}

static void PieVectTableInit(void)
{
	uint16_t  i;
	uint32_t  *Source  =  (void  *)  &ISR_ILLEGAL;
	uint32_t  *Dest  =  (void  *)  &PieVectTable;

	//
	// Do not write over first 3 32-bit locations (these locations are
	// initialized by Boot ROM with boot variables)
	//
	Dest  =  Dest  +  3;

	EALLOW;
	for(i  =  0;  i  <  221;  i++)
	{
		*Dest++  =  *Source;
	}
	EDIS;

	//
	// Enable the PIE Vector Table
	//
	PieCtrlRegs.PIECTRL.bit.ENPIE  =  1;
}

interrupt void ISR_ILLEGAL(void)   // Illegal operation TRAP
{
	PLX_ASSERT(0);
}

void InitFlashHz(uint32_t clkHz)
{
    uint16_t waitstates;
    uint16_t clkMHz = (uint16_t)(clkHz / 1000000L);
    if(clkMHz > 200){
        PLX_ASSERT(0);
    } else if(clkMHz > 150){
        waitstates = 0x3;
    } else if(clkMHz > 100){
        waitstates = 0x2;
    } else if(clkMHz > 50){
        waitstates = 0x1;
    } else {
        waitstates = 0x0;
    }

    Flash_initModule(FLASH0CTRL_BASE, FLASH0ECC_BASE, waitstates);
}

void MemCopy(uint16_t *SourceAddr, uint16_t* SourceEndAddr, uint16_t* DestAddr)
{
	while(SourceAddr < SourceEndAddr)
	{
		*DestAddr++ = *SourceAddr++;
	}
	return;
}

#ifdef CPU1

static void EnableUnbondedIOPullupsFor176Pin()
 {
     EALLOW;
     GpioCtrlRegs.GPCPUD.all = ~0x80000000;  //GPIO 95
     GpioCtrlRegs.GPDPUD.all = ~0xFFFFFFF7;  //GPIOs 96-127
     GpioCtrlRegs.GPEPUD.all = ~0xFFFFFFDF;  //GPIOs 128-159 except for 133
     GpioCtrlRegs.GPFPUD.all = ~0x000001FF;  //GPIOs 160-168
     EDIS;
 }

 static void EnableUnbondedIOPullups()
 {
     //
     //bits 8-10 have pin count
     //
     unsigned char pin_count = (DevCfgRegs.PARTIDL.bit.PIN_COUNT) ;

     //
     //6 = 176 pin
     //7 = 337 pin
     //
     if (pin_count == 6)
     {
         EnableUnbondedIOPullupsFor176Pin();
     }
     else
     {
         //do nothing - this is 337 pin package
     }
 }

#define BOOT_KEY                                0x5A000000UL
#define CM_BOOT_FREQ_125MHZ                     0x7D00U
#define CPU2_BOOT_FREQ_200MHZ                   0xC800U

void DevBootCPU2(uint32_t bootmode, uint32_t clkHz)
{
    IPC_setBootMode(IPC_CPU1_L_CPU2_R, (BOOT_KEY | CPU2_BOOT_FREQ_200MHZ | bootmode));

    IPC_setFlagLtoR(IPC_CPU1_L_CPU2_R, IPC_FLAG0);

    SysCtl_controlCPU2Reset(SYSCTL_CORE_DEACTIVE);
    while(SysCtl_isCPU2Reset() == 0x1U);
}

void DevBootCM(uint32_t bootmode, uint32_t clkHz)
{
    IPC_setBootMode(IPC_CPU1_L_CM_R, (BOOT_KEY | CM_BOOT_FREQ_125MHZ | bootmode));

    IPC_setFlagLtoR(IPC_CPU1_L_CM_R, IPC_FLAG0);

    SysCtl_controlCMReset(SYSCTL_CORE_DEACTIVE);
    while(SysCtl_isCMReset() == 0x1U);
}
#endif //CPU1
