--[[
  Copyright (c) 2021-2022 by Plexim GmbH
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

  local CanPort = require('blocks.block').getBlock(globals)
  CanPort["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function CanPort:checkMaskParameters(env)
    if (Block.Mask.baud > 1e6) or (Block.Mask.baud <= 0) then
      return 'Invalid CAN baud rate.'
    end
    if (Block.Mask.BitSamplePoint >= 100) or (Block.Mask.BitSamplePoint <= 50) then
      return 'Invalid sample point (must be greater than 50% and less than 100%).'
    end
    if (Block.Mask.BitInTq == Block.Mask.BitInTq) and 
       (math.floor(Block.Mask.BitInTq) ~= Block.Mask.BitInTq) then
      return 'Invalid value for bit length.'
    end
    if (Block.Mask.SjwInTq == Block.Mask.SjwInTq) and 
       (math.floor(Block.Mask.SjwInTq) ~= Block.Mask.SjwInTq) then
      return 'Invalid value for SJW.'
    end
  end

  function CanPort:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    self.can = Block.Mask.interface - 1
    self.can_letter = string.char(65 + self.can)
    Require:add('CAN %s' % {self.can_letter})

    -- see if a CAN object as already been created
    for _, b in ipairs(globals.instances) do
      if b:getType() == 'can' then
        if b:getParameter('can') == self.can then
          self.can_obj = b
          break
        end
      end
    end

    if self.can_obj == nil then
      -- cerate new CAN object
      self.can_obj = self:makeBlock('can')
      self.can_obj:createImplicit(self.can)
    end

    self.can_instance = self.can_obj:getParameter('instance')
    
    local bit_length_tq, sjw_tq
    if Block.Mask.AdvancedBitRateConf == 2 then
      bit_length_tq = Block.Mask.BitInTq
      sjw_tq = Block.Mask.SjwInTq
    end

    local error = self.can_obj:configure({
      sample_point = Block.Mask.BitSamplePoint/100,
      baud = Block.Mask.baud,
      gpio = Block.Mask.gpio,
      auto_buson = (Block.Mask.auto_buson == 2),
      bit_length_tq = bit_length_tq,
      sjw_tq = sjw_tq
    }, Require)

    if error ~= nil then
      return error
    end

    OutputCode:append('{\n')
    OutputCode:append('  static bool lastBusOn = false;\n')
    OutputCode:append('  bool busOn = %s;\n' % {Block.InputSignal[1][1]})
    OutputCode:append('  if(!busOn)\n')
    OutputCode:append('  {\n')
    OutputCode:append('    PLXHAL_CAN_setBusOn(%i, false);\n' %
                          {self.can_instance})
    OutputCode:append('  }\n')
    OutputCode:append('  else if (!lastBusOn)\n')
    OutputCode:append('  {\n')
    OutputCode:append('    PLXHAL_CAN_setBusOn(%i, true);\n' %
                          {self.can_instance})
    OutputCode:append('  }\n')
    OutputCode:append('  lastBusOn = busOn;\n')
    OutputCode:append('}\n')

    OutputSignal[1] = {}
    OutputSignal[1][1] = 'PLXHAL_CAN_getIsBusOn(%i)' % {self.can_instance}
    OutputSignal[2] = {}
    OutputSignal[2][1] = 'PLXHAL_CAN_getIsErrorActive(%i)' % {self.can_instance}

    return {
      InitCode = InitCode,
      OutputCode = OutputCode,
      OutputSignal = OutputSignal,
      Require = Require,
      UserData = {bid = CanPort:getId()}
    }
  end

  function CanPort:getNonDirectFeedthroughCode()
    return {}
  end

  function CanPort:finalizeThis(c)
    return c
  end

  function CanPort:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    for _, bid in pairs(static.instances) do
      local canport = globals.instances[bid]
      local c = canport:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return CanPort
end

return Module
