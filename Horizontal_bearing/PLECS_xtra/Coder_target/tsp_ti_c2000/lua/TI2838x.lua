--[[
  Copyright (c) 2021-2022 by Plexim GmbH
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

local P = require('resources.TI2838x_pin_map')

local TripInputsAllocated = {}
local GpioAllocated = {}

-- must match info.xml file
ChipCombo = {'28388D'}

function T.getFamilyPrefix()
  return '2838x'
end

function T.getChipName()
  return ChipCombo[Target.Variables.Chip]
end

-- target options
local boards = {'custom', 'controlcard'} -- must match info.xml file
local uniFlashConfigs = {
  controlcard = 'ControlCard_TMS320F28388S.ccxml'
}

local linkerFiles
if Target.Variables.targetCore ~= 2 then
  linkerFiles = {'f2838x_FLASH_lnk_cpu1.cmd', 'f2838x_RAM_lnk_cpu1.cmd'}
else
  linkerFiles = {'f2838x_FLASH_lnk_cpu2.cmd'}
end

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
  resources:add("GPIO", 0, 199)
  resources:add("CPUTIMER", 0, 1)
  resources:add("PWM", 1, 16)
  resources:add("ADCA-SOC", 0, 15)
  resources:add("ADCB-SOC", 0, 15)
  resources:add("ADCC-SOC", 0, 15)
  resources:add("ADCD-SOC", 0, 15)
  resources:add("ADC A")
  resources:add("ADC B")
  resources:add("ADC C")
  resources:add("ADC D")
  resources:add("DAC A")
  resources:add("DAC B")
  resources:add("DAC C")
  resources:add("QEP", 1, 3)
  resources:add("CAP", 1, 7)
  resources:add("CAN A")
  resources:add("CAN B")
  resources:add("MCAN", 0, 1)
  resources:add("SPI A")
  resources:add("SPI B")
  resources:add("SCI A")
  resources:add("SCI B")
  resources:add("SCI C")
  resources:add("SCI D")
  resources:add("EXTSYNC", 1, 2)
  resources:add("CMPSS", 1, 8)
  resources:add("XBAR_INPUT", 1, 16)
  resources:add("XBAR_TRIP", 4, 12)
end

function T.validateAlternateFunction(fun)
  local settings = P.getPinSettings(fun)
  return settings ~= nil
end

function T.getTargetParameters()
  params = {
    cpu_timers = {0},
    scis = {
      num_units = 2,
    },
    epwms = {
      type = 4,
      max_event_period = 15,
      sync_group_size = 1,
      gpio = {
        {0, 1}, {2, 3}, {4, 5}, {6, 7}, {8, 9}, {10, 11}, {12, 13}, {14, 15},
        {16, 17}, {18, 19}, {20, 21}, {22, 23}, {24, 25}, {26, 27}, {28, 29}, {30, 31}
        -- note for ePWM, gpio 16-23 is mux 5, gpio 24-31 is mux 13
      }
    },
    adcs = {type = 4, num_channels = 16, vref = 3.0},
    dacs = {min_out = 0.0, max_out = 3.0},
    qeps = {
    },
    caps = {},
    spis = {
      fifo_depth = 16,
      pin_sets = {
        A_GPIO58_GPIO59_GPIO60_GPIO61 = 10,
        A_GPIO58_GPIO59_GPIO60 = 10,
        A_GPIO16_GPIO17_GPIO18_GPIO19 = 11,
        A_GPIO16_GPIO17_GPIO18 = 11,
        B_GPIO63_GPIO64_GPIO65_GPIO66 = 20,
        B_GPIO63_GPIO64_GPIO65 = 20,
        B_GPIO24_GPIO25_GPIO26_GPIO27 = 21,
        B_GPIO24_GPIO25_GPIO26 = 21
      }
    },
    cans = {
    },
    comps = {
      positive = {
        A14 = 4,
        B14 = 4,
        C14 = 4,
        A2 = 1,
        A4 = 2,
        B2 = 3,
        C2 = 6,
        C4 = 5,
        D0 = 7,
        D2 = 8
      }
    },
    trip_groups = {A = 4, B = 5, C = 7},
    cbc_trip_inputs = {8, 9, 10, 11, 12},
    gpios = {
    	opendrain_supported = true,
    },
    clas = {
      type = 1,
    }
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

function T.getNextAvailableTripInput()
  -- find next available trip input
  local availableInputs = T.getTargetParameters()['cbc_trip_inputs']
  for _, tin in ipairs(availableInputs) do
    if TripInputsAllocated[tin] == nil then
      TripInputsAllocated[tin] = true
      return tin
    end
  end
end

function T.checkGpioIsValidPwmSync(gpio)
  if gpio > 168 then
    return
        "Only GPIO from 0 to 168 can be selected as external synchronisation source for 2837x."
  end
end

function T.getPwmSyncInSel(params)
  if params.type == 'external' then
    if params.source_unit == 1 then
      mux = 0x18
    elseif params.source_unit == 2 then
      mux = 0x19
    else
      return 'Unsupported external sync unit (%i).' % {params.source_unit}
    end
  elseif params.type == 'epwm' then
    if params.source_unit >= params.epwm then
       return 'Invalid synchronization order (EPWM%i cannot be synchronized from EPWM%i).' %
              {params.epwm, params.source_unit}
    end
    mux = params.source_unit
  else
    return 'Unsupported sync type (%s).' % {params.type}
  end
  return mux
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
  -- TBCLOCK - CLKDIV=/1, HSPCLKDIV=/2
  local sysClkHz = Target.Variables.sysClkMHz * 1e6
  if sysClkHz <= 100000000 then
    return sysClkHz / 2
  else
    return sysClkHz / 4
  end
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

function T.getTimerClock()
  -- relevant clock for dispatcher
  return T.getPwmClock()
end

function T.getDeadTimeClock()
  -- TBCLOCK - CLKDIV=/1, HSPCLKDIV=/2
  -- TBCLK = EPWMCLK/(HSPCLKDIV * CLKDIV)
  local sysClkHz = Target.Variables.sysClkMHz * 1e6
  if sysClkHz <= 100000000 then
    return sysClkHz / 2
  else
    return sysClkHz / 4
  end
end

function T.getAdcClock()
  local sysClkHz = Target.Variables.sysClkMHz * 1e6
  if sysClkHz <= 50000000 then
    return sysClkHz
  elseif sysClkHz <= 75000000 then
    return sysClkHz / 1.5
  elseif sysClkHz <= 100000000 then
    return sysClkHz / 2
  elseif sysClkHz <= 120000000 then
    return sysClkHz / 2.5
  elseif sysClkHz <= 150000000 then
    return sysClkHz / 3.0
  elseif sysClkHz <= 175000000 then
    return sysClkHz / 3.5
  else
    return sysClkHz / 4
  end
end

function T.getCanClkAndMaxBrp()
  return Target.Variables.sysClkMHz * 1e6, 0x400
end

function T.calcACQPS(ts,sigmode)
  local tsMin
  local acqpsMax = 511
  local acqpsMin = 0
  if sigmode~=nil and sigmode >1 then
      tsMin = math.max(320e-9, 1 / T.getAdcClock()) -- per datasheet, differential
  else
      tsMin = math.max(75e-9, 1 / T.getAdcClock()) -- per datasheet, single ended
  end
  if ts ~= ts or ts < tsMin then -- test for NAN or value that is too small
    ts = tsMin
  end
  local sysClkHz = Target.Variables.sysClkMHz * 1e6
  local acqps = math.ceil(ts * sysClkHz) - 1
  if acqps > acqpsMax then
    acqps = acqpsMax
  elseif acqps < acqpsMin then
    acqps = acqpsMin
  end
  return acqps
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
		PieVectTable.TIMER|<UNIT>|_INT = &|<ISR>|;
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
      EPwm|<UNIT>|Regs.ETPS.bit.SOCPSSEL = 1;
      EPwm|<UNIT>|Regs.ETSOCPS.bit.SOCAPRD2 = |<SOCAPRD>|;
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
      EPwm|<UNIT>|Regs.ETPS.bit.INTPSSEL = 1;
      EPwm|<UNIT>|Regs.ETINTPS.bit.INTPRD2 = |<INTPRD>|;
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
      EPwm%(unit)iRegs.EPWMSYNCOUTEN.all = %(synco_sel)i;
    ]] % {unit = unit, phsen = params.sync.phsen, synco_sel = params.sync.synco_sel}
    if params.sync.phsen ~= 0 then
      code = code .. [[
        EPwm%(unit)iRegs.TBCTL2.bit.PRDLDSYNC = 1; // load TBPRD at zero and SYNC
      ]] % {unit = unit}
    end
    if params.sync.synci_sel ~= nil then
      code = code .. [[
       EPwm%(unit)iRegs.EPWMSYNCINSEL.bit.SEL = %(synci_sel)i;
      ]] % {unit = unit, synci_sel = params.sync.synci_sel}
    end
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
     CpuSysRegs.PCLKCR0.bit.TBCLKSYNC = 1; // start all the timers synced
  ]]
  return code
end

function T.getCmpssRampComparatorEpwmTripSetupCode(unit, params)
  local code = [[
    SysCtl_enablePeripheral(SYSCTL_PERIPH_CLK_CMPSS|<UNIT>|);
    CMPSS_enableModule(CMPSS|<UNIT>|_BASE);
    CMPSS_configHighComparator(CMPSS|<UNIT>|_BASE, CMPSS_INSRC_DAC);
    // configuring ramp to |<ACTUAL_RAMP>| A/s (desired: |<DESIRED_RAMP>| A/s)
    CMPSS_configRamp(CMPSS|<UNIT>|_BASE, 0, |<DEC_VAL>|, 0, |<EPWM_SYNC_UNIT>|, true);

    CMPSS_configDAC(CMPSS|<UNIT>|_BASE, CMPSS_DACREF_VDDA | CMPSS_DACVAL_SYSCLK |
                    CMPSS_DACSRC_RAMP);

    CMPSS_configFilterHigh(CMPSS|<UNIT>|_BASE, |<FILTER_PRESCALE>|, |<FILTER_WINDOW>|, |<FILTER_THRESHOLD>|);
    CMPSS_initFilterHigh(CMPSS|<UNIT>|_BASE);

    CMPSS_configOutputsHigh(CMPSS|<UNIT>|_BASE, |<CMPSS_TRIP>|);
  ]]
  code = string.gsub(code, '|<EPWM_SYNC_UNIT>|', '%i' % {params.sync_epwm_unit})
  code = string.gsub(code, '|<DEC_VAL>|', '%i' % {params.decrement_val})
  code = string.gsub(code, '|<ACTUAL_RAMP>|', '%f' % {params.actual_ramp})
  code = string.gsub(code, '|<DESIRED_RAMP>|', '%f' % {params.desired_ramp})

  code = string.gsub(code, '|<UNIT>|', '%i' % {unit})
  if (params.filter_prescale ~= nil) and (params.filter_window ~= nil) and (params.filter_threshold ~= nil) then
    code = string.gsub(code, '|<FILTER_PRESCALE>|', '%i' % {params.filter_prescale - 1})
    code = string.gsub(code, '|<FILTER_WINDOW>|', '%i' % {params.filter_window})
    code = string.gsub(code, '|<FILTER_THRESHOLD>|', '%i' % {params.filter_threshold})
    code = string.gsub(code, '|<CMPSS_TRIP>|', 'CMPSS_TRIP_FILTER')
  else
    code = string.gsub(code, '|<FILTER_PRESCALE>|', '1-1')
    code = string.gsub(code, '|<FILTER_WINDOW>|', '1')
    code = string.gsub(code, '|<FILTER_THRESHOLD>|', '1')
    code = string.gsub(code, '|<CMPSS_TRIP>|', 'CMPSS_TRIP_ASYNC_COMP')
  end
  return code
end

function T.getCmpssWindowComparatorEpwmTripSetupCode(unit, params)
  local threshold_low_dac = math.floor(4096 / 3.3 * params.threshold_low + 0.5)
  if threshold_low_dac < 0 then
    threshold_low_dac = 0
  elseif threshold_low_dac > 4095 then
    threshold_low_dac = 4095
  end

  local threshold_high_dac =
      math.floor(4096 / 3.3 * params.threshold_high + 0.5)
  if threshold_high_dac < 0 then
    threshold_high_dac = 0
  elseif threshold_high_dac > 4095 then
    threshold_high_dac = 4095
  end

  local codeHL = [[
    SysCtl_enablePeripheral(SYSCTL_PERIPH_CLK_CMPSS|<UNIT>|);
    CMPSS_enableModule(CMPSS|<UNIT>|_BASE);
    CMPSS_configHighComparator(CMPSS|<UNIT>|_BASE, CMPSS_INSRC_DAC);
    CMPSS_configLowComparator(CMPSS|<UNIT>|_BASE, CMPSS_INSRC_DAC | CMPSS_INV_INVERTED);
    CMPSS_configDAC(CMPSS|<UNIT>|_BASE, CMPSS_DACREF_VDDA | CMPSS_DACVAL_SYSCLK |
                    CMPSS_DACSRC_SHDW);
    CMPSS_setDACValueHigh(CMPSS|<UNIT>|_BASE, |<THR_HIGH>|); // |<THR_HIGH_V>| V
    CMPSS_setDACValueLow(CMPSS|<UNIT>|_BASE, |<THR_LOW>|);  // |<THR_LOW_V>| V
    CMPSS_configFilterHigh(CMPSS|<UNIT>|_BASE, |<FILTER_PRESCALE>|, |<FILTER_WINDOW>|, |<FILTER_THRESHOLD>|);
    CMPSS_initFilterHigh(CMPSS|<UNIT>|_BASE);
    CMPSS_configFilterLow(CMPSS|<UNIT>|_BASE, |<FILTER_PRESCALE>|, |<FILTER_WINDOW>|, |<FILTER_THRESHOLD>|);
    CMPSS_initFilterLow(CMPSS|<UNIT>|_BASE);
    CMPSS_configOutputsHigh(CMPSS|<UNIT>|_BASE, |<CMPSS_TRIP>|);
    CMPSS_configOutputsLow(CMPSS|<UNIT>|_BASE, |<CMPSS_TRIP>|);
  ]]

  local codeH = [[
    SysCtl_enablePeripheral(SYSCTL_PERIPH_CLK_CMPSS|<UNIT>|);
    CMPSS_enableModule(CMPSS|<UNIT>|_BASE);
    CMPSS_configHighComparator(CMPSS|<UNIT>|_BASE, CMPSS_INSRC_DAC);
    CMPSS_configDAC(CMPSS|<UNIT>|_BASE, CMPSS_DACREF_VDDA | CMPSS_DACVAL_SYSCLK |
                    CMPSS_DACSRC_SHDW);
    CMPSS_setDACValueHigh(CMPSS|<UNIT>|_BASE, |<THR_HIGH>|); // |<THR_HIGH_V>| V
    CMPSS_configFilterHigh(CMPSS|<UNIT>|_BASE, |<FILTER_PRESCALE>|, |<FILTER_WINDOW>|, |<FILTER_THRESHOLD>|);
    CMPSS_initFilterHigh(CMPSS|<UNIT>|_BASE);
    CMPSS_configOutputsHigh(CMPSS|<UNIT>|_BASE, |<CMPSS_TRIP>|);
  ]]

  local codeL = [[
    SysCtl_enablePeripheral(SYSCTL_PERIPH_CLK_CMPSS|<UNIT>|);
    CMPSS_enableModule(CMPSS|<UNIT>|_BASE);
    CMPSS_configHighComparator(CMPSS|<UNIT>|_BASE, CMPSS_INSRC_DAC | CMPSS_INV_INVERTED);
    CMPSS_configDAC(CMPSS|<UNIT>|_BASE, CMPSS_DACREF_VDDA | CMPSS_DACVAL_SYSCLK |
                    CMPSS_DACSRC_SHDW);
    CMPSS_setDACValueHigh(CMPSS|<UNIT>|_BASE, |<THR_LOW>|); // |<THR_LOW_V>| V
    CMPSS_configFilterHigh(CMPSS|<UNIT>|_BASE, |<FILTER_PRESCALE>|, |<FILTER_WINDOW>|, |<FILTER_THRESHOLD>|);
    CMPSS_initFilterHigh(CMPSS|<UNIT>|_BASE);
    CMPSS_configOutputsHigh(CMPSS|<UNIT>|_BASE, |<CMPSS_TRIP>|);
  ]]

  local code
  if threshold_high_dac == 4095 then
    code = codeL
  elseif threshold_low_dac == 0 then
    code = codeH
  else
    code = codeHL
  end

  code = string.gsub(code, '|<UNIT>|', '%i' % {unit})
  code = string.gsub(code, '|<THR_LOW>|', '%i' % {threshold_low_dac})
  code = string.gsub(code, '|<THR_LOW_V>|', '%f' % {params.threshold_low})
  code = string.gsub(code, '|<THR_HIGH>|', '%i' % {threshold_high_dac})
  code = string.gsub(code, '|<THR_HIGH_V>|', '%f' % {params.threshold_high})
  if (params.filter_prescale ~= nil) and (params.filter_window ~= nil) and (params.filter_threshold ~= nil) then
    code = string.gsub(code, '|<FILTER_PRESCALE>|', '%i' % {params.filter_prescale - 1})
    code = string.gsub(code, '|<FILTER_WINDOW>|', '%i' % {params.filter_window})
    code = string.gsub(code, '|<FILTER_THRESHOLD>|', '%i' % {params.filter_threshold})
    code = string.gsub(code, '|<CMPSS_TRIP>|', 'CMPSS_TRIP_FILTER')
  else
    code = string.gsub(code, '|<FILTER_PRESCALE>|', '1-1')
    code = string.gsub(code, '|<FILTER_WINDOW>|', '1')
    code = string.gsub(code, '|<FILTER_THRESHOLD>|', '1')
    code = string.gsub(code, '|<CMPSS_TRIP>|', 'CMPSS_TRIP_ASYNC_COMP')
  end
  return code
end

function T.getAdcSetupCode(unit, params)
  local code = [[
    EALLOW;
    |<ADC_REGS>|.ADCINTSEL1N2.bit.INT1CONT = 0; // disable ADCINT1 Continuous mode
    |<ADC_REGS>|.ADCINTSEL1N2.bit.INT1SEL = %(INT1SEL)i; // setup EOC%(INT1SEL)i to trigger ADCINT1
    |<ADC_REGS>|.ADCINTSEL1N2.bit.INT1E = 1; // enable ADCINT1
    |<ADC_REGS>|.ADCCTL1.bit.INTPULSEPOS = 1; // ADCINT1 trips after AdcResults latch
    EDIS;
  ]] % {INT1SEL = params['INT1SEL']}

  if params['isr'] ~= nil then
    local isrConfigCode = [[
    EALLOW;
    *|<PIE_VECT>| = &|<ISR>|;
    PieCtrlRegs.PIEIER1.all |= |<PIEIER1_MASK>|;
    PieCtrlRegs.PIEACK.all = PIEACK_GROUP1;
    EDIS;
    ]]

    local pieVect, pieBitMask
    if unit <= 2 then
      pieVect =
          '(PINT *)((uint32_t)(&PieVectTable.ADCA1_INT) + ((uint32_t)%i)*sizeof(PINT *))' %
              {unit}
      pieBitMask = (1 << unit)
    else
      -- ADC C is special case
      pieVect = '(PINT *)&PieVectTable.ADCD1_INT'
      pieBitMask = (1 << 5)
    end
    isrConfigCode = string.gsub(isrConfigCode, '|<ISR>|', params['isr'])
    isrConfigCode = string.gsub(isrConfigCode, '|<PIE_VECT>|', pieVect)
    isrConfigCode = string.gsub(isrConfigCode, '|<PIEIER1_MASK>|', pieBitMask)
    code = code .. isrConfigCode
  end
  code = string.gsub(code, '|<ADC_REGS>|',
                     'Adc%sRegs' % {string.char(97 + unit)})
  return code
end

function T.getAdcInterruptAcknCode(unit, params)
  local code = [[
    |<ADC_REGS>|.ADCINTFLGCLR.bit.ADCINT1 = 1; // clear ADCINT1 flag reinitialize for next SOC
    PieCtrlRegs.PIEACK.all = PIEACK_GROUP1; // acknowledge interrupt to PIE (All ADCS in group 1)
    IER |= M_INT1;
  ]]
  code = string.gsub(code, '|<ADC_REGS>|',
                     'Adc%sRegs' % {string.char(97 + unit)})
  return code
end

function T.getPllConfigRecord(clkInHz, clkOutHz)
  pll = {}
  -- sysdiv = {1,2,4,6,8,10,12,14,16}
  local sysdiv_min = math.max(1, math.ceil(120000000/clkOutHz))
  local sysdiv_max = math.min(16, math.floor(400000000/clkOutHz))
  if (sysdiv_min <= 16) and (sysdiv_max >= 1) then
    for sysdiv = sysdiv_min, sysdiv_max do
      -- only certain values valid, which means we are doing a few unnecessary loops
      pll.sysdiv = math.max(1, 2*math.floor(sysdiv/2))
      local rawPllClk = clkOutHz * pll.sysdiv
      -- odiv = 1...32
      local odiv_min = math.max(1, math.ceil(220000000/rawPllClk))
      local odiv_max = math.min(32, math.floor(500000000/rawPllClk))
      if (odiv_min <= 32) and (odiv_max >= 1) then
        for odiv = odiv_min, odiv_max do
          pll.odiv = odiv
          local vcoClk = rawPllClk*pll.odiv
          -- imult = 1...127
          imult_max = math.max(1, math.floor(vcoClk/10000000))
          imult_min = math.min(127, math.ceil(vcoClk/25000000))
          if (imult_min <= 127) and (imult_max >= 1) then
            for imult = imult_min, imult_max do
              pll.imult = imult
              local intclk = vcoClk/pll.imult
              -- refdiv = 1...32
              refdiv = math.floor(clkInHz/intclk + 0.5)
              if (refdiv >= 1) and (refdiv <= 32) then
                if (intclk*refdiv == clkInHz) then
                  pll.refdiv = refdiv
                  return pll
                end
              end
            end
          end
        end
      end
    end
  end
end

function T.calcAndCheckPllClks(pll, clkInHz)
  refdiv_reg = pll.refdiv-1
  if (refdiv_reg < 0) or (refdiv_reg > 0x1F) then
    return 'REFDIV out of range(%i)' % {pll.refdiv}
  end
  pll.intclk = clkInHz / pll.refdiv
  if (pll.intclk < 10000000) or (pll.intclk > 25000000) then
    return 'INTCLK out of spec (%i)' % {pll.intclk}
  end
  imult_reg = pll.imult
  if (imult_reg < 1) or (imult_reg > 127) then
    return 'IMULT out of range(%i)' % {pll.imult}
  end
  pll.vcoclk = pll.intclk * pll.imult
  if (pll.vcoclk < 220000000) or (pll.vcoclk > 500000000) then
    return 'VCOCLK out of spec (%i)' % {pll.vcoclk}
  end
  local odiv_reg = pll.odiv-1
  if (odiv_reg < 0) or (odiv_reg > 0x1F) then
    return 'ODIV out of range(%i)' % {pll.odiv}
  end
  pll.rawclk = pll.vcoclk / pll.odiv
  if (pll.rawclk < 120000000) or (pll.rawclk > 400000000) then
    return 'RAWCLK out of spec (%i)' % {pll.rawclk}
  end
  local sysdiv_reg = math.floor(pll.sysdiv/2)
  if (sysdiv_reg < 0) or (sysdiv_reg > 8) then
    return 'SYSDIV out of range(%i)' % {pll.sysdiv}
  end
  pll.clk = pll.rawclk / math.max(1, 2*math.floor(pll.sysdiv/2))
  if pll.clk < 2000000 then
    return 'CLK out of spec (%i)' % {pll.clk}
  end
end

function T.getClockConfigurationCode()
  local sysClkHz = Target.Variables.sysClkMHz * 1e6

  local clkin, clksrc

  if sysClkHz > 200000000 then
    return "Excessive system clock setting."
  elseif sysClkHz < 2000000 then
    return "Insufficient system clock setting."
  end

  if sysClkHz ~= math.floor(sysClkHz) then
    return "System clock setting must be integer value."
  end

  local sysClkWcHi = sysClkHz
  if Target.Variables.useIntOsc ~= 1 then
    clkin = Target.Variables.extClkMHz * 1e6
    clksrc = 1
  else
    if sysClkHz > 194000000 then
      return
          "Excessive system clock setting for internal oscillator. Must not be greater than 194 MHz."
    end
    sysClkWcHi = 1000000 * math.floor((sysClkHz * 1.03 + 500000) / 1000000)
    clkin = T.getIntOscClock()
    clksrc = 0
  end

  local auxClkHz = 125e6

  -- establish PLL settings
  local defaultErrorMsg = "Unable to achieve the desired system clock frequency (with input clock = %d Hz)." %
            {clkin}
  local pll = T.getPllConfigRecord(clkin, sysClkHz)
  if pll == nil then
    return defaultErrorMsg
  end
  error = T.calcAndCheckPllClks(pll, clkin)
  if error ~= nil then
    return error
  end
  if pll.clk ~= sysClkHz then
    return defaultErrorMsg
  end
  if Target.Variables.useIntOsc == 1 then
    pll.src = 'SYSCTL_OSCSRC_OSC2'
  else
    pll.src = 'SYSCTL_OSCSRC_XTAL'
  end
  pll.dcc_base = 1

   -- establish AUXPLL settings
  local defaultErrorMsg = "Unable to achieve the desired auxiliary clock frequency (with input clock = %d Hz)." %
            {clkin}
  local aux_pll = T.getPllConfigRecord(clkin, auxClkHz)
  if aux_pll == nil then
    return defaultErrorMsg
  end
  error = T.calcAndCheckPllClks(aux_pll, clkin)
  if error ~= nil then
    return error
  end
  if aux_pll.clk ~= auxClkHz then
    return defaultErrorMsg
  end
  if Target.Variables.useIntOsc == 1 then
    aux_pll.src = 'SYSCTL_AUXPLL_OSCSRC_OSC2'
  else
    aux_pll.src = 'SYSCTL_AUXPLL_OSCSRC_XTAL'
  end
  aux_pll.dcc_base = 0

  local cmClkHz = auxClkHz
  local cpuRate = 100.0 / sysClkHz * 10000000

  local declarations = [[
    void DevInit(uint32_t aDeviceClkConf, uint32_t aAuxClockConf);
    void InitFlashHz(Uint32 clkHz);
    void PieCntlInit(void);
	void F28x_usDelay(long LoopCount);

// Clock configurations
#define PLX_DEVICE_SETCLOCK_CFG       (%(pll_src)s | SYSCTL_IMULT(%(pll_imult)i) | \
                                      SYSCTL_REFDIV(%(pll_refdiv)i) | SYSCTL_ODIV(%(pll_odiv)i) | \
                                      SYSCTL_SYSDIV(%(pll_sysdiv)i) | SYSCTL_PLL_ENABLE | \
                                      SYSCTL_DCC_BASE_%(pll_dcc_base)i)

#define PLX_DEVICE_AUXSETCLOCK_CFG    (%(aux_pll_src)s | SYSCTL_AUXPLL_IMULT(%(aux_pll_imult)i) |  \
                                      SYSCTL_REFDIV(%(aux_pll_refdiv)i) | SYSCTL_ODIV(%(aux_pll_odiv)i) | \
                                      SYSCTL_AUXPLL_DIV_%(aux_pll_sysdiv)i | SYSCTL_AUXPLL_ENABLE | \
                                      SYSCTL_DCC_BASE_%(aux_pll_dcc_base)i)

#define SYSCLK_HZ %(sysclk_hz)iL
#define SYSCLK_WC_HI_HZ %(sysclk_wc_hi_hz)iL
#define LSPCLK_HZ (%(sysclk_hz)iL / 4l)
#define CM_SYSCLK_HZ %(cmclk_hz)iL

#define PLX_DELAY_US(A)  F28x_usDelay(((((long double) A * 1000.0L) / (long double)%(cpu_rate)fL) - 9.0L) / 5.0L)
   ]] % {
    pll_src = pll.src, pll_imult = pll.imult, pll_refdiv = pll.refdiv,
    pll_odiv = pll.odiv, pll_sysdiv = pll.sysdiv, pll_dcc_base = pll.dcc_base,
    aux_pll_src = aux_pll.src, aux_pll_imult = aux_pll.imult, aux_pll_refdiv = aux_pll.refdiv,
    aux_pll_odiv = aux_pll.odiv, aux_pll_sysdiv = aux_pll.sysdiv, aux_pll_dcc_base = aux_pll.dcc_base,
    sysclk_hz = sysClkHz,
    sysclk_wc_hi_hz = sysClkWcHi,
    cmclk_hz = cmClkHz,
    cpu_rate = cpuRate
   }

   local code = [[
   SysCtl_disableWatchdog();
 	{
	    uint32_t sysPllConfig = PLX_DEVICE_SETCLOCK_CFG;
	    uint32_t auxPllConfig = PLX_DEVICE_AUXSETCLOCK_CFG;
	    DevInit(sysPllConfig, auxPllConfig);

	    SysCtl_setLowSpeedClock(SYSCTL_LSPCLK_PRESCALE_4);
	    SysCtl_setCMClk(SYSCTL_CMCLKOUT_DIV_1,SYSCTL_SOURCE_AUXPLL);
	}

	InitFlashHz(SYSCLK_WC_HI_HZ);

    // set cpu timers to same clock as ePWM
    CPUTimer_setPreScaler(CPUTIMER0_BASE, 3);
    CPUTimer_setPreScaler(CPUTIMER1_BASE, 3);
    CPUTimer_setPreScaler(CPUTIMER2_BASE, 3);

    EALLOW;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER0 = 1;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER1 = 1;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER2 = 1;
	CpuSysRegs.PCLKCR0.bit.TBCLKSYNC = 0; // stop all the TB clocks
	ClkCfgRegs.PERCLKDIVSEL.bit.EPWMCLKDIV = 1;
	EDIS;
  ]]

  return {declarations = declarations, code = code}
end

function T.getClockConfigurationCodeCpu2()
  local sysClkHz = Target.Variables.sysClkMHz * 1e6

  if sysClkHz > 200000000 then
    return "Excessive system clock setting."
  elseif sysClkHz < 2000000 then
    return "Insufficient system clock setting."
  end

  if sysClkHz ~= math.floor(sysClkHz) then
    return "System clock setting must be integer value."
  end

  local sysClkWcHi = sysClkHz
  if Target.Variables.useIntOsc ~= 1 then
    clkin = Target.Variables.extClkMHz * 1e6
  else
    if sysClkHz > 194000000 then
      return
          "Excessive system clock setting for internal oscillator. Must not be greater than 194 MHz."
    end
    sysClkWcHi = 1000000 * math.floor((sysClkHz * 1.03 + 500000) / 1000000)
  end

  local cpuRate = 100.0 / sysClkHz * 10000000

  local declarations = [[
    void DevInit();
    void InitFlashHz(Uint32 clkHz);
    void PieCntlInit(void);
	void F28x_usDelay(long LoopCount);

#define SYSCLK_HZ %(sysclk_hz)iL
#define SYSCLK_WC_HI_HZ %(sysclk_wc_hi_hz)iL
#define LSPCLK_HZ (%(sysclk_hz)iL / 4l)

#define PLX_DELAY_US(A)  F28x_usDelay(((((long double) A * 1000.0L) / (long double)%(cpu_rate)fL) - 9.0L) / 5.0L)
   ]] % {
    sysclk_hz = sysClkHz,
    sysclk_wc_hi_hz = sysClkWcHi,
    cpu_rate = cpuRate
   }

  local code = [[
    SysCtl_disableWatchdog();
    DevInit();
	InitFlashHz(SYSCLK_WC_HI_HZ);

    // set cpu timers to same clock as ePWM
    CPUTimer_setPreScaler(CPUTIMER0_BASE, 3);
    CPUTimer_setPreScaler(CPUTIMER1_BASE, 3);
    CPUTimer_setPreScaler(CPUTIMER2_BASE, 3);

    EALLOW;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER0 = 1;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER1 = 1;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER2 = 1;
	CpuSysRegs.PCLKCR0.bit.TBCLKSYNC = 0; // stop all the TB clocks
	ClkCfgRegs.PERCLKDIVSEL.bit.EPWMCLKDIV = 1;
	EDIS;
  ]]

  return {declarations = declarations, code = code}
end

function T.getCpu2BootCode()
  local declarations, code

  declarations = [[
  #define BOOTMODE_BOOT_TO_FLASH_SECTOR0 0x03U
  #define BOOT_KEY 0x5A000000UL
  #define CPU2_BOOT_FREQ_200MHZ 0xC800U

  static void BootCPU2ToFlashSector0()
  {
    IPC_setBootMode(IPC_CPU1_L_CPU2_R,
                (BOOT_KEY | CPU2_BOOT_FREQ_200MHZ | BOOTMODE_BOOT_TO_FLASH_SECTOR0));
    IPC_setFlagLtoR(IPC_CPU1_L_CPU2_R, IPC_FLAG0);
    SysCtl_controlCPU2Reset(SYSCTL_CORE_DEACTIVE);
    while(SysCtl_isCPU2Reset() == 0x1U);
  }
  ]]

  code = [[
    SysCtl_controlCPU2Reset(SYSCTL_CORE_ACTIVE);
    BootCPU2ToFlashSector0();
    // wait for CPU2 to signal that has completed its initialization
    while (!IPC_isFlagBusyRtoL(IPC_CPU1_L_CPU2_R, IPC_FLAG17)){
      continue;
    }
    // acknowledge flag which will allow CPU2 to proceed
    IPC_ackFlagRtoL(IPC_CPU1_L_CPU2_R, IPC_FLAG17);
  ]]

  return {declarations = declarations, code = code}
end

function T.getCpu2BootCodeCpu2()
  local declarations, code

  code = [[
    // signal to CPU1 that we are configured
    IPC_setFlagLtoR(IPC_CPU2_L_CPU1_R, IPC_FLAG17);
    // wait for acknowledgment and permission to go
    while(IPC_isFlagBusyLtoR(IPC_CPU2_L_CPU1_R, IPC_FLAG17)){
      continue;
    }
  ]]

  return {declarations = declarations, code = code}
end

return T
