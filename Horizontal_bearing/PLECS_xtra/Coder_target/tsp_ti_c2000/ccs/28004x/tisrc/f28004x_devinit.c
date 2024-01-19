#include "f28004x_device.h"     // Headerfile Include File
#include "f28004x_examples.h"   // Examples Include File

// Functions that will be run from RAM need to be assigned to
// a different section.  This section will then be mapped to a load and
// run address using the linker cmd file.
#pragma CODE_SECTION(InitFlashHz, ".TI.ramfunc");
#pragma CODE_SECTION(FlashOff, ".TI.ramfunc");

//
// The following values are used to validate PLL Frequency using DCC
//
#define   PLL_RETRIES              100
#define   PLL_LOCK_TIMEOUT        2000
#define   DCC_COUNTER0_WINDOW      100

// Function prototypes
void ISR_ILLEGAL(void);

void DisableDog(void);

static void PieCntlInit(void);
static void PieVectTableInit(void);

#pragma diag_suppress 112 // PLX_ASSERT(0) in switch statements
#define PLX_ASSERT(x) do {\
   if(!(x)){\
      asm("        ESTOP0");\
      for(;;);\
   }\
} while(0)

void DevInit(Uint16 clock_source, Uint16 imult, Uint16 fmult)
{
	DisableDog();
	DINT;			// Global Disable all Interrupts
	IER = 0x0000;	// Disable CPU interrupts
	IFR = 0x0000;	// Clear all CPU interrupt flags

	// Initialise interrupt controller and Vector Table
	// to defaults for now. Application ISR mapping done later.
	PieCntlInit();
	PieVectTableInit();

	PLX_ASSERT((clock_source == 1) || (clock_source == 0)); // only XTAL and OSC2 supported
	InitSysPll(clock_source, imult, fmult, PLLCLK_BY_2);
}

#if 0
//
// ServiceDog - This function resets the watchdog timer.
// Enable this function for using ServiceDog in the application
//
void ServiceDog(void)
{
    EALLOW;
    WdRegs.WDKEY.bit.WDKEY = 0x0055;
    WdRegs.WDKEY.bit.WDKEY = 0x00AA;
    EDIS;
}
#endif

void DisableDog(void)
{
	volatile Uint16 temp;

	//
	// Grab the clock config first so we don't clobber it
	//
	EALLOW;
	temp = WdRegs.WDCR.all & 0x0007;
	WdRegs.WDCR.all = 0x0068 | temp;
	EDIS;
}

//
// InitPll - This function initializes the PLL registers.
//
// Note: This function uses the DCC to check that the PLLRAWCLK is running at
// the expected rate. If you are using the DCC, you must back up its
// configuration before calling this function and restore it afterward.
//
void InitSysPll(Uint16 clock_source, Uint16 imult, Uint16 fmult, Uint16 divsel)
{
    Uint32 timeout, retries, temp_syspllmult, pllLockStatus;
    bool status;

    if(((clock_source & 0x3) == ClkCfgRegs.CLKSRCCTL1.bit.OSCCLKSRCSEL)    &&
       (((clock_source & 0x4) >> 2) == ClkCfgRegs.XTALCR.bit.SE)           &&
                     (imult  == ClkCfgRegs.SYSPLLMULT.bit.IMULT)           &&
                     (fmult  == ClkCfgRegs.SYSPLLMULT.bit.FMULT)           &&
                     (divsel == ClkCfgRegs.SYSCLKDIVSEL.bit.PLLSYSCLKDIV))
    {
        //
        // Everything is set as required, so just return
        //
        return;
    }

    if(((clock_source & 0x3) != ClkCfgRegs.CLKSRCCTL1.bit.OSCCLKSRCSEL) ||
       (((clock_source & 0x4) >> 2) != ClkCfgRegs.XTALCR.bit.SE))
    {
        switch (clock_source)
        {
            case INT_OSC1:
                SysIntOsc1Sel();
                break;

            case INT_OSC2:
                SysIntOsc2Sel();
                break;

            case XTAL_OSC:
                SysXtalOscSel();
                break;

//            case XTAL_OSC_SE:
//                SysXtalOscSESel();
//                break;
        }
    }

    EALLOW;

    //
    // First modify the PLL multipliers
    //
    if(imult != ClkCfgRegs.SYSPLLMULT.bit.IMULT ||
       fmult != ClkCfgRegs.SYSPLLMULT.bit.FMULT)
    {
        //
        // Bypass PLL and set dividers to /1
        //
        ClkCfgRegs.SYSPLLCTL1.bit.PLLCLKEN = 0;
        ClkCfgRegs.SYSCLKDIVSEL.bit.PLLSYSCLKDIV = 0;

        //
        // Evaluate PLL multipliers
        //
        temp_syspllmult = ((fmult << 8U) | imult);

        //
        // Loop to retry locking the PLL should the DCC module indicate
        // that it was not successful.
        //
        for(retries = 0; (retries < PLL_RETRIES); retries++)
        {
            //
            // Bypass PLL
            //
            ClkCfgRegs.SYSPLLCTL1.bit.PLLCLKEN = 0;

            //
            // Program PLL multipliers
            //
            ClkCfgRegs.SYSPLLMULT.all = temp_syspllmult;

            //
            // Enable SYSPLL
            //
            ClkCfgRegs.SYSPLLCTL1.bit.PLLEN = 1;

            timeout = PLL_LOCK_TIMEOUT;
            pllLockStatus = ClkCfgRegs.SYSPLLSTS.bit.LOCKS;

            //
            // Wait for the SYSPLL lock
            //
            while((pllLockStatus != 1) && (timeout != 0U))
            {
                pllLockStatus = ClkCfgRegs.SYSPLLSTS.bit.LOCKS;
                timeout--;
            }

            EDIS;

            status = IsPLLValid(clock_source, imult, fmult);

            //
            // Check DCC Status, if no error break the loop
            //
            if(status)
            {
                break;
            }
        }
    }
    else
    {
        status = true;
    }

    if(status)
    {
        EALLOW;
        //
        // Set divider to produce slower output frequency to limit current increase
        //
        if(divsel != PLLCLK_BY_126)
        {
            ClkCfgRegs.SYSCLKDIVSEL.bit.PLLSYSCLKDIV = divsel + 1;
        }
        else
        {
            ClkCfgRegs.SYSCLKDIVSEL.bit.PLLSYSCLKDIV = divsel;
        }

        //
        // Enable PLLSYSCLK is fed from system PLL clock
        //
        ClkCfgRegs.SYSPLLCTL1.bit.PLLCLKEN = 1;

        //
        // Small 100 cycle delay
        //
        asm(" RPT #100 || NOP");

        //
        // Set the divider to user value
        //
        ClkCfgRegs.SYSCLKDIVSEL.bit.PLLSYSCLKDIV = divsel;
        EDIS;
    }
}

#if 1
//
// SysIntOsc1Sel - This function switches to Internal Oscillator 1 and turns
// off all other clock sources to minimize power consumption
//
void
SysIntOsc1Sel (void)
{
    EALLOW;
    ClkCfgRegs.CLKSRCCTL1.bit.OSCCLKSRCSEL = 2; // Clk Src = INTOSC1
    ClkCfgRegs.XTALCR.bit.OSCOFF=1;             // Turn off XTALOSC
    EDIS;
}

//
// SysIntOsc2Sel - This function switches to Internal oscillator 2 from
// External Oscillator and turns off all other clock sources to minimize
// power consumption
// NOTE: If there is no external clock connection, when switching from
//       INTOSC1 to INTOSC2, EXTOSC and XLCKIN must be turned OFF prior
//       to switching to internal oscillator 1
//
void
SysIntOsc2Sel (void)
{
    EALLOW;
    ClkCfgRegs.CLKSRCCTL1.bit.INTOSC2OFF=0;         // Turn on INTOSC2
    ClkCfgRegs.CLKSRCCTL1.bit.OSCCLKSRCSEL = 0;     // Clk Src = INTOSC2
    ClkCfgRegs.XTALCR.bit.OSCOFF=1;                 // Turn off XTALOSC
    EDIS;
}
#endif

//
// PollX1Counter - Clear the X1CNT counter and then wait for it to saturate
// four times.
//
static void
PollX1Counter(void)
{
    Uint16 loopCount = 0;

    //
    // Delay for 1 ms while the XTAL powers up
    //
    // 2000 loops, 5 cycles per loop + 9 cycles overhead = 10009 cycles
    //
    F28x_usDelay(2000);

    //
    // Clear and saturate X1CNT 4 times to guarantee operation
    //
    do
    {
        //
        // Keep clearing the counter until it is no longer saturated
        //
        while(ClkCfgRegs.X1CNT.all > 0x1FF)
        {
            ClkCfgRegs.X1CNT.bit.CLR = 1;
        }

        //
        // Wait for the X1 clock to saturate
        //
        while(ClkCfgRegs.X1CNT.all != 0x3FFU)
        {
            ;
        }

        //
        // Increment the counter
        //
        loopCount++;
    }while(loopCount < 4);
}

//
// SysXtalOscSel - This function switches to External CRYSTAL oscillator and
// turns off all other clock sources to minimize power consumption. This option
// may not be available on all device packages
//
void
SysXtalOscSel (void)
{
    EALLOW;
    ClkCfgRegs.XTALCR.bit.OSCOFF = 0;     // Turn on XTALOSC
    ClkCfgRegs.XTALCR.bit.SE = 0;         // Select crystal mode
    EDIS;

    //
    // Wait for the X1 clock to saturate
    //
    PollX1Counter();

    //
    // Select XTAL as the oscillator source
    //
    EALLOW;
    ClkCfgRegs.CLKSRCCTL1.bit.OSCCLKSRCSEL = 1;
    EDIS;

    //
    // If a missing clock failure was detected, try waiting for the X1 counter
    // to saturate again. Consider modifying this code to add a 10ms timeout.
    //
    while(ClkCfgRegs.MCDCR.bit.MCLKSTS != 0)
    {
        EALLOW;
        ClkCfgRegs.MCDCR.bit.MCLKCLR = 1;
        EDIS;

        //
        // Wait for the X1 clock to saturate
        //
        PollX1Counter();

        //
        // Select XTAL as the oscillator source
        //
        EALLOW;
        ClkCfgRegs.CLKSRCCTL1.bit.OSCCLKSRCSEL = 1;
        EDIS;
    }
}

//*****************************************************************************
//
// SysCtl_isPLLValid()
//
//*****************************************************************************
bool IsPLLValid(Uint16 oscSource, Uint16 imult, Uint16 fmult)
{
    Uint32 dccCounterSeed0, dccCounterSeed1, dccValidSeed0;

    //
    // Setting Counter0 & Valid Seed Value with +/-2% tolerance
    //
    dccCounterSeed0 = DCC_COUNTER0_WINDOW - 2U;
    dccValidSeed0 = 4U;

    //
    // Multiplying Counter-0 window with PLL Integer Multiplier
    //
    dccCounterSeed1 = DCC_COUNTER0_WINDOW * imult;

    //
    // Multiplying Counter-0 window with PLL Fractional Multiplier
    //
    switch(fmult)
    {
        case FMULT_0pt25:
            //
            // FMULT * CNTR0 Window = 0.25 * 100 = 25, gets added to cntr0
            // seed value
            //
            dccCounterSeed1 = dccCounterSeed1 + 25U;
            break;
        case FMULT_0pt5:
            //
            // FMULT * CNTR0 Window = 0.5 * 100 = 50, gets added to cntr0
            // seed value
            //
            dccCounterSeed1 = dccCounterSeed1 + 50U;
            break;
        case FMULT_0pt75:
            //
            // FMULT * CNTR0 Window = 0.75 * 100 = 75, gets added to cntr0
            // seed value
            //
            dccCounterSeed1 = dccCounterSeed1 + 75U;
            break;
        default:
            //
            // No fractional multiplier
            //
            dccCounterSeed1 = dccCounterSeed1;
            break;
    }

    //
    // Enable Peripheral Clock Domain PCLKCR21 for DCC
    //
    EALLOW;
    CpuSysRegs.PCLKCR21.bit.DCC_0 = 1;

    //
    // Clear Error & Done Flag
    //
    Dcc0Regs.DCCSTATUS.bit.ERR = 1;
    Dcc0Regs.DCCSTATUS.bit.DONE = 1;

    //
    // Disable DCC
    //
    Dcc0Regs.DCCGCTRL.bit.DCCENA = 0x5;

    //
    // Disable Error Signal
    //
    Dcc0Regs.DCCGCTRL.bit.ERRENA = 0x5;

    //
    // Disable Done Signal
    //
    Dcc0Regs.DCCGCTRL.bit.DONEENA = 0x5;

    //
    // Configure Clock Source0 to whatever is set as a clock source for PLL
    //
    switch(oscSource)
    {
        case INT_OSC1:
            Dcc0Regs.DCCCLKSRC0.bit.CLKSRC0 = 1; // Clk Src0 = INTOSC1
            break;

        case INT_OSC2:
            Dcc0Regs.DCCCLKSRC0.bit.CLKSRC0 = 2; // Clk Src0 = INTOSC2
            break;

        case XTAL_OSC:
        case XTAL_OSC_SE:
            Dcc0Regs.DCCCLKSRC0.bit.CLKSRC0 = 0; // Clk Src0 = XTAL
            break;
    }

    //
    // Configure Clock Source1 to PLL
    //
    Dcc0Regs.DCCCLKSRC1.bit.KEY = 0xA; // Clk Src1 Key to enable clock source selection for count1
    Dcc0Regs.DCCCLKSRC1.bit.CLKSRC1 = 0; // Clk Src1 = PLL

    //
    // Configure COUNTER-0, COUNTER-1 & Valid Window
    //
    Dcc0Regs.DCCCNTSEED0.bit.COUNTSEED0 = dccCounterSeed0; // Loaded Counter0 Value
    Dcc0Regs.DCCVALIDSEED0.bit.VALIDSEED = dccValidSeed0;  // Loaded Valid Value
    Dcc0Regs.DCCCNTSEED1.bit.COUNTSEED1 = dccCounterSeed1; // Loaded Counter1 Value

    //
    // Enable Single Shot Mode
    //
    Dcc0Regs.DCCGCTRL.bit.SINGLESHOT = 0xA;

    //
    // Enable Error Signal
    //
    Dcc0Regs.DCCGCTRL.bit.ERRENA = 0xA;

    //
    // Enable Done Signal
    //
    Dcc0Regs.DCCGCTRL.bit.DONEENA = 0xA;

    //
    // Enable DCC to start counting
    //
    Dcc0Regs.DCCGCTRL.bit.DCCENA = 0xA;
    EDIS;

    //
    // Wait until Error or Done Flag is generated
    //
    while((Dcc0Regs.DCCSTATUS.all & 3) == 0)
    {
    }

    //
    // Returns true if DCC completes without error
    //
    return((Dcc0Regs.DCCSTATUS.all & 3) == 2);

}

// This function initializes the PIE control registers to a known state.
//
static void PieCntlInit(void)
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
	Uint16  i;
	Uint32  *Source  =  (void  *)  &ISR_ILLEGAL;
	Uint32  *Dest  =  (void  *)  &PieVectTable;

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

// This function initializes the Flash Control registers

//                   CAUTION
// This function MUST be executed out of RAM. Executing it
// out of OTP/Flash will yield unpredictable results
void InitFlashHz(Uint32 clkHz)
{
    EALLOW;

    //
    // At reset bank and pump are in sleep
    // A Flash access will power up the bank and pump automatically
    // After a Flash access, bank and pump go to low power mode (configurable
    // in FBFALLBACK/FPAC1 registers)- if there is no further access to flash
    // Power up Flash bank and pump and this also sets the fall back mode of
    // flash and pump as active
    //
    Flash0CtrlRegs.FPAC1.bit.PMPPWR = 0x1;
    Flash0CtrlRegs.FBFALLBACK.bit.BNKPWR0 = 0x3;
    Flash0CtrlRegs.FBFALLBACK.bit.BNKPWR1 = 0x3;

    //
    // Disable Cache and prefetch mechanism before changing wait states
    //
    Flash0CtrlRegs.FRD_INTF_CTRL.bit.DATA_CACHE_EN = 0;
    Flash0CtrlRegs.FRD_INTF_CTRL.bit.PREFETCH_EN = 0;

    //
    // Set waitstates according to frequency
    //                CAUTION
    // Minimum waitstates required for the flash operating
    // at a given CPU rate must be characterized by TI.
    // Refer to the datasheet for the latest information.
    //

    // WORK HERE!

    uint16_t clkMHz = (uint16_t)(clkHz / 1000000L);
    if((ClkCfgRegs.CLKSRCCTL1.bit.OSCCLKSRCSEL == 0x0)   ||
       (ClkCfgRegs.CLKSRCCTL1.bit.OSCCLKSRCSEL == 0x2)   ||
       (ClkCfgRegs.CLKSRCCTL1.bit.OSCCLKSRCSEL == 0x3))
    {
    	// internal oscillator
        if(clkMHz > 97){
        	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x5;
        } else if(clkMHz > 77){
        	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x4;
        } else if(clkMHz > 58){
        	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x3;
        } else if(clkMHz > 38){
         	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x2;
        } else if(clkMHz > 19){
         	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x1;
        } else {
        	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x0;
        }
    }
    else
    {
    	// external oscillator
        if(clkMHz > 80){
        	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x4;
        } else if(clkMHz > 60){
        	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x3;
        } else if(clkMHz > 40){
         	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x2;
        } else if(clkMHz > 20){
         	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x1;
        } else {
        	Flash0CtrlRegs.FRDCNTL.bit.RWAIT = 0x0;
        }
    }

    //
    // Enable Cache and prefetch mechanism to improve performance
    // of code executed from Flash.
    //
    Flash0CtrlRegs.FRD_INTF_CTRL.bit.DATA_CACHE_EN = 1;
    Flash0CtrlRegs.FRD_INTF_CTRL.bit.PREFETCH_EN = 1;

    //
    // At reset, ECC is enabled. If it is disabled by application software
    // and if application again wants to enable ECC
    //
    Flash0EccRegs.ECC_ENABLE.bit.ENABLE = 0xA;

    EDIS;

    //
    // Force a pipeline flush to ensure that the write to
    // the last register configured occurs before returning.
    //
    __asm(" RPT #7 || NOP");
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

// ============

//===========================================================================
// End of file.
//===========================================================================
