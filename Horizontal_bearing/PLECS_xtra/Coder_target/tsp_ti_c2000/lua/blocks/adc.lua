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
local Module = {}

local static = {numInstances = 0, instances = {}, finalized = nil}

function Module.getBlock(globals)

  local Adc = require('blocks.block').getBlock(globals)
  Adc["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Adc:setImplicitTriggerSource(bid)
    self['trig_base_task_exp'] = "{adctrig = {bid = %i}}" % {bid}
  end

  function Adc:checkMaskParameters(env)
  end

  function Adc:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()
    local TriggerOutputSignal = StringList:new()

    self.adc = Block.Mask.adc[1] - 1
    static.instances[self.adc] = self.bid

    local adcId = 'ADC%s' % {string.char(65 + self.adc)}

    -- triggered
    self.num_channels = Block.NumOutputSignals[1]
    self.channels = {}
    self.totalConversionTimeInAcqps = 0

    if self.num_channels >
        globals.target.getTargetParameters()['adcs']['num_channels'] then
      return 'Maximal number of conversions exceeded.'
    end

    --single-ended vs. differential signaling.
    self.sigmode = Block.Mask.sigmode
    if Block.Mask.sigmode == nil then
      self.sigmode=1 --single ended by default
    end

    local adcType = globals.target.getTargetParameters()['adcs']['type'] 
    if (self.sigmode>1) and (adcType ~=4) then
        return 'This chip does not support differential ADC configurations.'
    end


    for i = 1, self.num_channels do
      Require:add('%s-SOC' % {adcId}, i - 1)

      local input = Block.Mask.input[i]
      if input > 15 then
        return "AIN%i is not a valid input for for %s." % {input, adcId}
      end

      local ts = 0
      if Block.Mask.tacqsel ~= 1 then
        ts = globals.utils.getFromArrayOrScalar(Block.Mask.ts, i,
                                                      self.num_channels)
        if ts == nil then
          return "Invalid width of parameter 'sample & hold time'."
        end
      end
      local ACQPS = globals.target.calcACQPS(ts,self.sigmode)
      self.totalConversionTimeInAcqps = self.totalConversionTimeInAcqps + ACQPS

      local scale = globals.utils.getFromArrayOrScalar(Block.Mask.scale, i,
                                                       self.num_channels)
      if scale == nil then
        return "Invalid width of parameter 'scale'."
      end

      local offset = globals.utils.getFromArrayOrScalar(Block.Mask.offset, i,
                                                        self.num_channels)
      if offset == nil then
        return "Invalid width of parameter 'offset'."
      end

      self.channels[i] = {
        input = input,
        port = port,
        scale = scale,
        offset = offset,
        ACQPS = ACQPS
      }
      OutputSignal:append("PLXHAL_ADC_getIn(%i, %i)" % {self.instance, i - 1})
    end

    TriggerOutputSignal:append("{modtrig = {bid = %i}}" % {Adc:getId()})
    
    globals.syscfg:addEntry('adc', {
      unit = string.char(65 + self.adc),
    })
	Require:add('ADC %s' % {string.char(65 + self.adc)})

    return {
      InitCode = InitCode,
      OutputSignal = {OutputSignal, TriggerOutputSignal},
      Require = Require,
      UserData = {bid = Adc:getId()}
    }
  end

  function Adc:getNonDirectFeedthroughCode()
    local trig = Block.InputSignal[1][1]

    if Block.Mask.TrigSrc == 1 or string.find(trig, "UNCONNECTED") then
      -- not connected - will have to use implicit trigger
    else
      -- verify proper connection of trigger point
      trig = trig:gsub("%s+", "") -- remove whitespace
      if trig:sub(1, #"{adctrig") ~= "{adctrig" then
        return ("Trigger port must be connected to ADC Trigger source.")
      end

      self['trig_exp'] = trig
    end

    return {}
  end

  function Adc:setSinkForTriggerSource(sink)
    if self.num_channels == 0 then
      -- this block is not triggered and does not provide a trigger
      return
    end

    if self['trig_exp'] == nil then
      self['trig_exp'] = self['trig_base_task_exp']
    end

    local trig = eval(self['trig_exp'])['adctrig']
    local triggerBlock = globals.instances[trig['bid']]
    self['trig'] = triggerBlock

    if sink ~= nil then
      if self[sink.type] == nil then
        self[sink.type] = {}
      end
      table.insert(self[sink.type], globals.instances[sink.bid])
    end

    if self.downstreamConnectionsPropagated == nil then
      -- top of chain
      if self['trig'] ~= nil then
        self['trig']:setSinkForTriggerSource({type = 'adctrig', bid = self.bid})
      end
      self.downstreamConnectionsPropagated = true;
    end
  end

  function Adc:propagateTriggerSampleTime(ts)
    if ts ~= nil then
      self['ts'] = ts
      if self['modtrig'] ~= nil then
        for _, b in ipairs(self['modtrig']) do
          local f = b:propagateTriggerSampleTime(ts)
        end
      end
    end
  end

  function Adc:getTriggerSampleTime()
    return self['ts']
  end

  function Adc:finalizeThis(c)
    if self['trig'] == nil then
      return 'No trigger source configured for ADC'
    end

    local TRIGSEL, trigSelText
    if self.trig:getType() == 'timer' then
      local unit = self.trig:getParameter('unit')
      TRIGSEL = 1
      trigSelText = "CPU Timer%i" % {unit}
    elseif (self.trig:getType() == 'epwm_basic') or
        (self.trig:getType() == 'epwm_var') or 
        (self.trig:getType() == 'epwm_basic_pcc') or 
        (self.trig:getType() == 'epwm_var_pcc') then
      local unit = self.trig:getParameter('first_unit')
      TRIGSEL = 5 + 2 * (unit - 1)
      trigSelText = "PWM%i" % {unit}
    else
      return 'ADC can only be triggered by a PWM or Timer block.'
    end

    -- determine if this block is supplying the actual base task trigger
    -- and/or triggering a CLA
    self['is_mod_trigger'] = false
    self['is_cla_trigger'] = false
    if self['modtrig'] ~= nil then
      for _, b in ipairs(self['modtrig']) do
        if b:getType() == 'tasktrigger' then
          self['is_mod_trigger'] = true
        elseif b:getType() == 'cla' then
          self['is_cla_trigger'] = true
        end
      end
    end

    c.PreInitCode:append(" // configure ADC %s\n" % {string.char(65 + self.adc)})
    c.PreInitCode:append('{')
    c.PreInitCode:append("PLX_AIN_AdcParams_t params;")
    c.PreInitCode:append("PLX_AIN_setDefaultAdcParams(&params);")
    if (globals.target.getTargetParameters()['adcs']['type']==4) and (self["sigmode"]>1) then
      c.PreInitCode:append("params.sigmode=%i;" % {self["sigmode"]})
    end
    c.PreInitCode:append(
        "PLX_AIN_configure(AdcHandles[%i], (PLX_AIN_Unit_t)%i, &params);" %
            {self.instance, self.adc})
    if self['is_mod_trigger'] or self['is_cla_trigger'] then
      local isr
      if self['is_mod_trigger'] then
        isr = '%s_baseTaskInterrupt' % {Target.Variables.BASE_NAME}
      end
      c.PreInitCode:append(globals.target.getAdcSetupCode(self.adc, {
        isr = isr,
        INT1SEL = self.num_channels - 1,
        trig_is_timer = (TRIGSEL == 1)
      }))
    end
    c.PreInitCode:append('}')

    for soc, p in ipairs(self.channels) do
      c.PreInitCode:append(" // configure SOC%i of ADC-%s to measure ADCIN%i" %
                               {soc, string.char(65 + self.adc), p["input"]})
      c.PreInitCode:append("{\n")
      c.PreInitCode:append("  PLX_AIN_ChannelParams_t params;")
      c.PreInitCode:append("  PLX_AIN_setDefaultChannelParams(&params);")
      c.PreInitCode:append("  params.scale=  %.9ef;" % {p["scale"]})
      c.PreInitCode:append("  params.offset= %.9ef;" % {p["offset"]})
      if globals.target.getTargetParameters()['adcs']['type'] == 2 then
        c.PreInitCode:append("  params.trigsel = %i;" % {TRIGSEL})
      else
        c.PreInitCode:append("  // set SOC trigger to %s" % {trigSelText})
        c.PreInitCode:append("  params.ADCSOCxCTL.bit.TRIGSEL = %i;" % {TRIGSEL})
        c.PreInitCode:append("  params.ADCSOCxCTL.bit.ACQPS = %i;" %
                                 {p["ACQPS"]})
      end
      c.PreInitCode:append(
          "  PLX_AIN_setupChannel(AdcHandles[%i], %i, %i, &params);" %
              {self.instance, soc - 1, p["input"]})
      c.PreInitCode:append("}\n")
    end

    if self['is_mod_trigger'] then
      itFunction = [[
      interrupt void %s_baseTaskInterrupt(void)
      {
	    %s
        DISPR_dispatch();
      }
      ]]
      acknCode = globals.target.getAdcInterruptAcknCode(self.adc, {
        trig_is_timer = (TRIGSEL == 1)
      })
      c.Declarations:append("%s\n" %
                                {
            itFunction % {Target.Variables.BASE_NAME, acknCode}
          })
      c.InterruptEnableCode:append('IER |= M_INT1;')
    end

    return c
  end

  function Adc:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_ain.h')
    c.Declarations:append('PLX_AIN_Handle_t AdcHandles[%i];' %
                              {static.numInstances})
    c.Declarations:append('PLX_AIN_Obj_t AdcObj[%i];' % {static.numInstances})

    c.Declarations:append(
        'float PLXHAL_ADC_getIn(uint16_t aHandle, uint16_t aChannel){')
    c.Declarations:append(
        '  return PLX_AIN_getInF(AdcHandles[aHandle], aChannel);')
    c.Declarations:append('}')

    local code = [[
    {
      PLX_AIN_sinit(%f, %i);
      int i;
      for(i=0; i<%d; i++)
      {
        AdcHandles[i] = PLX_AIN_init(&AdcObj[i], sizeof(AdcObj[i]));
      }
    }
    ]]
    c.PreInitCode:append(code % {
      globals.target.getTargetParameters()['adcs']['vref'],
      Target.Variables.sysClkMHz * 1e6, static.numInstances
    })

    for _, bid in pairs(static.instances) do
      local adc = globals.instances[bid]
      local c = adc:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  function Adc:registerTriggerRequest(trig)
    print('Adc received trigger request: ' .. dump(trig))
    Adc:propagateTriggers()
  end

  function Adc:getTriggerSampleTime()
    if self.num_channels == 0 then
      -- this block is not triggered and does not provide a trigger
      return 0
    end
    return self['ts']
  end

  function Adc:getTotalConversionTime()
    return self.totalConversionTimeInAcqps
  end

  return Adc
end

return Module
