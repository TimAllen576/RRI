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

local P = require('resources.TI2837x_pin_map')

local TripInputsAllocated = {}
local GpioAllocated = {}

-- must match info.xml file
ChipCombo = {'28379D'}

function T.getFamilyPrefix()
  return '2837x'
end

function T.getChipName()
  return ChipCombo[Target.Variables.Chip]
end

-- target options
local boards = {'custom', 'launchpad', 'controlcard'} -- must match info.xml file
local uniFlashConfigs = {
  launchpad = 'Launchpad_TMS320F28379D.ccxml',
  controlcard = 'ControlCard_TMS320F28379D.ccxml'
}

local linkerFiles
if Target.Variables.targetCore ~= 2 then
  linkerFiles = {'f2837xD_FLASH_lnk_cpu1.cmd', 'f2837xD_RAM_lnk_cpu1.cmd'}
else
  linkerFiles = {'f2837xD_FLASH_lnk_cpu2.cmd'}
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
  resources:add("PWM", 1, 12)
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
  resources:add("CAP", 1, 6)
  resources:add("CAN A")
  resources:add("CAN B")
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
      gpio = {
        {0, 1}, {2, 3}, {4, 5}, {6, 7}, {8, 9}, {10, 11}, {12, 13}, {14, 15},
        {16, 17}, {18, 19}, {20, 21}, {22, 23}
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
  if (params.epwm == 1) then
    if (params.type ~= 'external') or (params.source_unit ~= 1) then
      return 'EPWM1 can only be synchronized from EXTSYNC 1'
    else
      return nil -- no configuration is necessary
    end
  end
  if (params.epwm ~= 4) and (params.epwm ~= 7) and (params.epwm ~= 10) then
    return 'EPWM%i does not have a configurable synchronization source.' % {params.epwm}
  end
  local mux
  if params.type == 'external' then
    if params.source_unit == 1 then
      mux = 5
    elseif params.source_unit == 2 then
      mux = 6
    else
      return 'Unsupported external sync unit (%i).' % {params.source_unit}
    end
  elseif params.type == 'epwm' then
    if params.source_unit >= params.epwm then
       return 'Invalid synchronization order (EPWM%i cannot be synchronized from EPWM%i).' %
              {params.epwm, params.source_unit}
    end
    if params.source_unit == 1 then
      mux = 0
    elseif params.source_unit == 4 then
      mux = 1
    elseif params.source_unit == 7 then
      mux = 2
    elseif params.source_unit == 10 then
      mux = 3
    else
      return 'Invalid synchronization order (EPWM%i cannot be synchronized from EPWM%i).' %
              {params.epwm, params.source_unit}
    end
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
      EPwm%(unit)iRegs.TBCTL.bit.SYNCOSEL = %(synco_sel)i;
    ]] % {unit = unit, phsen = params.sync.phsen, synco_sel = params.sync.synco_sel}
    if params.sync.phsen ~= 0 then
      code = code .. [[
        EPwm%(unit)iRegs.TBCTL2.bit.PRDLDSYNC = 1; // load TBPRD at zero and SYNC
      ]] % {unit = unit}
    end
    if params.sync.synci_sel ~= nil then
      code = code .. [[
       EALLOW;
       SyncSocRegs.SYNCSELECT.bit.EPWM%(unit)iSYNCIN = %(synci_sel)i;
       EDIS;
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
    clksrc_macro = "SYSCTL_OSCSRC_XTAL"
  else
    if sysClkHz > 194000000 then
      return
          "Excessive system clock setting for internal oscillator. Must not be greater than 194 MHz."
    end
    sysClkWcHi = 1000000 * math.floor((sysClkHz * 1.03 + 500000) / 1000000)
    clkin = T.getIntOscClock()
    clksrc = 0
    clksrc_macro = "SYSCTL_OSCSRC_OSC2"
  end

  local sysClkDivRegVal = 1 -- TODO: allow different values
  local sysClkDiv = math.max(1, sysClkDivRegVal * 2)

  local fmult = 0 -- TODO: allow different values for more flexibility below
  local fmultRegVal = fmult / 0.25
  local fmult_macro = "SYSCTL_FMULT_NONE"

  local imult = math.min(math.floor(sysClkDiv * sysClkHz / clkin - fmult), 127)
  local imultRegVal = imult

  local pllRawMHz = (imult + fmult) * clkin / 1000000
  if (pllRawMHz < 120) or (pllRawMHz > 400) then
    return "PLL raw frequency (%d MHz) outside of valid range (120-400 MHz)." %
               {pllRawMHz}
  end

  if not (sysClkHz == imult * clkin / sysClkDiv) then
    return
        "Unable to achieve the desired system clock frequency (with input clock = %d Hz)." %
            {clkin}
  end

  local cpuRate = 100.0 / sysClkHz * 10000000

  local declarations = [[
  	void DevInit(uint32_t aDeviceClkConf);
	void InitFlashHz(Uint32 clkHz);
	void DSP28x_usDelay(long LoopCount);

// clock configurations
#define PLX_DEVICE_SETCLOCK_CFG  (%(pll_src)s | SYSCTL_IMULT(%(imult)i) |  \
                                  %(fmult)s | SYSCTL_SYSDIV(%(sysdiv)i) |   \
                                  SYSCTL_PLL_ENABLE)
#define SYSCLK_HZ |<SYSCLK_HZ>|L
#define SYSCLK_WC_HI_HZ |<SYSCLK_WC_HI_HZ>|L
#define LSPCLK_HZ (SYSCLK_HZ / 4l)
#define PLX_DELAY_US(A)  DSP28x_usDelay( \
        ((((long double) A * \
           1000.0L) / \
          |<PLX_CPU_RATE>|L) - 9.0L) / 5.0L)
  ]]  % {
    pll_src = clksrc_macro,
    imult = imult,
    fmult = fmult_macro,
    sysdiv = sysClkDiv
  }
  declarations = string.gsub(declarations, '|<SYSCLK_HZ>|', '%i' % {sysClkHz})
  declarations = string.gsub(declarations, '|<SYSCLK_WC_HI_HZ>|',
                             '%i' % {sysClkWcHi})
  declarations = string.gsub(declarations, '|<PLX_CPU_RATE>|', '%f' % {cpuRate})

  local code = [[
  	{
  	   uint32_t sysPllConfig = PLX_DEVICE_SETCLOCK_CFG;
       DevInit(sysPllConfig);
       SysCtl_setLowSpeedClock(SYSCTL_LSPCLK_PRESCALE_4);

       PLX_ASSERT(SysCtl_getClock(%(clkin)i) == SYSCLK_HZ);
       PLX_ASSERT(SysCtl_getLowSpeedClock(%(clkin)i) == LSPCLK_HZ);
    }
    InitFlashHz(SYSCLK_WC_HI_HZ);
    // set cpu timers to same clock as ePWM
    CpuTimer0Regs.TPR.all = |<CPU_TIMER_DIV>|;
    CpuTimer1Regs.TPR.all = |<CPU_TIMER_DIV>|;
    CpuTimer2Regs.TPR.all = |<CPU_TIMER_DIV>|;
    EALLOW;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER0 = 1;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER1 = 1;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER2 = 1;
	CpuSysRegs.PCLKCR0.bit.TBCLKSYNC = 0; // stop all the TB clocks
	ClkCfgRegs.PERCLKDIVSEL.bit.EPWMCLKDIV = |<EPWMCLKDIV>|;
	EDIS;
  ]] % {clkin = clkin}

  if sysClkHz <= 100000000 then
    code = string.gsub(code, '|<CPU_TIMER_DIV>|', '1')
    code = string.gsub(code, '|<EPWMCLKDIV>|', '0')
  else
    code = string.gsub(code, '|<CPU_TIMER_DIV>|', '3')
    code = string.gsub(code, '|<EPWMCLKDIV>|', '1')
  end

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
	void DSP28x_usDelay(long LoopCount);

// Clock configurations
#define SYSCLK_HZ |<SYSCLK_HZ>|L
#define SYSCLK_WC_HI_HZ |<SYSCLK_WC_HI_HZ>|L
#define LSPCLK_HZ (SYSCLK_HZ / 4l)
#define PLX_DELAY_US(A)  DSP28x_usDelay( \
        ((((long double) A * \
           1000.0L) / \
          |<PLX_CPU_RATE>|L) - 9.0L) / 5.0L)
  ]]
  declarations = string.gsub(declarations, '|<SYSCLK_HZ>|', '%i' % {sysClkHz})
  declarations = string.gsub(declarations, '|<SYSCLK_WC_HI_HZ>|',
                             '%i' % {sysClkWcHi})
  declarations = string.gsub(declarations, '|<PLX_CPU_RATE>|', '%f' % {cpuRate})

  local code = [[
    DevInit();
    InitFlashHz(SYSCLK_WC_HI_HZ);
    // set cpu timers to same clock as ePWM
    CpuTimer0Regs.TPR.all = |<CPU_TIMER_DIV>|;
    CpuTimer1Regs.TPR.all = |<CPU_TIMER_DIV>|;
    CpuTimer2Regs.TPR.all = |<CPU_TIMER_DIV>|;
    EALLOW;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER0 = 1;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER1 = 1;
	CpuSysRegs.PCLKCR0.bit.CPUTIMER2 = 1;
	CpuSysRegs.PCLKCR0.bit.TBCLKSYNC = 0; // stop all the TB clocks
	ClkCfgRegs.PERCLKDIVSEL.bit.EPWMCLKDIV = |<EPWMCLKDIV>|;
	EDIS;
  ]]

  if sysClkHz <= 100000000 then
    code = string.gsub(code, '|<CPU_TIMER_DIV>|', '1')
    code = string.gsub(code, '|<EPWMCLKDIV>|', '0')
  else
    code = string.gsub(code, '|<CPU_TIMER_DIV>|', '3')
    code = string.gsub(code, '|<EPWMCLKDIV>|', '1')
  end

  return {declarations = declarations, code = code}
end

function T.getCpu2BootCode()
  local declarations, code

  declarations = [[
  #define C2_BOOTROM_BOOTSTS_SYSTEM_READY 0x00000002
  #define C1C2_BROM_BOOTMODE_BOOT_FROM_FLASH 0x0000000B
  #define BROM_IPC_EXECUTE_BOOTMODE_CMD 0x00000013

  static void BootCPU2ToFlashSector0()
  {
    volatile int32_t bootStatus;
    do
    {
      bootStatus = IpcRegs.IPCBOOTSTS & 0x0000000F;
    }
    while ((bootStatus != C2_BOOTROM_BOOTSTS_SYSTEM_READY));


    // loop until CPU02 control system IPC flags 0 and 31 are available
    while (IPC_isFlagBusyRtoL(IPC_CPU1_L_CPU2_R, IPC_FLAG0) |
           IPC_isFlagBusyRtoL(IPC_CPU1_L_CPU2_R, IPC_FLAG31))
    {
      continue;
    }

    //  send boot command to allow the CPU2 application to begin execution
    IpcRegs.IPCBOOTMODE = C1C2_BROM_BOOTMODE_BOOT_FROM_FLASH;
    IpcRegs.IPCSENDCOM  = BROM_IPC_EXECUTE_BOOTMODE_CMD;
    IpcRegs.IPCSET.all = 0x80000001;
  }
  ]]

  code = [[
    // reset CPU2
    EALLOW;
    DevCfgRegs.CPU2RESCTL.all = 0xa5a50001L;
    DevCfgRegs.CPU2RESCTL.all = 0xa5a50000L;
    EDIS;

    BootCPU2ToFlashSector0();

    // wait for CPU2 to signal that has completed its initialization
    while(!(HWREG(IPC_BASE + IPC_O_STS) & IPC_FLAG17)){
        continue;
    }

    // acknowledge flag which will allow CPU2 to proceed
    HWREG(IPC_BASE + IPC_O_ACK) = IPC_FLAG17;
  ]]

  return {declarations = declarations, code = code}
end

function T.getCpu2BootCodeCpu2()
  local declarations, code
  code = [[
    // signal to CPU1 that we are configured
    HWREG(IPC_BASE + IPC_O_SET) = IPC_FLAG17;
    // wait for acknowledgment and permission to go
    while(HWREG(IPC_BASE + IPC_O_FLG) & IPC_FLAG17){
        continue;
    }
  ]]

  return {declarations = declarations, code = code}
end

return T
