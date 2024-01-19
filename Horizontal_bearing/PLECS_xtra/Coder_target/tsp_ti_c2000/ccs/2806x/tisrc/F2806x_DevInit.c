
/***************************
Note that the CLA is not used nor initialized in this project.
 ***************************/

#include "includes.h"

// Functions that will be run from RAM need to be assigned to
// a different section.  This section will then be mapped to a load and
// run address using the linker cmd file.
#pragma CODE_SECTION(InitFlash, "ramfuncs");

void DeviceInit(Uint16 clock_source, Uint16 pllDiv);
void PieCntlInit(void);
void PieVectTableInit(void);
void WDogDisable(void);
void PLLset(Uint16 clock_source, Uint16 pllDiv);
void ISR_ILLEGAL(void);

// The following pointer to a function call calibrates the ADC and internal oscillators
#define Device_cal (void   (*)(void))0x3D7C80

//--------------------------------------------------------------------
//  Configure Device for target Application Here
//--------------------------------------------------------------------
void DeviceInit(Uint16 clock_source, Uint16 pllDiv)
{
	WDogDisable(); 	// Disable the watchdog initially
	DINT;			// Global Disable all Interrupts
	IER = 0x0000;	// Disable CPU interrupts
	IFR = 0x0000;	// Clear all CPU interrupt flags

	// assumes DSP28_DIVSEL   2
	PLLset(clock_source, pllDiv);	// choose from options above

	// Initialize interrupt controller and Vector Table
	// to defaults for now. Application ISR mapping done later.
	PieCntlInit();
	PieVectTableInit();

	EALLOW; // below registers are "protected", allow access.

	// LOW SPEED CLOCKS prescale register settings
	SysCtrlRegs.LOSPCP.all = 0x0002;		// Sysclk / 4
	SysCtrlRegs.XCLK.bit.XCLKOUTDIV=2;


	// ADC CALIBRATION
	//---------------------------------------------------
	// The Device_cal function, which copies the ADC & oscillator calibration values
	// from TI reserved OTP into the appropriate trim registers, occurs automatically
	// in the Boot ROM. If the boot ROM code is bypassed during the debug process, the
	// following function MUST be called for the ADC and oscillators to function according
	// to specification.

	SysCtrlRegs.PCLKCR0.bit.ADCENCLK = 1; // Enable ADC peripheral clock
	(*Device_cal)();					  // Auto-calibrate from TI OTP
	SysCtrlRegs.PCLKCR0.bit.ADCENCLK = 0; // Return ADC clock to original state


	// PERIPHERAL CLOCK ENABLES
	//---------------------------------------------------
	// If you are not using a peripheral you may want to switch
	// the clock off to save power, i.e. set to =0
	//
	// Note: not all peripherals are available on all 280x derivates.
	// Refer to the datasheet for your particular device.

#if 0
	SysCtrlRegs.PCLKCR1.bit.EPWM1ENCLK = 1;    // ePWM1
	SysCtrlRegs.PCLKCR1.bit.EPWM2ENCLK = 1;    // ePWM2
	SysCtrlRegs.PCLKCR1.bit.EPWM3ENCLK = 1;    // ePWM3
	SysCtrlRegs.PCLKCR1.bit.EPWM4ENCLK = 1;    // ePWM4
	SysCtrlRegs.PCLKCR1.bit.EPWM5ENCLK = 1;    // ePWM5
	SysCtrlRegs.PCLKCR1.bit.EPWM6ENCLK = 1;    // ePWM6
	SysCtrlRegs.PCLKCR1.bit.EPWM7ENCLK = 1;    // ePWM7
	SysCtrlRegs.PCLKCR1.bit.EPWM8ENCLK = 1;    // ePWM8

	SysCtrlRegs.PCLKCR0.bit.HRPWMENCLK = 1;    // HRPWM
	SysCtrlRegs.PCLKCR0.bit.TBCLKSYNC = 1;     // Enable TBCLK within the ePWM

	SysCtrlRegs.PCLKCR1.bit.EQEP1ENCLK = 1;    // eQEP1
	SysCtrlRegs.PCLKCR1.bit.EQEP2ENCLK = 1;    // eQEP2

	SysCtrlRegs.PCLKCR1.bit.ECAP1ENCLK = 1;    // eCAP1
	SysCtrlRegs.PCLKCR1.bit.ECAP2ENCLK = 1;    // eCAP2
	SysCtrlRegs.PCLKCR1.bit.ECAP3ENCLK = 1;    // eCAP3

	SysCtrlRegs.PCLKCR2.bit.HRCAP1ENCLK = 1;	  // HRCAP1
	SysCtrlRegs.PCLKCR2.bit.HRCAP2ENCLK = 1;	  // HRCAP2
	SysCtrlRegs.PCLKCR2.bit.HRCAP3ENCLK = 1;	  // HRCAP3
	SysCtrlRegs.PCLKCR2.bit.HRCAP4ENCLK = 1;   // HRCAP4

	SysCtrlRegs.PCLKCR0.bit.ADCENCLK = 1;      // ADC
	SysCtrlRegs.PCLKCR3.bit.COMP1ENCLK = 1;    // COMP1
	SysCtrlRegs.PCLKCR3.bit.COMP2ENCLK = 1;    // COMP2
	SysCtrlRegs.PCLKCR3.bit.COMP3ENCLK = 1;    // COMP3

	SysCtrlRegs.PCLKCR3.bit.CPUTIMER0ENCLK = 1; // CPU Timer 0
	SysCtrlRegs.PCLKCR3.bit.CPUTIMER1ENCLK = 1; // CPU Timer 1
	SysCtrlRegs.PCLKCR3.bit.CPUTIMER2ENCLK = 1; // CPU Timer 2

	SysCtrlRegs.PCLKCR3.bit.DMAENCLK = 1;      // DMA

	SysCtrlRegs.PCLKCR3.bit.CLA1ENCLK = 1;     // CLA1

	SysCtrlRegs.PCLKCR3.bit.USB0ENCLK = 1;	  // USB0

	SysCtrlRegs.PCLKCR0.bit.I2CAENCLK = 1;     // I2C-A
	SysCtrlRegs.PCLKCR0.bit.SPIAENCLK = 1;     // SPI-A
	SysCtrlRegs.PCLKCR0.bit.SPIBENCLK = 1;     // SPI-B
	SysCtrlRegs.PCLKCR0.bit.SCIAENCLK = 1;     // SCI-A
	SysCtrlRegs.PCLKCR0.bit.SCIBENCLK = 1;     // SCI-B
	SysCtrlRegs.PCLKCR0.bit.MCBSPAENCLK = 1;   // McBSP-A
	SysCtrlRegs.PCLKCR0.bit.ECANAENCLK=1;      // eCAN-A

	SysCtrlRegs.PCLKCR0.bit.TBCLKSYNC = 1;     // Enable TBCLK within the ePWM
#endif
	EDIS;	// Disable register access
}



//============================================================================
// NOTE:
// IN MOST APPLICATIONS THE FUNCTIONS AFTER THIS POINT CAN BE LEFT UNCHANGED
// THE USER NEED NOT REALLY UNDERSTAND THE BELOW CODE TO SUCCESSFULLY RUN THIS
// APPLICATION.
//============================================================================

void WDogDisable(void)
{
	EALLOW;
	SysCtrlRegs.WDCR= 0x0068;
	EDIS;
}

//---------------------------------------------------------------------------
// Example: IntOsc1Sel:
//---------------------------------------------------------------------------
// This function switches to Internal Oscillator 1 and turns off all other clock
// sources to minimize power consumption

void IntOsc1Sel (void) {
    EALLOW;
    SysCtrlRegs.CLKCTL.bit.INTOSC1OFF = 0;
    SysCtrlRegs.CLKCTL.bit.OSCCLKSRCSEL=0;  // Clk Src = INTOSC1
    SysCtrlRegs.CLKCTL.bit.XCLKINOFF=1;     // Turn off XCLKIN
    SysCtrlRegs.CLKCTL.bit.XTALOSCOFF=1;    // Turn off XTALOSC
    SysCtrlRegs.CLKCTL.bit.INTOSC2OFF=1;    // Turn off INTOSC2
    EDIS;
}

//---------------------------------------------------------------------------
// Example: IntOsc2Sel:
//---------------------------------------------------------------------------
// This function switches to Internal oscillator 2 from External Oscillator
// and turns off all other clock sources to minimize power consumption
// NOTE: If there is no external clock connection, when switching from
//       INTOSC1 to INTOSC2, EXTOSC and XLCKIN must be turned OFF prior
//       to switching to internal oscillator 1

void IntOsc2Sel (void) {
    EALLOW;
    SysCtrlRegs.CLKCTL.bit.INTOSC2OFF = 0;     // Turn on INTOSC2
    SysCtrlRegs.CLKCTL.bit.OSCCLKSRC2SEL = 1;  // Switch to INTOSC2
    SysCtrlRegs.CLKCTL.bit.XCLKINOFF = 1;      // Turn off XCLKIN
    SysCtrlRegs.CLKCTL.bit.XTALOSCOFF = 1;     // Turn off XTALOSC
    SysCtrlRegs.CLKCTL.bit.OSCCLKSRCSEL = 1;   // Switch to Internal Oscillator 2
    SysCtrlRegs.CLKCTL.bit.WDCLKSRCSEL = 0;    // Clock Watchdog off of INTOSC1 always
    SysCtrlRegs.CLKCTL.bit.INTOSC1OFF = 0;     // Leave INTOSC1 on
    EDIS;
}

//---------------------------------------------------------------------------
// Example: XtalOscSel:
//---------------------------------------------------------------------------
// This function switches to External CRYSTAL oscillator and turns off all other clock
// sources to minimize power consumption. This option may not be available on all
// device packages
#if 0
void XtalOscSel (void)  {
     EALLOW;
     SysCtrlRegs.CLKCTL.bit.XTALOSCOFF = 0;     // Turn on XTALOSC
     DELAY_US(1000);                            // Wait for 1ms while XTAL starts up
     SysCtrlRegs.CLKCTL.bit.XCLKINOFF = 1;      // Turn off XCLKIN
     SysCtrlRegs.CLKCTL.bit.OSCCLKSRC2SEL = 0;  // Switch to external clock
     SysCtrlRegs.CLKCTL.bit.OSCCLKSRCSEL = 1;   // Switch from INTOSC1 to INTOSC2/ext clk
     SysCtrlRegs.CLKCTL.bit.WDCLKSRCSEL = 0;    // Clock Watchdog off of INTOSC1 always
     SysCtrlRegs.CLKCTL.bit.INTOSC2OFF = 1;     // Turn off INTOSC2
     SysCtrlRegs.CLKCTL.bit.INTOSC1OFF = 0;     // Leave INTOSC1 on
     EDIS;
}
#endif

//---------------------------------------------------------------------------
// Example: ExtOscSel:
//---------------------------------------------------------------------------
// This function switches to External oscillator and turns off all other clock
// sources to minimize power consumption.

void ExtOscSel (void)  {
     EALLOW;
     SysCtrlRegs.XCLK.bit.XCLKINSEL = 1;       // 1-GPIO19 = XCLKIN, 0-GPIO38 = XCLKIN
     SysCtrlRegs.CLKCTL.bit.XTALOSCOFF = 1;    // Turn on XTALOSC
     SysCtrlRegs.CLKCTL.bit.XCLKINOFF = 0;     // Turn on XCLKIN
     SysCtrlRegs.CLKCTL.bit.OSCCLKSRC2SEL = 0; // Switch to external clock
     SysCtrlRegs.CLKCTL.bit.OSCCLKSRCSEL = 1;  // Switch from INTOSC1 to INTOSC2/ext clk
     SysCtrlRegs.CLKCTL.bit.WDCLKSRCSEL = 0;   // Clock Watchdog off of INTOSC1 always
     SysCtrlRegs.CLKCTL.bit.INTOSC2OFF = 1;    // Turn off INTOSC2
     SysCtrlRegs.CLKCTL.bit.INTOSC1OFF = 0;     // Leave INTOSC1 on
     EDIS;
}

// This function initializes the PLLCR register.
//void InitPll(Uint16 val, Uint16 clkindiv)
void PLLset(Uint16 clock_source, Uint16 val)
{
	volatile Uint16 iVol;

	PLX_ASSERT(clock_source == 0); // only OSC1 supported

	IntOsc1Sel();

	// Make sure the PLL is not running in limp mode
	if (SysCtrlRegs.PLLSTS.bit.MCLKSTS != 0)
	{
		EALLOW;
		// OSCCLKSRC1 failure detected. PLL running in limp mode.
		// Re-enable missing clock logic.
		SysCtrlRegs.PLLSTS.bit.MCLKCLR = 1;
		EDIS;
		PLX_ASSERT(0);
	}

	// DIVSEL MUST be 0 before PLLCR can be changed from
	// 0x0000. It is set to 0 by an external reset XRSn
	// This puts us in 1/4
	if (SysCtrlRegs.PLLSTS.bit.DIVSEL != 0)
	{
		EALLOW;
		SysCtrlRegs.PLLSTS.bit.DIVSEL = 0;
		EDIS;
	}

	// Change the PLLCR
	if (SysCtrlRegs.PLLCR.bit.DIV != val)
	{

		EALLOW;
		// Before setting PLLCR turn off missing clock detect logic
		SysCtrlRegs.PLLSTS.bit.MCLKOFF = 1;
		SysCtrlRegs.PLLCR.bit.DIV = val;
		EDIS;

		// Optional: Wait for PLL to lock.
		// During this time the CPU will switch to OSCCLK/2 until
		// the PLL is stable.  Once the PLL is stable the CPU will
		// switch to the new PLL value.
		//
		// This time-to-lock is monitored by a PLL lock counter.
		//
		// Code is not required to sit and wait for the PLL to lock.
		// However, if the code does anything that is timing critical,
		// and requires the correct clock be locked, then it is best to
		// wait until this switching has completed.

		// Wait for the PLL lock bit to be set.
		// The watchdog should be disabled before this loop, or fed within
		// the loop via ServiceDog().

		// Uncomment to disable the watchdog
		WDogDisable();

		while(SysCtrlRegs.PLLSTS.bit.PLLLOCKS != 1) {}

		EALLOW;
		SysCtrlRegs.PLLSTS.bit.MCLKOFF = 0;
		EDIS;
	}

	//divide down SysClk by 2 to increase stability
	EALLOW;
	SysCtrlRegs.PLLSTS.bit.DIVSEL = 2;
	EDIS;
}


// This function initializes the PIE control registers to a known state.
//
void PieCntlInit(void)
{
	// Disable Interrupts at the CPU level:
	DINT;

	// Disable the PIE
	PieCtrlRegs.PIECTRL.bit.ENPIE = 0;

	// Clear all PIEIER registers:
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

	// Clear all PIEIFR registers:
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

void PieVectTableInit(void)
{
	Int16	i;
	Uint32 *Source = (void *) &ISR_ILLEGAL;
	Uint32 *Dest = (void *) &PieVectTable;

	EALLOW;
	for(i=0; i < 128; i++)
		*Dest++ = *Source;
	EDIS;

	// Enable the PIE Vector Table
	PieCtrlRegs.PIECTRL.bit.ENPIE = 1;
}

interrupt void ISR_ILLEGAL(void)   // Illegal operation TRAP
{
	// Insert ISR Code here

	// Next two lines for debug only to halt the processor here
	// Remove after inserting ISR Code
	asm("          ESTOP0");
	for(;;);

}

// This function initializes the Flash Control registers

//                   CAUTION
// This function MUST be executed out of RAM. Executing it
// out of OTP/Flash will yield unpredictable results

void InitFlash(void)
{
	EALLOW;
	//Enable Flash Pipeline mode to improve performance
	//of code executed from Flash.
	FlashRegs.FOPT.bit.ENPIPE = 1;

	//                CAUTION
	//Minimum waitstates required for the flash operating
	//at a given CPU rate must be characterized by TI.
	//Refer to the datasheet for the latest information.

	//Set the Paged Waitstate for the Flash
	FlashRegs.FBANKWAIT.bit.PAGEWAIT = 2;

	//Set the Random Waitstate for the Flash
	FlashRegs.FBANKWAIT.bit.RANDWAIT = 2;

	//Set the Waitstate for the OTP
	FlashRegs.FOTPWAIT.bit.OTPWAIT = 2;

	//                CAUTION
	//ONLY THE DEFAULT VALUE FOR THESE 2 REGISTERS SHOULD BE USED
	FlashRegs.FSTDBYWAIT.bit.STDBYWAIT = 0x01FF;
	FlashRegs.FACTIVEWAIT.bit.ACTIVEWAIT = 0x01FF;
	EDIS;

	//Force a pipeline flush to ensure that the write to
	//the last register configured occurs before returning.

	asm(" RPT #7 || NOP");
}


// This function will copy the specified memory contents from
// one location to another.
//
//	Uint16 *SourceAddr        Pointer to the first word to be moved
//                          SourceAddr < SourceEndAddr
//	Uint16* SourceEndAddr     Pointer to the last word to be moved
//	Uint16* DestAddr          Pointer to the first destination word
//
// No checks are made for invalid memory locations or that the
// end address is > then the first start address.

void MemCopy(Uint16 *SourceAddr, Uint16* SourceEndAddr, Uint16* DestAddr)
{
	while(SourceAddr < SourceEndAddr)
	{
		*DestAddr++ = *SourceAddr++;
	}
	return;
}

//===========================================================================
// End of file.
//===========================================================================
