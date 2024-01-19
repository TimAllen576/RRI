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

  local SpiSlave = require('blocks.block').getBlock(globals)
  SpiSlave["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function SpiSlave:checkMaskParameters(env)
  end

  function SpiSlave:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    self.spi = Block.Mask.spi - 1

    if #Block.Mask.pinset ~= 4 then
      return "Invalid GPIO configuration."
    end

    local mode
    if Block.Mask.Mode~=Block.Mask.Mode then 
        mode = ({2,3,0,1})[Block.Mask.mode] --deprecated parameter re-map
        Block:LogMessage('warning', 'Block uses a deprecated SPI mode parameter. To remove this warning set the Mode parameter to \'hide\' and then reselect the desired option.')
    elseif Block.Mask.mode~=Block.Mask.mode then 
        mode = Block.Mask.Mode - 1
    else
        return "Invalid \'Mode\' parameter for SPI module"
    end

    self.spi_obj = self:makeBlock('spi')
    local error = self.spi_obj:createImplicit(self.spi, {
      charlen = Block.Mask.charlen,
      pol = (mode >= 2),
      phase = (mode == 0) or (mode == 2),
      baudrate = 0, -- slave
      gpio = Block.Mask.pinset
    }, Require)
    if error ~= nil then
      return error
    end

    self.spi_instance = self.spi_obj:getParameter('instance')

    local dim = Block.Mask.dim
    local spi_fifo_depth =
        globals.target.getTargetParameters()['spis']['fifo_depth']
    if dim > spi_fifo_depth then
      return
          "Maximum number of words per transmission for this target equals %i." %
              {spi_fifo_depth}
    end

    -- setup I/O buffers
    OutputCode:append("static uint16_t SpiSlave%iRxBuffer[%i] = {" %
                          {self.spi_instance, dim})
    for i = 1, dim do
      if i > 1 then
        OutputCode:append(", 0")
      else
        OutputCode:append("0")
      end
    end
    OutputCode:append("};\n" % {instance, dim})
    OutputCode:append("static uint16_t SpiSlave%iTxBuffer[%i];\n" %
                          {self.spi_instance, dim})
    OutputCode:append("static bool SpiSlave%iDataReady = false;\n" %
                          {self.spi_instance})
    OutputCode:append("static bool SpiSlave%iRxOverrun = false;\n" %
                          {self.spi_instance})
    OutputCode:append("{\n")
    for i = 1, dim do
      OutputCode:append("    SpiSlave%iTxBuffer[%i] = %s;\n" %
                            {self.spi_instance, i - 1, Block.InputSignal[1][i]})
    end

    -- service task
    OutputCode:append("\n")
    OutputCode:append(
        "SpiSlave%iRxOverrun = PLXHAL_SPI_getAndResetRxOverrunFlag(%i) || (PLXHAL_SPI_getRxFifoLevel(%i) > %i); \n" %
            {self.spi_instance, self.spi_instance, self.spi_instance, dim})
    OutputCode:append(
        "SpiSlave%iDataReady =  PLXHAL_SPI_getWords(%i, &SpiSlave%iRxBuffer[0], %i);\n" %
            {self.spi_instance, self.spi_instance, self.spi_instance, dim})
    OutputCode:append("if (SpiSlave%iDataReady)\n" % {self.spi_instance})
    OutputCode:append("  {\n")
    OutputCode:append(
        "      PLXHAL_SPI_putWords(%i, &SpiSlave%iTxBuffer[0], %i);\n" %
            {self.spi_instance, self.spi_instance, dim})
    OutputCode:append("	}\n")
    OutputCode:append("}\n")

    -- output signals
    OutputSignal[1] = {}
    for i = 1, dim do
      OutputSignal[1][i] = "SpiSlave%iRxBuffer[%i]" % {self.spi_instance, i - 1}
    end
    OutputSignal[2] = {}
    OutputSignal[2][1] = "SpiSlave%iDataReady" % {self.spi_instance}
    OutputSignal[3] = {}
    OutputSignal[3][1] = "SpiSlave%iRxOverrun" % {self.spi_instance}

    return {
      OutputSignal = OutputSignal,
      OutputCode = OutputCode,
      Require = Require,
      UserData = {bid = SpiSlave:getId()}
    }
  end

  function SpiSlave:getNonDirectFeedthroughCode()
    return {}
  end

  function SpiSlave:finalizeThis(c)
    return c
  end

  function SpiSlave:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    for _, bid in pairs(static.instances) do
      local spislave = globals.instances[bid]
      local c = spislave:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return SpiSlave
end

return Module

