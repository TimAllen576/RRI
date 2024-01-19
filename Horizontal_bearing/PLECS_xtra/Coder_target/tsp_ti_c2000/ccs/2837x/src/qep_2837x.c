/*
   Copyright (c) 2014-2022 by Plexim GmbH
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

void PLX_QEP_configure(PLX_QEP_Handle_t aHandle, uint16_t aUnit, const PLX_QEP_Params_t *aParams)
{
    PLX_QEP_Obj_t *obj = (PLX_QEP_Obj_t *)aHandle;

    EALLOW;
    switch(aUnit)
    {
      case 1:
        obj->qep = &EQep1Regs;
        CpuSysRegs.PCLKCR4.bit.EQEP1 = 1;
        break;

      case 2:
        obj->qep = &EQep2Regs;
        CpuSysRegs.PCLKCR4.bit.EQEP2 = 1;
        break;

      default:
        PLX_ASSERT(0);
    }
    EDIS;

	obj->qep->QDECCTL.all = 0;

	obj->qep->QPOSINIT = aParams->QPOSINIT ;   // set counter initialization to 0
	obj->qep->QPOSMAX = aParams->QPOSMAX; //<<<< set maximum count value to 1999

	obj->qep->QEPCTL = aParams->QEPCTL;
	/*
	obj->qep->QEPCTL.bit.FREE_SOFT = 0; // all QEP timers stop on emulation suspend
	obj->qep->QEPCTL.bit.PCRM = 1; // operate QEP in Reset on Max counter mode
	obj->qep->QEPCTL.bit.SEI = 0; // disable strobe init
	obj->qep->QEPCTL.bit.IEI = 0; // disable index init
	obj->qep->QEPCTL.bit.SWI = 0; // don't allow software to initialize counter
	obj->qep->QEPCTL.bit.SEL = 0; // disable strobe event
	obj->qep->QEPCTL.bit.IEL = 3; //<<<< Latch on index event marker
	obj->qep->QEPCTL.bit.QPEN = 1; //<<<< QEP enable
	obj->qep->QEPCTL.bit.QCLM = 0; // disable EQEP capture latch
	obj->qep->QEPCTL.bit.UTE = 0; // disable unit timer
	obj->qep->QEPCTL.bit.WDE = 0; // disable QEP watchdog
    */
	obj->qep->QPOSCTL.all = 0;   // set eQEP position-compare control unit to the default mode

	obj->qep->QEINT.bit.QDC = 0;   // disable quadrature direction change interrupt
	obj->qep->QEINT.bit.PCO = 0;   // disable position counter overflow interrupt
	obj->qep->QEINT.bit.PCU = 0;   // disable position counter underflow interrupt
	obj->qep->QEINT.bit.PCM = 0;   // disable position compare match interrupt
	obj->qep->QEINT.bit.UTO = 0;   // disable unit time out event interrupt

	EDIS;
//#endif
}
