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
  numChannels = 0,
  instances = {},
  inalized = nil
}

function Module.getBlock(globals)

  local Din = require('blocks.block').getBlock(globals)
  Din["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Din:checkMaskParameters(env)
    if not env.utils.isPositiveIntScalarOrArray(Block.Mask.gpio) then
      return 'GPIO numbers(s) must be a scalar or vector of non-negative integers.'
    end
  end

  function Din:createImplicit(gpio, params, req)
    table.insert(static.instances, self.bid)
    self.gpio = {}
    self.gpio[static.numChannels] = gpio
    globals.target.allocateGpio(gpio, {}, req)

    local pullup = params.pullup
    if pullup == nil then
      pullup = "enabled" -- default
    end
    globals.syscfg:addEntry('gpio', {
      unit = gpio,
      direction = "in",
      pullup = pullup,
    })

    local handle = static.numChannels
    static.numChannels = static.numChannels + 1
    return handle
  end

  function Din:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()

    table.insert(static.instances, self.bid)
    self.gpio = {}

    local inputTypes = {'pullup', 'float'}  -- must match parameter combo
    self.in_type = 'float'
    if Block.Mask.InputType ~= nil then
      self.in_type = inputTypes[Block.Mask.InputType]
    end

    for i = 1, Block.NumOutputSignals[1] do
      self.gpio[static.numChannels] = Block.Mask.gpio[i]
      globals.target.allocateGpio(Block.Mask.gpio[i], {}, Require)
      OutputSignal:append("PLXHAL_DIO_get(%i)" % {static.numChannels})
      static.numChannels = static.numChannels + 1

      if self.in_type == "pullup" then
        pullup = "enabled"
      end
      globals.syscfg:addEntry('gpio', {
        unit = Block.Mask.gpio[i],
        direction = "in",
        pullup = pullup,
      })
    end

    return {
      InitCode = InitCode,
      OutputSignal = {OutputSignal},
      Require = Require,
      UserData = {bid = Din:getId()}
    }
  end

  function Din:finalizeThis(c)
    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    for ch, gpio in pairs(self.gpio) do
      c.PreInitCode:append("{")
      c.PreInitCode:append("  PLX_DIO_InputProperties_t props = {0};")
      if not driverLibTarget then
        if self.in_type == 'pullup' then
          c.PreInitCode:append("  props.type = PLX_DIO_PULLUP;")
        else
          c.PreInitCode:append("  props.type = PLX_DIO_NOPULL;")
        end
      end
      c.PreInitCode:append("  props.enableInvert = false;")
      c.PreInitCode:append("  PLX_DIO_configureIn(DinHandles[%i], %i, &props);" %
                               {ch, gpio})
      c.PreInitCode:append("}")
    end
    return c
  end

  function Din:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_dio.h')
    c.Declarations:append('PLX_DIO_Handle_t DinHandles[%i];' %
                              {static.numChannels})
    c.Declarations:append('PLX_DIO_Obj_t DinObj[%i];' % {static.numChannels})

    c.Declarations:append('bool PLXHAL_DIO_get(uint16_t aHandle){')
    c.Declarations:append('  return PLX_DIO_get(DinHandles[aHandle]);')
    c.Declarations:append('}')

    local code = [[
    {
      PLX_DIO_sinit();
      int i;
      for(i=0; i<%d; i++)
      {
        DinHandles[i] = PLX_DIO_init(&DinObj[i], sizeof(DinObj[i]));
      }
    }
    ]]
    c.PreInitCode:append(code % {static.numChannels})

    for _, bid in pairs(static.instances) do
      local din = globals.instances[bid]
      local c = din:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Din
end

return Module
