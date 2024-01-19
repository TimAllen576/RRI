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

  local Estimator = require('blocks.block').getBlock(globals)
  Estimator["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Estimator:checkMaskParameters(env)
  end

  function Estimator:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local OutputCode = StringList:new()
    local OutputSignal = StringList:new()

    table.insert(static.instances, self.bid)

    Require:add('EST-%d' % {self.instance})

    local in_Iab = 1
    local in_Vab = 2
    -- local in_Vdc = 3
    local in_RsSet = 3
    local in_ForceAngleDir = 4
    local in_Enable = 5
    -- local in_IdqSet = 7
    -- local in_EnOnlineRs = 7
    -- local in_UpdateRs = 6

    local out_the = 1
    -- local out_Idq = 2
    -- local out_1_Vdc = 3
    local out_wm = 2
    local out_state = 3
    local out_psi = 4
    -- local out_Rs_online = 5
    local out_Rs = 5
    -- local out_Idq_Ref = 8

    self.rs_is_variable = false
    if Block.Mask.R_sel == 2 and
        not string.match(Block.InputSignal[in_RsSet][1], "UNCONNECTED") then
      self.rs_is_variable = true
    end

    local inputVarName = "est%iInputData" % {self.instance}
    local outputVarName = "est%iOutputData" % {self.instance}
    OutputCode:append('PLXHAL_EST_Inputs_t %s;\n' % {inputVarName})
    OutputCode:append('PLXHAL_EST_Outputs_t %s;\n' % {outputVarName})
    OutputCode:append('%s.ia = %s;\n' %
                          {inputVarName, Block.InputSignal[in_Iab][1]})
    OutputCode:append('%s.ib = %s;\n' %
                          {inputVarName, Block.InputSignal[in_Iab][2]})
    OutputCode:append('%s.va = %s;\n' %
                          {inputVarName, Block.InputSignal[in_Vab][1]})
    OutputCode:append('%s.vb = %s;\n' %
                          {inputVarName, Block.InputSignal[in_Vab][2]})
    OutputCode:append('%s.rs = %s;\n' %
                          {inputVarName, Block.InputSignal[in_RsSet][1]})
    OutputCode:append('%s.enable = %s;\n' %
                          {inputVarName, Block.InputSignal[in_Enable][1]})
    OutputCode:append('%s.foreAngleDir = %s;\n' %
                          {inputVarName, Block.InputSignal[in_ForceAngleDir][1]})

    OutputCode:append('PLXHAL_EST_update(%i, &%s, &%s);\n' %
                          {self.instance, inputVarName, outputVarName})

    OutputSignal[out_the] = {}
    OutputSignal[out_the][1] = "%s.angle_rad" % {outputVarName}
    -- OutputSignal[out_Idq] = {}
    -- OutputSignal[out_Idq][1] = "idq_A.value[0]"
    -- OutputSignal[out_Idq][2] = "idq_A.value[1]"
    -- OutputSignal[out_1_Vdc] = {}
    -- OutputSignal[out_1_Vdc][1] = "Estimator%iOutputData.oneOverDcBus_invV" % {instance}
    OutputSignal[out_wm] = {}
    OutputSignal[out_wm][1] = "%s.fm_rps" % {outputVarName}
    OutputSignal[out_state] = {}
    OutputSignal[out_state][1] = "%s.state" % {outputVarName}

    OutputSignal[out_psi] = {}
    OutputSignal[out_psi][1] = "%s.flux_wb" % {outputVarName}

    -- OutputSignal[out_Rs_online] = {}
    -- OutputSignal[out_Rs_online][1] = "EST_getRsOnLine_Ohm(Estimator%iHandle)" % {outputVarName}

    -- OutputSignal[out_Idq_Ref] = {}
    -- OutputSignal[out_Idq_Ref][1] = "Idq_ref_A.value[0]"
    -- OutputSignal[out_Idq_Ref][2] = "Idq_ref_A.value[1]"

    OutputSignal[out_Rs] = {}
    OutputSignal[out_Rs][1] = "%s.rs_ohm" % {outputVarName}

    local dict = {}
    table.insert(dict,
                 {before = "|>BASE_NAME<|", after = Target.Variables.BASE_NAME})

    -- timing
    table.insert(dict, {
      before = "|>USER_SYSTEM_FREQ_MHz<|",
      after = Block.Mask.sysclk_MHz
    })
    table.insert(dict, {
      before = "|>USER_PWM_FREQ_kHz<|",
      after = Block.Mask.fpwm / 1000
    })
    table.insert(dict, {
      before = "|>USER_NUM_PWM_TICKS_PER_ISR_TICK<|",
      after = "%i" % {Block.Mask.pwm_per_ISR}
    })
    table.insert(dict, {
      before = "|>USER_VOLTAGE_FILTER_POLE_Hz<|",
      after = Block.Mask.vfilt_pole
    })

    -- online resistance estimation
    table.insert(dict, {
      before = "|>RsOnLine_DeltaInc_Ohm<|",
      after = Block.Mask.rs_online_inc
    })
    table.insert(dict, {
      before = "|>RsOnLine_DeltaDec_Ohm<|",
      after = Block.Mask.rs_online_dec
    })
    table.insert(dict, {
      before = "|>RsOnLine_min_Ohm<|",
      after = Block.Mask.rs_online_min
    })
    table.insert(dict, {
      before = "|>RsOnLine_max_Ohm<|",
      after = Block.Mask.rs_online_max
    })
    table.insert(dict, {
      before = "|>RsOnLine_angleDelta_rad<|",
      after = Block.Mask.rs_online_delta
    })
    table.insert(dict, {
      before = "|>RsOnLine_pole_rps<|",
      after = Block.Mask.rs_online_pole_hz * 2 * math.pi
    })

    -- zero speed operation
    table.insert(dict, {
      before = "|>USER_ZEROSPEEDLIMIT_HZ<|",
      after = Block.Mask.zero_speed
    })
    table.insert(dict, {
      before = "|>USER_FORCE_ANGLE_FREQ_Hz<|",
      after = Block.Mask.force_angle_freq
    })

    if Target.Name == "TI2806x" then
      table.insert(dict,
                   {before = "|>USER_NUM_ISR_TICKS_PER_CTRL_TICK<|", after = 1}) -- not sure if needed
      table.insert(dict, {
        before = "|>USER_NUM_CTRL_TICKS_PER_EST_TICK<|",
        after = "%i" % {Block.Mask.ISR_per_est}
      })
    end

    -- motor parameters
    table.insert(dict, {
      before = "|>USER_MOTOR_NUM_POLE_PAIRS<|",
      after = "%i" % {Block.Mask.p}
    })
    table.insert(dict, {before = "|>USER_MOTOR_TYPE<|", after = "MOTOR_TYPE_PM"})
    table.insert(dict, {before = "|>USER_MOTOR_Rs_Ohm<|", after = Block.Mask.R})
    table.insert(dict,
                 {before = "|>USER_MOTOR_Ls_d_H<|", after = Block.Mask.L[1]})
    table.insert(dict,
                 {before = "|>USER_MOTOR_Ls_q_H<|", after = Block.Mask.L[2]})
    table.insert(dict, {
      before = "|>USER_MOTOR_RATED_FLUX_VpHz<|",
      after = Block.Mask.phi * 2 * math.pi
    })

    -- 280049: not sure about
    -- pUserParams->BWc_rps
    -- pUserParams->BWdelta
    -- pUserParams->Kctrl_Wb_p_kgm2

    local srcDir = Target.Variables.TARGET_ROOT .. "/ccs/" ..
                       string.sub(Target.Name, 3)

    local error = globals.utils.copyTemplateToBuildDir(srcDir ..
                                                           "/tiinc/fast/user.h.template",
                                                       "%s_user.h" %
                                                           {
          Target.Variables.BASE_NAME
        }, dict)
    if error ~= nil then
      return error
    end

    local error = globals.utils.copyTemplateToBuildDir(srcDir ..
                                                           "/tisrc/fast/user.c.template",
                                                       "%s_user.c" %
                                                           {
          Target.Variables.BASE_NAME
        }, dict)
    if error ~= nil then
      return error
    end

    return {
      OutputCode = OutputCode,
      OutputSignal = OutputSignal,
      Require = Require,
      UserData = {bid = Estimator:getId()}
    }
  end

  function Estimator:finalizeThis(c)
    c.PreInitCode:append(
        "EST_setFlag_enableForceAngle(EstimatorHandles[%i], true);" %
            {self.instance})
    c.PreInitCode:append(
        "EST_setFlag_enableRsRecalc(EstimatorHandles[%i], false);" %
            {self.instance})

    local bgcode = [[
      if(EstimatorEnable[|<INSTANCE>|] > 0){
        if(!EstimatorWasOn[|<INSTANCE>|]){
          EST_enable(EstimatorHandles[|<INSTANCE>|]);
          EST_enableTraj(EstimatorHandles[|<INSTANCE>|]);
        }
      } else {
        EST_disable(EstimatorHandles[|<INSTANCE>|]);
        EST_disableTraj(EstimatorHandles[|<INSTANCE>|]);
      }
      EST_updateTrajState(EstimatorHandles[|<INSTANCE>|]);
      if(EST_updateState(EstimatorHandles[|<INSTANCE>|], 0.0)){
        EST_configureTraj(EstimatorHandles[|<INSTANCE>|]);
      }
      EstimatorWasOn[|<INSTANCE>|] = (EstimatorEnable[|<INSTANCE>|] > 0);
    ]]

    if self.rs_is_variable == true then
      -- this is a semi-official hack: https://e2e.ti.com/support/microcontrollers/c2000/f/171/t/851117
      bgcode = bgcode .. [[
      {
        EST_setFlag_enableRsOnLine(EstimatorHandles[|<INSTANCE>|], true);
        EST_setRsOnLine_Ohm(EstimatorHandles[|<INSTANCE>|], EstimatorRs[|<INSTANCE>|]);
        EST_setFlag_updateRs(EstimatorHandles[|<INSTANCE>|], true);
      }
      ]]
    end
    bgcode = bgcode .. [[
      EST_setFlag_enableForceAngle(EstimatorHandles[|<INSTANCE>|], (bool)(EstimatorForceAngleDir[|<INSTANCE>|] != 0));
    ]]
    bgcode = string.gsub(bgcode, '|<INSTANCE>|', '%i' % {self.instance})
    c.BackgroundTaskCodeBlocks:append(bgcode)
  end

  function Estimator:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('Controller_user.h')
    c.Include:append('userParams.h')
    c.Include:append('est.h')
    c.Include:append('ctrl.h')

    c.Declarations:append('EST_Handle EstimatorHandles[%i];' %
                              {static.numInstances})
    c.Declarations:append('USER_Params EstimatorUserParams[%i];' %
                              {static.numInstances})

    c.Declarations:append("static bool EstimatorEnable[%i];" %
                              {static.numInstances})
    c.Declarations:append("static bool EstimatorWasOn[%i];" %
                              {static.numInstances})
    c.Declarations:append("static float EstimatorRs[%i];" %
                              {static.numInstances})
    c.Declarations:append("static int EstimatorForceAngleDir[%i];" %
                              {static.numInstances})

    local dCode = [[
	void PLXHAL_EST_update(int16_t aChannel, const PLXHAL_EST_Inputs_t *aInputs, PLXHAL_EST_Outputs_t *aOutputs){
      EST_InputData_t inputData = {0, {0.0, 0.0}, {0.0, 0.0}, 0.0, 0.0};
      EST_OutputData_t outputData = {0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, {0.0, 0.0}, {0.0, 0.0}, 0, 0.0};

      MATH_Vec2 idq_ref_A;
      idq_ref_A.value[0] = 0;
      idq_ref_A.value[1] = 0;
      idq_ref_A.value[0] = EST_getIdRated_A(EstimatorHandles[aChannel]);
      EST_updateId_ref_A(EstimatorHandles[aChannel], (float32_t *)&(idq_ref_A.value[0]));
      inputData.Iab_A.value[0] = aInputs->ia;
      inputData.Iab_A.value[1] = aInputs->ib;
      inputData.Vab_V.value[0] = aInputs->va;
      inputData.Vab_V.value[1] = aInputs->vb;
      inputData.dcBus_V = 1;
      inputData.speed_ref_Hz = aInputs->foreAngleDir;
      inputData.speed_int_Hz = aInputs->foreAngleDir;
      EST_run(EstimatorHandles[aChannel], &inputData, &outputData);
      EST_setIdq_ref_A(EstimatorHandles[aChannel], &idq_ref_A);
      MATH_Vec2 idq_A;
      EST_getIdq_A(EstimatorHandles[aChannel], &idq_A);
      aOutputs->angle_rad = outputData.angle_rad;
      aOutputs->fm_rps = outputData.fm_rps;
      aOutputs->state = EST_getState(EstimatorHandles[aChannel]);
      aOutputs->flux_wb = EST_getFlux_Wb(EstimatorHandles[aChannel]);
      aOutputs->rs_ohm = EST_getRs_Ohm(EstimatorHandles[aChannel]);
      // for background loop
      EstimatorRs[aChannel] = aInputs->rs;
      EstimatorEnable[aChannel] = aInputs->enable;
      EstimatorForceAngleDir[aChannel] = aInputs->foreAngleDir;
    }
	]]
    c.Declarations:append(dCode)

    local code = [[
    {
      int i;
      for(i=0; i<%d; i++)
      {
	    USER_setParams(&EstimatorUserParams[i]);
	    EstimatorUserParams[i].flag_bypassMotorId = true;
	    USER_setParams_priv(&EstimatorUserParams[i]);
        EstimatorHandles[i] = EST_initEst(i);
        EST_setParams(EstimatorHandles[i], &EstimatorUserParams[i]);
        EstimatorEnable[i] = false;
        EstimatorRs[i] = 0;
        EstimatorForceAngleDir[i] = false;
        EstimatorWasOn[i] = false;
      }
    }
    ]]
    c.PreInitCode:append(code % {static.numInstances})

    for _, bid in pairs(static.instances) do
      local est = globals.instances[bid]
      local c = est:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Estimator
end

return Module
