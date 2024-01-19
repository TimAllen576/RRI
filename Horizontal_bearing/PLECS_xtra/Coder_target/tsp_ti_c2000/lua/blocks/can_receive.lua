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

  local CanReceive = require('blocks.block').getBlock(globals)
  CanReceive["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function CanReceive:checkMaskParameters(env)
  end

  function CanReceive:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local Declarations = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    self.can = Block.Mask.interface - 1

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

    self.mbox = self.can_obj:getRxMailbox()
    if type(self.mbox) == 'string' then
      return self.mbox
    end
    
    local outSignal = Block:OutputSignal()
    
    -- prepare initialization array for static 'data' variable 
    local dataInit = ''
    for idx = 1, Block.Mask.frameLength do
      if idx > 1 then
        dataInit = dataInit .. ', 0xFF'
      else
     	dataInit = dataInit .. '0xFF'
      end
    end

    local outputCode = [[{
      static unsigned char data[%(width)i] = {%(data_init)s};
      static bool firstRun = true;
      %(out_sig_v)s = PLXHAL_CAN_getMessage(%(handle)i, %(mbox)i, &data[0], %(width)i);
      if(firstRun || %(out_sig_v)s){
        memcpy(&%(out_sig_d)s, &data[0], %(width)i*sizeof(uint8_t));
        firstRun = false;
      }}]] % {
        handle = self.can_instance,
        mbox = self.mbox,
        width = Block.Mask.frameLength,
        data_init = dataInit,
        out_sig_d = outSignal[1][1],
        out_sig_v = outSignal[2][1],
    }
    OutputCode:append(outputCode)
 
    return {
      Declarations = Declarations,
      InitCode = InitCode,
      OutputCode = OutputCode,
      Require = Require,
      UserData = {bid = CanReceive:getId()}
    }
  end

  function CanReceive:getNonDirectFeedthroughCode()
    local idSource = Block.Mask.idSource
    local canId = Block.Mask.canId
    local width = Block.Mask.frameLength;
    local canInterface = Block.Mask.interface - 1
    local frameFormat = Block.Mask.frameFormat;

    if self.can_obj:getParameter('is_configured') == false then
      return "Please add CAN Port component for interface %s." %
                 {string.char(65 + self.can)}
    end

    if idSource == 2 then
      local canIdStr = Block.InputSignal[1][1]
      if string.sub(canIdStr, -1, -1) == 'f' then
        canIdStr = string.sub(canIdStr, 1, -2);
      end
      canId = tonumber(canIdStr)
    end

    if (not canId) then
      return "Signal 'id' must be constant."
    end

    local extId = false
    if frameFormat == 3 then
      extId = true -- forcing extended
    end
    if canId > 0x7FF then
      extId = true
      if frameFormat == 2 then -- forcing standard
        return "CAN identifier exceeds 11 bit base format."
      end
      if canId > 0x1FFF0000 then
        return "CAN identifier exceeds 29 bit extended format."
      end
    end

    self.can_obj:setupRxMailbox(self.mbox, {
      can_id = canId,
      ext_id = extId,
      width = width
    })

    return {}
  end

  function CanReceive:finalizeThis(c)
    return c
  end

  function CanReceive:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    for _, bid in pairs(static.instances) do
      local canrx = globals.instances[bid]
      local c = canrx:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return CanReceive
end

return Module

