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

  local CanTransmit = require('blocks.block').getBlock(globals)
  CanTransmit["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function CanTransmit:checkMaskParameters(env)
  end

  function CanTransmit:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local Declarations = StringList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    self.mcan = Block.Mask.MCanInterface - 1

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

    self.width = #Block.InputSignal[1]

    if Block.Mask.idSource == 2 then
      local canIdString = Block.InputSignal[3][1]
      if string.match(canIdString, "UNCONNECTED") then
        return ("'id' terminal cannot be left unconnected.")
      end
      self.canId = tonumber(canIdString);
      if self.canId == nil then
        return "Signal 'id' must be constant and of integer type."
      end
    else
      self.canId = Block.Mask.canId
    end

    self.extId = false
    if Block.Mask.frameFormat == 3 then
      self.extId = true -- forcing extended
    end
    if self.canId > 0x7FF then
      self.extId = true
      if Block.Mask.frameFormat == 2 then -- forcing standard
        return "CAN identifier exceeds 11 bit base format."
      end
      if self.canId > 0x1FFF0000 then
        return "CAN identifier exceeds 29 bit extended format."
      end
    end

    if self.width <= 8 then
      self.dlc = self.width
    elseif self.width == 12 then
      self.dlc = 9
    elseif self.width == 16 then
      self.dlc = 10
    elseif self.width == 20 then
      self.dlc = 11
    elseif self.width == 24 then
      self.dlc = 12
    elseif self.width == 32 then
      self.dlc = 13
    elseif self.width == 48 then
      self.dlc = 14
    elseif self.width == 64 then
     self.dlc = 15
    else
      return "Invalid CAN message length."
    end

    local inputType = Block.InputType[1]
    for idx = 1, self.width do
      if (inputType[idx] ~= "uint8_t") then
        return "Input type of signal at index %i must be uint8 (is %s)." %
                   {idx - 1, inputType[idx]}
      end
    end

    if (not self.canId) then
      return "Signal 'id' must be constant."
    end

    -- setup mailbox
    self.mbox = self.can_obj:getTxMailbox()
    if type(self.mbox) == 'string' then
      return self.mbox
    end

    self.can_obj:setupTxMailbox(self.mbox, {
      can_id = self.canId,
      ext_id = self.extId,
      width = self.width,
      dlc = self.dlc,
      brs = (Block.Mask.EnableBitRateSwitching == 2)
    })

    OutputCode:append("{ unsigned char canData[] = { ")
    for idx = 1, self.width do
      if idx > 1 then
        OutputCode:append(", ");
      end
      OutputCode:append(Block.InputSignal[1][idx])
    end
    OutputCode:append(" };\n")
    if (Block.Mask.execution == 2) then
      OutputCode:append("static unsigned char canLastTriggerValue = 0;\n")
      OutputCode:append("int canTriggerValue = !!%s;\n" %
                            {Block.InputSignal[2][1]})
      if Block.Mask.triggerType == 1 then
        OutputCode:append("if (!canLastTriggerValue && canTriggerValue) {\n")
      elseif Block.Mask.triggerType == 2 then
        OutputCode:append("if (canLastTriggerValue && !canTriggerValue) {\n")
      else
        OutputCode:append("if (canLastTriggerValue != canTriggerValue) {\n")
      end
    end

    OutputCode:append("PLXHAL_MCAN_putMessage(%i, %i, canData, %i);\n" %
                          {self.can_instance, self.mbox, self.width})

    if (Block.Mask.execution == 2) then
      OutputCode:append("}\ncanLastTriggerValue = canTriggerValue;\n")
    end
    OutputCode:append("}\n")

    return {
      InitCode = InitCode,
      OutputCode = OutputCode,
      Require = Require,
      UserData = {bid = CanTransmit:getId()}
    }
  end

  function CanTransmit:getNonDirectFeedthroughCode()
    if self.can_obj:getParameter('is_configured') == false then
      return "Please add CAN Port component for interface MCAN%i." % {self.mcan}
    end
    return {}
  end

  function CanTransmit:finalizeThis(c)
    return c
  end

  function CanTransmit:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    for _, bid in pairs(static.instances) do
      local cantx = globals.instances[bid]
      local c = cantx:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return CanTransmit
end

return Module

