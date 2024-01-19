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

function Module.getBlock(globals)
  local TargetBlock = {
    bid = nil, -- block id
    globals = globals
  }

  -- create convenient shortcut for new
  setmetatable(TargetBlock, {
    __call = function(cls, ...)
      return cls:new(...)
    end
  })

  function TargetBlock:new(type)
    local obj = {}
    table.insert(globals.instances, obj)
    local bid = #globals.instances
    self.__index = self -- inherit from prototype
    self.__call = function(cls, ...)
      return cls:new(...)
    end -- make () constructor available to copies (derived classes)
    self.bid = bid
    self.type = type
    setmetatable(obj, self)
    return obj
  end

  function TargetBlock:makeBlock(name)
    local block = require('blocks.%s' % {name}).getBlock({
      target = globals.target,
      utils = globals.utils,
      instances = globals.instances,
      syscfg = globals.syscfg 
    })(name)
    return block
  end

  function TargetBlock:getId()
    return self.bid
  end

  function TargetBlock:getType()
    return self.type
  end

  function TargetBlock:getObjIndex()
    return self['instance']
  end

  function TargetBlock:checkMaskParameters(env)
  end

  function TargetBlock:checkTspVersion()
    if (Block.Mask ~= nil) and (Block.Mask.TspMinVer ~= nil) and
        (Block.Mask.TspMaxVer ~= nil) then
      Block:LogMessage('warning', 'Experimental block. Do not use for important work as it may no longer be supported in the future.')
      local mav, miv = string.match(Target.Version, '(%d+).(%d+)')
      if mav ~= nil and miv ~= nil then
        if (Block.Mask.TspMinVer > '%i.%i' % {mav, miv}) or
            (Block.Mask.TspMaxVer < '%i.%i' % {mav, miv}) then
          return 'This component is not supported by TSP version %s.' %
                     {Target.Version}
        end
      end
    end
  end

  function TargetBlock:getParameter(p)
    return self[p]
  end

  function TargetBlock:getNonDirectFeedthroughCode()
    return {}
  end

  function TargetBlock:requestImplicitTrigger(ts)
  end

  function TargetBlock:setImplicitTriggerSource(bid)
  end

  -- informs the source of a trigger about its sink
  -- called multiple times if a source has multiple sinks
  function TargetBlock:setSinkForTriggerSource()
  end

  -- propagates sample time down the connections (towards sinks)
  function TargetBlock:propagateTriggerSampleTime()
  end

  function TargetBlock:finalize()
  end

  function TargetBlock:logLine(line)
    globals.utils.log('- %02i (%s): %s\n' % {self.bid, self.type, line})
  end

  return TargetBlock
end

return Module
