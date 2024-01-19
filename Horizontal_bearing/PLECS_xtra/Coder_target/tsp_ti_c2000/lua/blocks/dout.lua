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
  finalized = nil
}

function Module.getBlock(globals)

  local Dout = require('blocks.block').getBlock(globals)
  Dout["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Dout:checkMaskParameters(env)
    if not env.utils.isPositiveIntScalarOrArray(Block.Mask.gpio) then
      return 'GPIO numbers(s) must be a scalar or vector of non-negative integers.'
    end
  end

  function Dout:createImplicit(gpio, params, req)
    table.insert(static.instances, self.bid)
    self.gpio = {}
    self.gpio[static.numChannels] = gpio
    globals.target.allocateGpio(gpio, {}, req)

    local type = params.type
    if type == nil then
      type = "pp" -- default
    end
    globals.syscfg:addEntry('gpio', {
        unit = gpio,
        direction = "out",
        type = type,
    })

    local handle = static.numChannels
    static.numChannels = static.numChannels + 1
    return handle
  end

  function Dout:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)
    self.gpio = {}

    local outputTypes = {'pp', 'od'}  -- must match parameter combo
    self.out_type = 'pp'
    if Block.Mask.OutputType ~= nil then
      self.out_type = outputTypes[Block.Mask.OutputType]
    end

    local odSupported = globals.target.getTargetParameters()['gpios']['opendrain_supported']
    if (self.out_type == 'od') and ((odSupported == nil) or (odSupported == false)) then
       return 'Open drain output characteristic is not supported by this chip.'
    end

    for i = 1, #Block.InputSignal[1] do
      self.gpio[static.numChannels] = Block.Mask.gpio[i]
      globals.target.allocateGpio(Block.Mask.gpio[i], {}, Require)
      OutputCode:append("PLXHAL_DIO_set(%i, %s);" %
                            {static.numChannels, Block.InputSignal[1][i]})
      static.numChannels = static.numChannels + 1

      globals.syscfg:addEntry('gpio', {
        unit = Block.Mask.gpio[i],
        direction = "out",
        type = self.out_type,
      })
    end

    return {
      InitCode = InitCode,
      OutputCode = OutputCode,
      Require = Require,
      UserData = {bid = Dout:getId()}
    }
  end

  function Dout:finalizeThis(c)
    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                              (globals.target.getFamilyPrefix() ~= '2833x')

    for ch, gpio in pairs(self.gpio) do
      c.PreInitCode:append("{")
      c.PreInitCode:append("  PLX_DIO_OutputProperties_t props = {0};")
      if not driverLibTarget then
        if self.out_type == 'od' then
          c.PreInitCode:append("  props.type = PLX_DIO_OPENDRAIN;")
        else
          c.PreInitCode:append("  props.type = PLX_DIO_PUSHPULL;")
        end
      end
      c.PreInitCode:append("  props.enableInvert = false;")
      c.PreInitCode:append("  PLX_DIO_configureOut(DoutHandles[%i], %i,  &props);" %
                               {ch, gpio})
      c.PreInitCode:append("}")
    end
    return c
  end

  function Dout:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_dio.h')
    c.Declarations:append('PLX_DIO_Handle_t DoutHandles[%i];' %
                              {static.numChannels})
    c.Declarations:append('PLX_DIO_Obj_t DoutObj[%i];' % {static.numChannels})

    c.Declarations:append('void PLXHAL_DIO_set(uint16_t aHandle, bool aVal){')
    c.Declarations:append('  PLX_DIO_set(DoutHandles[aHandle], aVal);')
    c.Declarations:append('}')

    local code = [[
    {
      PLX_DIO_sinit();
      int i;
      for(i=0; i<%d; i++)
      {
        DoutHandles[i] = PLX_DIO_init(&DoutObj[i], sizeof(DoutObj[i]));
      }
    }
    ]]
    c.PreInitCode:append(code % {static.numChannels})

    for _, bid in pairs(static.instances) do
      local dout = globals.instances[bid]
      local c = dout:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Dout
end

return Module

