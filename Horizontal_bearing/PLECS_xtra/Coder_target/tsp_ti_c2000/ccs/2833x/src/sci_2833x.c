/*
   Copyright (c) 2019 by Plexim GmbH
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

#include "plx_sci.h"

#pragma diag_suppress 112 // ASSERT(0) in switch statement

#define PLX_SCI_ONE_STOPBIT 0x00
#define PLX_SCI_TWO_STOPBITS 0x80
#define PLX_SCI_NO_PARITY 0x00
#define PLX_SCI_ODD_PARITY 0x20
#define PLX_SCI_EVEN_PARITY 0x60
#define PLX_SCI_SEVEN_BITS 0x06
#define PLX_SCI_EIGHT_BITS 0x07
#define PLX_SCI_PLX_SCI_LOOPBACK 0x10

PLX_SCI_Handle_t PLX_SCI_init(void *aMemory, const size_t aNumBytes)
{
	if(aNumBytes < sizeof(PLX_SCI_Obj_t))
	{
		return((PLX_SCI_Handle_t)NULL);
	}
	PLX_SCI_Handle_t handle = (PLX_SCI_Handle_t)aMemory;
	return handle;
}

void PLX_SCI_configureViaPinSet(PLX_SCI_Handle_t aHandle, uint16_t port, uint32_t clk)
{
	PLX_SCI_Obj_t *obj = (PLX_SCI_Obj_t *)aHandle;
	obj->port = port;
	obj->clk = clk;
}

bool PLX_SCI_setupPort(PLX_SCI_Handle_t aHandle, uint32_t baudrate){
	PLX_SCI_Obj_t *obj = (PLX_SCI_Obj_t *)aHandle;

	EALLOW;

	switch(obj->port)
	{
        case 0:
            obj->portHandle = (uint32_t)&SciaRegs;
            // enable clock to SCIA
            SysCtrlRegs.PCLKCR0.bit.SCIAENCLK=1;
            // configure pins
            GpioCtrlRegs.GPAPUD.bit.GPIO28 = 0;    // enable pull-up for rx
            GpioCtrlRegs.GPAPUD.bit.GPIO29 = 0;    // enable pull-up for tx
            GpioCtrlRegs.GPAQSEL2.bit.GPIO28 = 3;  // asynch input rx
            GpioCtrlRegs.GPAMUX2.bit.GPIO28 = 1;   // configure GPIO for rx operation
            GpioCtrlRegs.GPAMUX2.bit.GPIO29 = 1;   // configure GPIO for tx operation
            break;

		default:
			PLX_ASSERT(0);
	}

    PLX_SCI_REGS_PTR->SCICTL1.all = 0; // reset SCI
    PLX_SCI_REGS_PTR->SCICCR.all = PLX_SCI_ONE_STOPBIT+ PLX_SCI_NO_PARITY + PLX_SCI_EIGHT_BITS;
    PLX_SCI_REGS_PTR->SCICTL1.all = 0x0013; // enable tx, rx, disable rx err, sleep, txwake

 	uint16_t brr = (uint16_t)(obj->clk /8l /baudrate) - 1;
    PLX_SCI_REGS_PTR->SCIHBAUD = 0xFF & (brr>>8);
    PLX_SCI_REGS_PTR->SCILBAUD = 0xFF & brr;

    // setup FIFO
    PLX_SCI_REGS_PTR->SCIFFTX.all = 0xC000;
    PLX_SCI_REGS_PTR->SCIFFRX.all = 0x0000;
    PLX_SCI_REGS_PTR->SCIFFCT.all = 0x00;

    PLX_SCI_REGS_PTR->SCICTL1.all = 0x0033;  // relinquish SCI from reset *

    // reset FIFO
    PLX_SCI_REGS_PTR->SCIFFTX.bit.TXFIFOXRESET = 1;
    PLX_SCI_REGS_PTR->SCIFFRX.bit.RXFIFORESET = 1;

	EDIS;

    return true;
}
