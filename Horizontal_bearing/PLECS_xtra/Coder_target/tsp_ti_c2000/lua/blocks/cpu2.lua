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

local static = {numInstances = 0}

function Module.getBlock(globals)

  local Cpu2 = require('blocks.block').getBlock(globals)
  Cpu2["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Cpu2:createImplicit(req)
    if Target.Variables.targetCore == 2 then
      return
    end
    -- CPU1 must adopt CPU2 system configuration
    local cpu2SyscfgFileName = "%s/%s_syscfg.txt" % {Target.Variables.BUILD_ROOT, Target.Variables.SecondaryCoreModelBaseName}
    local cpu2BinaryFileName = "%s/%s.elf" % {Target.Variables.BUILD_ROOT, Target.Variables.SecondaryCoreModelBaseName}
    if (not Plecs:FileExists(cpu2SyscfgFileName)) or (not Plecs:FileExists(cpu2BinaryFileName)) then
      errorMsg = [[
         Secondary core model files not found. Please generate code for model with base name '%s' first.
      ]] % {Target.Variables.SecondaryCoreModelBaseName}
      return errorMsg
    end

    local file, error = io.open(cpu2SyscfgFileName, "rb")
    if error ~= nil then
      return error
    end
    local content = file:read("*all")
    file:close()

    local cpu2SysCfg = eval(content)
    if cpu2SysCfg['System']['clk'] ~= Target.Variables.sysClkMHz * 1e6 then
      return "System clock frequency of secondary core does not match primary core configuration."
    end

    if cpu2SysCfg['gpio'] ~= nil then
      for _, gpio in ipairs(cpu2SysCfg['gpio']) do
        -- claim resource
        req:add("GPIO", gpio['unit'], "Secondary core")
        gpio.core = 2
        globals.syscfg:addEntry('gpio', gpio)
      end
    end

    if cpu2SysCfg['sci'] ~= nil then
      for _, sci in ipairs(cpu2SysCfg['sci']) do
        req:add('SCI %s' % {sci.unit}, -1, "Secondary core")
        req:add("GPIO", sci["pins"][1], "Secondary core")
        req:add("GPIO", sci["pins"][2], "Secondary core")
        sci.core = 2
        globals.syscfg:addEntry('sci', sci)
      end
    end

    if cpu2SysCfg['epwm'] ~= nil then
      for _, epwm in ipairs(cpu2SysCfg['epwm']) do
        req:add("PWM", epwm.unit, "Secondary core")
        req:add("GPIO", epwm["pins"][1], "Secondary core")
        req:add("GPIO", epwm["pins"][2], "Secondary core")
        epwm.core = 2
        globals.syscfg:addEntry('epwm', epwm)
      end
    end

    if cpu2SysCfg['can'] ~= nil then
      for _, can in ipairs(cpu2SysCfg['can']) do
        req:add('CAN %s' % {can.unit}, -1, "Secondary core")
        can.core = 2
        globals.syscfg:addEntry('can', can)
      end
    end

    if cpu2SysCfg['mcan'] ~= nil then
      return "MCAN not supported on CPU2."
    end

    if cpu2SysCfg['spi'] ~= nil then
      for _, spi in ipairs(cpu2SysCfg['spi']) do
        req:add('SPI %s' % {spi.unit}, -1, "Secondary core")
        spi.core = 2
        globals.syscfg:addEntry('spi', spi)
      end
    end

    if cpu2SysCfg['qep'] ~= nil then
      for _, qep in ipairs(cpu2SysCfg['qep']) do
        req:add("QEP", qep.unit, "Secondary core")
        qep.core = 2
        globals.syscfg:addEntry('qep', qep)
      end
    end

    if cpu2SysCfg['cmpss'] ~= nil then
      for _, cmpss in ipairs(cpu2SysCfg['cmpss']) do
        req:add("CMPSS", cmpss.unit, "Secondary core")
        cmpss.core = 2
        globals.syscfg:addEntry('cmpss', cmpss)
      end
    end

    if cpu2SysCfg['epwm_xbar'] ~= nil then
      for _, epwm_xbar in ipairs(cpu2SysCfg['epwm_xbar']) do
        req:add("XBAR_TRIP", epwm_xbar.trip, "Secondary core")
        globals.syscfg:addEntry('epwm_xbar', epwm_xbar)
      end
    end

    if cpu2SysCfg['input_xbar'] ~= nil then
      for _, input_xbar in ipairs(cpu2SysCfg['input_xbar']) do
        req:add("XBAR_INPUT", input_xbar.input, "Secondary core")
        globals.syscfg:addEntry('input_xbar', input_xbar)
      end
    end

    if cpu2SysCfg['ecap'] ~= nil then
      for _, ecap in ipairs(cpu2SysCfg['ecap']) do
        req:add("CAP", ecap.unit, "Secondary core")
        ecap.core = 2
        globals.syscfg:addEntry('ecap', ecap)
      end
    end

    if cpu2SysCfg['adc'] ~= nil then
      for _, adc in ipairs(cpu2SysCfg['adc']) do
        req:add('ADC %s' % {adc.unit}, -1, "Secondary core")
        adc.core = 2
        globals.syscfg:addEntry('adc', adc)
      end
    end

    if cpu2SysCfg['dac'] ~= nil then
      for _, dac in ipairs(cpu2SysCfg['dac']) do
        req:add('DAC %s' % {dac.unit}, -1, "Secondary core")
        dac.core = 2
        globals.syscfg:addEntry('dac', dac)
      end
    end
  end

  function Cpu2:getDirectFeedthroughCode()
    return "Explicit use of CLOCK via target block not supported."
  end

  function Cpu2:finalize(f)
    if static.numInstances ~= 1 then
      return 'There should be only one (implicit) instance of the Cpu2 block.'
    end

    f.Include:append('ipc.h')

    local cpu2BootCode
    if Target.Variables.targetCore == 1 then
      cpu2BootCode = globals.target.getCpu2BootCode()
    else
      cpu2BootCode = globals.target.getCpu2BootCodeCpu2()
    end
    if type(cpu2BootCode) == 'string' then
      return cpu2BootCode
    end

    if cpu2BootCode.declarations ~= nil then
      f.Declarations:append(cpu2BootCode.declarations)
    end
    f.PostInitCode:append(cpu2BootCode.code)
    return f
  end

  return Cpu2
end

return Module

