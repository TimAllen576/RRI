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

  local SpiMaster = require('blocks.block').getBlock(globals)
  SpiMaster["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function SpiMaster:checkMaskParameters(env)
    if #Block.Mask.pinset ~= 3 then
      return "Invalid GPIO configuration."
    end

    if Block.Mask.clk <= 0 then
      return "Invalid clock rate."
    end
  end

  function SpiMaster:getDirectFeedthroughCode()
    local Require = ResourceList:new()
    local OutputSignal = StringList:new()
    local OutputCode = StringList:new()

    table.insert(static.instances, self.bid)

    self.spi = Block.Mask.spi - 1

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
      baudrate = Block.Mask.clk,
      gpio = Block.Mask.pinset
    }, Require)
    if error ~= nil then
      return error
    end

    self.spi_instance = self.spi_obj:getParameter('instance')

    if #Block.Mask.csgpio ~= #Block.Mask.dim then
      return
          "Dimensions of slave '/CS' and 'Words per transmission' must match."
    end

    local masterVarPrefix = "SpiMaster%i" % {self.spi_instance}

    -- setup chip selects
    local csArrayString = ""
    for i = 1, #Block.Mask.csgpio do
      local dio_obj = self:makeBlock('dout')
      local cs = dio_obj:createImplicit(Block.Mask.csgpio[i], {}, Require)
      if type(cs) == 'string' then
        return cs
      end
      csArrayString = csArrayString .. "%i" % {cs}
      if i ~= #Block.Mask.csgpio then
        csArrayString = csArrayString .. ", "
      end
    end
    OutputCode:append("static uint16_t %sSlaveCsHandles[] = {%s};\n" %
                          {masterVarPrefix, csArrayString})

    -- setup message size vector
    local spi_fifo_depth =
        globals.target.getTargetParameters()['spis']['fifo_depth']
    local dimArrayString = ""
    for i = 1, #Block.Mask.dim do
      if Block.Mask.dim[i] > spi_fifo_depth then
        return
            "Maximum number of words per transmission for this target equals %i." %
                {spi_fifo_depth}
      end
      dimArrayString = dimArrayString .. "%i" % {Block.Mask.dim[i]}
      if i ~= #Block.Mask.dim then
        dimArrayString = dimArrayString .. ", "
      end
    end
    OutputCode:append(
        "static uint16_t %sSlaveWordsPerTransmission[] = {%s};\n" %
            {masterVarPrefix, dimArrayString})

    -- setup buffers
    OutputCode:append("static uint16_t %sRxData[%i] = {" %
                          {masterVarPrefix, #Block.InputSignal[1]})
    for i = 1, #Block.InputSignal[1] do
      if i > 1 then
        OutputCode:append(", 0")
      else
        OutputCode:append("0")
      end
    end
    OutputCode:append("};\n")
    OutputCode:append("static uint16_t %sTxData[%i];\n" %
                          {masterVarPrefix, #Block.InputSignal[1]})
    OutputCode:append("static uint16_t %sRxDataBuffer[%i];\n" %
                          {masterVarPrefix, #Block.InputSignal[1]})

    -- setup flags
    OutputCode:append("static uint16_t %sSlaveIndex = 0;\n" % {masterVarPrefix})
    OutputCode:append("static uint16_t %sSlaveDataIndex = 0;\n" %
                          {masterVarPrefix})
    OutputCode:append("static bool %sSlaveTxActive = false;\n" %
                          {masterVarPrefix})
    OutputCode:append("static bool %sReady = false;\n" % {masterVarPrefix})
    OutputCode:append("static bool %sTxOverrun = false;\n" % {masterVarPrefix})

    -- output code
    local code = [[
			 |>VAR_BASE<|Ready = false;
	       if(|>VAR_BASE<|SlaveTxActive){
	           // de-assert last CS
	           PLXHAL_DIO_set(|>VAR_BASE<|SlaveCsHandles[|>VAR_BASE<|SlaveIndex], true);

				  |>VAR_BASE<|TxOverrun = (PLXHAL_SPI_getRxFifoLevel(|>CHANNEL<|) != |>VAR_BASE<|SlaveWordsPerTransmission[|>VAR_BASE<|SlaveIndex]);
	           if(|>VAR_BASE<|TxOverrun){
	               // overrun occurred
	               |>VAR_BASE<|SlaveIndex = 0;
	               |>VAR_BASE<|SlaveTxActive = false;
	           } else {
	               // read data
	               PLXHAL_SPI_getWords(|>CHANNEL<|, &|>VAR_BASE<|RxDataBuffer[|>VAR_BASE<|SlaveDataIndex], |>VAR_BASE<|SlaveWordsPerTransmission[|>VAR_BASE<|SlaveIndex]); // FIXME: incorrect index

	               // next slave
	               |>VAR_BASE<|SlaveDataIndex += |>VAR_BASE<|SlaveWordsPerTransmission[|>VAR_BASE<|SlaveIndex];
	               |>VAR_BASE<|SlaveIndex++;
	               if(|>VAR_BASE<|SlaveIndex == |>NUM_SLAVES<|){
	                   // all slaves have been serviced
	]]

    for i = 1, #Block.InputSignal[1] do
      code = code ..
                 "    |>VAR_BASE<|RxData[%i] = |>VAR_BASE<|RxDataBuffer[%i];\n" %
                 {i - 1, i - 1}
    end

    code = code .. [[
	                   |>VAR_BASE<|Ready = true;

	                   |>VAR_BASE<|SlaveIndex = 0;
	                   |>VAR_BASE<|SlaveTxActive = false;
	               }
	           }
	       }

	       // prime next transmission
	       if(|>VAR_BASE<|SlaveIndex == 0){
	]]

    for i = 1, #Block.InputSignal[1] do
      code = code .. "    |>VAR_BASE<|TxData[%i] = %s;\n" %
                 {i - 1, Block.InputSignal[1][i]}
    end

    code = code .. [[
				  |>VAR_BASE<|SlaveDataIndex = 0;
	           |>VAR_BASE<|SlaveTxActive = true;
	       }

	       if(|>VAR_BASE<|SlaveTxActive){
	           PLXHAL_DIO_set(|>VAR_BASE<|SlaveCsHandles[|>VAR_BASE<|SlaveIndex], false);
	           PLXHAL_SPI_putWords(|>CHANNEL<|, &|>VAR_BASE<|TxData[|>VAR_BASE<|SlaveDataIndex], |>VAR_BASE<|SlaveWordsPerTransmission[|>VAR_BASE<|SlaveIndex]);
	       }
	]]

    code = string.gsub(code, '|>VAR_BASE<|', masterVarPrefix)
    code = string.gsub(code, '|>CHANNEL<|', self.spi_instance)
    code = string.gsub(code, '|>NUM_SLAVES<|', #Block.Mask.csgpio)
    OutputCode:append(code)

    OutputSignal[1] = {}
    for i = 1, #Block.InputSignal[1] do
      OutputSignal[1][i] = "%sRxData[%i]" % {masterVarPrefix, i - 1}
    end
    OutputSignal[2] = {}
    OutputSignal[2][1] = "%sReady" % {masterVarPrefix}
    OutputSignal[3] = {}
    OutputSignal[3][1] = "%sTxOverrun" % {masterVarPrefix}

    return {
      OutputCode = OutputCode,
      OutputSignal = OutputSignal,
      Require = Require,
      UserData = {bid = SpiMaster:getId()}
    }
  end

  function SpiMaster:getNonDirectFeedthroughCode()
    return {}
  end

  function SpiMaster:finalizeThis(c)
    return c
  end

  function SpiMaster:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    for _, bid in pairs(static.instances) do
      local spimaster = globals.instances[bid]
      local c = spimaster:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return SpiMaster
end

return Module

