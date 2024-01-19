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

  local ExtSync = require('blocks.block').getBlock(globals)
  ExtSync["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function ExtSync:checkMaskParameters(env)
    if Block.Mask.sync_gpio ~= Block.Mask.sync_gpio or
        type(Block.Mask.sync_gpio) ~= 'number' then
      return 'Invalid GPIO number.'
    end
  end

  function ExtSync:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local OutputSignal = StringList:new()
    
    table.insert(static.instances, self.bid)
    
    self.unit = Block.Mask.Unit
    self.gpio = Block.Mask.sync_gpio
        
    Require:add('EXTSYNC', self.unit)
    
    local error = globals.target.checkGpioIsValidPwmSync(self.gpio)
    if error ~= nil then
      return error
    end
    
    OutputSignal:append("{synco = {bid = %i}}" % {ExtSync:getId()})

    return {
      Require = Require, 
      OutputSignal = {OutputSignal},
      UserData = {bid = ExtSync:getId()}
    }
  end

  function ExtSync:getNonDirectFeedthroughCode()
    local Require = ResourceList:new()
    if globals.target.getTargetParameters()['epwms']['type'] < 4 then
      -- dedicated sync pin - we need to claim it outright
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
  
  function ExtSync:finalizeThis(c)
    if globals.target.getTargetParameters()['epwms']['type'] < 4 then
      -- configure dedicated pin (for 69 and 335)
      local port
      if self.gpio == 6 then
        port = 'A'
      else
        port = 'B'
      end
      
      c.PreInitCode:append([[
        EALLOW;
        // configure external sync input
        GpioCtrlRegs.GP%(port)sMUX1.bit.GPIO%(gpio)i = 2;
        GpioCtrlRegs.GP%(port)sDIR.bit.GPIO%(gpio)i = 0;
        EDIS;
      ]] % {port = port, gpio = self.gpio})
    else
      -- this device uses XBAR inputs 5 & 6
      local input
      if self.unit == 1 then
        input = 5
      else
        input = 6
      end
      c.PreInitCode:append([[
        EALLOW;
        InputXbarRegs.INPUT%(input)iSELECT = %(gpio)i;
        EDIS;
      ]] % {input = input, gpio = self.gpio})
    end
  end

  function ExtSync:finalize(c)
    for _, bid in pairs(static.instances) do
      local extsync = globals.instances[bid]
      local c = extsync:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end
    
    static.finalized = true  
    return c
  end

  return ExtSync
end

return Module
