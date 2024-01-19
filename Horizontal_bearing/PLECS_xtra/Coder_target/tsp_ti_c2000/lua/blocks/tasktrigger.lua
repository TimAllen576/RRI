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

  local TaskTrigger = require('blocks.block').getBlock(globals)
  TaskTrigger["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function TaskTrigger:setImplicitTriggerSource(bid)
    self['trig_base_task_exp'] = "{modtrig = {bid = %i}}" % {bid}
  end

  function TaskTrigger:getDirectFeedthroughCode()
    -- there can only be one model trigger
    if static.numInstances ~= 1 then
      return "The use of multiple Control Task Trigger blocks is not allowed."
    end

    -- verify proper connection of trigger port
    local trig = Block.InputSignal[1]
    trig = trig:gsub("%s+", "") -- remove whitespace
    if trig:sub(1, #"{modtrig") ~= "{modtrig" then
      return "This block must be connected to a 'Task trigger' port."
    end

    self['trig_exp'] = trig

    return {}
  end

  function TaskTrigger:getNonDirectFeedthroughCode()
    return 'Non-direct feedthrough not supported by this block.'
  end

  function TaskTrigger:setSinkForTriggerSource(sink)
    if sink ~= nil then
      -- should never happen (block has no trigger output)
    end
    -- top of chain
    if self['trig_exp'] ~= nil then
      local trig = eval(self['trig_exp'])['modtrig']
      if trig['bid'] ~= nil then
        globals.instances[trig['bid']]:setSinkForTriggerSource({
          type = 'modtrig',
          bid = self.bid
        })
      end
    end
  end

  function TaskTrigger:propagateTriggerSampleTime(ts)
    if ts ~= nil then
      self['ts'] = ts
      self:logLine('Task trigger sample time for %s (%i) propagated to: %f.' %
                       {self.type, self.bid, ts})
    end
  end

  function TaskTrigger:getTriggerSampleTime()
    return self['ts']
  end

  function TaskTrigger:finalize(f)
    local modelClkHz = 1 / Target.Variables.SAMPLE_TIME

    -- note: tolerances are verified in Coder.lua
    local achievableModelClkHz = modelClkHz
    local achievableModelPeriodInTimerTicks =
        math.floor(globals.target.getTimerClock() * Target.Variables.SAMPLE_TIME +
                       0.5)

    local taskFunction
    if #Model.Tasks == 1 then
      taskFunction = [[
          static void Tasks(bool aInit, void * const aParam)
          {
            if(aInit){
              %s_enableTasksInterrupt();
            } else {
              %s_step();
            }
          }
          ]]
    elseif #Model.Tasks > 16 then
      return "Maximal allowable number of tasks (16) exceeded."
    else
      taskFunction = [[
          static void Tasks(bool aInit, void * const aParam)
          {
            if(aInit){
              %s_enableTasksInterrupt();
            } else {
              %s_step(*(int *)aParam);
            }
          }
          ]]
    end
    f.Declarations:append("extern PIL_Handle_t PilHandle;")
    f.Declarations:append('DISPR_TaskObj_t TaskObj[%i];' % {#Model.Tasks})
    if #Model.Tasks == 1 then
      f.Declarations:append('extern void %s_step();' %
                                {Target.Variables.BASE_NAME})
    else
      f.Declarations:append('extern void %s_step(int task_id);' %
                                {Target.Variables.BASE_NAME})
    end
    f.Declarations:append('extern void %s_enableTasksInterrupt();' %
                              {Target.Variables.BASE_NAME})
    f.Declarations:append('extern void %s_syncTimers();' %
                              {Target.Variables.BASE_NAME})

    f.Declarations:append("%s\n" %
                              {
          taskFunction %
              {Target.Variables.BASE_NAME, Target.Variables.BASE_NAME}
        })

    f.PreInitCode:append('DISPR_sinit();')
    f.PreInitCode:append(
        'DISPR_configure((uint32_t)(%i), PilHandle, &TaskObj[0], sizeof(TaskObj)/sizeof(DISPR_TaskObj_t));' %
            {achievableModelPeriodInTimerTicks})
    f.PreInitCode:append('DISPR_registerIdleTask(&%s_background);' %
                             {Target.Variables.BASE_NAME})
    f.PreInitCode:append('DISPR_registerSyncCallback(&%s_syncTimers);' %
                             {Target.Variables.BASE_NAME})
    f.PreInitCode:append('DISPR_setPowerupDelay(%i);' %
                             {math.floor(0.001 * achievableModelClkHz + 0.5)})

    local numTasks = 0
    for idx = 1, #Model.Tasks do
      local tsk = Model.Tasks[idx]
      local ts = tsk["SampleTime"]
      if ts[2] ~= 0 then
        return "Sample time offset not supported."
      end

      local achievablePeriodInTimerTicks =
          achievableModelPeriodInTimerTicks *
              math.floor(achievableModelClkHz * ts[1] + 0.5)
      local dispatcherDiv = math.floor(achievablePeriodInTimerTicks /
                                           achievableModelPeriodInTimerTicks)
      if dispatcherDiv > 0xFFFF then
        return
            'Period of Task "%s" too large with respect to base task period.' %
                {tsk["Name"]}
      end
      if (dispatcherDiv * achievableModelPeriodInTimerTicks) ~=
          achievablePeriodInTimerTicks then
        return
            'Task period calculation exception. Please report this error to the author of the Target Support Package.'
      end

      f.PreInitCode:append("{")
      f.PreInitCode:append("    static int taskId = %i;" % {numTasks})
      f.PreInitCode:append("    // Task %i at %e Hz" %
                               {
            numTasks,
            globals.target.getTimerClock() / achievablePeriodInTimerTicks
          });
      f.PreInitCode:append(
          "    DISPR_registerTask(%i, &Tasks, %iL, (void *)&taskId);" %
              {numTasks, achievablePeriodInTimerTicks});
      f.PreInitCode:append("}")
      numTasks = numTasks + 1
    end

    return f
  end

  return TaskTrigger
end

return Module
