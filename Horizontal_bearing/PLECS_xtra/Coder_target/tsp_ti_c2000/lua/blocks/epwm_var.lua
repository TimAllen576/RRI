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
  numChannels = 0,
  instances = {},
  finalized = nil
}

function Module.getBlock(globals)

  local EpwmVar = require('blocks.block').getBlock(globals)
  EpwmVar["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function EpwmVar:checkMaskParameters(env)
  end

  function EpwmVar:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    local num_pwm = Block.Mask.num_pwm
    if num_pwm == 0 then
      return "At least one PWM must be configured."
    end

    local pwm_selected = {}
    if num_pwm == 1 then
      local pwm1 = Block.Mask.pwm_1
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
      local pwm2 = Block.Mask.pwm_2
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
      local pwm3 = Block.Mask.pwm_3
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
    self.fsw = Block.Mask.fc

    if Block.Mask.type == 1 then
      self.carrier_type = 'sawtooth'
    else
      self.carrier_type = 'triangle'
    end

    local timing = globals.target.getPwmFrequencySettings(self.fsw,
                                                          self.carrier_type)
    self.fsw_actual = timing.freq

    -- accuracy of frequency settings
    if Block.Mask.fc_tol == 1 then
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

    self.dead_time = Block.Mask.delay

    -- task trigger event
    self.int_loc = ''
    if Block.Mask.intsel == 2 then
      self.int_loc = 'z'
    elseif Block.Mask.intsel == 3 then
      self.int_loc = 'p'
    elseif Block.Mask.intsel == 4 then
      if self.carrier_type == 'sawtooth' then
        return "Invalid task trigger event for sawtooth carrier"
      end
      if globals.target.getTargetParameters()['epwms']['type'] == 0 then
        return "Dual task trigger events no supported by this chip."
      end
      self.int_loc = 'zp'
    end

    self.int_prd = 1
    if Block.Mask.intsel_prd == Block.Mask.intsel_prd then -- checks if not nan
      self.int_prd = Block.Mask.intsel_prd
    end

    -- ADC trigger event
    self.soc_loc = ''
    if Block.Mask.socsel == 2 then
      self.soc_loc = 'z'
    elseif Block.Mask.socsel == 3 then
      self.soc_loc = 'p'
    elseif Block.Mask.socsel == 4 then
      if self.carrier_type == 'sawtooth' then
        return "Invalid ADC trigger event for sawtooth carrier"
      end
      if globals.target.getTargetParameters()['epwms']['type'] == 0 then
        return "Dual ADC trigger events no supported by this chip."
      end
      self.soc_loc = 'zp'
    end

    self.soc_prd = 1
    if Block.Mask.socsel_prd == Block.Mask.socsel_prd then -- checks if not nan
      self.soc_prd = Block.Mask.socsel_prd
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
    
    -- check to deal with limitations of older MCUs
    if (globals.target.getFamilyPrefix() == '2833x') or (globals.target.getFamilyPrefix() == '2806x') then
      if Block.Mask.fvar == 2 then
        for i = 1, num_pwm do
          phStr = Block.InputSignal[2][i]
          if not string.find(phStr, "UNCONNECTED") then
            if string.sub(phStr, -1, -1) == 'f' then
              phStr = string.sub(phStr, 1, -2);
            end
            ph = tonumber(phStr)
            if (ph == nil) or (ph ~= 0) then
             return [[
              This MCU does not support phase shifting combined with variable frequency operation.
              Please disable variable frequency or leave the ph' port disconnected.]]
            end
          end
        end
      end
    end
    
    self.channels = {}
    for i = 1, num_pwm do
      local pwm = pwm_selected[i]

      local epwm = self:makeBlock("epwm")
      
      -- ouput settings
      local polarity
	  if Block.Mask.polarity == 1 then
	    polarity = 1
	  else
	    polarity = -1
	  end
	  
	  local sequence = 1
	  local outmode = 'AB'

      local error = epwm:createImplicit(pwm, {
        fsw = self.fsw,
        carrier_type = self.carrier_type,
        polarity = polarity,
        outmode = outmode,
        sequence = sequence,
        dead_time = self.dead_time,
        trip_zone_settings = self.trip_zone_settings,
      }, Require)

      if type(error) == 'string' then
        return error
      end

      self:logLine('EPWM implicitly created for channel %i, pwm %i.' %
                       {static.numChannels, pwm})

      self.channels[static.numChannels] = epwm

      if Block.Mask.fvar == 1 then
        OutputCode:append("PLXHAL_PWM_setDutyFreqPhase(%i, %s, %s, %s);" %
                              {
              epwm:getParameter('instance'), Block.InputSignal[1][i], '1.0',
              Block.InputSignal[2][i]
            })
      else
        OutputCode:append("PLXHAL_PWM_setDutyFreqPhase(%i, %s, %s, %s);" % {
          epwm:getParameter('instance'), Block.InputSignal[1][i], Block.InputSignal[4][1],
          Block.InputSignal[2][i]
        })
      end
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
    self.is_self_synchonized = (Block.Mask.sync_src == 1)
    OutputSignal:append("{synco = {bid = %i}}" % {EpwmVar:getId()})
    
    return {
      InitCode = InitCode,
      OutputSignal = OutputSignal,
      OutputCode = OutputCode,
      Require = Require,
      UserData = {bid = EpwmVar:getId()}
    }
  end

  function EpwmVar:getNonDirectFeedthroughCode()
    local Require = ResourceList:new()
    local UpdateCode = StringList:new()

    local enableCode = self.channels[self.first_channel]:getEnableCode()
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

  function EpwmVar:setSinkForTriggerSource(sink)
    if sink ~= nil then
      self:logLine('EpwmVar connected to %s of %d' % {sink.type, sink.bid})
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
        self.channels[self.first_channel]:configureSocEvents({
          soc_prd = self.soc_prd,
          soc_loc = self.soc_loc
        })
      end
      table.insert(self[sink.type], globals.instances[sink.bid])
    end
  end

  function EpwmVar:propagateTriggerSampleTime(ts)
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

  function EpwmVar:requestImplicitTrigger(ts)
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

  function EpwmVar:finalizeThis(c)
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

  function EpwmVar:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_pwm.h')

    c.Declarations:append('extern PLX_PWM_Handle_t EpwmHandles[];')

    local code = [==[
	void PLXHAL_PWM_setDutyFreqPhase(uint16_t aChannel, float aDuty, float aFreqScaling, float aPhase)
	{
	    if((aFreqScaling <= (1.0/65536.0)) || (aFreqScaling > 65536.0))
	    {
	        return; // silent user error better than assert
	    }
		PLX_PWM_Handle_t handle = EpwmHandles[aChannel];
	    PLX_PWM_scalePeriod(handle, 1.0/aFreqScaling);
	    PLX_PWM_setPhase(handle, aPhase);
	    PLX_PWM_setPwmDuty(handle, aDuty);
	}
    ]==]
    c.Declarations:append(code)

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

  return EpwmVar
end

return Module
