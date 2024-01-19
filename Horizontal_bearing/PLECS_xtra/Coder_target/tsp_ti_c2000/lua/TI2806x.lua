--[[
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
--]] --
local T = {}

local GpioAllocated = {}

-- must match info.xml file
ChipCombo = {'28069'}

function T.getFamilyPrefix()
  return '2806x'
end

function T.getChipName()
  return ChipCombo[Target.Variables.Chip]
end

-- target options
local boards = {'custom', 'launchpad', 'controlcard'} -- must match info.xml file
local uniFlashConfigs = {
  launchpad = 'Launchpad_TMS320F28069.ccxml',
  controlcard = 'ControlCard_TMS320F28069.ccxml'
}

local linkerFiles = {'F28069.cmd', 'F28069-RAM.cmd'}

function T.getBoardNameFromComboIndex(index)
  return boards[index]
end

function T.getUniflashConfig(board)
  return uniFlashConfigs[board]
end

function T.getLinkerFileName(index)
  return linkerFiles[index]
end

function T.configure(resources)
  resources:add("Base Task Load")
  resources:add("Powerstage Control")
  resources:add("GPIO", 0, 58)
  resources:add("CPUTIMER", 0, 1)
  resources:add("PWM", 1, 6)
  resources:add("ADCA-SOC", 0, 15)
  resources:add("ADC A")
  resources:add("QEP", 1, 2)
  resources:add("CAP", 1, 3)
  resources:add("CAN A")
  resources:add("CAN B")
  resources:add("SPI A")
  resources:add("SPI B")
  resources:add("EXTSYNC", 1, 1)
end

function T.getTargetParameters()
  params = {
    cpu_timers = {0},
    scis = {pin_sets = {GPIO28_GPIO29 = 0}},
    epwms = {
      type = 1,
      max_event_period = 3,
      gpio = {{0, 1}, {2, 3}, {4, 5}, {6, 7}, {8, 9}, {10, 11}}
    },
    adcs = {type = 3, num_channels = 16, vref = 3.3},
    qeps = {
      pin_sets = {_1_GPIO20_GPIO21_GPIO23 = 0, _1_GPIO50_GPIO51_GPIO53 = 1, 
                  _2_GPIO24_GPIO25_GPIO26 = 0, _2_GPIO24_GPIO25_GPIO30 = 1, 
                  _2_GPIO24_GPIO25_GPIO56 = 2, _2_GPIO54_GPIO55_GPIO56 = 3}
                 },
    caps = {
      pins = {
        GPIO5 = 1,
        GPIO11 = 1,
        GPIO19 = 1,
        GPIO24 = 1,
        GPIO7 = 2,
        GPIO15 = 2,
        GPIO25 = 2,
        GPIO9 = 3,
        GPIO26 = 3
      }
    },
    spis = {
      fifo_depth = 4,
      pin_sets = {
        A_GPIO16_GPIO17_GPIO18_GPIO19 = 10,
        A_GPIO16_GPIO17_GPIO18 = 10,
        B_GPIO24_GPIO25_GPIO26_GPIO27 = 20,
        B_GPIO24_GPIO25_GPIO26 = 20,
        B_GPIO24_GPIO25_GPIO14_GPIO27 = 21,
        B_GPIO24_GPIO25_GPIO14 = 21
      }
    },
    cans = {pin_sets = {A_GPIO30_GPIO31 = 0}},
    clas = {
      type = 0,
    },
    gpios = {}
  }
  return params
end

function T.allocateGpio(gpio, properties, req, label)
  GpioAllocated[gpio] = properties
  req:add("GPIO", gpio, label)
end

function T.isGpioAllocated(gpio)
  return (GpioAllocated[gpio] ~= nil)
end

function T.getGpioProperties(gpio)
  return GpioAllocated[gpio]
end

function T.checkGpioIsValidPwmSync(gpio)
  if gpio ~= 6 and gpio ~= 32 then
    return
        "Only GPIO 6 and 32 can be selected as external synchronisation source for 2806x."
  end
end

function T.getPwmSyncInSel(params)
  if params.type == 'external' then
    if (params.epwm ~= 1) then
      return "Only EPWM1 can have an external synchronization source."
    end
  else
    if params.epwm ~= params.source_last_unit+1 then
      return 'EPWM%i cannot be synchronized from EPWM%i.' %
              {params.epwm, params.source_last_unit}
    end
  end
end

function T.getMaxSciBaudRate()
  -- assuming 8N1. 1.5 characters per poll
  local maxRate = 1 / Target.Variables.SAMPLE_TIME * 15
  return math.min(115200, maxRate)
end

function T.checkSpiClockIsAchievable(clk)
  local lspClkHz = T.getLowSpeedClock()
  local maxClk = math.floor(lspClkHz / (0x03 + 1))
  local minClk = math.ceil(lspClkHz / (0x7F + 1))

  if clk > maxClk then
    return "SPI clock rate must not exceed %d Hz." % {maxClk}
  elseif clk < minClk then
    return "SPI clock rate must not be below %d Hz." % {minClk}
  end
end

function T.getIntOscClock()
  return 10000000 -- INTOSC2
end

function T.getLowSpeedClock()
  return Target.Variables.sysClkMHz * 1e6 / 4
end

function T.getPwmClock()
  return Target.Variables.sysClkMHz * 1e6 / 2
end

function T.getTimerClock()
  -- relevant clock for dispatcher
  return T.getPwmClock()
end

function T.getDeadTimeClock()
  return Target.Variables.sysClkMHz * 1e6 / 2
end

function T.getAdcClock()
  local sysClkHz = Target.Variables.sysClkMHz * 1e6
  return sysClkHz / 2
end

function T.getCanClkAndMaxBrp()
  return Target.Variables.sysClkMHz * 1e6 / 2, 0x40
end

function T.getPwmFrequencySettings(fsw, carrier)
  local prd, periodInSysTicks, achievableF
  if carrier == 'triangle' then
    prd = math.floor(T.getPwmClock() / fsw / 2 + 0.5)
    periodInSysTicks = prd * 2 * Target.Variables.sysClkMHz * 1e6 /
                           T.getTimerClock()
    achievableF = T.getPwmClock() / 2 / prd
  else
    prd = math.floor(T.getPwmClock() / fsw - 1 + 0.5)
    periodInSysTicks = (prd + 1) * Target.Variables.sysClkMHz * 1e6 /
                           T.getTimerClock()
    achievableF = T.getPwmClock() / (prd + 1)
  end
  return {
    freq = achievableF,
    period = prd,
    period_in_systicks = periodInSysTicks
  }
end

function T.calcACQPS(ts,sigmode)
  local tsMin = 7 / T.getAdcClock() -- per datasheet - different
  local tsMax = 64 / T.getAdcClock()
  if ts ~= ts or ts < tsMin then -- test for NAN or value that is too small
    ts = tsMin
  elseif ts > tsMax then
    ts = tsMax -- maybe we should be less tolerant here and throw an error?
  end
  return math.floor(ts * T.getAdcClock()) - 1; -- ACQPS register is one less than the number of cycles desired
end

function T.getCpuTimerSetupCode(unit, params)
  local code = [[
	CpuTimer|<UNIT>|Regs.TCR.bit.TSS = 1; // stop timer
	CpuTimer|<UNIT>|Regs.TPRH.all = 0;
	CpuTimer|<UNIT>|Regs.PRD.all = |<PERIOD>|;
	CpuTimer|<UNIT>|Regs.TCR.bit.TRB = 1; // reload period
	CpuTimer|<UNIT>|Regs.TCR.bit.TIE = 1; // enable trigger to SOC/interrupt
  ]]

  if params['isr'] ~= nil then
    -- note, this is really hard-coded for CPUTimer0
    local isrConfigCode = [[
		PieCtrlRegs.PIEIER1.bit.INTx7 = 1;
		EALLOW;
		PieVectTable.TINT|<UNIT>| = &|<ISR>|;
		EDIS;
		PieCtrlRegs.PIEIER1.bit.INTx7 = 1;
		PieCtrlRegs.PIEACK.all = PIEACK_GROUP1; // acknowledge interrupt to PIE
	]]
    isrConfigCode =
        string.gsub(isrConfigCode, '|<ISR>|', '%s' % {params['isr']})
    code = code .. isrConfigCode
  end

  code = string.gsub(code, '|<UNIT>|', '%i' % {unit})
  code = string.gsub(code, '|<PERIOD>|', '%i-1' % {params['period']})
  return code
end

function T.getEpwmSetupCode(unit, params)
  local code = [[
  ]]

  if params['soca_sel'] ~= nil then
    local soccode = [[
      EPwm|<UNIT>|Regs.ETSEL.bit.SOCASEL = |<SOCASEL>|;
      EPwm|<UNIT>|Regs.ETPS.bit.SOCAPRD = |<SOCAPRD>|;
      EPwm|<UNIT>|Regs.ETSEL.bit.SOCAEN = 1;
    ]]
    if params['soca_prd'] == nil then
      soccode = string.gsub(soccode, '|<SOCAPRD>|', '%i' % {1})
    else
      soccode = string.gsub(soccode, '|<SOCAPRD>|', '%i' % {params['soca_prd']})
    end
    soccode = string.gsub(soccode, '|<SOCASEL>|', params['soca_sel'])
    code = code .. soccode
  end

  if params['int_sel'] ~= nil then
    local intConfigCode = [[
      EPwm|<UNIT>|Regs.ETSEL.bit.INTSEL = |<INTSEL>|;
      EPwm|<UNIT>|Regs.ETPS.bit.INTPRD = |<INTPRD>|;
      EPwm|<UNIT>|Regs.ETSEL.bit.INTEN = 1;  // enable INT
    ]]
    intConfigCode = string.gsub(intConfigCode, '|<INTSEL>|', params['int_sel'])
    if params['int_prd'] == nil then
      intConfigCode = string.gsub(intConfigCode, '|<INTPRD>|', '%i' % {1})
    else
      intConfigCode = string.gsub(intConfigCode, '|<INTPRD>|',
                                  '%i' % {params['int_prd']})
    end
    code = code .. intConfigCode
  end

  if params['sync'] ~= nil then
    code = code .. [[
      EPwm%(unit)iRegs.TBCTL.bit.PHSEN = %(phsen)i;
      EPwm%(unit)iRegs.TBCTL.bit.SYNCOSEL = %(synco_sel)i;
    ]] % {unit = unit, phsen = params.sync.phsen, synco_sel = params.sync.synco_sel}
  end

  if params['isr'] ~= nil then
    local isrConfigCode = [[
      PieCtrlRegs.PIEIER3.all |= (1 << (|<UNIT>|-1));
      EALLOW;
      *|<PIE_VECT>| = &|<ISR>|;
      EDIS;
      PieCtrlRegs.PIEACK.all = PIEACK_GROUP3; // Acknowledge interrupt to PIE
    ]]
    local pieVect
    if unit <= 8 then
      pieVect =
          '(PINT *)((uint32_t)(&PieVectTable.EPWM1_INT) + ((uint32_t)%i-1)*sizeof(PINT *))' %
              {unit}
    else
      pieVect =
          '(PINT *)((uint32_t)(&PieVectTable.EPWM9_INT) + ((uint32_t)%i-1)*sizeof(PINT *))' %
              {unit}
    end
    isrConfigCode = string.gsub(isrConfigCode, '|<PIE_VECT>|', pieVect)
    isrConfigCode = string.gsub(isrConfigCode, '|<ISR>|', params['isr'])
    code = code .. isrConfigCode
  end
  code = string.gsub(code, '|<UNIT>|', '%i' % {unit})
  return code
end

function T.getEpwmTimersSyncCode()
  code = [[
    SysCtrlRegs.PCLKCR0.bit.TBCLKSYNC = 1; // start all the timers synced
  ]]
  return code
end

function T.getAdcSetupCode(unit, params)
  local code = [[
    EALLOW;
    AdcRegs.INTSEL1N2.bit.INT1CONT = 0; // disable ADCINT1 Continuous mode
    AdcRegs.INTSEL1N2.bit.INT1SEL = %(INT1SEL)i; // setup EOC%(INT1SEL)i to trigger ADCINT1
    AdcRegs.INTSEL1N2.bit.INT1E = 1; // enable ADCINT1
    AdcRegs.ADCCTL1.bit.INTPULSEPOS = 1; // ADCINT1 trips after AdcResults latch
    EDIS;
  ]] % {INT1SEL = params['INT1SEL']}

  if params['isr'] ~= nil then
    local isrConfigCode = [[
    EALLOW;
    PieVectTable.ADCINT1 = |<ISR>|;
    PieCtrlRegs.PIEIER1.bit.INTx1 = 1;
    PieCtrlRegs.PIEACK.all = PIEACK_GROUP1;
    EDIS;
    ]]
    isrConfigCode = string.gsub(isrConfigCode, '|<ISR>|', params['isr'])
    code = code .. isrConfigCode
  end
  code = string.gsub(code, '|<UNIT>|', '%i' % {unit})
  return code
end

function T.getAdcInterruptAcknCode(unit, params)
  local code = [[
    AdcRegs.ADCINTFLGCLR.bit.ADCINT1 = 1; // clear ADCINT1 flag reinitialize for next SOC
    PieCtrlRegs.PIEACK.all = PIEACK_GROUP1; // acknowledge interrupt to PIE (All ADCS in group 1)
    IER |= M_INT1;
  ]]
  return code
end

function T.getClockConfigurationCode()
  local sysClkHz = Target.Variables.sysClkMHz * 1e6

  if sysClkHz > 90000000 then
    return "Excessive system clock setting."
  elseif sysClkHz < 2000000 then
    return "Insufficient system clock setting."
  end

  if sysClkHz ~= math.floor(sysClkHz) then
    return "System clock setting must be integer value."
  end

  local clkin, clksrc

  if Target.Variables.useIntOsc ~= 1 then
    clkin = Target.Variables.extClkMHz * 1e6
    clksrc = 1
  else
    clkin = T.getIntOscClock()
    clksrc = 0
  end

  local pllDivSelValLookup = {4, 4, 2, 1}
  local pllDivSel = 2 -- hard-coded

  local pllDiveSelVal = pllDivSelValLookup[pllDivSel + 1]

  local pllDiv = math.min(math.floor(pllDivSel * sysClkHz / clkin), 18)
  -- important: VCOCLK must be at least 50 MHz
  if (pllDiv * clkin < 50000000) then
    return "PLL OSC frequency (%d MHz) outside of valid range (>= 50 MHz)." %
               {pllDiv * clkin / 1000000}
  end

  if not (sysClkHz == pllDiv * clkin / pllDivSel) then
    return
        "Unable to achieve the desired system clock frequency (with input clock = %d Hz)." %
            {clkin}
  end

  local cpuRate = 100.0 / sysClkHz * 10000000;

  local declarations = [[
  	void DeviceInit(Uint16 clock_source, Uint16 pllDiv);
	void InitFlash();
	void DSP28x_usDelay(long LoopCount);

// Clock configurations
#define SYSCLK_HZ |<SYSCLK_HZ>|L
#define LSPCLK_HZ (SYSCLK_HZ / 4l)
#define PLL_DIV |<PLL_DIV>|
#define PLL_DIVSEL |<PLL_DIVSEL>|
#define PLL_SRC |<PLL_SRC>|
#define PLX_DELAY_US(A)  DSP28x_usDelay( \
        ((((long double) A * \
           1000.0L) / \
          |<PLX_CPU_RATE>|L) - 9.0L) / 5.0L)
  ]]
  declarations = string.gsub(declarations, '|<SYSCLK_HZ>|', '%i' % {sysClkHz})
  declarations = string.gsub(declarations, '|<PLL_DIV>|', '%i' % {pllDiv})
  declarations = string.gsub(declarations, '|<PLL_DIVSEL>|', '%i' % {pllDivSel})
  declarations = string.gsub(declarations, '|<PLL_SRC>|', '%i' % {clksrc})
  declarations = string.gsub(declarations, '|<PLX_CPU_RATE>|', '%f' % {cpuRate})

  if 2 * T.getTimerClock() ~= sysClkHz then
    return 'T.getTimerClockPeriodInSysTicks() configuration error.'
  end

  local code = [[
    DeviceInit(PLL_SRC, PLL_DIV);
    InitFlash();
    // set cpu timers to same clock as ePWM (SYSCLK/2)
    CpuTimer0Regs.TPR.all = 1;
    CpuTimer1Regs.TPR.all = 1;
    CpuTimer2Regs.TPR.all = 1;
    EALLOW;
    SysCtrlRegs.PCLKCR0.bit.TBCLKSYNC = 0; // stop all the TB clocks
    EDIS;
  ]]

  return {declarations = declarations, code = code}
end

return T
