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

local static = {numInstances = 0, instances = {}, finalized = nil}

function Module.getBlock(globals)

  local Native = require('blocks.block').getBlock(globals)
  Native["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Native:checkMaskParameters(env)
  end
  
  function Native:setCode(code)
    table.insert(static.instances, self.bid)
    
    self.code = code;
    local typeLookup = {'bool', 'unsigned char', 'char', 'uint16_t', 'int16_t', 'uint32_t', 'int32_t', 'float', 'double', Target.Variables.FLOAT_TYPE}
    
    local inW = #Block.InputSignal
    local outSignal = Block:OutputSignal()
    local outW = #outSignal
    
    if (Block.Mask.InputWidth ~= nil) and (Block.Mask.InputWidth == 0) then
      inW = 0
    end
    if (Block.Mask.OuputWidth ~= nil) and (Block.Mask.OuputWidth == 0) then
      outW = 0
    end
    
    local Declarations
    local OutputCode
    if self.code.OutputCode == nil then
      if (outW ~= 0) or (inW ~= 0) then
        return 'OutputCode undefined.'
      end
    else
      Declarations = StringList:new()
      OutputCode = StringList:new()

      if outW > 1 then
        return 'Only a single output port is supported.'
      end
      if inW > 1 then
        return 'Only a single input port is supported.'
      end
    
      -- determine function signature and arguments
      self.fun_sig = ''
      fun_arg = ''
      if inW ~= 0 then
        self.fun_sig = '%(input_type)s const *in' % {input_type = Block.InputType[1][1]}
        fun_arg = '&x[0]'
      end
      if outW ~= 0 then
        if self.fun_sig ~= '' then
          self.fun_sig = self.fun_sig .. ', '
          fun_arg = fun_arg .. ', '
        end
         self.fun_sig = self.fun_sig .. '%(output_type)s *out' % {output_type = typeLookup[Block.Mask.OutputDataType]}
         fun_arg = fun_arg .. '&y[0]'
      end
      Declarations:append('void PLXHAL_CUSTOM_f%(bid)s(%(sig)s);'% {bid = self.bid, sig = self.fun_sig})

      -- produce output code
      OutputCode:append('{')
      if (inW == 0) and (outW == 0) then
        -- no inputs, no outputs
        OutputCode:append('PLXHAL_CUSTOM_f%(bid)s();'% {bid = self.bid})
      else
        if inW ~= 0 then
          OutputCode:append('%(input_type)s x[%(signal)i];' % {input_type = Block.InputType[1][1], signal = #Block.InputSignal[1]})
          for i=1,#Block.InputSignal[1] do
            OutputCode:append('x[%i] = %s;' % {i-1, Block.InputSignal[1][i]})
          end
        end
        if outW ~= 0 then
          OutputCode:append('%(output_type)s y[%(signal)i];' % {output_type = typeLookup[Block.Mask.OutputDataType], signal = #outSignal[1]})
        end
        OutputCode:append('PLXHAL_CUSTOM_f%(bid)s(%(arg)s);'% {bid = self.bid, arg = fun_arg})
        if outW ~= 0 then
          for i=1,#outSignal[1] do
            OutputCode:append('%s= y[%i];' % {outSignal[1][i], i-1})
          end
        end
      end
      OutputCode:append('}')
    end
    return {
      Declarations = Declarations,
      OutputCode = OutputCode,
    }
  end

  function Native:getDirectFeedthroughCode()
    return 'Target IO Block not supported.'
  end

  function Native:finalizeThis(c)
    -- includes
    if self.code.Include ~=nil then
      for _, v in ipairs(self.code.Include) do
        c.Include:append(v)
      end
    end
    
    -- declarations
    if self.code.Declarations ~= nil then
      for _, v in ipairs(self.code.Declarations) do
        c.Declarations:append(v)
      end
    end
    
    -- init code
    if self.code.InitCode ~= nil then
      for _, v in ipairs(self.code.InitCode) do
        c.PreInitCode:append(v)
      end
    end
    
    -- post-init code
    if self.code.PostInitCode ~= nil then
      for _, v in ipairs(self.code.PostInitCode) do
        c.PostInitCode:append(v)
      end
    end
    
    -- generate inline code
    if self.code.OutputCode ~= nil then
      c.Declarations:append('void PLXHAL_CUSTOM_f%(bid)s(%(sig)s){' % {bid = self.bid, sig = self.fun_sig})
      for _, v in ipairs(self.code.OutputCode) do
        c.Declarations:append(v)
      end    
      c.Declarations:append('}\n')
    end
    
    -- generate background code
    if self.code.BackgroundCode ~= nil then
      local bgcode = ''
      for _, v in ipairs(self.code.BackgroundCode) do
        bgcode = '%s\n%s' % {bgcode, v}
      end
      c.BackgroundTaskCodeBlocks:append(bgcode)
    end
  end

  function Native:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    for _, bid in pairs(static.instances) do
      local native = globals.instances[bid]
      local c = native:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Native
end

return Module

