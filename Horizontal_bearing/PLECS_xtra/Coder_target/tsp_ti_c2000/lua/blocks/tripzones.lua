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
  trip_zones_configured = {},
  trip_signal_groups_configured = {}
 }

function Module.getBlock(globals)

  local TripZones = require('blocks.block').getBlock(globals)
  TripZones["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function TripZones:createImplicit(req)

    -- process digital trip inputs
    local z = 1
    while Target.Variables['Tz%iEnable' % {z}] ~= nil do
      if Target.Variables['Tz%iEnable' % {z}] == 1 then
        local gpio = Target.Variables['Tz%iGpio' % {z}]
        if type(gpio) ~= 'number' or gpio ~= gpio or math.floor(gpio) ~= gpio or gpio < 0 then
          return 'TZ %i GPIO must be a non-negative integer.' % {z}
        end
        globals.target.allocateGpio(gpio, {}, req, 'TZ %i GPIO' % {z})
        static.trip_zones_configured[z] = {
           gpio = gpio
        }
      end
      z = z+1
    end

    -- process analog trip inputs
    local comps_used = {}
    local i = 1
    while (Target.Variables['AnTrip%iEnable' % {i}] ~= nil) do
      if Target.Variables['AnTrip%iEnable' % {i}] == 1 then
        local pin
        if (Target.Variables['AnTrip%iInputType' % {i}] == nil) or (Target.Variables['AnTrip%iInputType' % {i}] == 1) then
          pin = '%s%i' % {
            string.char(64 + Target.Variables['AnTrip%iAdcUnit' % {i}]),
            Target.Variables['AnTrip%iAdcChannel' % {i}]
          }
        else
          pin = 'PGA%i' % {Target.Variables['AnTrip%iPgaUnit' % {i}]}
        end
        local comps = globals.target.getTargetParameters()['comps']
        if comps == nil then
          return "Analog compare inputs are not supported by this target."
        end
        local comp = comps.positive[pin]
        if comp == nil then
          return "No comparator found for pin %s." % {pin}
        end
        if comps_used[comp[1]] ~= nul then
          return "Duplicate use of COMP %i." % comp[1]
        end
        comps_used[comp[1]] = true
        local group = string.char(64 + Target.Variables['AnTrip%iSignal' % {i}])

        static.trip_signal_groups_configured[group] = true
        local comp_obj = self:makeBlock('comp')

        local threshold_low = Target.Variables['AnTrip%iThresholdLow' % {i}]
        local threshold_high = Target.Variables['AnTrip%iThresholdHigh' % {i}]
        if (threshold_low < 0) or (threshold_low > 3.3) then
          return "Lower protection threshold out of range."
        end
        if (threshold_high < 0) or (threshold_high > 3.3) then
          return "Upper protection threshold out of range."
        end
        if threshold_low >= threshold_high then
          return "Lower protection threshold must be set below upper threshold."
        end
        comp_obj:createImplicit(comp[1], {
          pin_mux = comp[2],
          trip_in = globals.target.getTargetParameters().trip_groups[group],
          window = {
            threshold_low = threshold_low,
            threshold_high = threshold_high
          }
        }, req, 'Analog trip %i' % {i})
      end
      i = i + 1
    end

    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    if driverLibTarget then
      for z, par in pairs(static.trip_zones_configured) do
        req:add("XBAR_INPUT", z,"Trip zones")
        globals.syscfg:addEntry('input_xbar', {
          gpio = par.gpio,
          input = z,
        })
        globals.syscfg:addEntry('gpio', {
          unit = par.gpio,
          direction = "in",
        })
      end
    end
  end

  function TripZones:getDirectFeedthroughCode()
    return "Explicit use of TripZones via target block not supported."
  end

  function TripZones:isTripZoneConfigured(zone)
    return (static.trip_zones_configured[zone] ~= nil)
  end

  function TripZones:isTripSignalGroupConfigured(group)
    return (static.trip_signal_groups_configured[group] ~= nil)
  end

  function TripZones:isAnyTripZoneOrGroupConfigured()
    return (next(static.trip_zones_configured) ~= nil) or
            (next(static.trip_signal_groups_configured) ~= nil)
  end

  function TripZones:finalize(c)
    if static.numInstances ~= 1 then
      return
          'There should be only one (implicit) instance of the TripZones block.'
    end

    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    if not driverLibTarget then
      for z, par in pairs(static.trip_zones_configured) do
        c.PreInitCode:append("PLX_PWR_configureTZGpio(%i, %i);" %
                               {z, par.gpio})
      end
    end
    return c
  end

  return TripZones
end

return Module
