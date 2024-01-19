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

local static = {numInstances = 0}

function Module.getBlock(globals)

  local Clock = require('blocks.block').getBlock(globals)
  Clock["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Clock:getDirectFeedthroughCode()
    return "Explicit use of CLOCK via target block not supported."
  end

  function Clock:finalize(f)
    if static.numInstances ~= 1 then
      return 'There should be only one (implicit) instance of the Clock block.'
    end

    if Target.Variables.targetCore == 2 then
      clockConfig = globals.target.getClockConfigurationCodeCpu2()
    else
      clockConfig = globals.target.getClockConfigurationCode()
    end
    if type(clockConfig) == 'string' then
      return clockConfig
    end

    f.Declarations:append(clockConfig.declarations)
    f.PreInitCode:append(clockConfig.code)

    globals.syscfg:setEntry('System', {
    	clk = Target.Variables.sysClkMHz * 1e6
  	})
    return f
  end

  return Clock
end

return Module

