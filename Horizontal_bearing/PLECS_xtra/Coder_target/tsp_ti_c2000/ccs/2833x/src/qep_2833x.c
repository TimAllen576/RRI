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

#include "plx_qep.h"

PLX_QEP_Handle_t PLX_QEP_init(void *aMemory, const size_t aNumBytes)
{
	PLX_QEP_Handle_t handle;

	if(aNumBytes < sizeof(PLX_QEP_Obj_t))
		return((PLX_QEP_Handle_t)NULL);

	// set handle
	handle = (PLX_QEP_Handle_t)aMemory;

	return handle;
}

void PLX_QEP_setDefaultParams(PLX_QEP_Params_t *aParams)
{
    aParams->QPOSINIT = 0;   // set counter initialization
    aParams->QPOSMAX = 0xFFFFFFFF; // maximum count value

    aParams->QEPCTL.all = 0;
    aParams->QEPCTL.bit.FREE_SOFT = 0; // all QEP timers stop on emulation suspend
    aParams->QEPCTL.bit.PCRM = 1; // operate QEP in Reset on Max counter mode
    aParams->QEPCTL.bit.SEI = 0; // disable strobe init
    aParams->QEPCTL.bit.IEI = 0; // disable index init
    aParams->QEPCTL.bit.SWI = 0; // don't allow software to initialize counter
    aParams->QEPCTL.bit.SEL = 0; // disable strobe event
    aParams->QEPCTL.bit.IEL = 3; // latch on index event marker (only applicable for QEPCTL[PCRM]=01)
    aParams->QEPCTL.bit.QPEN = 1; // QEP enable
    aParams->QEPCTL.bit.QCLM = 0; // disable EQEP capture latch
    aParams->QEPCTL.bit.UTE = 0; // disable unit timer
    aParams->QEPCTL.bit.WDE = 0; // disable QEP watchdog
}

void PLX_QEP_configureViaPinSet(PLX_QEP_Handle_t aHandle, uint16_t aUnit, uint16_t aPinSet, const PLX_QEP_Params_t *aParams)
{
	PLX_QEP_Obj_t *obj = (PLX_QEP_Obj_t *)aHandle;

	if((aUnit < 1) || (aUnit > 2))
	{
		aUnit = 1;
	}

	EALLOW;
	switch(aUnit)
	{
		default:
		case 1:
			obj->qep = &EQep1Regs;
			SysCtrlRegs.PCLKCR1.bit.EQEP1ENCLK = 1;
			switch(aPinSet)
			{
				default:
				case 0:
					GpioCtrlRegs.GPAMUX2.bit.GPIO20 = 1;	// 0=GPIO,  1=EQEPA-1,  2=Resv,  3=COMP1OUT
					GpioCtrlRegs.GPAMUX2.bit.GPIO21 = 1;	// 0=GPIO,  1=EQEPB-1,  2=Resv,  3=COMP2OUT
					GpioCtrlRegs.GPAMUX2.bit.GPIO23 = 1;	// 0=GPIO,  1=EQEPI-1,  2=Resv,  3=LINRX-A
					break;
				case 1:
					// enable internal pull-up for the eQEP selected pins
					GpioCtrlRegs.GPBPUD.bit.GPIO50 = 0;
					GpioCtrlRegs.GPBPUD.bit.GPIO51 = 0;
					GpioCtrlRegs.GPBPUD.bit.GPIO53 = 0;

					// synchronize inputs to SYSCLKOUT
					GpioCtrlRegs.GPBQSEL2.bit.GPIO50 = 0;
					GpioCtrlRegs.GPBQSEL2.bit.GPIO51 = 0;
					GpioCtrlRegs.GPBQSEL2.bit.GPIO53 = 0;

					// set muxes
					GpioCtrlRegs.GPBMUX2.bit.GPIO50 = 1;
					GpioCtrlRegs.GPBMUX2.bit.GPIO51 = 1;
					GpioCtrlRegs.GPBMUX2.bit.GPIO53 = 1;
					break;
			}
			break;
	}

	obj->qep->QDECCTL.all = 0;

	obj->qep->QPOSINIT = aParams->QPOSINIT;
	obj->qep->QPOSMAX = aParams->QPOSMAX;
	obj->qep->QEPCTL.all = aParams->QEPCTL.all;

	obj->qep->QPOSCTL.all = 0;   // set eQEP position-compare control unit to the default mode

	obj->qep->QEINT.bit.QDC = 0;   // disable quadrature direction change interrupt
	obj->qep->QEINT.bit.PCO = 0;   // disable position counter overflow interrupt
	obj->qep->QEINT.bit.PCU = 0;   // disable position counter underflow interrupt
	obj->qep->QEINT.bit.PCM = 0;   // disable position compare match interrupt
	obj->qep->QEINT.bit.UTO = 0;   // disable unit time out event interrupt

	EDIS;
}
