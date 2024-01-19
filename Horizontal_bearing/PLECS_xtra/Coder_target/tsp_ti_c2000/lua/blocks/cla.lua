--[[
  Copyright (c) 2021-2022 by Plexim GmbH
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

--[[
TODO:
- handle background task
- figure out how to trigger on-time init task
- does it make sense to allow tasks that are periodically triggered by s/w?
- add resource management
]]

local static = {numInstances = 0, instances = {}, finalized = nil}

function Module.getBlock(globals)

  local Cla = require('blocks.block').getBlock(globals)
  Cla["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1
  
  
  function Cla:checkMaskParameters(env)
     if (globals.target.getFamilyPrefix() ~= '28004x') and
       (globals.target.getFamilyPrefix() ~='2837x') and
       (globals.target.getFamilyPrefix() ~='2838x') then
       return 'CLA is not supported for this chip.'
     end
  end
  
  function Cla:getDirectFeedthroughCode(par)
    local Require = ResourceList:new()
    local OutputSignal = StringList:new()
    local TriggerOutputSignal = StringList:new()
    
    table.insert(static.instances, self.bid)
    
    local taskNum = Block.Mask.ClaTask
    local isBackgroundTask = false
    if (Block.Mask.ClaTaskTrig == 2) and (Block.Mask.ClaTaskType == 2) then
      isBackgroundTask = true
      taskNum = 8
    end
    
    -- TODO: resource management - background is task 8
    
    self.task = {
      is_background = isBackgroundTask,
      num = taskNum,
      declarations = par.Declarations,
      include = par.Include,
      code = par.Code
    }
    
    TriggerOutputSignal:append("{modtrig = {bid = %i}}" % {Cla:getId()})
    
    return {
      OutputSignal = {TriggerOutputSignal},
      Require = Require,
      UserData = {bid = Cla:getId()}
    }
  end
  
  function Cla:getNonDirectFeedthroughCode()
    local trig = Block.InputSignal[1][1]
    
    if Block.Mask.ClaTaskTrig == 1 then
      -- hardware trigger
      if string.find(trig, "UNCONNECTED") then
        return 'Trigger input port can not be left unconnected.'
      end
      -- verify proper connection of trigger point
      trig = trig:gsub("%s+", "") -- remove whitespace
      if trig:sub(1, #"{modtrig") ~= "{modtrig" then
        return "This block must be connected to a 'Task trigger' port."
      end
      self['trig_exp'] = trig
    end

    return {}
  end
  
  function Cla:setSinkForTriggerSource(sink)
    if self['trig_exp'] == nil then
      -- no triggering
      return
    end
    
    local trig = eval(self['trig_exp'])['modtrig']
    local triggerBlock = globals.instances[trig['bid']]
    self['trig'] = triggerBlock

    if sink ~= nil then
      self:logLine('Cla task connected to %s of %d.' % {sink.type, sink.bid})
      if self[sink.type] == nil then
        self[sink.type] = {}
      end
      table.insert(self[sink.type], globals.instances[sink.bid])
    end

    if self.downstreamConnectionsPropagated == nil then
      -- top of chain
      if self['trig'] ~= nil then
        self['trig']:setSinkForTriggerSource({type = 'modtrig', bid = self.bid})
      end
      self.downstreamConnectionsPropagated = true;
    end
  end

  function Cla:propagateTriggerSampleTime(ts)
    if ts ~= nil then
      self:logLine('Cla trigger sample time propagated to %f.' % {ts})
      self['ts'] = ts
      if self['modtrig'] ~= nil then
        for _, b in ipairs(self['modtrig']) do
          local f = b:propagateTriggerSampleTime(ts)
        end
      end
    end
  end

  function Cla:getTriggerSampleTime()
    return self['ts']
  end
  
  function Cla:finalizeThis(c)
    local cla_trig = 'NOPERPH'
    local trigSelText
    if self['trig'] ~= nil then
      print(self.trig:getType())
      if self.trig:getType() == 'timer' then
        local unit = self.trig:getParameter('unit')
        trigSelText = "CPU Timer%i" % {unit}
        cla_trig = 'TINT%i' % {unit}
      elseif self.trig:getType() == 'adc' then
        local unit = self.trig:getParameter('adc')
        trigSelText = 'ADC%s' % {string.char(65 + unit)}
        cla_trig = 'ADC%sINT1' % {string.char(65 + unit)}
      elseif (self.trig:getType() == 'epwm_basic') or
          (self.trig:getType() == 'epwm_var') or 
          (self.trig:getType() == 'epwm_basic_pcc') or 
          (self.trig:getType() == 'epwm_var_pcc') then
        local unit = self.trig:getParameter('first_unit')
        trigSelText = 'EPWM%i' % {unit}
        cla_trig = 'EPWM%iINT' % {unit}
      else
        return 'CLA can only be triggered by a Timer, PWM or ADC block.'
      end

      -- determine if this block is supplying the actual base task trigger
      self['is_mod_trigger'] = false
      if self['modtrig'] ~= nil then
        for _, b in ipairs(self['modtrig']) do
          if b:getType() == 'tasktrigger' then
            self['is_mod_trigger'] = true
          end
        end
      end
    end
  
    local declarations = [[
         __interrupt void Cla1Task%(task_num)i();
    ]]
     
    if not self.task.is_background then
      if not self['is_mod_trigger'] then
        declarations = declarations .. [[
	    __interrupt void cla1_task%(task_num)i_isr(void)
        {
          PieCtrlRegs.PIEACK.bit.ACK11 = 1;
        }
        ]] 
      end
    end
    c.Declarations:append(declarations % {
      task_num = self.task.num
    })
    
    if not self.task.is_background then
      init = [[
        EALLOW;
#if 0
        PieVectTable.CLA1_INT%(task_num)i  = &%(cla_isr)s;
#else
        PieVectTable.CLA1_%(task_num)i_INT  = &%(cla_isr)s;
#endif
        EDIS;

        EALLOW;
#if 0
        la1Regs.MVECT%(task_num)i = (Uint16)((Uint32)&Cla1Task%(task_num)i -(Uint32)&Cla1Prog_Start);
#else
#pragma diag_suppress=770
        Cla1Regs.MVECT%(task_num)i = (uint16_t)&Cla1Task%(task_num)i;
#endif
        EDIS;

        EALLOW;
#if 0
        Cla1Regs.MPISRCSEL1.bit.PERINT%(task_num)iSEL  = CLA_INT%(task_num)i_NONE;
     //Cla1Regs.MIER.all                           = 0x00FF;
#endif
        EDIS;
      
        EALLOW;
#if 0
        Cla1Regs.MPISRCSEL1.bit.PERINT%(task_num)iSEL  = CLA_INT%(task_num)i_NONE;
#else
        DmaClaSrcSelRegs.%(tasksrcsel_reg)s.bit.TASK%(task_num)i = CLA_TRIG_%(cla_trig)s;
#endif
        EDIS;
   
        EALLOW;
        Cla1Regs.MIER.bit.INT%(task_num)i = 1U;
        EDIS;

        PieCtrlRegs.PIEIER11.bit.INTx%(task_num)i = 1U;
      ]]
      local cla_isr = 'cla1_task%i_isr' % {self.task.num}
      if self['is_mod_trigger'] then
        cla_isr = '%s_baseTaskInterrupt' % {Target.Variables.BASE_NAME}
      end
    
      c.PreInitCode:append(init % {
        task_num = self.task.num,
        cla_trig = cla_trig,
        cla_isr = cla_isr,
        tasksrcsel_reg = 'CLA1TASKSRCSEL%i' % {math.floor(self.task.num/4)+1}
      })
    else
      local init = [[
        EALLOW;
#pragma diag_suppress=770
        Cla1Regs._MVECTBGRND = (uint16_t)&Cla1Task%(task_num)i;
        Cla1Regs._MCTLBGRND.bit.TRIGEN = 0U;
        DmaClaSrcSelRegs.CLA1TASKSRCSEL2.bit.TASK%(task_num)i = 0U; //Software
        Cla1Regs._MCTLBGRND.bit.BGEN = 1U;
        EDIS;
      ]]
      c.PreInitCode:append(init % {
        task_num = self.task.num
      })
    end
    
    if self['is_mod_trigger'] then
      local itFunction
      if self.trig:getType() == 'adc' then
        local unit = self.trig:getParameter('adc')
        itFunction = [[
          interrupt void %(base_name)s_baseTaskInterrupt(void)
          {
            PieCtrlRegs.PIEACK.bit.ACK11 = 1;
            %(adc_reg)s.ADCINTFLGCLR.bit.ADCINT1 = 1;
            IER |= M_INT11;
            DISPR_dispatch();
          }
        ]] % { 
          base_name = Target.Variables.BASE_NAME,
          adc_reg = 'Adc%sRegs' % {string.char(string.byte('a') + unit)}
        }
      elseif (self.trig:getType() == 'epwm_basic') or
        (self.trig:getType() == 'epwm_var') or 
        (self.trig:getType() == 'epwm_basic_pcc') or 
        (self.trig:getType() == 'epwm_var_pcc') then
        itFunction = [[
          interrupt void %(base_name)s_baseTaskInterrupt(void)
          {
            PieCtrlRegs.PIEACK.bit.ACK11 = 1;
            %(epwm_reg)s.ETCLR.bit.INT = 1;
            IER |= M_INT11;
            DISPR_dispatch();
          }
        ]] % { 
          base_name = Target.Variables.BASE_NAME,
          epwm_reg = 'EPwm%iRegs' % {self.trig:getParameter('first_unit')}
        }     
      else
        itFunction = [[
          interrupt void %(base_name)s_baseTaskInterrupt(void)
          {
            PieCtrlRegs.PIEACK.bit.ACK11 = 1;
            IER |= M_INT11;
            DISPR_dispatch();
          }
        ]] % {base_name = Target.Variables.BASE_NAME}
      end
      c.Declarations:append(itFunction)
      c.InterruptEnableCode:append('IER |= M_INT11;')
    end
    
    if self.task.declarations ~= nil then
      for _, v in ipairs(self.task.declarations) do
        c.ClaDeclarations:append(v)
      end
    end
    
    if self.task.include ~= nil then
      for _, v in ipairs(self.task.include) do
        c.ClaInclude:append(v)
      end
    end
    
	if self.task.is_background then
	  c.ClaCode:append('__attribute__((interrupt("background"))) void Cla1Task%(task_num)i(void)' % {task_num = self.task.num})
	else
	  c.ClaCode:append('__attribute__((interrupt)) void Cla1Task%(task_num)i(void)' % {task_num = self.task.num})
    end
    c.ClaCode:append('{')
    for _, v in ipairs(self.task.code) do
      c.ClaCode:append(v)
    end
    c.ClaCode:append('}')
  end

  function Cla:finalize(c)
    if static.finalized ~= nil then
      return {}
    end
    
     if globals.target.getFamilyPrefix() == '28004x' then
       c.Include:append('f28004x_cla_defines.h')
    elseif globals.target.getFamilyPrefix() =='2837x' then
       c.Include:append('f2837xS_cla_defines.h')
    elseif globals.target.getFamilyPrefix() =='2838x' then
       c.Include:append('f2838x_cla_defines.h')
    end

    local declarations = [[
    ]]
    c.Declarations:append(declarations)
    
    local code = [[
      EALLOW;
#if 0
      SysCtrlRegs.PCLKCR3.bit.CLA1ENCLK = 1;
#else
      CpuSysRegs.PCLKCR0.bit.CLA1 = 1U;
#endif
      EDIS;

      EALLOW;
      Cla1Regs.MCTL.bit.IACKE = 1;
      EDIS;
    ]]
    c.PreInitCode:append(code)
    
    for _, bid in pairs(static.instances) do
      local cla = globals.instances[bid]
      local c = cla:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Cla
end

return Module

