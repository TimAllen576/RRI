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

  local EpwmBasic = require('blocks.block').getBlock(globals)
  EpwmBasic["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function EpwmBasic:checkMaskParameters(env)
    if Block.Mask.sequence == 3 and
        globals.target.getTargetParameters()['epwms']['type'] < 4 then
      return "Sequence port 'seq' not supported by this target (%s)." %
                 {Target.Name}
    end

    if Block.Mask.show_enable == 2 and
        globals.target.getTargetParameters()['epwms']['type'] < 4 then
      return "Enable port 'en' not supported by this target (%s)." %
                 {Target.Name}
    end
  end

  function EpwmBasic:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    local dim = #Block.InputSignal[1]
    if dim == 0 then
      return "At least one PWM must be configured."
    end

    self.first_unit = Block.Mask.pwm[1]
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

    -- polarity
    if Block.Mask.polarity == 1 then
      self.polarity = 1
    else
      self.polarity = -1
    end

    -- sequence
    if Block.Mask.AllowSpecialSequences == 1 then
      -- allow sequences 2&3 for CSI modulation
      self.allow_special_sequences = 1
    end
    if Block.Mask.sequence == 1 then
      self.sequence = 1
    else
      self.sequence = 0
    end

    -- outmode
    if Block.Mask.outmode == 1 then
      self.outmode = 'AB'
    elseif Block.Mask.outmode == 2 then
      self.outmode = 'A'
    else
      self.outmode = ''
    end

    -- show enable
    if Block.Mask.show_enable==1 then
        self.show_enable=0 
    else
        self.show_enable=1 -- Enable port active
    end

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

    self.channels = {}
    for i = 1, dim do
      local pwm = Block.Mask.pwm[i]

      local epwm = self:makeBlock("epwm")

      local syncosel, phsen
      if Block.Mask.EnablePhaseSyncFromDownstream ~= nil then
        -- for R&D only
        if Block.Mask.OverrideSyncoSelVal ~= nil then
          syncosel = Block.Mask.OverrideSyncoSelVal
        else
          syncosel = 0
        end
        phsen = 1
      end
      local error = epwm:createImplicit(pwm, {
        fsw = self.fsw,
        carrier_type = self.carrier_type,
        polarity = self.polarity,
        outmode = self.outmode,
        sequence = self.sequence,
        dead_time = self.dead_time,
        trip_zone_settings = self.trip_zone_settings,
        show_enable = self.show_enable,
        syncosel = syncosel,
        phsen = phsen
      }, Require)

      if type(error) == 'string' then
        return error
      end

      self:logLine('EPWM implicitly created for channel %i, pwm %i.' %
                       {static.numChannels, pwm})

      self.channels[static.numChannels] = epwm

      if Block.Mask.show_enable == 2 then
        OutputCode:append("if((%s) == 0)\n" % {Block.InputSignal[3][i]})
        OutputCode:append("{\n")
        OutputCode:append("  PLXHAL_PWM_setToPassive(%i);" %
                              {epwm:getParameter('instance')})
        OutputCode:append("}\n")
        OutputCode:append("else\n")
      end

      OutputCode:append("{\n")
      if Block.Mask.sequence == 3 then
        OutputCode:append("  PLXHAL_PWM_setSequence(%i, %s);" %
                              {epwm:getParameter('instance'), Block.InputSignal[2][i]})
        if Block.Mask.show_enable == 2 then
          OutputCode:append("  PLXHAL_PWM_prepareSetOutToXTransition(%i);" %
                              {epwm:getParameter('instance')})
        end
      end
      if Block.Mask.show_enable == 2 then
        OutputCode:append("  PLXHAL_PWM_setToOperational(%i);" %
                              {epwm:getParameter('instance')})
      end
      if (type(Block.Mask.delay_scale) == 'number') and (Block.Mask.delay_scale == 2) then
        if string.find(Block.InputSignal[4][i], "UNCONNECTED") then
          return "Blanking time scaling cannot be left unconnected."
        end
        local dt = math.floor(self["dead_time"] *
                                globals.target.getDeadTimeClock())
        OutputCode:append("  PLXHAL_PWM_setScaledDeadTimeCounts(%i, %s, %i);" %
                              {epwm:getParameter('instance'), Block.InputSignal[4][i], dt})
      end
      OutputCode:append("  PLXHAL_PWM_setDuty(%i, %s);" %
                            {epwm:getParameter('instance'), Block.InputSignal[1][i]})
      OutputCode:append("}\n")

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
    
    -- for R&D only
    if Block.Mask.SynchronizationInput ~= nil then
      local synci_top = Block.Mask.SynchronizationInput
      synci_top = synci_top:gsub("%s+", "") -- remove whitespace
      if synci_top:sub(1, #"{synco") ~= "{synco" then
        return
            ("'sycni' port must be connected to the 'sycni' port of another PWM (Variable) block or to the output of an External Sync block.")
      end
      local type = eval(synci_top)["synco"]["type"]
      if type == 'pwm' then
        local upmux = {}
        upmux[1] = 0
        upmux[4] = 1
        upmux[7] = 2
        upmux[10] = 3
        self.channels[self.first_channel]:configureSyncSrc({
          type = type,
          unit = upmux[eval(synci_top)["synco"]["unit"]]
        })
      else
        local gpio = eval(synci_top)["synco"]["unit"]
        local error = globals.target.checkGpioIsValidPwmSync(gpio)
        if error ~= nil then
          return error
        end
        self.channels[self.first_channel]:configureSyncSrc({
          type = type,
          unit = gpio
        })
      end
    end

    return {
      InitCode = InitCode,
      OutputSignal = OutputSignal,
      OutputCode = OutputCode,
      Require = Require,
      UserData = {bid = EpwmBasic:getId()}
    }
  end

  function EpwmBasic:getNonDirectFeedthroughCode()
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
        powerstage_obj:isDeprecated()
        if powerstage_obj:isDeprecated() then
          return 'Please replace deprecated powerstage protection block.'
        else 
          return 'Please enable TZ%i under Coder Options -> Target -> Protections.' % {zone}
        end
      end
    end

    return {Require = Require, UpdateCode = UpdateCode}
  end

  function EpwmBasic:setSinkForTriggerSource(sink)
    if sink ~= nil then
      self:logLine('EpwmBasic connected to %s of %d' % {sink.type, sink.bid})
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

  function EpwmBasic:propagateTriggerSampleTime(ts)
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

  function EpwmBasic:requestImplicitTrigger(ts)
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

  function EpwmBasic:finalizeThis(c)
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

  function EpwmBasic:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_pwm.h')

    c.Declarations:append('extern PLX_PWM_Handle_t EpwmHandles[];')

    c.Declarations:append(
        'void PLXHAL_PWM_setDuty(uint16_t aHandle, float aDuty){')
    c.Declarations:append(
        '  PLX_PWM_setPwmDuty(EpwmHandles[aHandle], aDuty);')
    c.Declarations:append('}')

    c.Declarations:append('void PLXHAL_PWM_setToPassive(uint16_t aChannel){')
    c.Declarations:append(
        '  PLX_PWM_setOutToPassive(EpwmHandles[aChannel]);')
    c.Declarations:append('}')

    c.Declarations:append('void PLXHAL_PWM_setToOperational(uint16_t aChannel){')
    c.Declarations:append(
        '  PLX_PWM_setOutToOperational(EpwmHandles[aChannel]);')
    c.Declarations:append('}')

    c.Declarations:append(
        'void PLXHAL_PWM_setSequence(uint16_t aChannel, uint16_t aSequence){')
    if self.allow_special_sequences then
      c.Declarations:append(
          '  PLX_PWM_setSequence(EpwmHandles[aChannel], aSequence);')
    else
      c.Declarations:append(
          '  PLX_PWM_setSequence(EpwmHandles[aChannel], (aSequence > 0));')
    end
    c.Declarations:append('}')

    c.Declarations:append(
        'void PLXHAL_PWM_prepareSetOutToXTransition(uint16_t aHandle){')
    c.Declarations:append(
        '  PLX_PWM_prepareSetOutToXTransition(EpwmHandles[aHandle]);')
    c.Declarations:append('}')


    local setDeadTimeCode = [==[
    void PLXHAL_PWM_setScaledDeadTimeCounts(uint16_t aChannel, float aScaling, uint16_t aNominalCounts){
        uint16_t scaledCounts = 0;
        if (aScaling > 0){
          scaledCounts = (uint16_t)((float)aNominalCounts * aScaling);
        }
        PLX_PWM_setDeadTimeCounts(EpwmHandles[aChannel], scaledCounts, scaledCounts);
    }
    ]==]
    c.Declarations:append(setDeadTimeCode)

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

  return EpwmBasic
end

return Module
