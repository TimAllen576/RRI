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

  local SysCfg = require('blocks.block').getBlock(globals)
  SysCfg["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function SysCfg:getDirectFeedthroughCode()
    return "Explicit use of SysCfg:getDirectFeedthroughCode via target block not supported."
  end

  function SysCfg:finalize(f)
    if static.numInstances ~= 1 then
      return 'There should be only one (implicit) instance of the SysCfg block.'
    end

    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    if not driverLibTarget then
      return
    end

	f.Include:append('pin_map.h')
	f.Include:append('gpio.h')
	f.Include:append('xbar.h')
	f.Include:append('asysctl.h')
	f.Include:append('sysctl.h')

    sysCfg =  globals.syscfg:get()

    if (Target.Variables.targetCore ~=nil) and (Target.Variables.targetCore == 2) then
      filename = "%s/%s_syscfg.txt" % {Target.Variables.BUILD_ROOT, Target.Variables.BASE_NAME}
      local file, e = io.open(filename, "w")
      if file == nil then
        return e
      end
      io.output(file)
      io.write(dump(sysCfg));
      file.close()
      return
    end

    print(dump(sysCfg))

    f.PreInitCode:append("{ // early system configuration")
    f.PostInitCode:append("{ // late system configuration")

    f.PreInitCode:append("PLX_DIO_sinit();")
    if sysCfg['gpio'] ~= nil then
      for _, gpio in ipairs(sysCfg['gpio']) do
        -- configure hardware
        local type = 'GPIO_PIN_TYPE_STD'
        if gpio['pullup'] == 'enabled' then
          type = '%s | GPIO_PIN_TYPE_PULLUP' % {type}
        end
        if gpio['direction'] == 'out' then
          if gpio['type'] == 'od' then
            type = 'GPIO_PIN_TYPE_OD'
          end
          f.PostInitCode:append('GPIO_setPadConfig(%i, %s);' % {gpio['unit'], type})
          f.PostInitCode:append('GPIO_setDirectionMode(%i, GPIO_DIR_MODE_OUT);' % {gpio['unit']})
        else
          f.PreInitCode:append('GPIO_setPadConfig(%i, %s);' % {gpio['unit'], type})
          f.PreInitCode:append('GPIO_setDirectionMode(%i, GPIO_DIR_MODE_IN);' % {gpio['unit']})
        end
        if gpio.core == 2 then
          f.PreInitCode:append('GPIO_setMasterCore(%i, GPIO_CORE_CPU2);' % {gpio['unit']})
        end
        local hasAnalogMode = globals.target.getTargetParameters()['gpios']['has_analog_mode']
        if (hasAnalogMode ~= nil) and (hasAnalogMode[gpio['unit']]) then
          f.PreInitCode:append('GPIO_setAnalogMode(%i, GPIO_ANALOG_DISABLED);' % {gpio['unit']})
        end
      end
    end

    if sysCfg['sci'] ~= nil then
      for _, sci in ipairs(sysCfg['sci']) do
        unit_n = 1+string.byte(sci["unit"])-string.byte('A')
        f.PostInitCode:append([[
          GPIO_setPinConfig(%(rxgpio)s);
          GPIO_setPinConfig(%(txgpio)s);]] % {rxgpio = sci.pinconf[1], txgpio = sci.pinconf[2], unit_n = unit_n})
        if sci.core == 2 then
          unit_n = 1+string.byte(sci["unit"])-string.byte('A')
          f.PreInitCode:append("SysCtl_selectCPUForPeripheral(SYSCTL_CPUSEL5_SCI, %(unit_n)i, SYSCTL_CPUSEL_CPU2);" % {unit_n = unit_n})
        end
      end
    end

    if sysCfg['epwm'] ~= nil then
      for _, epwm in ipairs(sysCfg['epwm']) do
        if epwm.pinconf ~= nil then
          for _, config in ipairs(epwm.pinconf) do
            f.PostInitCode:append("GPIO_setPinConfig(%s);" % {config})
          end
        end
        if epwm.core == 2 then
          f.PreInitCode:append("SysCtl_selectCPUForPeripheral(SYSCTL_CPUSEL0_EPWM, %i, SYSCTL_CPUSEL_CPU2);" % {epwm.unit})
        end
      end
    end

    if sysCfg['can'] ~= nil then
      for _, can in ipairs(sysCfg['can']) do
        unit_n = 1+string.byte(can["unit"])-string.byte('A')
        f.PostInitCode:append([[
          GPIO_setPadConfig(%(rxgpio_num)i, GPIO_PIN_TYPE_PULLUP);
          GPIO_setPadConfig(%(txgpio_num)i, GPIO_PIN_TYPE_PULLUP);
          GPIO_setQualificationMode(%(rxgpio_num)i, GPIO_QUAL_ASYNC);]] %
          {rxgpio_num = can["pins"][1], txgpio_num = can["pins"][2], unit_n = unit_n})
        if can.pinconf ~= nil then
          for _, config in ipairs(can.pinconf) do
            f.PostInitCode:append("GPIO_setPinConfig(%s);" % {config})
          end
        end
        if can.core == 2 then
          f.PreInitCode:append("SysCtl_selectCPUForPeripheral(SYSCTL_CPUSEL8_CAN, %(unit_n)i, SYSCTL_CPUSEL_CPU2);" % {unit_n = unit_n})
        end
      end
    end

    if sysCfg['mcan'] ~= nil then
      for _, mcan in ipairs(sysCfg['mcan']) do
        f.PostInitCode:append([[
          GPIO_setPadConfig(%(rxgpio_num)i, GPIO_PIN_TYPE_PULLUP);
          GPIO_setPadConfig(%(txgpio_num)i, GPIO_PIN_TYPE_PULLUP);
          GPIO_setQualificationMode(%(rxgpio_num)i, GPIO_QUAL_ASYNC);]] %
          {rxgpio_num = mcan["pins"][1], txgpio_num = mcan["pins"][2], unit_n = unit_n})
        if mcan.pinconf ~= nil then
          for _, config in ipairs(mcan.pinconf) do
            f.PostInitCode:append("GPIO_setPinConfig(%s);" % {config})
          end
        end
        if mcan.core == 2 then
          return "MCAN not supported on CPU2."
        end
      end
    end

    if sysCfg['spi'] ~= nil then
      for _, spi in ipairs(sysCfg['spi']) do
        unit_n = 1+string.byte(spi["unit"])-string.byte('A')
        for i=1,#spi.pins do
          f.PostInitCode:append([[
            GPIO_setPadConfig(%(pin)i, GPIO_PIN_TYPE_PULLUP);
            GPIO_setQualificationMode(%(pin)i, GPIO_QUAL_SYNC);
            GPIO_setPinConfig(%(conf)s);]] %
          {pin = spi.pins[i], conf = spi.pinconf[i]})
        end
        if spi.core == 2 then
          f.PreInitCode:append("SysCtl_selectCPUForPeripheral(SYSCTL_CPUSEL6_SPI, %(unit_n)i, SYSCTL_CPUSEL_CPU2);" % {unit_n = unit_n})
        end
      end
    end

    if sysCfg['qep'] ~= nil then
      for _, qep in ipairs(sysCfg['qep']) do
        for _, pin in ipairs(qep.pins) do
          f.PostInitCode:append([[
            GPIO_setPadConfig(%(pin)i, GPIO_PIN_TYPE_PULLUP);
            GPIO_setQualificationMode(%(pin)i, GPIO_QUAL_SYNC);]] %
            {pin = pin})
        end
        if qep.pinconf ~= nil then
          for _, config in ipairs(qep.pinconf) do
            f.PostInitCode:append("GPIO_setPinConfig(%s);" % {config})
          end
        end
        if qep.core == 2 then
          f.PreInitCode:append("SysCtl_selectCPUForPeripheral(SYSCTL_CPUSEL2_EQEP, %i, SYSCTL_CPUSEL_CPU2);" % {qep.unit})
        end
      end
    end

    if sysCfg['cmpss'] ~= nil then
      for _, cmpss in ipairs(sysCfg['cmpss']) do
        if cmpss.lpmux ~= nil then
          f.PreInitCode:append("ASysCtl_selectCMPLPMux(ASYSCTL_CMPLPMUX_SELECT_%(unit)i, %(mux)i);" % {unit = cmpss.unit, mux = cmpss.lpmux})
        end
        if cmpss.hpmux ~= nil then
          f.PreInitCode:append("ASysCtl_selectCMPHPMux(ASYSCTL_CMPHPMUX_SELECT_%(unit)i, %(mux)i);" % {unit = cmpss.unit, mux = cmpss.hpmux})
        end
        if cmpss.core == 2 then
          f.PreInitCode:append("SysCtl_selectCPUForPeripheral(SYSCTL_CPUSEL12_CMPSS, %i, SYSCTL_CPUSEL_CPU2);" % {cmpss.unit})
        end
      end
    end

    if sysCfg['epwm_xbar'] ~= nil then
      for _, epwm_xbar in ipairs(sysCfg['epwm_xbar']) do
        f.PostInitCode:append([[
            XBAR_setEPWMMuxConfig(XBAR_TRIP%(trip)i, %(muxconf)s);
            XBAR_enableEPWMMux(XBAR_TRIP%(trip)i, XBAR_MUX%(mux)02i);]] %
          {trip = epwm_xbar.trip, mux = epwm_xbar.mux, muxconf = epwm_xbar.muxconf})
      end
    end

    if sysCfg['input_xbar'] ~= nil then
      for _, input_xbar in ipairs(sysCfg['input_xbar']) do
        local xbarConfig
        if globals.target.getFamilyPrefix() == '28004x' then
          xbarConfig = "XBAR_setInputPin(XBAR_INPUT%(input)i, %(pin)i);"
        elseif globals.target.getFamilyPrefix() == '2837x' then
          xbarConfig = "XBAR_setInputPin(XBAR_INPUT%(input)i, %(pin)i);"
        else
          xbarConfig = "XBAR_setInputPin(INPUTXBAR_BASE, XBAR_INPUT%(input)i, %(pin)i);"
        end
        f.PreInitCode:append(xbarConfig % {pin = input_xbar.gpio, input = input_xbar.input})
      end
    end
    
    if sysCfg['ecap'] ~= nil then
      for _, ecap in ipairs(sysCfg['ecap']) do
        if ecap.core == 2 then
          f.PreInitCode:append("SysCtl_selectCPUForPeripheral(SYSCTL_CPUSEL1_ECAP, %i, SYSCTL_CPUSEL_CPU2);" % {ecap.unit})
        end
      end
    end
    
    if sysCfg['adc'] ~= nil then
      for _, adc in ipairs(sysCfg['adc']) do
        unit_n = 1+string.byte(adc["unit"])-string.byte('A')
        if adc.core == 2 then
          f.PreInitCode:append("SysCtl_selectCPUForPeripheral(SYSCTL_CPUSEL11_ADC, %i, SYSCTL_CPUSEL_CPU2);" % {unit_n})
        end
      end
    end
    
    if sysCfg['dac'] ~= nil then
      for _, dac in ipairs(sysCfg['dac']) do
        unit_n = 1+string.byte(dac["unit"])-string.byte('A')
        if dac.core == 2 then
          f.PreInitCode:append("SysCtl_selectCPUForPeripheral(SYSCTL_CPUSEL14_DAC, %i, SYSCTL_CPUSEL_CPU2);" % {unit_n})
        end
      end
    end
    
    f.PreInitCode:append("}")
    f.PostInitCode:append("}")
    return f
  end

  return SysCfg
end

return Module

