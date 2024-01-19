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

local static = {numInstances = 0, instances = {}}

function Module.getBlock(globals)

  local Comp = require('blocks.block').getBlock(globals)
  Comp["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Comp:createImplicit(comp, params, req, label)
    req:add("CMPSS", comp, label)
    self:logLine('COMP%i implicitly created.' % {comp})
    table.insert(static.instances, self.bid)

    self.comp = comp
    self.pin_mux = params.pin_mux
    self.trip_in = params.trip_in
    self.window = params.window
    self.ramp = params.ramp

    local mux = (self.comp - 1) * 2
    local muxconf
    local hpmux, lpmux
    if self.window == nil then
      -- default for ramp comparator
      muxconf = 'XBAR_EPWM_MUX%02i_CMPSS%i_CTRIPH' % {mux, self.comp}
      hpmux = params.pin_mux
    elseif self.window.threshold_high >= 3.3 then
      -- only low mux
      muxconf = 'XBAR_EPWM_MUX%02i_CMPSS%i_CTRIPH' % {mux, self.comp}
      lpmux = params.pin_mux
    elseif self.window.threshold_low <= 0 then
      -- only high mux
      muxconf = 'XBAR_EPWM_MUX%02i_CMPSS%i_CTRIPH' % {mux, self.comp}
      hpmux = params.pin_mux
    else
      -- both muxes
      muxconf = 'XBAR_EPWM_MUX%02i_CMPSS%i_CTRIPH_OR_L' % {mux, self.comp}
      lpmux = params.pin_mux
      hpmux = params.pin_mux
    end

    if globals.target.getFamilyPrefix() ~= '28004x' then
      lpmux = nil
      hpmux = nil
    end

    globals.syscfg:addEntry('cmpss', {
      unit = self.comp,
      hpmux = hpmux,
      lpmux = lpmux,
    })

    req:add("XBAR_TRIP", self.trip_in, label)
    globals.syscfg:addEntry('epwm_xbar', {
      trip = self.trip_in,
      mux = mux,
      muxconf = muxconf,
    })

    self.pin_mux = nil
    self.trip_in = nil
  end

  function Comp:checkMaskParameters(env)
    return "Explicit use of comparator via target block not supported."
  end

  function Comp:getDirectFeedthroughCode()
    return "Explicit use of comparator via target block not supported."
  end

  function Comp:finalizeThis(c)
    c.PreInitCode:append('{')
    assert(not(self.window ~= nil and self.ramp ~= nil), "Must be either window or ramp.")
    --[[
      Per TRM, we need to ensure that the trip pulse width is at least 3xTBCLK.
      This can be achieved by using the CMPSS FILTER path, but will delay the trip detection.
      Alternatively, we could use the LATCH path, but then the latch would to be cleared by PWMSYNC
      a few TBCLK (3?) before the end of the switching period (using CMPC or CMPD). This in turn,
      requires a delay of the ramp start. LATCH clearing is also affected by an advisory. Too convoluted.
    --]]
    local glitchLatencyInSysTick = math.ceil(3 * Target.Variables.sysClkMHz * 1e6 / globals.target.getPwmClock())
    local filter_prescale = 1
    -- filter latency = 1 + prescale(1+threshold)
    local filter_threshold = math.ceil((glitchLatencyInSysTick - 1)/filter_prescale) - 1
    local filter_window = filter_threshold

    if self.window ~= nil then
        c.PreInitCode:append(globals.target.getCmpssWindowComparatorEpwmTripSetupCode(
                             self.comp, {
          threshold_low = self.window.threshold_low,
          threshold_high = self.window.threshold_high,
          filter_prescale = filter_prescale,
          filter_threshold = filter_threshold,
          filter_window = filter_window
        }))
    else
        c.PreInitCode:append(globals.target.getCmpssRampComparatorEpwmTripSetupCode(
                             self.comp, {
          sync_epwm_unit = self.ramp.sync_epwm_unit,
          decrement_val = self.ramp.decrement_val,
          desired_ramp = self.ramp.desired_ramp,
          actual_ramp = self.ramp.actual_ramp,
          filter_prescale = filter_prescale,
          filter_threshold = filter_threshold,
          filter_window = filter_window
        }))
    end

    c.PreInitCode:append('}')
    return c
  end

  function Comp:finalize(c)
    c.Include:append('cmpss.h')
    c.Include:append('sysctl.h')

    if static.finalized ~= nil then
      return {}
    end

    for _, bid in pairs(static.instances) do
      local comp = globals.instances[bid]
      local c = comp:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Comp
end

return Module
