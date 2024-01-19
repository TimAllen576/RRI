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
  cbc_max_duty = 0.9,
  numInstances = 0,
  numChannels = 0,
  instances = {},
  finalized = nil
}

function Module.getBlock(globals)

  local EpwmPccVar = require('blocks.block').getBlock(globals)
  EpwmPccVar["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function EpwmPccVar:checkMaskParameters(env)
  end

  function EpwmPccVar:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    local num_pwm = Block.Mask.NumPwm
    if num_pwm == 0 then
      return "At least one PWM must be configured."
    end

    local pwm_selected = {}
    if num_pwm == 1 then
      local pwm1 = Block.Mask.PwmUnits1
      if pwm1 == 1 then
        pwm_selected = {1}
      elseif pwm1 == 2 then
        pwm_selected = {4}
      elseif pwm1 == 3 then
        pwm_selected = {7}
      elseif pwm1 == 4 then
        pwm_selected = {10}
      else
        return 'EXCEPTION: Invalid selection.'
      end
    elseif num_pwm == 2 then
      local pwm2 = Block.Mask.PwmUnits2
      if pwm2 == 1 then
        pwm_selected = {1, 2}
      elseif pwm2 == 2 then
        pwm_selected = {4, 5}
      elseif pwm2 == 3 then
        pwm_selected = {7, 8}
      elseif pwm2 == 4 then
        pwm_selected = {10, 11}
      else
        return 'EXCEPTION: Invalid selection.'
      end
    else
      local pwm3 = Block.Mask.PwmUnits3
      if pwm3 == 1 then
        pwm_selected = {1, 2, 3}
      elseif pwm3 == 2 then
        pwm_selected = {4, 5, 6}
      elseif pwm3 == 3 then
        pwm_selected = {7, 8, 9}
      elseif pwm3 == 4 then
        pwm_selected = {10, 11, 12}
      else
        return 'EXCEPTION: Invalid selection.'
      end
    end

    self.first_unit = pwm_selected[1]
    self.last_unit = pwm_selected[num_pwm]
    self.first_channel = static.numChannels
    local task_name = Block.Task["Name"]

    -- carrier
    self.fsw = Block.Mask.CarrierFreq

    if Block.Mask.Type == 1 then
      self.carrier_type = 'sawtooth'
    else
      self.carrier_type = 'triangle'
      return 'Symmetrical carrier not yet supported.'
    end

    local timing = globals.target.getPwmFrequencySettings(self.fsw,
                                                          self.carrier_type)
    self.fsw_actual = timing.freq

    -- accuracy of frequency settings
    if Block.Mask.CarrierFreqTol == 1 then
      local fc_rtol = 1e-6
      local fc_atol = 1
      local tol = self.fsw * fc_rtol
      if tol < fc_atol then
        tol = fc_atol
      end
      local fswError = self.fsw - self.fsw_actual
      if math.abs(fswError) > tol then
        local msg = [[
            Unable to accurately achieve the desired PWM frequency:
            - desired value: %f Hz
            - closest achievable value: %f Hz

            Please modify the frequency setting or change the "Frequency tolerance" parameter.
            You may also adjust the system clock frequency under Coder Options->Target->General.
            ]]
        return msg % {self.fsw, self.fsw_actual}
      end
    end

    self.dead_time = Block.Mask.Delay

    -- task trigger event
    self.int_loc = ''
    if Block.Mask.IntSel == 2 then
      self.int_loc = 'z'
    elseif Block.Mask.IntSel == 3 then
      self.int_loc = 'p'
    elseif Block.Mask.IntSel == 4 then
      if self.carrier_type == 'sawtooth' then
        return "Invalid task trigger event for sawtooth carrier"
      end
      if globals.target.getTargetParameters()['epwms']['type'] == 0 then
        return "Dual task trigger events no supported by this chip."
      end
      self.int_loc = 'zp'
    end

    self.int_prd = 1
    if Block.Mask.IntSelPeriod == Block.Mask.IntSelPeriod then -- checks if not nan
      self.int_prd = Block.Mask.IntSelPeriod
    end

    -- ADC trigger event
    self.soc_loc = ''
    if Block.Mask.SocSel == 2 then
      self.soc_loc = 'z'
    elseif Block.Mask.SocSel == 3 then
      self.soc_loc = 'p'
    elseif Block.Mask.SocSel == 4 then
      if self.carrier_type == 'sawtooth' then
        return "Invalid ADC trigger event for sawtooth carrier"
      end
      if globals.target.getTargetParameters()['epwms']['type'] == 0 then
        return "Dual ADC trigger events no supported by this chip."
      end
      self.soc_loc = 'zp'
    end

    self.soc_prd = 1
    if Block.Mask.SocSelPeriod == Block.Mask.SocSelPeriod then -- checks if not nan
      self.soc_prd = Block.Mask.SocSelPeriod
    end

    -- trip zone (trip generated by digital input)
    self.trip_zone_settings = {}
    for z = 1, 3 do
      if Block.Mask['tz%imode' % {z}] == 2 then
        self.trip_zone_settings[z] = 'cbc'
      elseif Block.Mask['tz%imode' % {z}]  == 3 then
        self.trip_zone_settings[z] = 'osht'
      end
    end
    
    self.channels = {}
    for i = 1, num_pwm do
      local pwm = pwm_selected[i]
      
      -- cycle-cycle limiting
      local sequence = 1
      local comp_obj
      local cbc_trip
      
      if Block.Mask['InputType%i' % {i}] == 3 then
        -- no comparator in use
        cbc_max_duty = Block.Mask['duty%i' % {i}]
        if Block.Mask['Sequence%i' % {i}] == 2 then
          sequence = 0
        end
      else
        local pin
        if Block.Mask['InputType%i' % {i}] == 1 then
            pin = '%s%i' % {
              string.char(64 + Block.Mask['AdcUnit%i' % {i}]),
              Block.Mask['AdcChannel%i' % {i}]
            }
        else
          pin = 'PGA%i' % {Block.Mask['PgaUnit%i' % {i}]}
        end
        -- find comparator associated with selected analog input
        local comps = globals.target.getTargetParameters()['comps']
        if comps == nil then
          return "Analog compare inputs are not supported by this target."
        end
        local comp = comps.positive[pin]
        if comp == nil then
          return "No comparator found for pin %s." % {pin}
        end
        -- find next available trip input
        local tripInput = globals.target.getNextAvailableTripInput()
        if tripInput == nil then
          return "Maximal number of trip inputs exceeded."
        end
        -- calculate ramp decrement value
        local dec = math.ceil(Block.Mask.RampSlope * Block.Mask.SenseGain / (3.3 / 65536 * Target.Variables.sysClkMHz * 1e6))
        local actualRamp = dec / (Block.Mask.SenseGain / (3.3 / 65536 * Target.Variables.sysClkMHz * 1e6))
        self:logLine('DAC decrement set to %i, resulting in ramp of %f A/s, desired was %f A/s.' % {dec, actualRamp, Block.Mask.RampSlope})

        -- create comparator instance
        comp_obj = self:makeBlock('comp')
        comp_obj:createImplicit(comp[1], {
            pin_mux = comp[2],
            trip_in = tripInput,
            ramp = {
              sync_epwm_unit = pwm,
              decrement_val = dec,
              desired_ramp = Block.Mask.RampSlope,
              actual_ramp = actualRamp,
            }
        }, Require)
        local cmp = comp[1]
        local cbc_trip_input = tripInput
        local cbc_min_duty = Block.Mask.LeadingEdgeBlanking * Block.Mask.CarrierFreq
        if cbc_min_duty < 0 then
          cbc_min_duty = 0
        elseif cbc_min_duty >= static.cbc_max_duty then
          return "Excessive leading edge blanking time."
        end
        
        cbc_trip =  {
          input = cbc_trip_input,
          min_duty = cbc_min_duty
        }
      end
    
      -- create and configure epwm instance
      local epwm = self:makeBlock("epwm")
      
      if Block.Mask.OverrideSyncoSelVal ~= nil then
        -- for R&D only
        self.syncosel =  Block.Mask.OverrideSyncoSelVal
      end
      
      -- ouput settings
      local polarity
      if Block.Mask.Polarity == 1 then
        polarity = 1
      else
        polarity = -1
      end
      
      -- outmode
      local outmode
      if Block.Mask.OutMode == 1 then
        outmode = 'AB'
      elseif Block.Mask.OutMode == 2 then
        outmode = 'A'
      else
        outmode = ''
      end

      local error = epwm:createImplicit(pwm, {
        fsw = self.fsw,
        carrier_type = self.carrier_type,
        polarity = polarity,
        outmode = outmode,
        sequence = sequence,
        dead_time = self.dead_time,
        trip_zone_settings = self.trip_zone_settings,
        cbc_trip =  cbc_trip,
      }, Require)

      if type(error) == 'string' then
        return error
      end

      self:logLine('EPWM implicitly created for channel %i, pwm %i.' %
                       {static.numChannels, pwm})

      self.channels[static.numChannels] = {
        epwm_obj = epwm,
        cmp_obj = comp_obj
      }

	  local phase = 0
      if num_pwm > 1 then
        phase = (i-1)*Block.Mask.DeltaPhase
      end
      if Block.Mask.SyncSrc == 2 then
        phase = phase + Block.Mask.Phase0
      end
      local aPhase = '%f' % {phase}
    
      local aFreq = '0.0' -- disables frequency scaling
      if Block.Mask.CarrierFreqVariation ~= 1 then
        aFreq = Block.InputSignal[4][i]
      end
      
      local aDuty
      local aPeak
      if Block.Mask['InputType%i' % {i}] == 3 then
        -- duty control
        aDuty = '%s' % {Block.InputSignal[1][i]}
        aPeak = '0.0'
      else
        -- peak current
        aDuty = '%f' % {static.cbc_max_duty}
        aPeak = '(%s+%f)*%f' % {Block.InputSignal[1][i], 
                            Block.Mask.RampOffset,
                            Block.Mask.SenseGain}
      end
     
      OutputCode:append("PLXHAL_PWM_setDutyFreqPhaseAndPeak(%i, %s, %s, %s, %s);" % {
          static.numChannels, aDuty, aFreq, aPhase, aPeak})
    
      static.numChannels = static.numChannels + 1
    end
    
    if (self.int_loc == '') then
      OutputSignal:append("{}")
    else
      self.modTrigTs = 1 / (self.fsw_actual * #self.int_loc)
      if self.int_prd ~= nil then
        self.modTrigTs = self.modTrigTs * self.int_prd;
      end
      OutputSignal:append("{modtrig = {bid = %i}}" % {self:getId()})
    end

    if (self.soc_loc == '') then
      OutputSignal:append("{}")
    else
      self.adcTrigTs = 1 / (self.fsw_actual * #self.soc_loc)
      if self.soc_prd ~= nil then
        self.adcTrigTs = self.adcTrigTs * self.soc_prd;
      end
      OutputSignal:append("{adctrig = {bid = %i}}" % {self:getId()})
    end

    -- synchronization
    self.is_self_synchonized = (Block.Mask.SyncSrc == 1)
    OutputSignal:append("{synco = {bid = %i}}" % {EpwmVar:getId()})

    return {
      InitCode = InitCode,
      OutputSignal = OutputSignal,
      OutputCode = OutputCode,
      Require = Require,
      UserData = {bid = EpwmPccVar:getId()}
    }
  end

  function EpwmPccVar:getNonDirectFeedthroughCode()
    local Require = ResourceList:new()
    local UpdateCode = StringList:new()

    local enableCode = self.channels[self.first_channel].epwm_obj:getEnableCode()
    if enableCode ~= nil then
      UpdateCode:append(enableCode)
    end

    local powerstage_obj
    for _, b in ipairs(globals.instances) do
      if b:getType() == 'powerstage' then
        powerstage_obj = b
        break
      end
    end
    
    for zone, _ in pairs(self.trip_zone_settings) do
      if powerstage_obj == nil then
        return
            'TZ%i protection requires the use of a Powerstage Protection block.' %
                {zone}
      end
      if not powerstage_obj:isTripZoneConfigured(zone) then
        if powerstage_obj:isDeprecated() then
          return 'Please replace deprecated powerstage protection block.'
        else 
          return 'Please enable TZ%i under Coder Options -> Target -> Protections.' % {zone}
        end
      end
    end
    
    -- construct synchronized ePWM chain
    local individualSync = (globals.target.getTargetParameters()['epwms']['sync_group_size'] == 1)
    if self.is_self_synchonized then
      for c,p in pairs(self.channels) do
        if c == self.first_channel then
          -- first ePWM is chain is self-triggered and must provide SYNCO
          local synco_sel
          if individualSync then 
            synco_sel = 2 -- ZEROEN
          else
            synco_sel = 1 -- TB_CTR_ZERO
          end
          self.channels[c]:configureSync({
            synco_sel = synco_sel,
            phsen = 0
          })
        else
          -- other modulators are in 'flow-through'
          local synci_sel
          if individualSync then
              -- 'flow-through' must be emulated
              synci_sel = globals.target.getPwmSyncInSel({
                epwm = p['epwm'],
                type = 'epwm',
                source_unit = self.first_unit
              })
              if type(synci_sel) == 'string' then
                return synci_sel
              end
          end
          self.channels[c]:configureSync({
            synco_sel = 0, -- TB_SYNC_IN / NONE
            phsen = 1,
            synci_sel = synci_sel
          })
        end
      end
    else
      -- configure external synchronization source
      local synci_top = Block.InputSignal[3][1]
      synci_top = synci_top:gsub("%s+", "") -- remove whitespace
      if synci_top:sub(1, #"{synco") ~= "{synco" then
        return
            ("'sycni' port must be connected to the sync port of another PWM block or to the output of an External Sync block.")
      end
      
      local trig = eval(synci_top)['synco']
      if trig['bid'] == nil then
        error('Malformed trigger expression: %s' % {synci_top})
      end
      
      local synctype, source_unit, source_last_unit
      local syncBlockType = globals.instances[trig['bid']]:getType()
      if syncBlockType == 'extsync' then
        synctype = 'external'
        source_unit = globals.instances[trig['bid']]:getParameter('unit')
      elseif syncBlockType == 'epwm_var' then
        if individualSync then
           if not globals.instances[trig['bid']]:getParameter('is_self_synchonized') then
             return [[
               Synchronization flow-through not supported by this target.
               Please connect synchronization input directly to synchronization origin.
             ]]
           end
        end
        synctype = 'epwm'
        source_unit = globals.instances[trig['bid']]:getParameter('first_unit')
        source_last_unit = globals.instances[trig['bid']]:getParameter('last_unit')
      else
        error('Unsupported synchronization block: %s.' % {synctype})
      end
      
      local synci_sel_first = globals.target.getPwmSyncInSel({
        epwm = self.first_unit,
        type = synctype,
        source_unit = source_unit,
        source_last_unit = source_last_unit
      })
      if type(synci_sel_first) == 'string' then
        return synci_sel_first
      end
      for c,p in pairs(self.channels) do
        if (c == self.first_channel) or individualSync then
          -- first ePWM is chain is externally triggered and must provide SYNCO
          self.channels[c]:configureSync({
            synco_sel = 0, -- TB_SYNC_IN / NONE
            synci_sel = synci_sel_first,
            phsen = 1,
          })
        else
          -- other modulators are in 'flow through'
          self.channels[c]:configureSync({
            synco_sel = 0, -- TB_SYNC_IN / NONE
            phsen = 1
          })
        end
      end
    end

    return {Require = Require, UpdateCode = UpdateCode}
  end

  function EpwmPccVar:setSinkForTriggerSource(sink)
    if sink ~= nil then
      self:logLine('EpwmPccVar connected to %s of %d' % {sink.type, sink.bid})
      if self[sink.type] == nil then
        self[sink.type] = {}
      end
      if sink.type == 'modtrig' then
       local b = globals.instances[sink.bid]
        local isr
        if b:getType() == 'tasktrigger' then
          isr = '%s_baseTaskInterrupt' % {Target.Variables.BASE_NAME}
          self:logLine('Providing Task trigger')
        else
          -- CLA trigger
        end
         self.channels[self.first_channel]:configureInterruptEvents({
          int_prd = self.int_prd,
          int_loc = self.int_loc,
          isr = isr
        })
      end
      if sink.type == 'adctrig' then
        self:logLine('Providing ADC trigger')
        self.channels[self.first_channel].epwm_obj:configureSocEvents({
          soc_prd = self.soc_prd,
          soc_loc = self.soc_loc
        })
      end
      table.insert(self[sink.type], globals.instances[sink.bid])
    end
  end

  function EpwmPccVar:propagateTriggerSampleTime(ts)
    if self['modtrig'] ~= nil then
      for _, b in ipairs(self['modtrig']) do
        local f = b:propagateTriggerSampleTime(self.modTrigTs)
      end
    end
    if self['adctrig'] ~= nil then
      for _, b in ipairs(self['adctrig']) do
        local f = b:propagateTriggerSampleTime(self.adcTrigTs)
      end
    end
  end

  function EpwmPccVar:requestImplicitTrigger(ts)
    if self.modTrigTs == nil then
      -- offer best fit
      if self.soc_loc ~= '' then
        self.int_loc = self.soc_loc
        self.int_prd = self.soc_prd
      else
        self.int_loc = 'z'
        local pwmTs = 1 / (self.fsw_actual * #self.int_loc)
        self.int_prd = math.max(1, math.floor(ts / pwmTs + 0.5))
        self.int_prd = math.min(self.int_prd, globals.target
                                    .getTargetParameters()['epwms']['max_event_period'])
      end
      self.modTrigTs = 1 / (self.fsw_actual * #self.int_loc) * self.int_prd
    end
    if self.adcTrigTs == nil then
      -- same as interrupt
      self.soc_prd = self.int_prd
      self.soc_loc = self.int_loc
      self.adcTrigTs = self.modTrigTs
    end
    self:logLine('Offered trigger generator at %f Hz' % {1 / self.modTrigTs})
    return self.modTrigTs
  end

  function EpwmPccVar:finalizeThis(c)
    local isModTrigger = false
    if self['modtrig'] ~= nil then
      for _, b in ipairs(self['modtrig']) do
        if b:getType() == 'tasktrigger' then
          isModTrigger = true
          break
        end
      end
    end

    if isModTrigger == true then
      itFunction = [[
      interrupt void %s_baseTaskInterrupt(void)
      {
        EPwm%iRegs.ETCLR.bit.INT = 1;  // clear INT flag for this timer
        PieCtrlRegs.PIEACK.all = PIEACK_GROUP3; // acknowledge interrupt to PIE
    	IER |= M_INT3;
        DISPR_dispatch();
      }
      ]]
      c.Declarations:append("%s\n" %
                                {
            itFunction % {Target.Variables.BASE_NAME, self.first_unit}
          })
      c.InterruptEnableCode:append('IER |= M_INT3;')
    end

    return c
  end

  function EpwmPccVar:finalize(c)
    if static.finalized ~= nil then
      return {}
    end
    
    -- generate lookup tables for epwm and comp handles
    local epwmMap = {}
    local cmpMap = {}
    for _, bid in pairs(static.instances) do
      local basic_epwm = globals.instances[bid]
      for channel, m in pairs(basic_epwm:getParameter('channels')) do
        epwmMap[channel] = m.epwm_obj:getParameter('instance')
        if m.cmp_obj ~= nil then
          cmpMap[channel] = m.cmp_obj:getParameter('comp')
        end
      end
    end
    
    c.Declarations:append('const uint16_t EpwmVarPccLookup[%d] = {' %
                              {static.numChannels})
    local lookupS = ''
    for i = 1, static.numChannels do
      if i < static.numChannels then
        lookupS = lookupS .. '%d,' % {epwmMap[i - 1]}
      else
        lookupS = lookupS .. '%d' % {epwmMap[i - 1]}
      end
    end
    c.Declarations:append('%s' % {lookupS})
    c.Declarations:append('};')

    c.Declarations:append('const uint32_t EpwmVarPccCmpssLookup[%d] = {' %
                              {static.numChannels})
	lookupS = ''
    for i = 1, static.numChannels do
      local cmp = '0'
      if cmpMap[i - 1] ~= nil then
        cmp = 'CMPSS%i_BASE' % {cmpMap[i - 1]}
      end
      if i < static.numChannels then
        lookupS = lookupS .. '%s, ' % {cmp}
      else
        lookupS = lookupS .. '%s' % {cmp}
      end
    end
    c.Declarations:append('%s' % {lookupS})
    c.Declarations:append('};')
    
    c.Include:append('plx_pwm.h')

    c.Declarations:append('extern PLX_PWM_Handle_t EpwmHandles[];')

    local setPeakCurrentCode = [==[
      void PLXHAL_PWM_setDutyFreqPhaseAndPeak(uint16_t aHandle, float aDuty, float aFreqScaling, float aPhase, float aPeak){
        {
          uint32_t base = EpwmVarPccCmpssLookup[aHandle];
          if (base != 0)
          {
            float val = 65536.0 / 3.3 * aPeak;
            uint32_t valInt = 0;
            if (val > 0xFFFFFFFF)
            {
                valInt = 0xFFFFFFFF;
            }
            else if (val > 0)
            {
                valInt = (uint32_t)val;
            }
            if (valInt > 0xFFFF)
            {
                uint16_t decVal =  CMPSS_getRampDecValue(base);
                if(decVal != 0)
                {
                    uint32_t rampDelay = (valInt-0xFFFF)/decVal;
                    if (rampDelay > 0x1FFF)
                    {
                        rampDelay = 0x1FFF;
                    }
                    CMPSS_setRampDelayValue(base, (uint16_t)rampDelay);
                }
                valInt = 0xFFFF;
            }
            else
            {
            	 CMPSS_setRampDelayValue(base, 0x0000);     
            }
            CMPSS_setMaxRampValue(base, ((uint16_t)valInt));
          }
        }
        {
          PLX_PWM_Handle_t handle = EpwmHandles[EpwmVarPccLookup[aHandle]];
          if((aFreqScaling > (1.0/65536.0)) && (aFreqScaling < 65536.0))
          {
            PLX_PWM_scalePeriod(handle, 1.0/aFreqScaling);
          }
          PLX_PWM_setPhase(handle, aPhase);
          if(aPeak <= 0)
          {
            PLX_PWM_setPwmDuty(handle, 0);
          }
          else
          {
            PLX_PWM_setPwmDuty(handle, aDuty);
          }
        }
      }
    ]==]
    c.Declarations:append(setPeakCurrentCode)

    for _, bid in pairs(static.instances) do
      local epwm = globals.instances[bid]
      local c = epwm:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return EpwmPccVar
end

return Module
