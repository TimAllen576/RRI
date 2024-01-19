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

  local Can = require('blocks.block').getBlock(globals)
  Can["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function Can:checkMaskParameters(env)
  end

  function Can:createImplicit(mcan)
    self.mcan = mcan
    static.instances[self.mcan] = self.bid

    self.rx_mailboxes = {}
    self.num_rx_mailboxes = 0
    self.tx_mailboxes = {}
    self.num_tx_mailboxes = 0
    self.is_configured = false

    self:logLine('MCAN %i implicitly created.' % {self.mcan})
  end

  function Can:configure(params, req)
    self.gpio = params.gpio

    rxgpio = 'GPIO_%i_MCAN_RX' % {self.gpio[1]}
    txgpio = 'GPIO_%i_MCAN_TX' % {self.gpio[2]}

    if (not globals.target.validateAlternateFunction(rxgpio)) or (not globals.target.validateAlternateFunction(txgpio)) then
      return 'Invalid GPIO configured for CAN communication.'
    end

    globals.syscfg:addEntry('mcan', {
      unit = self.mcan,
      pins = {self.gpio[1], self.gpio[2]},
      pinconf = {rxgpio, txgpio}
    })

    -- claim pins
    globals.target.allocateGpio(self.gpio[1], {}, req)
    globals.target.allocateGpio(self.gpio[2], {}, req)

    -- TODO: make configurable!
    self.clk = Target.Variables.sysClkMHz * 1e6 -- for now

    self.bt_nominal = globals.utils.determineCanBitTiming({
      clk = self.clk,
      baud = params.nom_bit_rate,
      brpMax = 512,
      tseg1_range = {2, 256},
      tseg2_range = {1, 128},
      sjw_range = {1, 128},
      sample_point = params.nom_sample_point,
      -- advanced configuration
      bit_length_tq = params.nom_bit_length_tq,
      sjw = params.nom_sjw_tq
    })
    if type(self.bt_nominal) == 'string' then
      return "CAN baud rate (%i) not achievable: %s" % {params.nom_bit_rate, self.bt_nominal}
    end

    if params.data_bit_rate ~= nil then
      self.bt_data = globals.utils.determineCanBitTiming({
        clk = self.clk,
        baud = params.data_bit_rate,
        brpMax = 32,
        tseg1_range = {1, 32},
        tseg2_range = {1, 16},
        sjw_range = {1, 16},
        sample_point = params.data_sample_point,
        -- advanced configuration
        bit_length_tq = params.data_bit_length_tq,
        sjw = params.data_sjw_tq
      })
      if type(self.bt_data) == 'string' then
        return "CAN baud rate (%i) not achievable: %s" % {params.data_bit_rate, self.bt_data}
      end

      -- SSP configuration
      if params.ssp ~= nil then
        if (params.ssp.tdcf ~= nil) and (params.ssp.tdco ~= nil) then
          self.ssp = params.ssp
        end
      else
        -- automatic configuration at middle of bit
        self.ssp = {
          tdcf = 0,
          tdco = math.floor((1+self.bt_data.tseg1+self.bt_data.tseg2)/2)
        }
      end
    end

    self.is_configured = true
  end

  function Can:getTxMailbox()
    if self.num_tx_mailboxes == 32 then
      return 'Only 32 CAN mailboxes available.'
    end
    local mbox = self.num_tx_mailboxes
    self.num_tx_mailboxes = self.num_tx_mailboxes + 1
    return mbox
  end

  function Can:setupTxMailbox(mbox, params)
    self.tx_mailboxes[mbox] = {
      can_id = params.can_id,
      ext_id = params.ext_id,
      width = params.width,
      dlc = params.dlc,
      brs = params.brs
    }
  end

  function Can:getRxMailbox()
    if self.num_rx_mailboxes == 16 then
      return 'Out of available CAN mailboxes.'
    end
    local mbox = self.num_rx_mailboxes
    self.num_rx_mailboxes = self.num_rx_mailboxes + 1
    return mbox
  end

  function Can:setupRxMailbox(mbox, params)
    self.rx_mailboxes[mbox] = {
      can_id = params.can_id,
      ext_id = params.ext_id,
      width = params.width,
      dlc = params.dlc
    }
  end

  function Can:getDirectFeedthroughCode()
    return "Explicit use of CAN via target block not supported."
  end

  function Can:getNonDirectFeedthroughCode()
    return "Explicit use of CAN via target block not supported."
  end

  function Can:finalizeThis(c)
    self:logLine('CAN settings (nominal): %s' % {dump(self.bt_nominal)})
    if self.bt_data ~= nil then
      self:logLine('CAN settings (data): %s' % {dump(self.bt_data)})
    end
    c.PreInitCode:append(
        "// Configure MCAN %i at %.3f Bit/s, with sampling at %.1f%%" %
            {
              self.mcan,
              self.bt_nominal.baud,
              100*self.bt_nominal.sample_point
            }
    )
    if self.bt_data ~= nil then
        c.PreInitCode:append(
        "//   FD rate set to %.3f Bit/s" % {self.bt_data.baud}
        )
    end

    c.PreInitCode:append("{")
    c.PreInitCode:append("PLX_MCAN_Params_t params = {0};")
    c.PreInitCode:append("params.tseg1 = %i;" % {self.bt_nominal.tseg1})
    c.PreInitCode:append("params.tseg2 = %i;" % {self.bt_nominal.tseg2})
    c.PreInitCode:append("params.sjw = %i;" % {self.bt_nominal.sjw})
    c.PreInitCode:append("params.brp = %i;" % {self.bt_nominal.brp})

    if self.bt_data == nil then
      c.PreInitCode:append("params.enableRateSwitching = false;")
    else
      c.PreInitCode:append("params.enableRateSwitching = true;")
      c.PreInitCode:append("params.tseg1_data = %i;" % {self.bt_data.tseg1})
      c.PreInitCode:append("params.tseg2_data = %i;" % {self.bt_data.tseg2})
      c.PreInitCode:append("params.sjw_data = %i;" % {self.bt_data.sjw})
      c.PreInitCode:append("params.brp_data = %i;" % {self.bt_data.brp})
    end

    if self.ssp == nil then
      c.PreInitCode:append("params.enableSecondarySamplePoint = false;")
    else
      c.PreInitCode:append("params.enableSecondarySamplePoint = true;")
      c.PreInitCode:append("params.tdcf = %i;" % {self.ssp.tdcf})
      c.PreInitCode:append("params.tdco = %i;" % {self.ssp.tdco})
    end

    c.PreInitCode:append("params.numRxMailboxes = %i;" % {self.num_rx_mailboxes})
    if self.num_rx_mailboxes ~= 0 then
      c.PreInitCode:append("static PLX_MCAN_RxMailbox_t rxMailboxes[%i];" % {self.num_rx_mailboxes})
      c.PreInitCode:append("params.rxMailboxes = &rxMailboxes[0];")
    end
    c.PreInitCode:append("params.numTxMailboxes = %i;" % {self.num_tx_mailboxes})
    if self.num_tx_mailboxes ~= 0 then
      c.PreInitCode:append("static PLX_MCAN_TxMailbox_t txMailboxes[%i];" % {self.num_tx_mailboxes})
      c.PreInitCode:append("params.txMailboxes = &txMailboxes[0];")
    end

    c.PreInitCode:append('PLX_MCAN_configure(MCanHandles[%(instance)i], PLX_MCAN_MCAN_%(unit)i, &params);' % {
      instance = self.instance,
      unit = self.mcan,
    })

    for mbox, params in pairs(self.rx_mailboxes) do
      c.PreInitCode:append(
          "  (void)PLX_MCAN_setupRxMailbox(MCanHandles[%i], %i, %i, %i, %i);" %
              {
                self.instance, mbox, params.can_id, params.ext_id,
                params.dlc
              })
    end
    for mbox, params in pairs(self.tx_mailboxes) do
      c.PreInitCode:append(
          "  (void)PLX_MCAN_setupTxMailbox(MCanHandles[%i], %i, %i, %i, %i, %s);" %
              {
                self.instance, mbox, params.can_id, params.ext_id,
                params.dlc, tostring(params.brs)
              })
    end
    c.PreInitCode:append("}")
    return c
  end

  function Can:finalize(c)
    if static.finalized ~= nil then
      return {}
    end

    c.Include:append('PLX_MCAN.h')
    c.Declarations:append('PLX_MCAN_Handle_t MCanHandles[%i];' %
                              {static.numInstances})
    c.Declarations:append('PLX_MCAN_Obj_t MCanObj[%i];' % {static.numInstances})

    c.Declarations:append(
        'bool PLXHAL_MCAN_getMessage(uint16_t aChannel, uint16_t aMailBox, unsigned char data[], unsigned char lenMax, uint16_t *aFlags){')
    c.Declarations:append(
        '  return PLX_MCAN_getMessage(MCanHandles[aChannel], aMailBox, data, lenMax, aFlags);')
    c.Declarations:append('}')

    c.Declarations:append(
        'void PLXHAL_MCAN_putMessage(uint16_t aChannel, uint16_t aMailBox, unsigned char data[], unsigned char len){')
    c.Declarations:append(
        '  (void)PLX_MCAN_putMessage(MCanHandles[aChannel], aMailBox, data, len);')
    c.Declarations:append('}')

    c.Declarations:append(
        'void PLXHAL_MCAN_setBusOn(uint16_t aChannel, bool aBusOn){')
    c.Declarations:append('  PLX_MCAN_setBusOn(MCanHandles[aChannel], aBusOn);')
    c.Declarations:append('}')

    c.Declarations:append('bool PLXHAL_MCAN_getIsBusOn(uint16_t aChannel){')
    c.Declarations:append('  return PLX_MCAN_isBusOn(MCanHandles[aChannel]);')
    c.Declarations:append('}')

    c.Declarations:append('bool PLXHAL_MCAN_getIsErrorActive(uint16_t aChannel){')
    c.Declarations:append(
        '  return PLX_MCAN_isErrorActive(MCanHandles[aChannel]);')
    c.Declarations:append('}')

    local code = [[
    {
      PLX_MCAN_sinit();
      int i;
      for(i=0; i<%d; i++)
      {
        MCanHandles[i] = PLX_MCAN_init(&MCanObj[i], sizeof(MCanObj[i]));
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
