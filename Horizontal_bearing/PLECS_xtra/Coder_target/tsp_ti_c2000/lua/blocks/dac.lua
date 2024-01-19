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

local static = {numInstances = 0, instances = {}, inalized = nil}

function Module.getBlock(globals)

  local Dac = require('blocks.block').getBlock(globals)
  Dac["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Dac:checkMaskParameters(env)
    local scale = env.utils.getFromArrayOrScalar(Block.Mask.scale)
    if scale == nil then
      return "Invalid width of parameter 'scale'."
    end

    local offset = env.utils.getFromArrayOrScalar(Block.Mask.offset)
    if offset == nil then
      return "Invalid width of parameter 'offset'."
    end

    local min = env.utils.getFromArrayOrScalar(Block.Mask.minOutput)
    if min == nil then
      return "Invalid width of parameter 'minOutput'."
    end

    local max = env.utils.getFromArrayOrScalar(Block.Mask.maxOutput)
    if max == nil then
      return "Invalid width of parameter 'maxOutput'."
    end
  end

  function Dac:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    self.dac = Block.Mask.dac[1] - 1
    Require:add("DAC %s" % {string.char(65 + self.dac)})

    local dim = #Block.InputSignal[1]
    if dim ~= 1 then
      return "Expecting scalar input."
    end

    self.scale = globals.utils.getFromArrayOrScalar(Block.Mask.scale)
    self.offset = globals.utils.getFromArrayOrScalar(Block.Mask.offset)
    self.min = globals.utils.getFromArrayOrScalar(Block.Mask.minOutput)
    self.max = globals.utils.getFromArrayOrScalar(Block.Mask.maxOutput)

    local dacParams = globals.target.getTargetParameters()['dacs']
    if dacParams == nil then
      return 'Buffered DAC peripheral is not available for this target device.'
    end

    self.targmin = dacParams.min_out
    self.targmax = dacParams.max_out

    if self.min == nil or self.min < self.targmin then
      self.min = self.targmin
    end
    if self.min > self.targmax then
      self.min = self.targmax
    end

    if self.max == nil or self.max > self.targmax then
      self.max = self.targmax
    end
    if self.max < self.targmin then
      self.max = self.targmin
    end

    OutputCode:append("PLXHAL_DAC_set(%i, %s);" %
                          {self.instance, Block.InputSignal[1][1]})

    globals.syscfg:addEntry('dac', {
      unit = string.char(65 + self.dac),
    })

    return {
      InitCode = InitCode,
      OutputCode = OutputCode,
      Require = Require,
      UserData = {bid = Dac:getId()}
    }
  end

  function Dac:finalizeThis(c)
    c.PreInitCode:append(" // configure DAC%s \n" % {string.char(65 + self.dac)})
    c.PreInitCode:append("{\n")
    c.PreInitCode:append("  PLX_DAC_configure(DacHandles[%i], PLX_DAC_%s);" %
                             {self.instance, string.char(65 + self.dac)})
    c.PreInitCode:append(
        "  PLX_DAC_configureScaling(DacHandles[%i], %.9ef, %.9ef, %.9ef, %.9ef );" %
            {self.instance, self.scale, self.offset, self.min, self.max})
    c.PreInitCode:append("}\n")
    return c
  end

  function Dac:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_dac.h')
    c.Declarations:append('PLX_DAC_Handle_t DacHandles[%i];' %
                              {static.numInstances})
    c.Declarations:append('PLX_DAC_Obj_t DacObj[%i];' % {static.numInstances})

    c.Declarations:append('void PLXHAL_DAC_set(uint16_t aHandle, float aValue){')
    c.Declarations:append('  PLX_DAC_setValF(DacHandles[aHandle], aValue);')
    c.Declarations:append('}')

    local code = [[
    {
      PLX_DAC_sinit(%f);
      int i;
      for(i=0; i<%d; i++)
      {
        DacHandles[i] = PLX_DAC_init(&DacObj[i], sizeof(DacObj[i]));
      }
    }
    ]]
    c.PreInitCode:append(code %
                             {
          globals.target.getTargetParameters()['adcs']['vref'],
          static.numInstances
        })

    for _, bid in pairs(static.instances) do
      local dac = globals.instances[bid]
      local c = dac:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Dac
end

return Module

