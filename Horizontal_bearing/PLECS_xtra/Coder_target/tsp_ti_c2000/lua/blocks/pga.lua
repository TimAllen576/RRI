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

  local Pga = require('blocks.block').getBlock(globals)
  Pga["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Pga:createImplicit(pga, params, req)
    static.instances[pga] = self.bid
    self.pga = pga
    self.gain = params.gain
    self.rf = params.rf
    self:logLine('PGA%i implicitly created.' % {self.pga})
  end

  function Pga:checkMaskParameters(env)
  end

  function Pga:getDirectFeedthroughCode()
    return 'Target IO Block not supported.'
  end

  function Pga:finalizeThis(c)
    c.PreInitCode:append("PLX_PGA_enable(%i, (uint16_t)%i, (uint16_t)%i);" %
                             {self.pga, self.gain, self.rf})
    return c
  end

  function Pga:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_pga.h')
    local code = [[
    {
      PLX_PGA_sinit();
    }
    ]]
    c.PreInitCode:append(code)

    for _, bid in pairs(static.instances) do
      local pga = globals.instances[bid]
      local c = pga:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Pga
end

return Module

