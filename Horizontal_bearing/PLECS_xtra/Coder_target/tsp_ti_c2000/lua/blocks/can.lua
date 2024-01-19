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

  local Can = require('blocks.block').getBlock(globals)
  Can["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Can:checkMaskParameters(env)
  end

  function Can:createImplicit(can)
    self.can = can
    static.instances[self.can] = self.bid

    self.can_letter = string.char(65 + self.can)
    self.mailboxes = {}
    self.num_mailboxes = 0
    self.is_configured = false

    self:logLine('CAN %s implicitly created.' % {self.can_letter})
  end

  function Can:configure(params, req)
    self.gpio = params.gpio
    self.auto_buson = params.auto_buson

    if (globals.target.getFamilyPrefix() == '2833x') or (globals.target.getFamilyPrefix() == '2806x') then
      -- older targets require hard-coded pin-sets
      local canpins = '%s_GPIO%i_GPIO%i' % {
          string.char(65 + self.can), self.gpio[1], self.gpio[2]
        }
      self.pinset =
        globals.target.getTargetParameters()['cans']['pin_sets'][canpins]

      if self.pinset == nil then
        return 'Pins %i/%i not supported for CAN %s.' % {
            self.gpio[1], self.gpio[2], string.char(65 + self.can)
          }
      end
    else
      -- newer targets have driverlib
      if globals.target.getFamilyPrefix() == '2837x' then
        rxgpio = 'GPIO_%i_CANRX%s' % {self.gpio[1], string.char(65 + self.can)}
        txgpio = 'GPIO_%i_CANTX%s' % {self.gpio[2], string.char(65 + self.can)}
      else
        rxgpio = 'GPIO_%i_CAN%s_RX' % {self.gpio[1], string.char(65 + self.can)}
        txgpio = 'GPIO_%i_CAN%s_TX' % {self.gpio[2], string.char(65 + self.can)}
      end
      if (not globals.target.validateAlternateFunction(rxgpio)) or (not globals.target.validateAlternateFunction(txgpio)) then
        return 'Invalid GPIO configured for CAN communication.'
      end
      globals.syscfg:addEntry('can', {
        unit = string.char(65 + self.can),
        pins = {self.gpio[1], self.gpio[2]},
        pinconf = {rxgpio, txgpio}
      })
    end

    -- claim pins
    globals.target.allocateGpio(self.gpio[1], {}, req)
    globals.target.allocateGpio(self.gpio[2], {}, req)

    -- determine bit timing
    local clk, brpMax = globals.target.getCanClkAndMaxBrp()

    self.bt = globals.utils.determineCanBitTiming({
      clk = clk,
      baud = params.baud,
      brpMax = brpMax,
      tseg1_range = {2, 16},
      tseg2_range = {1, 8},
      sjw_range = {1, 4},
      sample_point = params.sample_point,
      -- advanced configuration
      bit_length_tq = params.bit_length_tq,
      sjw = params.sjw_tq
    })
    if type(self.bt) == 'string' then
      return "CAN baud rate (%i) not achievable: %s" % {params.baud, self.bt}
    end
    self.is_configured = true
  end

  function Can:getTxMailbox()
    if self.num_mailboxes == 32 then
      return 'Only 32 CAN mailboxes available.'
    end
    local mbox = self.num_mailboxes
    self.num_mailboxes = self.num_mailboxes + 1
    return mbox
  end

  function Can:setupTxMailbox(mbox, params)
    self.mailboxes[mbox] = {
      is_tx = true,
      can_id = params.can_id,
      ext_id = params.ext_id,
      width = params.width
    }
  end

  function Can:getRxMailbox()
    if self.num_mailboxes == 16 then
      return 'Out of available CAN mailboxes.'
    end
    local mbox = self.num_mailboxes
    self.num_mailboxes = self.num_mailboxes + 1
    return mbox
  end

  function Can:setupRxMailbox(mbox, params)
    self.mailboxes[mbox] = {
      is_tx = false,
      can_id = params.can_id,
      ext_id = params.ext_id,
      width = params.width
    }
  end

  function Can:getDirectFeedthroughCode()
    return "Explicit use of CAN via target block not supported."
  end

  function Can:getNonDirectFeedthroughCode()
    return "Explicit use of CAN via target block not supported."
  end

  function Can:finalizeThis(c)
    self:logLine('CAN settings: %s' % {dump(self.bt)})

    c.PreInitCode:append(
        "// Configure CAN %s at %.3f Bit/s, with sampling at %.1f%%" %
            {
              string.char(65 + self.can),
              self.bt.baud,
              100*self.bt.sample_point
            })
    c.PreInitCode:append("{")
    c.PreInitCode:append("  PLX_CANBUS_Params_t params;")
    c.PreInitCode:append("  params.tseg1 = %i;" % {self.bt.tseg1})
    c.PreInitCode:append("  params.tseg2 = %i;" % {self.bt.tseg2})
    c.PreInitCode:append("  params.sjw = %i;" % {self.bt.sjw})
    c.PreInitCode:append("  params.sam = %i;" % {0}) -- 1x ((3x sampling not supported on newer MCUs)
    c.PreInitCode:append("  params.brp = %i;" % {self.bt.brp})
    c.PreInitCode:append("  params.autoBusOn = %i;" % {self.auto_buson})
    if self.pinset ~= nil then
        c.PreInitCode:append('PLX_CANBUS_configureViaPinSet(CanHandles[%i], PLX_CANBUS_CAN_%s, %i, &params);' %
            {self.instance, string.char(65 + self.can), self.pinset}
        )
    else
        c.PreInitCode:append('PLX_CANBUS_configure(CanHandles[%(instance)i], PLX_CANBUS_CAN_%(unit)s, &params);' % {
          instance = self.instance,
          unit = string.char(65 + self.can),
        })
    end
    for mbox, params in pairs(self.mailboxes) do
      c.PreInitCode:append(
          "  (void)PLX_CANBUS_setupMailbox(CanHandles[%i], %i, %i, %i, %i, %i);" %
              {
                self.instance, mbox, params.is_tx, params.can_id, params.ext_id,
                params.width
              })
    end
    c.PreInitCode:append("}")
    return c
  end

  function Can:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('plx_canbus.h')
    c.Declarations:append('PLX_CANBUS_Handle_t CanHandles[%i];' %
                              {static.numInstances})
    c.Declarations:append('PLX_CANBUS_Obj_t CanObj[%i];' % {static.numInstances})

    c.Declarations:append(
        'bool PLXHAL_CAN_getMessage(uint16_t aChannel, uint16_t aMailBox, unsigned char data[], unsigned char lenMax){')
    c.Declarations:append(
        '  return PLX_CANBUS_getMessage(CanHandles[aChannel], aMailBox, data, lenMax);')
    c.Declarations:append('}')

    c.Declarations:append(
        'void PLXHAL_CAN_putMessage(uint16_t aChannel, uint16_t aMailBox, unsigned char data[], unsigned char len){')
    c.Declarations:append(
        '  (void)PLX_CANBUS_putMessage(CanHandles[aChannel], aMailBox, data, len);')
    c.Declarations:append('}')

    c.Declarations:append(
        'void PLXHAL_CAN_setBusOn(uint16_t aChannel, bool aBusOn){')
    c.Declarations:append('  PLX_CANBUS_setBusOn(CanHandles[aChannel], aBusOn);')
    c.Declarations:append('}')

    c.Declarations:append('bool PLXHAL_CAN_getIsBusOn(uint16_t aChannel){')
    c.Declarations:append('  return PLX_CANBUS_isBusOn(CanHandles[aChannel]);')
    c.Declarations:append('}')

    c.Declarations:append('bool PLXHAL_CAN_getIsErrorActive(uint16_t aChannel){')
    c.Declarations:append(
        '  return PLX_CANBUS_isErrorActive(CanHandles[aChannel]);')
    c.Declarations:append('}')

    local code = [[
    {
      PLX_CANBUS_sinit();
      int i;
      for(i=0; i<%d; i++)
      {
        CanHandles[i] = PLX_CANBUS_init(&CanObj[i], sizeof(CanObj[i]));
      }
    }]]
    c.PreInitCode:append(code % {static.numInstances})

    for _, bid in pairs(static.instances) do
      local can = globals.instances[bid]
      local c = can:finalizeThis(c)
      if type(c) == 'string' then
        return c
      end
    end

    static.finalized = true
    return c
  end

  return Can
end

return Module
