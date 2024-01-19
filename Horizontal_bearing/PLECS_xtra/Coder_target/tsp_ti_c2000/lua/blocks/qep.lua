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

local static = {numInstances = 0, instances = {}, finalized = nil}

function Module.getBlock(globals)

  local Qep = require('blocks.block').getBlock(globals)
  Qep["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Qep:checkMaskParameters(env)
  end

  function Qep:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local InitCode = StringList:new()
    local OutputSignal = StringList:new()

    table.insert(static.instances, self.bid)

    if #Block.Mask.abi ~= 3 then
      return "Invalid GPIO configuration."
    end

    self.qep = Block.Mask.qep[1]
    self.reset_on_index = false
    if Block.Mask.rst == 2 then
      self.reset_on_index = true
    end

    Require:add("QEP", self.qep)
    for p in ipairs(Block.Mask.abi) do
      globals.target.allocateGpio(Block.Mask.abi[p], {}, Require)
    end

    if (globals.target.getFamilyPrefix() == '2833x') or (globals.target.getFamilyPrefix() == '2806x') then
      -- older targets require hard-coded pin-sets

      local qep_params = globals.target.getTargetParameters()['qeps']
      if qep_params == nil or qep_params.pin_sets == null then
        return 'Qep support not configured.'
      end

      self.pin_set_string = '[A=GPIO%i, B=GPIO%i, I=GPIO%i]' %
                              {
          Block.Mask.abi[1], Block.Mask.abi[2], Block.Mask.abi[3]
        }
      self.pin_set = qep_params.pin_sets['_%i_GPIO%i_GPIO%i_GPIO%i' %
                       {
          self.qep, Block.Mask.abi[1], Block.Mask.abi[2], Block.Mask.abi[3]
        }]
      if self.pin_set == nil then
        return 'Pinset %s not supported for QEP%d.' %
                 {self.pin_set_string, self.qep}
      end
    else
      -- newer targets have driverlib
      self.abi = Block.Mask.abi
      if globals.target.getFamilyPrefix() == '2837x' then
        chagpio = 'GPIO_%i_EQEP%iA' % {self.abi[1], self.qep}
        chbgpio = 'GPIO_%i_EQEP%iB' % {self.abi[2], self.qep}
        chigpio = 'GPIO_%i_EQEP%iI' % {self.abi[3], self.qep}
      else
        chagpio = 'GPIO_%i_EQEP%i_A' % {self.abi[1], self.qep}
        chbgpio = 'GPIO_%i_EQEP%i_B' % {self.abi[2], self.qep}
        chigpio = 'GPIO_%i_EQEP%i_INDEX' % {self.abi[3], self.qep}
      end
      if (not globals.target.validateAlternateFunction(chagpio)) or
         (not globals.target.validateAlternateFunction(chbgpio)) or
         (not globals.target.validateAlternateFunction(chigpio)) then
        return 'Invalid GPIO configured for QEP block.'
      end
      globals.syscfg:addEntry('qep', {
        unit = self.qep,
        pins = self.abi,
        pinconf = {chagpio, chbgpio, chigpio}
      })
    end

    self.prd = Block.Mask.prd

    local OutputSignal1 = StringList:new()
    OutputSignal1:append("PLXHAL_QEP_getCounter(%i)" % {self.instance})
    local OutputSignal2 = StringList:new()
    OutputSignal2:append("PLXHAL_QEP_getIndexLatchCounter(%i)" % {self.instance})
    local OutputSignal3 = StringList:new()
    OutputSignal3:append("PLXHAL_QEP_getAndCearIndexFlag(%i)" % {self.instance})

    return {
      InitCode = InitCode,
      OutputSignal = {OutputSignal1, OutputSignal2, OutputSignal3},
      Require = Require,
      UserData = {bid = Qep:getId()}
    }
  end

  function Qep:getNonDirectFeedthroughCode()
    return {
    }
  end

  function Qep:finalizeThis(c)
    if self.pin_set_string ~= nil then
      c.PreInitCode:append(" // configure QEP%i for pinset %s" %
                             {self.qep, self.pin_set_string})
    else
      c.PreInitCode:append(" // configure QEP%i" %
                             {self.qep})
    end
    c.PreInitCode:append("{")
    c.PreInitCode:append("  PLX_QEP_Params_t params;")
    c.PreInitCode:append("  PLX_QEP_setDefaultParams(&params);")
    c.PreInitCode:append("  params.QPOSMAX = %i;" % {self.prd})
    if self.reset_on_index then
      c.PreInitCode:append(
          "  params.QEPCTL.bit.PCRM = 0; // operate QEP with reset on index event")
    else
      c.PreInitCode:append(
          "  params.QEPCTL.bit.PCRM = 1; // operate QEP in reset on max counter mode")
    end
    if self.pin_set ~= nil then
      c.PreInitCode:append(
        "PLX_QEP_configureViaPinSet(QepHandles[%i], %i, %i, &params);" %
            {self.instance, self.qep, self.pin_set})
    else
      c.PreInitCode:append('PLX_QEP_configure(QepHandles[%(instance)i], %(unit)i, &params);' % {
        instance = self.instance,
        unit = self.qep,
      })
    end
    c.PreInitCode:append("}\n")
    return c
  end

  function Qep:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_qep.h')
    c.Declarations:append('PLX_QEP_Handle_t QepHandles[%i];' %
                              {static.numInstances})
    c.Declarations:append('PLX_QEP_Obj_t QepObj[%i];' % {static.numInstances})

    c.Declarations:append('uint32_t PLXHAL_QEP_getCounter(uint16_t aChannel){')
    c.Declarations:append('  return PLX_QEP_getPosCnt(QepHandles[aChannel]);')
    c.Declarations:append('}')

    c.Declarations:append(
        'bool PLXHAL_QEP_getAndCearIndexFlag(uint16_t aChannel){')
    c.Declarations:append(
        '  return PLX_QEP_getAndClearIndexFlag(QepHandles[aChannel]);')
    c.Declarations:append('}')

    c.Declarations:append(
        'uint32_t PLXHAL_QEP_getIndexLatchCounter(uint16_t aChannel){')
    c.Declarations:append(
        '  return PLX_QEP_getPosILatchCnt(QepHandles[aChannel]);')
    c.Declarations:append('}')

    local code = [[
    {
      PLX_QEP_sinit();
      int i;
      for(i=0; i<%d; i++)
      {
        QepHandles[i] = PLX_QEP_init(&QepObj[i], sizeof(QepObj[i]));
      }
    }
    ]]
    c.PreInitCode:append(code % {static.numInstances})

    for _, bid in pairs(static.instances) do
      local qep = globals.instances[bid]
      local c = qep:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Qep
end

return Module
