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

local static = {numInstances = 0, numChannels = 0, instances = {}}

function Module.getBlock(globals)

  local PilCalibrations = require('blocks.block').getBlock(globals)
  PilCalibrations["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function PilCalibrations:checkMaskParameters(env)
  end

  function PilCalibrations:getDirectFeedthroughCode()
    local OutputSignal = StringList:new()
    local Declarations = StringList:new()

    table.insert(static.instances, self.bid)

    if (type(Target.Variables.EXTERNAL_MODE)) ~= 'number' or
        (Target.Variables.EXTERNAL_MODE ~= 1) then
      return
          'PIL requires external mode communication over serial to be enabled.'
    end

    -- grab (singleton) pil object
    local pil_obj
    for _, b in ipairs(globals.instances) do
      if b:getType() == 'pil' then
        pil_obj = b
      end
    end
    if pil_obj == nil then
      pil_obj = self:makeBlock('pil')
      local declaration = pil_obj:createImplicit()
      Declarations:append(declaration)
    end

    for i = 1, #Block.Mask.val do
      local name
      if #Block.NumOutputSignals[1] == 1 then
        name = Block.Mask.path
      else
        name = string.format("%s_%i", Block.Mask.path, i)
      end

      if (not globals.utils.isValidCName(name)) then
        return ("The name of this block must be a valid C variable name.")
      end

      pil_obj:registerCalibration(name, {
        type = Block.OutputType[1][i],
        val = Block.Mask.val[i],
        min = Block.Mask.val_min[i],
        max = Block.Mask.val_max[i]
      })

      OutputSignal:append("%s_probes.%s" % {Target.Variables.BASE_NAME, name})
    end

    return {
      Declarations = Declarations,
      OutputSignal = {OutputSignal},
      UserData = {bid = PilCalibrations:getId()}
    }
  end

  function PilCalibrations:finalize(c)
    return c
  end

  return PilCalibrations
end

return Module
