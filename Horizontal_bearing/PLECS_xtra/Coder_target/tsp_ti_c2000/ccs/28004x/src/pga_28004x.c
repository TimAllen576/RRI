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

#include "plx_pga.h"

#pragma diag_suppress 112 // PLX_ASSERT(0) in switch statements

void PLX_PGA_sinit()
{
    EALLOW;
    // enable clocks to peripherals
    CpuSysRegs.PCLKCR15.bit.PGA1 = 1;
    CpuSysRegs.PCLKCR15.bit.PGA2 = 1;
    CpuSysRegs.PCLKCR15.bit.PGA3 = 1;
    CpuSysRegs.PCLKCR15.bit.PGA4 = 1;
    CpuSysRegs.PCLKCR15.bit.PGA5 = 1;
    CpuSysRegs.PCLKCR15.bit.PGA6 = 1;
    CpuSysRegs.PCLKCR15.bit.PGA7 = 1;

    // but disable functionality
    Pga1Regs.PGACTL.bit.PGAEN = 0;
    Pga2Regs.PGACTL.bit.PGAEN = 0;
    Pga3Regs.PGACTL.bit.PGAEN = 0;
    Pga4Regs.PGACTL.bit.PGAEN = 0;
    Pga5Regs.PGACTL.bit.PGAEN = 0;
    Pga6Regs.PGACTL.bit.PGAEN = 0;
    Pga7Regs.PGACTL.bit.PGAEN = 0;
    EDIS;
}

static volatile struct PGA_REGS* PLX_PGA_getReg(int16_t aChannel)
{
    switch(aChannel){
        case 1: return &Pga1Regs;
        case 2: return &Pga2Regs;
        case 3: return &Pga3Regs;
        case 4: return &Pga4Regs;
        case 5: return &Pga5Regs;
        case 6: return &Pga6Regs;
        case 7: return &Pga7Regs;
        default:
            PLX_ASSERT(0);
    }
    return((volatile struct PGA_REGS*)0); // to keep compiler happy
}

void PLX_PGA_enable(uint16_t aChannel, uint16_t aGain, uint16_t aFilterResistor)
{
    volatile struct PGA_REGS* pga = PLX_PGA_getReg(aChannel);

    EALLOW;
    switch(aGain)
    {
        case 3:
            pga->PGACTL.bit.GAIN = 0;
            break;
        case 6:
            pga->PGACTL.bit.GAIN = 1;
            break;
        case 12:
            pga->PGACTL.bit.GAIN = 2;
            break;
        case 24:
            pga->PGACTL.bit.GAIN = 3;
            break;

        default:
            PLX_ASSERT(0);
    }

    switch(aFilterResistor)
    {
        case 0: // special case: no filter
            pga->PGACTL.bit.FILTRESSEL = 0;
            break;
        case 200:
            pga->PGACTL.bit.FILTRESSEL = 1;
            break;
        case 160:
            pga->PGACTL.bit.FILTRESSEL = 2;
            break;
        case 130:
            pga->PGACTL.bit.FILTRESSEL = 3;
            break;
        case 100:
            pga->PGACTL.bit.FILTRESSEL = 4;
            break;
        case 80:
            pga->PGACTL.bit.FILTRESSEL = 5;
            break;
        case 50:
            pga->PGACTL.bit.FILTRESSEL = 6;
            break;
        default:
            PLX_ASSERT(0);
    }
    pga->PGACTL.bit.PGAEN = 1;
    EDIS;
}

void PLX_PGA_disable(uint16_t aChannel){
    volatile struct PGA_REGS* pga = PLX_PGA_getReg(aChannel);
    EALLOW;
    pga->PGACTL.bit.PGAEN = 0;
    EDIS;
}
