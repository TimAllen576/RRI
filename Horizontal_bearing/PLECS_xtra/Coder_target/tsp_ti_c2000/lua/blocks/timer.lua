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

local static = {
  numInstances = 0,
  unitsAllocated = {},
  instances = {},
  finalized = nil
}

function Module.getBlock(globals)

  local Timer = require('blocks.block').getBlock(globals)
  Timer["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Timer:AllocateUnit()
    local units = globals.target.getTargetParameters()['cpu_timers']
    for k, v in pairs(units) do
      if static.unitsAllocated[k] == nil then
        table.insert(static.unitsAllocated, v)
        return v
      end
    end
  end

  function Timer:createImplicit(params)
    self.unit = Timer:AllocateUnit()
    if self.unit == nil then
      return 'Unable to allocate CpuTimer.'
    end
    self.period = math.max(1, math.floor(
                               globals.target.getTimerClock() / params['f'] +
                                   0.5))
    if self.period > 0x100000000 then
      return
          "Unable to achieve the desired timer frequency (%f Hz is too low)." %
              {f}
    end
    self.frequency = globals.target.getTimerClock() / self.period
    static.instances[self.unit] = self.bid
    self:logLine('CPUTIMER%i implicitly created.' % {self.unit})
  end

  function Timer:checkMaskParameters(env)
    if not env.utils.isPositiveScalar(Block.Mask.f) then
      return 'Timer frequency [Hz]" must be a positive real scalar value.'
    end
  end

  function Timer:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputCode = StringList:new()
    local OutputSignal = StringList:new()

    self.unit = Timer:AllocateUnit()
    if self.unit == nil then
      return "No spare timer available."
    end
    -- important: finalize code assumes timer 0
    if self.unit ~= 0 then
      -- important: timer 0 is assumed in finalize call
      return "Only CPUTimer 0 is currently supported."
    end
    static.instances[self.unit] = self.bid

    Require:add('CPUTIMER', self.unit)

    -- accuracy of frequency settings
    local f = Block.Mask.f
    local f_rtol, f_atol
    if Block.Mask.f_tol == 1 then
      f_rtol = 1e-6
      f_atol = 1
    end

    local period = math.max(1, math.floor(
                                globals.target.getTimerClock() / f + 0.5))
    if period > 0x100000000 then
      return
          "Unable to achieve the desired timer frequency (%f Hz is too low)." %
              {f}
    end

    local achievableF = globals.target.getTimerClock() / period
    if (f_rtol ~= nil) and (f_atol ~= nil) then
      tol = f * f_rtol
      if tol < f_atol then
        tol = f_atol
      end
      local fError = f - achievableF
      if math.abs(fError) > tol then
        local msg = [[
            Unable to accurately achieve the desired timer frequency:
            - desired value: %f Hz
            - closest achievable value: %f Hz

            Please modify the frequency setting or change the "Frequency tolerance" parameter.
            You may also adjust the system clock frequency under Coder Options->Target->General.
            ]]
        return msg % {f, achievableF}
      end
    end
    self['frequency'] = achievableF
    self['period'] = period

    OutputSignal:append("{modtrig = {bid = %i}}" % {Timer:getId()})
    OutputSignal:append("{adctrig = {bid = %i}}" % {Timer:getId()})

    return {
      InitCode = InitCode,
      OutputCode = OutputCode,
      OutputSignal = OutputSignal,
      Require = Require,
      UserData = {bid = Timer:getId()}
    }
  end

  function Timer:getNonDirectFeedthroughCode()
    return {}
  end

  function Timer:setSinkForTriggerSource(sink)
    if sink ~= nil then
      --print('Timer connected to %s of %d' % {sink.type, sink.bid})
      if self[sink.type] == nil then
        self[sink.type] = {}
      end
      table.insert(self[sink.type], globals.instances[sink.bid])
    end
  end

  function Timer:propagateTriggerSampleTime(ts)
    if self['modtrig'] ~= nil then
      for _, b in ipairs(self['modtrig']) do
        local f = b:propagateTriggerSampleTime(1 / self['frequency'])
      end
    end
    if self['adctrig'] ~= nil then
      for _, b in ipairs(self['adctrig']) do
        local f = b:propagateTriggerSampleTime(1 / self['frequency'])
      end
    end
  end

  function Timer:requestImplicitTrigger(ts)
    local achievableTs = 1 / self['frequency']
    self:logLine('Offered trigger generator at %f Hz' % {1 / achievableTs})
    return achievableTs
  end

  function Timer:finalizeThis(c)
    local isModTrigger = false
    if self['modtrig'] ~= nil then
      for _, b in ipairs(self['modtrig']) do
        if b:getType() == 'tasktrigger' then
          isModTrigger = true
          break
        end
      end
    end

    c.PreInitCode:append('{')
    local isr
    if isModTrigger then
      isr = '%s_baseTaskInterrupt' % {Target.Variables.BASE_NAME}
    end
    c.PreInitCode:append(globals.target.getCpuTimerSetupCode(self.unit, {
      period = self.period,
      isr = isr
    }))
    c.PreInitCode:append('}')

    if isModTrigger then
      -- note: this is hard-coded for CPUTimer0
      itFunction = [[
      interrupt void %s_baseTaskInterrupt(void)
      {
      	CpuTimer0Regs.TCR.bit.TIF = 1;
    	PieCtrlRegs.PIEACK.all = PIEACK_GROUP1;
    	IER |= M_INT1;
        DISPR_dispatch();
      }
      ]]
      c.Declarations:append("%s\n" % {itFunction % {Target.Variables.BASE_NAME}})
      c.InterruptEnableCode:append('IER |= M_INT1;')
    end
    c.TimerSyncCode:append('CpuTimer%iRegs.TCR.bit.TSS = 0;' % {self.unit})

    return c
  end

  function Timer:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    for _, bid in pairs(static.instances) do
      local timer = globals.instances[bid]
      local c = timer:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  function Timer:registerTriggerRequest(trig)
    print('Timer received trigger request: ' .. dump(trig))
  end

  return Timer

end

return Module
