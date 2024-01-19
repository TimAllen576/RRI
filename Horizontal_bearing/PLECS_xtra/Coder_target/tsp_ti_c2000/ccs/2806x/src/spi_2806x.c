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

#include "plx_spi.h"

#pragma diag_suppress 112 // PLX_ASSERT(0) in switch statements

PLX_SPI_Handle_t PLX_SPI_init(void *aMemory, const size_t aNumBytes)
{
	if(aNumBytes < sizeof(PLX_SPI_Obj_t))
	{
		return((PLX_SPI_Handle_t)NULL);
	}
	PLX_SPI_Handle_t handle = (PLX_SPI_Handle_t)aMemory;
	return handle;
}

void PLX_SPI_configure(PLX_SPI_Handle_t aHandle, PLX_SPI_Unit_t aUnit, uint32_t clk)
{
	PLX_SPI_Obj_t *obj = (PLX_SPI_Obj_t *)aHandle;
	obj->unit = aUnit;
	obj->clk = clk;
}

void PLX_SPI_setupPortViaPinSet(PLX_SPI_Handle_t aHandle, uint16_t aPinSet, PLX_SPI_Params_t *aParams)
{
	PLX_SPI_Obj_t *obj = (PLX_SPI_Obj_t *)aHandle;

	EALLOW;

	switch(obj->unit)
	{
		default:
			PLX_ASSERT(0);
			break;
		case PLX_SPI_SPI_A:
			obj->portHandle = (uint32_t)&SpiaRegs;
			// enable clock to SPIA
			SysCtrlRegs.PCLKCR0.bit.SPIAENCLK = 1;
			switch(aPinSet)
			{
				default:
					PLX_ASSERT(0);
					break;
				case 10:
					// configure pins
					GpioCtrlRegs.GPAMUX2.bit.GPIO16 = 1;	// 0=GPIO,  1=SPISIMO-A,  2=Resv,  3=TZ2
					GpioCtrlRegs.GPAMUX2.bit.GPIO17 = 1;	// 0=GPIO,  1=SPISOMI-A,  2=Resv,  3=TZ3
					GpioCtrlRegs.GPAMUX2.bit.GPIO18 = 1;	// 0=GPIO,  1=SPICLK-A,  2=SCITXD-A,  3=XCLKOUT
					// enable pull-ups
					GpioCtrlRegs.GPAPUD.bit.GPIO16 = 0;   // Enable pull-up on GPIO16 (SPISIMO-A)
					GpioCtrlRegs.GPAPUD.bit.GPIO17 = 0;   // Enable pull-up on GPIO17 (SPISOMI-A)
					GpioCtrlRegs.GPAPUD.bit.GPIO18 = 0;   // Enable pull-up on GPIO18 (SPICLK-A)
					// async inputs
					GpioCtrlRegs.GPAQSEL2.bit.GPIO16 = 3; // Asynch input GPIO16 (SPISIMO-A)
					GpioCtrlRegs.GPAQSEL2.bit.GPIO17 = 3; // Asynch input GPIO17 (SPISOMI-A)
					GpioCtrlRegs.GPAQSEL2.bit.GPIO18 = 3; // Asynch input GPIO18 (SPICLK-A)

					// for slave also configure SPISTE
					if(aParams->MASTERSLAVE == 0)
					{
	                    GpioCtrlRegs.GPAMUX2.bit.GPIO19 = 1; // 0=GPIO,  1=SPISTE-A,  2=SCIRXD-B,  3=ECAP1
	                    GpioCtrlRegs.GPAPUD.bit.GPIO19 = 0;   // Enable pull-up on GPIO19 (SPISTE-A)
	                    GpioCtrlRegs.GPAQSEL2.bit.GPIO19 = 3; // Asynch input GPIO19 (SPISTE-A)
					}
					break;
			}
			break;

		case PLX_SPI_SPI_B:
			obj->portHandle = (uint32_t)&SpibRegs;
			// enable clock to SPIB
			SysCtrlRegs.PCLKCR0.bit.SPIBENCLK = 1;
			switch(aPinSet)
			{
				default:
					PLX_ASSERT(0);
					break;
				case 20:
					// configure pins
					GpioCtrlRegs.GPAMUX2.bit.GPIO24 = 3;	// 0=GPIO,  1=ECAP1,  2=EQEP2-A,  3=SPISIMO-B
					GpioCtrlRegs.GPAMUX2.bit.GPIO25 = 3;	// 0=GPIO,  1=ECAP2,  2=EQEP2-B,  3=SPISOMI-B
					GpioCtrlRegs.GPAMUX2.bit.GPIO26 = 3; // 0=GPIO,  1=ECAP3,  2=EQEP2-I,  3=SPICLK-B
					// enable pull-ups
					GpioCtrlRegs.GPAPUD.bit.GPIO24 = 0;
					GpioCtrlRegs.GPAPUD.bit.GPIO25 = 0;
					GpioCtrlRegs.GPAPUD.bit.GPIO26 = 0;
					// async inputs
					GpioCtrlRegs.GPAQSEL2.bit.GPIO24 = 3;
					GpioCtrlRegs.GPAQSEL2.bit.GPIO25 = 3;
					GpioCtrlRegs.GPAQSEL2.bit.GPIO26 = 3;

	                // for slave also configure SPISTE
	                if(aParams->MASTERSLAVE == 0)
	                {
	                    GpioCtrlRegs.GPAMUX2.bit.GPIO27 = 3; // 0=GPIO,  1=HRCAP2,  2=EQEP2-S,  3=SPISTE-B
	                    GpioCtrlRegs.GPAPUD.bit.GPIO27 = 0;
	                    GpioCtrlRegs.GPAQSEL2.bit.GPIO27 = 3;
	                }
					break;

	             case 21:
	                // configure pins
		            GpioCtrlRegs.GPAMUX1.bit.GPIO14 = 3;    // 0=GPIO,  1=TZ3,  2=LINTX-A,  3=SPICLK-B
		            GpioCtrlRegs.GPAMUX2.bit.GPIO24 = 3;    // 0=GPIO,  1=ECAP1,  2=Resv,  3=SPISIMO-B
		            GpioCtrlRegs.GPAMUX2.bit.GPIO25 = 3;    // 0=GPIO,  1=Resv,  2=Resv,  3=SPISOMI-B
		            // enable pull-ups
		            GpioCtrlRegs.GPAPUD.bit.GPIO14 = 0;
		            GpioCtrlRegs.GPAPUD.bit.GPIO24 = 0;
		            GpioCtrlRegs.GPAPUD.bit.GPIO25 = 0;
		            // async inputs
		            GpioCtrlRegs.GPAQSEL1.bit.GPIO14 = 3;
		            GpioCtrlRegs.GPAQSEL2.bit.GPIO24 = 3;
		            GpioCtrlRegs.GPAQSEL2.bit.GPIO25 = 3;
                    // for slave also configure SPISTE
                    if(aParams->MASTERSLAVE == 0)
                    {
                        GpioCtrlRegs.GPAMUX2.bit.GPIO27 = 3; // 0=GPIO,  1=HRCAP2,  2=EQEP2-S,  3=SPISTE-B
                        GpioCtrlRegs.GPAPUD.bit.GPIO27 = 0;
                        GpioCtrlRegs.GPAQSEL2.bit.GPIO27 = 3;
                    }
                    break;
			}
			break;
	}

	PLX_SPI_REGS_PTR->SPICCR.bit.SPISWRESET = 0;

	PLX_SPI_REGS_PTR->SPICTL.bit.MASTER_SLAVE = aParams->MASTERSLAVE;
	PLX_SPI_REGS_PTR->SPICTL.bit.TALK = 1;
	PLX_SPI_REGS_PTR->SPICTL.bit.CLK_PHASE = aParams->CLKPHASE;
	PLX_SPI_REGS_PTR->SPICCR.bit.CLKPOLARITY = aParams->CLKPOLARITY;
	PLX_SPI_REGS_PTR->SPIBRR =  (Uint16)(obj->clk / aParams->BAUDRATE - 1); //Calculate BRR = (LSPCLK freq / SPI CLK freq) - 1
	PLX_SPI_REGS_PTR->SPICCR.bit.SPICHAR = aParams->SPICHAR - 1;
	PLX_SPI_REGS_PTR->SPISTS.all = 0x0000; // Clear all status bits，clear OVERRUN_FLAG and INT_FLAG
	PLX_SPI_REGS_PTR->SPIPRI.all = 0x0010; // SPI priority high, emulator immediate on and free run was 0x0020

	// Initialize SPI FIFO registers
	PLX_SPI_REGS_PTR->SPIFFTX.bit.SPIFFENA = 1;  // Enable FIFO
	PLX_SPI_REGS_PTR->SPIFFTX.bit.TXFFINTCLR = 0;
	PLX_SPI_REGS_PTR->SPIFFRX.bit.RXFFINTCLR = 0;
	PLX_SPI_REGS_PTR->SPIFFRX.bit.RXFFOVFCLR = 0;
	PLX_SPI_REGS_PTR->SPIFFCT.all = 0x00;
	PLX_SPI_REGS_PTR->SPIFFTX.bit.TXFIFO = 1;
	PLX_SPI_REGS_PTR->SPIFFRX.bit.RXFIFORESET = 1;
	PLX_SPI_REGS_PTR->SPIFFTX.bit.SPIRST = 0;
	PLX_SPI_REGS_PTR->SPIFFTX.bit.SPIRST = 1;

	PLX_SPI_REGS_PTR->SPICCR.bit.SPISWRESET = 1;

	EDIS;

    if(aParams->SPICHAR == 16){
        obj->rxMask = 0xFFFF;
    } else {
        obj->rxMask = (1<<aParams->SPICHAR)-1;
    }
    obj->txShift = 16 - aParams->SPICHAR;
}

void PLX_SPI_putGetWords(PLX_SPI_Handle_t aHandle, uint16_t *aOutData, uint16_t *aInData, uint16_t aLen){
    PLX_SPI_Obj_t *obj = (PLX_SPI_Obj_t *)aHandle;

    int i;
    for(i=0; i<aLen; i++)
    {
        PLX_SPI_REGS_PTR->SPITXBUF = (aOutData[i] << obj->txShift);
    }
    while(PLX_SPI_REGS_PTR->SPIFFRX.bit.RXFFST != aLen){
        continue;

    }
    for(i=0; i<aLen; i++)
    {
        aInData[i] = PLX_SPI_REGS_PTR->SPIRXBUF & obj->rxMask;
    }
}


