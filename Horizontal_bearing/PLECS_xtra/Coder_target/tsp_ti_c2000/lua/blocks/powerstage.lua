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

local static = {
  numInstances = 0,
  numChannels = 0,
  instances = {},
  finalized = nil
}

function Module.getBlock(globals)

  local Powerstage = require('blocks.block').getBlock(globals)
  Powerstage["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Powerstage:getEnableCode()
    -- TODO: maybe we need to issue this statement once for each task?
    if self.enable_code_generated == nil then
      -- only do this once
      self.enable_code_generated = true
      return 'PLXHAL_PWR_syncdPwmEnable();'
    end
  end

  function Powerstage:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    Require:add("Powerstage Control")

    table.insert(static.instances, self.bid)

    for _, b in ipairs(globals.instances) do
      if b:getType() == 'tripzones' then
        self.tripzones_obj = b
        break
      end
    end

    if self.tripzones_obj == nil then
      return 'TSP exception: TZs object not found.'
    end

    self.deprecated = (Block.Mask.IsDeprecated == 1)

    local ts = Block.Task["SampleTime"]
    if ts[1] == 0 then
      return "Invalid sample time."
    end
    self['sample_time'] = ts[1]
    self['task_name'] = Block.Task["Name"]
    -- this property is a global setting and can be used an accessed by other
    -- objects (e.g. epwm)
    self['force_safe'] = (Block.Mask.PwmSafeState == 1)

    if Block.Mask.EnableSignal == 1 then
      self["enable_gpio"] = Block.Mask.EnableSignalGpio
      self["enable_pol"] = (Block.Mask.EnableSignalPolarity == 2)
      globals.target.allocateGpio(Block.Mask.EnableSignalGpio, {}, Require)

      globals.syscfg:addEntry('gpio', {
        unit = Block.Mask.EnableSignalGpio,
        direction = "out",
        type = "pp",
      })
    end

    self.trip_zones_configured = {}
    if self.deprecated then
      if self.tripzones_obj:isAnyTripZoneOrGroupConfigured() then
        return 'Please replace deprecated Powerstage Protection block.'
      end
      for z = 1, 3 do
        if Block.Mask['tz%i_gpio' % {z}] == Block.Mask['tz%i_gpio' % {z}] then
          self['tz%i_gpio' % {z}] = Block.Mask['tz%i_gpio' % {z}]
          globals.target.allocateGpio(Block.Mask['tz%i_gpio' % {z}], {}, Require)
          self.trip_zones_configured[z] = true
        end
      end
    end

    -- trip zone activation
    self.trip_zones = {}
    local z = 1
    while Block.Mask['Tz%iMode' % {z}] ~= nil do
      if Block.Mask['Tz%iMode' % {z}] ~= 1 then
        if not self.tripzones_obj:isTripZoneConfigured(z) then
          return 'Please configure TZ%i under Coder Options -> Target -> Protections.' % {z}
        end
        if Block.Mask['Tz%iMode' % {z}] == 2 then
          self.trip_zones[z] = 'cbc'
        elseif Block.Mask['Tz%iMode' % {z}] == 3 then
          self.trip_zones[z] = 'osht'
        end
      end
      z = z + 1
    end

    -- trip signal group activation
    self.trip_signal_groups = {}
    local s = 1
    while Block.Mask['Tsig%sMode' % {string.char(64 + s)}] ~= nil do
      local group = '%s' % {string.char(64 + s)}
      if Block.Mask['Tsig%sMode' % {group}] == 2 then
        if not self.tripzones_obj:isTripSignalGroupConfigured(group) then
          return 'Please configure trip signal %s under Coder Options -> Target -> Protections.' % {group}
        end
        self.trip_signal_groups[group] = 'osht'
      end
      s = s + 1
    end

    OutputCode:append("{")
    OutputCode:append("  if((%s) > 0){" % {Block.InputSignal[1][1]})
    OutputCode:append("   PLXHAL_PWR_setEnableRequest(true);")
    OutputCode:append("  } else {")
    OutputCode:append("   PLXHAL_PWR_setEnableRequest(false);")
    OutputCode:append("  }")
    OutputCode:append("}")

    OutputSignal:append("PLXHAL_PWR_isEnabled()")

    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    if driverLibTarget then
      -- for deprecated block
      local tzpgio = {}
      for z = 1, 3 do
        if self['tz%i_gpio' % {z}] ~= nil then
          Require:add("XBAR_INPUT", z)
          globals.syscfg:addEntry('input_xbar', {
            gpio = self['tz%i_gpio' % {z}],
            input = z,
          })
          globals.syscfg:addEntry('gpio', {
            unit = self['tz%i_gpio' % {z}],
            direction = "in",
          })
        end
      end
    end

    return {
      InitCode = InitCode,
      OutputCode = OutputCode,
      OutputSignal = {OutputSignal},
      Require = Require,
      UserData = {bid = Powerstage:getId()}
    }
  end

  function Powerstage:isDeprecated()
    return self.deprecated
  end

  function Powerstage:isTripZoneConfigured(zone)
    return (self.trip_zones_configured[zone]) or (self.tripzones_obj:isTripZoneConfigured(zone))
  end

  function Powerstage:getTripZoneMode(zone)
    return self.trip_zones[zone]
  end

  function Powerstage:getTripSignalGroupModes()
    return self.trip_signal_groups
  end

  function Powerstage:finalizeThis(c)
    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    -- for deprecated block
    if not driverLibTarget then
      for z = 1, 3 do
        if self['tz%i_gpio' % {z}] ~= nil then
          c.PreInitCode:append("PLX_PWR_configureTZGpio(%i, %i);" %
                               {z, self['tz%i_gpio' % {z}]})
        end
      end
    end

    local ps_rate = math.floor(1 / self['sample_time'] + 0.5)

    c.PreInitCode:append("{")
    c.PreInitCode:append('PLX_PWR_sinit();')
    if self['enable_gpio'] ~= nil then
      c.PreInitCode:append('PLX_DIO_sinit();')
      c.PreInitCode:append('static PLX_DIO_Obj_t doutObj;')
      c.PreInitCode:append(
          'PLX_DIO_Handle_t doutHandle = PLX_DIO_init(&doutObj, sizeof(doutObj));')

      c.PreInitCode:append("  PLX_DIO_OutputProperties_t props = {0};")
      if self.enable_pol == true then
        c.PreInitCode:append("  props.enableInvert = false;")
      else
        c.PreInitCode:append("  props.enableInvert = true;")
      end
      c.PreInitCode:append("PLX_DIO_configureOut(doutHandle, %i, &props);" %
                               {self.enable_gpio})
      c.PreInitCode:append("PLX_PWR_configure(doutHandle, %i);" % {ps_rate})
    else
      c.PreInitCode:append("PLX_PWR_configure(0, %i);" % {ps_rate})
    end
    c.PreInitCode:append("}")

    return c
  end

  function Powerstage:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_power.h')

    c.Declarations:append('void PLXHAL_PWR_setEnableRequest(bool aEnable){');
    c.Declarations:append('  PLX_PWR_setEnableRequest(aEnable);');
    c.Declarations:append('  PLX_PWR_runFsm();');
    c.Declarations:append('}');

    c.Declarations:append('bool PLXHAL_PWR_isEnabled(){');
    c.Declarations:append('  return PLX_PWR_isEnabled();');
    c.Declarations:append('}');

    c.Declarations:append('void PLXHAL_PWR_syncdPwmEnable(){');
    c.Declarations:append('  PLX_PWR_syncdSwitchingEnable();');
    c.Declarations:append('}');

    for _, bid in pairs(static.instances) do
      local Powerstage = globals.instances[bid]
      local c = Powerstage:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Powerstage
end

return Module
