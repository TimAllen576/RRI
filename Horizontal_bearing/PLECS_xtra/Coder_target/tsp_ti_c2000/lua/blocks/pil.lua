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

local static = {numInstances = 0, numChannels = 0, instances = {}}

function Module.getBlock(globals)

  local Pil = require('blocks.block').getBlock(globals)
  Pil["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Pil:createImplicit()
    table.insert(static.instances, self.bid)
    self.read_probes = {}
    self.override_probes = {}
    self.calibrations = {}

    return "%sProbes_t %s_probes;" %
               {Target.Variables.BASE_NAME, Target.Variables.BASE_NAME}
  end

  function Pil:registerReadProbe(name, par)
    self.read_probes[name] = par
  end

  function Pil:registerOverrideProbe(name, par)
    self.override_probes[name] = par
  end

  function Pil:registerCalibration(name, par)
    self.calibrations[name] = par
  end

  function Pil:checkMaskParameters(env)
    return "Explicit use of PIL via target block not supported."
  end

  function Pil:getDirectFeedthroughCode()
    return "Explicit use of PIL via target block not supported."
  end

  function Pil:finalize(c)
    c.PilHeaderDeclarations:append("// PIL Probes")
    c.PilHeaderDeclarations:append("typedef struct {")

    c.PreInitCode:append("{")
    for name, params in pairs(self.read_probes) do
      local type = params['type']
      c.PilHeaderDeclarations:append("  %s %s;" % {type, name})
      c.Declarations:append("PIL_SYMBOL_DEF(%s_probes_%s, 0, 1.0, \"\");" %
                                {Target.Variables.BASE_NAME, name})
    end

    for name, params in pairs(self.override_probes) do
      local type = params['type']
      c.PilHeaderDeclarations:append("  %s %s;" % {type, name})
      c.PilHeaderDeclarations:append("  %s %s_probeV;" % {type, name})
      c.PilHeaderDeclarations:append("  %s %s_probeF;" % {"int16_t", name})
      c.Declarations:append("PIL_SYMBOL_DEF(%s_probes_%s, 0, 1.0, \"\");" %
                                {Target.Variables.BASE_NAME, name})
      c.PreInitCode:append("INIT_OPROBE(%s_probes.%s);" %
                               {Target.Variables.BASE_NAME, name})
    end

    for name, params in pairs(self.calibrations) do
      local type = params['type']
      c.PilHeaderDeclarations:append("  %s %s;" % {type, name})
      c.Declarations:append(
          "PIL_SYMBOL_CAL_DEF(%s_probes_%s, 0, 1.0, \"\", %f, %f, %f);" %
              {
                Target.Variables.BASE_NAME, name, params['min'], params['max'],
                params['val']
              })
      c.PreInitCode:append("%s_probes.%s = %f;\n" %
                               {Target.Variables.BASE_NAME, name, params['val']})
    end
    c.PreInitCode:append("}")

    c.PilHeaderDeclarations:append("} %sProbes_t;" %
                                       {Target.Variables.BASE_NAME})

    c.Declarations:append("extern %sProbes_t %s_probes;" %
                              {
          Target.Variables.BASE_NAME, Target.Variables.BASE_NAME
        })

    -- see if the model contains epwm blocks
    local epwm_obj
    for _, b in ipairs(globals.instances) do
      if b:getType() == 'epwm' then
        epwm_obj = b
      end
    end

    -- see if the model contains a powerstage block
    local powerstage_obj
    for _, b in ipairs(globals.instances) do
      if b:getType() == 'powerstage' then
        powerstage_obj = b
      end
    end

    local enableActuationCode = ''
    local disableActuationCode = ''
    if powerstage_obj ~= nil then
      c.Include:append('plx_power.h')
      enableActuationCode = 'PLX_PWR_setPilMode(false);'
      disableActuationCode = 'PLX_PWR_setPilMode(true);'
    elseif epwm_obj ~= nil then
      c.Declarations:append('extern bool EpwmForceDisable;')
      enableActuationCode = 'EpwmForceDisable = false;'
      disableActuationCode = 'EpwmForceDisable = true;'
    end

    local startTimersCode = [[
      CpuTimer0Regs.TCR.bit.TSS = 0;
      CpuTimer1Regs.TCR.bit.TSS = 0;
    ]]
    local stopTimersCode = [[
      CpuTimer0Regs.TCR.bit.TSS = 1;
      CpuTimer1Regs.TCR.bit.TSS = 1;
    ]]
    if epwm_obj ~= nil then
      c.Include:append('plx_pwm.h')
      startTimersCode = startTimersCode .. [[
        PLX_PWM_enableAllClocks();
      ]]
      stopTimersCode = stopTimersCode .. [[
        PLX_PWM_disableAllClocks();
      ]]
    end

    local callbackCode = [[
	void PilCallback(PIL_Handle_t aPilHandle, PIL_CtrlCallbackReq_t aCallbackReq)
	{
		switch(aCallbackReq)
		{
			case  PIL_CLBK_ENTER_NORMAL_OPERATION_REQ:
				// allow power
			    PIL_inhibitPilSimulation(aPilHandle);
	            %(enable_actuation_code)s
				return;

			case PIL_CLBK_LEAVE_NORMAL_OPERATION_REQ:
				// disable power
				%(disable_actuation_code)s
			    PIL_allowPilSimulation(aPilHandle);
				return;

			case PIL_CLBK_INITIALIZE_SIMULATION:
			    %(base_name)s_initialize(0.0);
				return;

			case PIL_CLBK_TERMINATE_SIMULATION:
			     return;

			case PIL_CLBK_STOP_TIMERS:
				// stopping relevant timers
                %(stop_timers_code)s
				return;

			case PIL_CLBK_START_TIMERS:
				// starting relevant timers
                %(start_timers_code)s
				return;
	   }
	}
	]] % {
	  base_name = Target.Variables.BASE_NAME,
	  enable_actuation_code = enableActuationCode,
	  disable_actuation_code = disableActuationCode,
	  stop_timers_code = stopTimersCode,
	  start_timers_code = startTimersCode
	}
    c.Declarations:append(callbackCode)
    c.PreInitCode:append(
        "PIL_setCtrlCallback(PilHandle, (PIL_CtrlCallbackPtr_t)PilCallback);")
    c.PreInitCode:append("PIL_requestNormalMode(PilHandle);")
    return c
  end

  return Pil
end

return Module
