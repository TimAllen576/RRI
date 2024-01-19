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

  local CpuLoad = require('blocks.block').getBlock(globals)
  CpuLoad["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function CpuLoad:getDirectFeedthroughCode()
    local Require = ResourceList:new()

    -- there can only be one cpu load block
    Require:add("Base Task Load")

    local OutputSignal1 = StringList:new()
    OutputSignal1:append("PLXHAL_DISPR_getTask0LoadInPercent()")

    local OutputSignal2 = StringList:new()
    OutputSignal2:append("PLXHAL_DISPR_getTimeStamp0()")
    OutputSignal2:append("PLXHAL_DISPR_getTimeStampB()")
    OutputSignal2:append("PLXHAL_DISPR_getTimeStampD()")
    OutputSignal2:append("PLXHAL_DISPR_getTimeStampP()")

    return {
      Require = Require,
      OutputSignal = {OutputSignal1, OutputSignal2},
      UserData = {bid = CpuLoad:getId()}
    }
  end

  function CpuLoad:getNonDirectFeedthroughCode()
    return {}
  end

  function CpuLoad:finalize(f)

    f.Declarations:append('uint32_t PLXHAL_DISPR_getTimeStamp0(){')
    f.Declarations:append('  return DISPR_getTimeStamp0();')
    f.Declarations:append('}')

    f.Declarations:append('uint32_t PLXHAL_DISPR_getTimeStamp1(){')
    f.Declarations:append('  return DISPR_getTimeStamp1();')
    f.Declarations:append('}')

    f.Declarations:append('uint32_t PLXHAL_DISPR_getTimeStamp2(){')
    f.Declarations:append('  return DISPR_getTimeStamp2();')
    f.Declarations:append('}')

    f.Declarations:append('uint32_t PLXHAL_DISPR_getTimeStamp3(){')
    f.Declarations:append('  return DISPR_getTimeStamp3();')
    f.Declarations:append('}')

    f.Declarations:append('uint32_t PLXHAL_DISPR_getTimeStampB(){')
    f.Declarations:append('  return DISPR_getTimeStampB();')
    f.Declarations:append('}')

    f.Declarations:append('uint32_t PLXHAL_DISPR_getTimeStampD(){')
    f.Declarations:append('  return DISPR_getTimeStampD();')
    f.Declarations:append('}')

    f.Declarations:append('uint32_t PLXHAL_DISPR_getTimeStampP(){')
    f.Declarations:append('  return DISPR_getTimeStampP();')
    f.Declarations:append('}')

    f.Declarations:append('float PLXHAL_DISPR_getTask0LoadInPercent(){')
    f.Declarations:append('  return DISPR_getTask0LoadInPercent();')
    f.Declarations:append('}')

    return f
  end

  return CpuLoad
end

return Module
