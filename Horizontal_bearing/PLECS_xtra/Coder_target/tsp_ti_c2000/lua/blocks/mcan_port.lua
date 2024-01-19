--[[
  Copyright (c) 2022 by Plexim GmbH
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
    if (Block.Mask.NomBitRate > 5e6) or (Block.Mask.NomBitRate <= 0) then
      return 'Invalid nominal bit rate rate.'
    end
    if (Block.Mask.NomBitSamplePoint >= 100) or (Block.Mask.NomBitSamplePoint <= 50) then
      return 'Invalid nominal bit rate sample point (must be greater than 50% and less than 100%).'
    end
    if (Block.Mask.DataBitRate == Block.Mask.DataBitRate) and 
       ((Block.Mask.DataBitRate > 5e6) or (Block.Mask.DataBitRate <= 0)) then
      return 'Invalid data bit rate rate.'
    end
    if (Block.Mask.DataBitSamplePoint == Block.Mask.DataBitSamplePoint) and 
       ((Block.Mask.DataBitSamplePoint >= 100) or (Block.Mask.DataBitSamplePoint < 50)) then
      return 'Invalid data bit rate sample point (must be greater than 50% and less than 100%).'
    end
    
    if (Block.Mask.EnableSSP == Block.Mask.EnableSSP) and (Block.Mask.EnableSSP == 2) then
      if (math.floor(Block.Mask.SSPFilter) ~= Block.Mask.SSPFilter) or
         (Block.Mask.SSPFilter < 0) or (Block.Mask.SSPFilter > 127) then
        return 'Invalid value for SSP filter.'
      end
      if (math.floor(Block.Mask.SSPOffset) ~= Block.Mask.SSPOffset) or
         (Block.Mask.SSPFilter < 0) or (Block.Mask.SSPFilter > 127) then
        return 'Invalid value for SSP offset.'
      end
    end
    
    if (Block.Mask.DataBitInTq == Block.Mask.DataBitInTq) and 
       (math.floor(Block.Mask.DataBitInTq) ~= Block.Mask.DataBitInTq) then
      return 'Invalid value for data rate bit length.'
    end
    if (Block.Mask.NominalBitInTq == Block.Mask.NominalBitInTq) and 
       (math.floor(Block.Mask.NominalBitInTq) ~= Block.Mask.NominalBitInTq) then
      return 'Invalid value for nominal rate bit length.'
    end
    if (Block.Mask.DataSjwInTq == Block.Mask.DataSjwInTq) and 
       (math.floor(Block.Mask.DataSjwInTq) ~= Block.Mask.DataSjwInTq) then
      return 'Invalid value for data rate SJW.'
    end
    if (Block.Mask.NominalSjwInTq == Block.Mask.NominalSjwInTq) and 
       (math.floor(Block.Mask.NominalSjwInTq) ~= Block.Mask.NominalSjwInTq) then
      return 'Invalid value for nominal rate SJW.'
    end
  end

  function CanPort:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    self.mcan = Block.Mask.MCanInterface - 1
    Require:add('MCAN',  self.mcan)

    -- see if a CAN object as already been created
    for _, b in ipairs(globals.instances) do
      if b:getType() == 'mcan' then
        if b:getParameter('mcan') == self.mcan then
          self.can_obj = b
          break
        end
      end
    end

    if self.can_obj == nil then
      -- create new CAN object
      self.can_obj = self:makeBlock('mcan')
      self.can_obj:createImplicit(self.mcan)
    end

    self.can_instance = self.can_obj:getParameter('instance')

    local data_bit_rate, data_sample_point
    if Block.Mask.DataBitRate == Block.Mask.DataBitRate then
      data_bit_rate = Block.Mask.DataBitRate
      data_sample_point = Block.Mask.DataBitSamplePoint/100
    end
    
    local nom_bit_length_tq, nom_sjw_tq
    local data_bit_length_tq, data_sjw_tq
    if Block.Mask.AdvancedBitRateConf == 2 then
      nom_bit_length_tq = Block.Mask.NominalBitInTq
      nom_sjw_tq = Block.Mask.NominalSjwInTq
      if Block.Mask.DataBitRate == Block.Mask.DataBitRate then
        data_bit_length_tq = Block.Mask.DataBitInTq
        data_sjw_tq = Block.Mask.DataSjwInTq
      end
    end
    
    -- SSP configuration
    local ssp
    if Block.Mask.EnableSSP == Block.Mask.EnableSSP then
      if Block.Mask.EnableSSP == 2 then
        ssp = {
          tdcf = Block.Mask.SSPFilter,
          tdco = Block.Mask.SSPOffset
        }
      else
        ssp = {}
      end
    end
    
    local error = self.can_obj:configure({
      nom_sample_point = (Block.Mask.NomBitSamplePoint/100),
      nom_bit_rate = Block.Mask.NomBitRate,
      data_bit_rate = data_bit_rate,
      data_sample_point = data_sample_point,
      nom_bit_length_tq = nom_bit_length_tq,
      nom_sjw_tq = nom_sjw_tq,
      data_bit_length_tq = data_bit_length_tq,
      data_sjw_tq = data_sjw_tq,
      ssp = ssp,
      gpio = Block.Mask.gpio,
    }, Require)

    if error ~= nil then
      return error
    end
    
    if (Block.Mask.auto_buson == 2) then
      -- auto bus-on
      OutputCode:append('{\n')
      OutputCode:append('  bool setBusOn = %s;\n' % {Block.InputSignal[1][1]})
      OutputCode:append('  bool isBusOn = PLXHAL_MCAN_getIsBusOn(%i);\n' % {self.can_instance})
      OutputCode:append('  if(isBusOn != setBusOn){\n')
      OutputCode:append('    PLXHAL_MCAN_setBusOn(%i, setBusOn);\n' % {self.can_instance})
      OutputCode:append('  }\n')
      OutputCode:append('}\n')
    else
      OutputCode:append('{\n')
      OutputCode:append('  static bool lastBusOn = false;\n')
      OutputCode:append('  bool busOn = %s;\n' % {Block.InputSignal[1][1]})
      OutputCode:append('  if(!busOn)\n')
      OutputCode:append('  {\n')
      OutputCode:append('    PLXHAL_MCAN_setBusOn(%i, false);\n' %
                          {self.can_instance})
      OutputCode:append('  }\n')
      OutputCode:append('  else if (!lastBusOn)\n')
      OutputCode:append('  {\n')
      OutputCode:append('    PLXHAL_MCAN_setBusOn(%i, true);\n' %
                          {self.can_instance})
      OutputCode:append('  }\n')
      OutputCode:append('  lastBusOn = busOn;\n')
      OutputCode:append('}\n')
    end

    OutputSignal[1] = {}
    OutputSignal[1][1] = 'PLXHAL_MCAN_getIsBusOn(%i)' % {self.can_instance}
    OutputSignal[2] = {}
    OutputSignal[2][1] = 'PLXHAL_MCAN_getIsErrorActive(%i)' % {self.can_instance}

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
