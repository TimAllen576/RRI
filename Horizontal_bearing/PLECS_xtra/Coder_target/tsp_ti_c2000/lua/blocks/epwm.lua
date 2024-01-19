--[[
  Copyright (c) 2021 by Plexim GmbH
  All rights reserved.

  A free license is granted to anyone to use this software for any legal
  non safety-critical purpose, incluEpwmg commercial applications, provided
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
local Module = {}

local static = {
  numInstances = 0,
  instances = {},
  finalized = nil,
  ps_protection = nil,
  enableCodeGenerated = nil
}

function Module.getBlock(globals)

  local Epwm = require('blocks.block').getBlock(globals)
  Epwm["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Epwm:createImplicit(epwm, params, req)
    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    self.epwm = epwm
    static.instances[self.epwm] = self.bid
    self:logLine('EPWM%i implicitly created.' % {self.epwm})

    self.fsw = params.fsw
    self.carrier_type = params.carrier_type
    self.polarity = params.polarity
    self.outmode = params.outmode
    self.sequence = params.sequence
    self.dead_time = params.dead_time
    self.trip_zone_settings = params.trip_zone_settings
    self.cbc_trip = params.cbc_trip
    self.show_enable = params.show_enable

    local timing = globals.target.getPwmFrequencySettings(self.fsw,
                                                          self.carrier_type)
    self.fsw_actual = timing.freq
    self.prd = timing.period
    self.periodInSysTicks = timing.period_in_systicks

    if self.prd > 0xFFFF then
      return "Unable to achieve the desired PWM frequency (%f Hz is too low)." %
                 {self.fsw}
    end

    req:add("PWM", epwm)
    local p = globals.target.getTargetParameters()['epwms']['gpio'][epwm]
    if p == nil then
      return "PWM generator %d is not available for this target device." %
                 {epwm}
    end
    local pins = {}
    if string.find(self.outmode, "A") then
      globals.target.allocateGpio(p[1], {}, req)
      pins[1] = 2*(epwm-1)
    end
    if string.find(self.outmode, "B") then
      globals.target.allocateGpio(p[2], {}, req)
      pins[2] = 2*(epwm-1) + 1
    end

    if driverLibTarget then
      local gpioConfigA
      local gpioConfigB
      if globals.target.getFamilyPrefix() == '28004x' then
        gpioConfigA = "GPIO_%(gpio)i_EPWM%(epwm)i_A"
        gpioConfigB = "GPIO_%(gpio)i_EPWM%(epwm)i_B"
      else
        gpioConfigA = "GPIO_%(gpio)i_EPWM%(epwm)iA"
        gpioConfigB = "GPIO_%(gpio)i_EPWM%(epwm)iB"
      end
      local pinconf = {}
      if string.find(self["outmode"], "A") then
        table.insert(pinconf, gpioConfigA % {gpio = 2*(self["epwm"]-1), epwm = self["epwm"]})
      end
      if string.find(self["outmode"], "B") then
        table.insert(pinconf, gpioConfigB % {gpio = 2*(self["epwm"]-1)+1, epwm = self["epwm"]})
      end
      globals.syscfg:addEntry('epwm', {
        unit = epwm,
        pins = pins,
        pinconf = pinconf
      })
    end
  end

  function Epwm:configureSocEvents(params)
    if params.soc_prd >
        globals.target.getTargetParameters()['epwms']['max_event_period'] then
      self:logLine('EXCEPTION: Excessive SOC trigger divider value.')
      return
    end
    self.soc_loc = params.soc_loc
    self.soc_prd = params.soc_prd
  end

  function Epwm:configureInterruptEvents(params)
    if params.int_prd >
        globals.target.getTargetParameters()['epwms']['max_event_period'] then
      self:logLine('EXCEPTION: Excessive interrupt trigger divider value.')
      return
    end
    self.int_loc = params.int_loc
    self.int_prd = params.int_prd
    self.isr = params.isr
  end

  function Epwm:configureSync(sync)
    self.sync = sync
  end

  function Epwm:checkMaskParameters(env)
    return "Explicit use of EPWM via target block not supported."
  end

  function Epwm:getDirectFeedthroughCode()
    return "Explicit use of EPWM via target block not supported."
  end

  function Epwm:getEnableCode() -- must be called from nondirect feedthrough code
    if static.ps_protection == nil then
      -- see if there is a powerstage protection block in the circuit
      for _, b in ipairs(globals.instances) do
        if b:getType() == 'powerstage' then
          static.ps_protection = b
        end
      end
    end

    if static.enableCodeGenerated == nil then
      static.enableCodeGenerated = true
      if static.ps_protection ~= nil then
        return static.ps_protection:getEnableCode()
      else
        return 'PLXHAL_PWM_enableAllOutputs();'
      end
    end
  end

  function Epwm:finalizeThis(c)
    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    c.PreInitCode:append("// configure PWM%i at %.1f Hz in %s mode" %
                             {
          self["epwm"], self["fsw_actual"], self["carrier_type"]
        })
    if self["soc_loc"] ~= nil then
      c.PreInitCode:append("// (soc='%s')" % {self["soc_loc"]})
    end
    if self["int_loc"] ~= nil then
      c.PreInitCode:append("// (int='%s')" % {self["int_loc"]})
    end
    if self["fsw_actual"] ~= self["fsw"] then
      c.PreInitCode:append("// (desired frequency was %1.f Hz)" % {self["fsw"]})
    end
    c.PreInitCode:append("{")
    c.PreInitCode:append("PLX_PWM_Params_t params;")
    c.PreInitCode:append("PLX_PWM_setDefaultParams(&params);")

    if self["outmode"] == '' then
      c.PreInitCode:append("params.outMode = PLX_PWM_OUTPUT_MODE_DISABLED;")
    elseif self["outmode"] == 'A' then
      c.PreInitCode:append("params.outMode = PLX_PWM_OUTPUT_MODE_SINGLE;")
    else
      c.PreInitCode:append("params.outMode = PLX_PWM_OUTPUT_MODE_DUAL;")
    end
    c.PreInitCode:append("params.reg.TBPRD = %i;" % {self["prd"]})
    if self.carrier_type == 'triangle' then
      c.PreInitCode:append("params.reg.TBCTL.bit.CTRMODE = %i;" % {2})
    else
      c.PreInitCode:append("params.reg.TBCTL.bit.CTRMODE = %i;" % {0})
    end
    if self["outmode"] ~= '' then
      if self["polarity"] > 0 then
        c.PreInitCode:append("// active state is high")
        c.PreInitCode:append("params.reg.DBCTL.bit.POLSEL = 2;")
      else
        c.PreInitCode:append("// active state is low")
        c.PreInitCode:append("params.reg.DBCTL.bit.POLSEL = 1;")
      end

      for z = 1, 3 do
        if (self.trip_zone_settings[z] == nil) and static['ps_protection'] ~= nil then
          self.trip_zone_settings[z] = static['ps_protection']:getTripZoneMode(z)
        end
        if self.trip_zone_settings[z] == 'cbc' then
          c.PreInitCode:append("params.reg.TZSEL.bit.CBC%i = 1;" % {z})
          c.PreInitCode:append("params.reg.TZSEL.bit.OSHT%i = 0;" % {z})
        elseif self.trip_zone_settings[z] == 'osht' then
          c.PreInitCode:append("params.reg.TZSEL.bit.CBC%i = 0;" % {z})
          c.PreInitCode:append("params.reg.TZSEL.bit.OSHT%i = 1;" % {z})
        else
          c.PreInitCode:append("params.reg.TZSEL.bit.CBC%i = 0;" % {z})
          c.PreInitCode:append("params.reg.TZSEL.bit.OSHT%i = 0;" % {z})
        end
      end

      local tzsafe
      -- OSHT
      if static['ps_protection'] ~= nil then
        if static['ps_protection']:getParameter("force_safe") == true then
          if self["polarity"] > 0 then
            tzsafe = 2
          else
            tzsafe = 1
          end
        else
          tzsafe = 0
        end
      end

      -- CBC
      if (self.cbc_trip ~= nil) and (globals.target.getFamilyPrefix() == '2837x') then
        -- cbc control on 2837x relies on trip zone (as no EPWM_AQ_TRIGGER_EVENT_TRIG_DC_EVTFILT)
        -- must override global setting from powerstage protection block
        if self["polarity"] > 0 then
          tzsafe = 2
        else
          tzsafe = 1
        end
      end

      if tzsafe ~= nil then
        if tzsafe == 2 then
          c.PreInitCode:append("  // force low when tripped")
        elseif tzsafe == 1 then
          c.PreInitCode:append("  // force high when tripped")
        else
          c.PreInitCode:append("  // float output when tripped")
        end
        c.PreInitCode:append("params.reg.TZCTL.bit.TZA = %i;" % {tzsafe})
        c.PreInitCode:append("params.reg.TZCTL.bit.TZB = %i;" % {tzsafe})
      end
    end

    c.PreInitCode:append("PLX_PWM_configure(EpwmHandles[%i], %i, &params);" %
                             {self["instance"], self["epwm"]})

    if self["outmode"] ~= '' and static['ps_protection'] ~= nil then
      c.PostInitCode:append("PLX_PWR_registerPwmChannel(EpwmHandles[%i]);" %
                                {self["instance"]})
    end

    if self["outmode"] ~= '' then
      local dt = math.floor(self["dead_time"] *
                                globals.target.getDeadTimeClock())
      c.PreInitCode:append("// configure deadtime to %e seconds" %
                               {self["dead_time"]})
      c.PreInitCode:append(
          "PLX_PWM_setDeadTimeCounts(EpwmHandles[%i], %i, %i);" %
              {self["instance"], dt, dt})
      if self.cbc_trip == nil then
        if self["sequence"] == 0 then
          c.PreInitCode:append("// PWM sequence starting with passive state")
        else
          c.PreInitCode:append("// PWM sequence starting with active state")
        end
        c.PreInitCode:append("PLX_PWM_setSequence(EpwmHandles[%i], %i);" %
                               {self["instance"], self["sequence"]})
        if self.show_enable == 1 then
          -- If using forcing, configure shadow behavior.
          c.PreInitCode:append("PLX_PWM_prepareSetOutToXTransition(EpwmHandles[%i]);" %
                               {self["instance"]})
        end
      end
    end

    local SOCASEL
    if self["soc_loc"] ~= nil then
      if self["soc_loc"] == 'z' then
        SOCASEL = 1
      elseif self["soc_loc"] == 'p' then
        SOCASEL = 2
      elseif self["soc_loc"] == 'zp' then
        SOCASEL = 3
      end
    end

    local INTSEL
    if self["int_loc"] ~= nil then
      if self.int_loc == 'p' then
        INTSEL = 2
      elseif self.int_loc == 'zp' then
        INTSEL = 3
      else
        INTSEL = 1 -- default value for ETSEL.bit.INTSEL is ET_CTR_ZERO
      end
    end

    c.PreInitCode:append(globals.target.getEpwmSetupCode(self["epwm"], {
      soca_sel = SOCASEL,
      soca_prd = self.soc_prd,
      isr = self.isr,
      int_sel = INTSEL,
      int_prd = self.int_prd,
      sync = self.sync
    }))

    if self["outmode"] ~= '' then
      local trip = globals.target.getTargetParameters().trip_groups
      local trips = ''
      local trip_signal_groups = {}

      if static['ps_protection'] ~= nil then
        trip_signal_groups = static['ps_protection']:getTripSignalGroupModes()
      end

      for grp, _ in pairs(trip_signal_groups) do
        if trips == '' then
          trips = 'EPWM_DC_COMBINATIONAL_TRIPIN%i' % {trip[grp]}
        else
          trips = trips .. '| EPWM_DC_COMBINATIONAL_TRIPIN%i' % {trip[grp]}
        end
      end

      if trips ~= '' then
        c.Include:append('epwm.h')

        local dcCode = [[
        EPWM_setTripZoneDigitalCompareEventCondition(EPWM|<UNIT>|_BASE,
                                                    EPWM_TZ_DC_OUTPUT_A1,
                                                    EPWM_TZ_EVENT_DCXH_HIGH);
        EPWM_enableDigitalCompareTripCombinationInput(EPWM|<UNIT>|_BASE,
                                                     |<TRIPS>|,
                                                     EPWM_DC_TYPE_DCAH);

        EPWM_setDigitalCompareEventSource(EPWM|<UNIT>|_BASE,
                                         EPWM_DC_MODULE_A,
                                         EPWM_DC_EVENT_1,
                                         EPWM_DC_EVENT_SOURCE_ORIG_SIGNAL);

        EPWM_enableTripZoneSignals(EPWM|<UNIT>|_BASE, EPWM_TZ_SIGNAL_DCAEVT1);
        ]]
        dcCode = string.gsub(dcCode, '|<UNIT>|', '%i' % {self["epwm"]})
        dcCode = string.gsub(dcCode, '|<TRIPS>|', '%s' % {trips})
        c.PreInitCode:append(dcCode)
      end

      if self.cbc_trip ~= nil then
        c.Include:append('epwm.h')
        c.Include:append('hrpwm.h')
        local dcCode = [[
		HRPWM_setSyncPulseSource(EPWM|<UNIT>|_BASE, HRPWM_PWMSYNC_SOURCE_ZERO);

        EPWM_setTripZoneDigitalCompareEventCondition(EPWM|<UNIT>|_BASE,
                                                    EPWM_TZ_DC_OUTPUT_B2,
                                                    EPWM_TZ_EVENT_DCXH_HIGH);
        EPWM_enableDigitalCompareTripCombinationInput(EPWM|<UNIT>|_BASE,
                                                     |<TRIPS>|,
                                                     EPWM_DC_TYPE_DCBH);

        EPWM_setDigitalCompareFilterInput(EPWM|<UNIT>|_BASE, EPWM_DC_WINDOW_SOURCE_DCBEVT2);
        EPWM_setDigitalCompareBlankingEvent(EPWM|<UNIT>|_BASE, EPWM_DC_WINDOW_START_TBCTR_ZERO);
        EPWM_setDigitalCompareWindowOffset(EPWM|<UNIT>|_BASE, |<BLANKING_OFFSET>|);
        EPWM_setDigitalCompareWindowLength(EPWM|<UNIT>|_BASE, |<BLANKING_WINDOW>|);
        EPWM_enableDigitalCompareBlankingWindow(EPWM|<UNIT>|_BASE);

        EPWM_setDigitalCompareEventSource(EPWM|<UNIT>|_BASE,
                                         EPWM_DC_MODULE_B,
                                         EPWM_DC_EVENT_2,
                                         EPWM_DC_EVENT_SOURCE_FILT_SIGNAL);

        EPWM_setDigitalCompareEventSyncMode(EPWM|<UNIT>|_BASE,
                                         EPWM_DC_MODULE_B,
                                         EPWM_DC_EVENT_2,
                                         EPWM_DC_EVENT_INPUT_SYNCED);
        ]]
        if globals.target.getFamilyPrefix() == '2837x' then
          -- cbc control on 2837x relies on trip zone (as no EPWM_AQ_TRIGGER_EVENT_TRIG_DC_EVTFILT)
          if self.carrier_type == 'triangle' then
            return "CBC with symmetrical carrier not supported for this device."
          end
          dcCode = dcCode .. [[
            EPWM_enableTripZoneSignals(EPWM|<UNIT>|_BASE, EPWM_TZ_SIGNAL_DCBEVT2);
            EPWM_setActionQualifierAction(EPWM|<UNIT>|_BASE, EPWM_AQ_OUTPUT_A ,
              EPWM_AQ_OUTPUT_HIGH, EPWM_AQ_OUTPUT_ON_TIMEBASE_ZERO);
            EPWM_setActionQualifierAction(EPWM|<UNIT>|_BASE, EPWM_AQ_OUTPUT_A ,
              EPWM_AQ_OUTPUT_LOW, EPWM_AQ_OUTPUT_ON_TIMEBASE_UP_CMPA);
          ]]
        else
          if self.carrier_type == 'triangle' then
            dcCode = dcCode .. [[
              EPWM_setActionQualifierT1TriggerSource(EPWM|<UNIT>|_BASE,
                                             EPWM_AQ_TRIGGER_EVENT_TRIG_DC_EVTFILT);
              EPWM_setActionQualifierAction(EPWM|<UNIT>|_BASE, EPWM_AQ_OUTPUT_A ,
                EPWM_AQ_OUTPUT_HIGH, EPWM_AQ_OUTPUT_ON_TIMEBASE_ZERO);
              EPWM_setActionQualifierAction(EPWM|<UNIT>|_BASE, EPWM_AQ_OUTPUT_A ,
                EPWM_AQ_OUTPUT_LOW, EPWM_AQ_OUTPUT_ON_T1_COUNT_UP);
              EPWM_setActionQualifierAction(EPWM|<UNIT>|_BASE, EPWM_AQ_OUTPUT_A ,
                EPWM_AQ_OUTPUT_LOW, EPWM_AQ_OUTPUT_ON_TIMEBASE_PERIOD);
              EPWM_setActionQualifierAction(EPWM|<UNIT>|_BASE, EPWM_AQ_OUTPUT_A ,
                EPWM_AQ_OUTPUT_HIGH, EPWM_AQ_OUTPUT_ON_T1_COUNT_DOWN);
            ]]
          else
            dcCode = dcCode .. [[
              EPWM_setActionQualifierT1TriggerSource(EPWM|<UNIT>|_BASE,
                                             EPWM_AQ_TRIGGER_EVENT_TRIG_DC_EVTFILT);
              EPWM_setActionQualifierAction(EPWM|<UNIT>|_BASE, EPWM_AQ_OUTPUT_A ,
                EPWM_AQ_OUTPUT_HIGH, EPWM_AQ_OUTPUT_ON_TIMEBASE_ZERO);
              EPWM_setActionQualifierAction(EPWM|<UNIT>|_BASE, EPWM_AQ_OUTPUT_A ,
                EPWM_AQ_OUTPUT_LOW, EPWM_AQ_OUTPUT_ON_T1_COUNT_UP);
              EPWM_setActionQualifierAction(EPWM|<UNIT>|_BASE, EPWM_AQ_OUTPUT_A ,
                EPWM_AQ_OUTPUT_LOW, EPWM_AQ_OUTPUT_ON_TIMEBASE_UP_CMPA);
            ]]
          end
        end
        dcCode = string.gsub(dcCode, '|<UNIT>|', '%i' % {self["epwm"]})
        dcCode = string.gsub(dcCode, '|<TRIPS>|', '%s' % {
          'EPWM_DC_COMBINATIONAL_TRIPIN%i' % {self.cbc_trip.input}})
        blankingWindow = math.floor(self.prd * self.cbc_trip.min_duty + 0.5)
        if blankingWindow < 1 then
          -- this is needed in case of the compare event still beeing active at 
          -- the start of the period
          blankingWindow = 1
        end
        dcCode = string.gsub(dcCode, '|<BLANKING_WINDOW>|', '%i' % {blankingWindow})
        -- to ensure minimal required tz pulse length, the cmpss filter is set to 3 TBCLK (see comp.lua)
        -- we therefore need to start blanking TZ accordingly before the PWM sync pulse
        blankingOffset = self.prd - 4
        dcCode = string.gsub(dcCode, '|<BLANKING_OFFSET>|', '%i' % {blankingOffset})
        c.PreInitCode:append(dcCode)
      end
    end
    c.PreInitCode:append("}")

    return c
  end

  function Epwm:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_pwm.h')
    c.Declarations:append('PLX_PWM_Handle_t EpwmHandles[%i];' %
                              {static.numInstances})
    c.Declarations:append('PLX_PWM_Obj_t EpwmObj[%i];' % {static.numInstances})

    -- see if the model contains a powerstage block
    local powerstage_obj
    for _, b in ipairs(globals.instances) do
      if b:getType() == 'powerstage' then
        powerstage_obj = b
      end
    end

    -- see if the model contains a pil block
    local pil_obj
    for _, b in ipairs(globals.instances) do
      if b:getType() == 'pil' then
        pil_obj = b
      end
    end

    if powerstage_obj == nil then
      if pil_obj ~= nil then
        c.Declarations:append('bool EpwmForceDisable = false;')
      end
      c.Declarations:append('void PLXHAL_PWM_enableAllOutputs(){')
      if pil_obj ~= nil then
        c.Declarations:append('  if(!EpwmForceDisable){')
      end
      for _, bid in pairs(static.instances) do
        local epwm = globals.instances[bid]
        c.Declarations:append('    PLX_PWM_enableOut(EpwmHandles[%i]);' %
                                  epwm:getParameter('instance'))
      end
      if pil_obj ~= nil then
        c.Declarations:append('  }')
      end
      c.Declarations:append('}')
    end

    local code = [[
    {
      PLX_PWM_sinit();
      int i;
      for(i=0; i<%d; i++)
      {
        EpwmHandles[i] = PLX_PWM_init(&EpwmObj[i], sizeof(EpwmObj[i]));
      }
    }
    ]]
    c.PreInitCode:append(code % {static.numInstances})

    for _, bid in pairs(static.instances) do
      local epwm = globals.instances[bid]
      local c = epwm:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    c.TimerSyncCode:append(globals.target.getEpwmTimersSyncCode())

    static.finalized = true
    return c
  end

  return Epwm
end

return Module
