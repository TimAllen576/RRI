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

  local Cap = require('blocks.block').getBlock(globals)
  Cap["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Cap:checkMaskParameters(env)
  end

  function Cap:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local Declarations = StringList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    self.cap = Block.Mask.cap[1]

    Require:add("CAP", self.cap)

    self.div = 1
    if Block.Mask.pre_en ~= 1 then
      self.div = Block.Mask.pre_div
      if (self.div & 1) ~= 0 then
        return "Event prescaler must be an even value."
      end
      if self.div >= 62 then
        return "Event prescaler must no exceed 62."
      end
    end

    self.single_shot = 1

    -- vectorize configuration of events
    self.evts = {}
    self.rsts = {}
    local evt_lookup = {0, 1, -1} -- must match combo
    local rst_lookup = {false, true} -- must match combo

    local i
    for i = 1, #Block.Mask.evts do
      self.evts[i] = evt_lookup[Block.Mask.evts[i]]
      self.rsts[i] = rst_lookup[Block.Mask.rsts[i]]
    end

    if #self.evts > 4 then
      return "Only up to 4 events supported."
    end

    self.gpio = Block.Mask.gpio
    -- resource allocation done in non direct feedthrough

    local cap_params = globals.target.getTargetParameters()['caps']
    if cap_params == nil then
      return 'Cap support not configured.'
    end

    if cap_params.pins ~= nil then
      local capForGio = cap_params.pins['GPIO%d' % {self.gpio}]
      if capForGio == nil then
        return 'GPIO%d is not supported for pulse capture.' % {self.gpio}
      end
      if capForGio ~= self.cap then
        return 'GPIO%d is not associated with CAP%i.' % {self.gpio, self.cap}
      end
    end

    -- setup buffers
    Declarations:append("static uint32_t Cap%iValues[%i];\n" %
                            {self.instance, #self.evts})
    Declarations:append("static bool Cap%iOverflowFlag;\n" % {self.instance})
    Declarations:append("static bool Cap%iValid;\n" % {self.instance})

    -- output code
    OutputCode:append("{\n")
    OutputCode:append(
        "  Cap%iValid = PLXHAL_CAP_getNewValues(%i, %i, &Cap%iValues[0], &Cap%iOverflowFlag);\n" %
            {
              self.instance, self.instance, self.div, self.instance,
              self.instance
            })
    OutputCode:append("}\n")

    local OutputSignal1 = StringList:new()
    for i = 1, #self.evts do
      InitCode:append("Cap%iValues[%i] = 0;\n" % {self.instance, i - 1})
      OutputSignal1:append("Cap%iValues[%i]" % {self.instance, i - 1})
    end

    local OutputSignal2 = StringList:new()
    InitCode:append("Cap%iValid = 0;\n" % {self.instance})
    OutputSignal2:append("Cap%iValid" % {self.instance})

    local OutputSignal3 = StringList:new()
    InitCode:append("Cap%iOverflowFlag = 0;\n" % {self.instance})
    OutputSignal3:append("Cap%iOverflowFlag" % {self.instance})

    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    if driverLibTarget then
      local xbarFirst
      if globals.target.getFamilyPrefix() == '28004x' then
        xbarFirst = 10
      else
        xbarFirst = 7
      end
      Require:add("XBAR_INPUT", xbarFirst+self.cap-1)

      globals.syscfg:addEntry('ecap', {
        unit = self.cap,
      })

      globals.syscfg:addEntry('input_xbar', {
        gpio = self.gpio,
        input = (xbarFirst+self.cap-1),
      })
    end

    return {
      Declarations = Declarations,
      InitCode = InitCode,
      OutputSignal = {OutputSignal1, OutputSignal2, OutputSignal3},
      OutputCode = OutputCode,
      Require = Require,
      UserData = {bid = Cap:getId()}
    }
  end

  function Cap:getNonDirectFeedthroughCode()
    local Require = ResourceList:new()
    if globals.target.getTargetParameters()['caps']['pins'] ~= nil then
      -- dedicated capture pin - we need to claim it outright
      globals.target.allocateGpio(self.gpio, {}, Require)
    elseif not globals.target.isGpioAllocated(self.gpio) then
      -- configure pin implicitely as input
      local din_obj = self:makeBlock('din')
      din_obj:createImplicit(self.gpio, {}, Require)
    end
    return {
      Require = Require
    }
  end

  function Cap:finalizeThis(c)
    c.PreInitCode:append("{")
    c.PreInitCode:append("  PLX_CAP_Params_t params;")
    c.PreInitCode:append("  PLX_CAP_setDefaultParams(%i, %i, &params);" %
                             {#self.evts, self.single_shot})
    if self.div > 1 then
      c.PreInitCode:append(
          "  params.reg.ECCTL1.bit.PRESCALE = %i; // prescale events by %i" %
              {(self.div / 2) % 0x1F, self.div})
    end
    for i, p in ipairs(self.evts) do
      if p > 0 then
        c.PreInitCode:append("  params.reg.ECCTL1.bit.CAP%iPOL = 0; // rising" %
                                 {i})
      else
        c.PreInitCode:append(
            "  params.reg.ECCTL1.bit.CAP%iPOL = 1; // falling" % {i})
      end
    end
    for i, r in ipairs(self.rsts) do
      if r then
        c.PreInitCode:append(
            "  params.reg.ECCTL1.bit.CTRRST%i = 1; // reset counter" % {i})
      else
        c.PreInitCode:append(
            "  params.reg.ECCTL1.bit.CTRRST%i = 0; // don't reset counter" % {i})
      end
    end
    c.PreInitCode:append(
        "  PLX_CAP_configure(CapHandles[%i], %i, %i, &params);" %
            {self.instance, self.cap, self.gpio})
    c.PreInitCode:append("}")
    return c
  end

  function Cap:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_cap.h')
    c.Declarations:append('PLX_CAP_Handle_t CapHandles[%i];' %
                              {static.numInstances})
    c.Declarations:append('PLX_CAP_Obj_t CapObj[%i];' % {static.numInstances})

    c.Declarations:append(
        'bool PLXHAL_CAP_getNewValues(uint16_t aChannel, uint16_t aNewPrescale, uint32_t *aValues, bool *aOverflowFlag){')
    c.Declarations:append(
        '  return PLX_CAP_getNewValues(CapHandles[aChannel], aNewPrescale, aValues, aOverflowFlag);')
    c.Declarations:append('}')

    local code = [[
    {
      PLX_CAP_sinit();
      int i;
      for(i=0; i<%d; i++)
      {
        CapHandles[i] = PLX_CAP_init(&CapObj[i], sizeof(CapObj[i]));
      }
    }
    ]]
    c.PreInitCode:append(code % {static.numInstances})

    for _, bid in pairs(static.instances) do
      local cap = globals.instances[bid]
      local c = cap:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Cap
end

return Module
