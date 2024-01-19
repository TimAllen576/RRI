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

  local Spi = require('blocks.block').getBlock(globals)
  Spi["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Spi:checkMaskParameters(env)
  end

  function Spi:createImplicit(spi, params, req)
    self.spi = spi
    static.instances[self.spi] = self.bid

    self.spi_letter = string.char(65 + self.spi)
    req:add('SPI %s' % {self.spi_letter})

    self:logLine('SPI %s implicitly created.' % {self.spi_letter})

    self.charlen = params.charlen
    self.pol = params.pol
    self.phase = params.phase
    self.baudrate = params.baudrate
    self.masterslave = (params.baudrate > 0)

    if (globals.target.getFamilyPrefix() == '2833x') or (globals.target.getFamilyPrefix() == '2806x') then
      -- older targets require hard-coded pin-sets

      for _, p in ipairs(params.gpio) do
        req:add('GPIO', p)
        if self.pinset_string == nil then
          self.pinset_string = "GPIO%i" % {p}
        else
          self.pinset_string = "%s_GPIO%i" % {self.pinset_string, p}
        end
      end

      local pinsetWithModule = "%s_%s" % {self.spi_letter, self.pinset_string}
      self.pinset =
        globals.target.getTargetParameters()['spis']['pin_sets'][pinsetWithModule]
      if self.pinset == nil then
        return "Pinset %s not supported for SPI %s." %
                 {self.pinset_string, self.spi_letter}
      end
    else
      -- newer targets have driverlib
      if globals.target.getFamilyPrefix() == '2837x' then
        simogpio = 'GPIO_%i_SPISIMO%s' % {params.gpio[1], self.spi_letter}
        somigpio = 'GPIO_%i_SPISOMI%s' % {params.gpio[2], self.spi_letter}
        clkgpio  = 'GPIO_%i_SPICLK%s' % {params.gpio[3], self.spi_letter}
        if params.gpio[4] ~= nil then
          csgpio  = 'GPIO_%i_SPISTE%s' % {params.gpio[4], self.spi_letter}
        end
      else
        simogpio = 'GPIO_%i_SPI%s_SIMO' % {params.gpio[1], self.spi_letter}
        somigpio = 'GPIO_%i_SPI%s_SOMI' % {params.gpio[2], self.spi_letter}
        clkgpio  = 'GPIO_%i_SPI%s_CLK' % {params.gpio[3], self.spi_letter}
        if params.gpio[4] ~= nil then
          if globals.target.getFamilyPrefix() == '28004x' then
            csgpio  = 'GPIO_%i_SPI%s_STE' % {params.gpio[4], self.spi_letter}
          else
            csgpio  = 'GPIO_%i_SPI%s_STEN' % {params.gpio[4], self.spi_letter}
          end
        end
      end
      if (not globals.target.validateAlternateFunction(simogpio)) or
         (not globals.target.validateAlternateFunction(somigpio)) or
         (not globals.target.validateAlternateFunction(clkgpio)) or
         ((csgpio ~= nil) and (not globals.target.validateAlternateFunction(csgpio))) then
        return 'Invalid GPIO configured for SPI block.'
      end

      globals.syscfg:addEntry('spi', {
        unit = self.spi_letter,
        pins = params.gpio,
        pinconf = {simogpio, somigpio, clkgpio, csgpio}
      })

    end

    -- for master, also check if clock is within allowable range
    if self.baudrate > 0 then
      local error = globals.target.checkSpiClockIsAchievable(self.baudrate)
      if error ~= nil then
        return error
      end
    end

  end

  function Spi:getDirectFeedthroughCode()
    return "Explicit use of SPI via target block not supported."
  end

  function Spi:getNonDirectFeedthroughCode()
    return "Explicit use of SPI via target block not supported."
  end

  function Spi:finalizeThis(c)
    if self.pin_set ~= nil then
      c.PreInitCode:append(" // configure SPI-%s for pinset %s" %
                             {self.spi_letter, self.pinset_string})
    else
      c.PreInitCode:append(" // configure SPI-%s" %
                             {self.spi_letter})
    end
    c.PreInitCode:append("{")
    c.PreInitCode:append("  PLX_SPI_Params_t params;")
    c.PreInitCode:append("  params.SPICHAR = %i;" % {self.charlen})
    c.PreInitCode:append("  params.CLKPOLARITY = %i;" % {self.pol})
    c.PreInitCode:append("  params.CLKPHASE = %i;" % {self.phase})
    c.PreInitCode:append("  params.BAUDRATE = %i;" % {self.baudrate})
    c.PreInitCode:append("  params.MASTERSLAVE = %i;" % {self.masterslave})
    c.PreInitCode:append(
        "  PLX_SPI_configure(SpiHandles[%i], PLX_SPI_SPI_%s, LSPCLK_HZ);" %
            {self.instance, self.spi_letter})
    if self.pinset ~= nil then
      c.PreInitCode:append("  PLX_SPI_setupPortViaPinSet(SpiHandles[%i], %i, &params);" %
                             {self.instance, self.pinset})
    else
      c.PreInitCode:append("  PLX_SPI_setupPort(SpiHandles[%i], &params);" %
                             {self.instance})
    end
    c.PreInitCode:append("}")
    return c
  end

  function Spi:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_spi.h')
    c.Declarations:append('PLX_SPI_Handle_t SpiHandles[%i];' %
                              {static.numInstances})
    c.Declarations:append('PLX_SPI_Obj_t SpiObj[%i];' % {static.numInstances})

    c.Declarations:append(
        'uint16_t PLXHAL_SPI_getRxFifoLevel(int16_t aChannel){')
    c.Declarations:append(
        '  return PLX_SPI_getRxFifoLevel(SpiHandles[aChannel]);')
    c.Declarations:append('}')

    c.Declarations:append(
        'bool PLXHAL_SPI_putWords(int16_t aChannel, uint16_t *aData, uint16_t aLen){')
    c.Declarations:append(
        '  return PLX_SPI_putWords(SpiHandles[aChannel], aData, aLen);')
    c.Declarations:append('}')

    c.Declarations:append(
        'bool PLXHAL_SPI_getWords(int16_t aChannel, uint16_t *aData, uint16_t aLen){')
    c.Declarations:append(
        '  return PLX_SPI_getWords(SpiHandles[aChannel], aData, aLen);')
    c.Declarations:append('}')

    c.Declarations:append(
        'bool PLXHAL_SPI_getAndResetRxOverrunFlag(int16_t aChannel){')
    c.Declarations:append(
        '  return PLX_SPI_getAndResetRxOverrunFlag(SpiHandles[aChannel]);')
    c.Declarations:append('}')

    local code = [[
    {
      PLX_SPI_sinit();
      int i;
      for(i=0; i<%d; i++)
      {
        SpiHandles[i] = PLX_SPI_init(&SpiObj[i], sizeof(SpiObj[i]));
      }
    }]]
    c.PreInitCode:append(code % {static.numInstances})

    for _, bid in pairs(static.instances) do
      local spi = globals.instances[bid]
      local c = spi:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Spi
end

return Module
