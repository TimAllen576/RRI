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

  local ExtMode = require('blocks.block').getBlock(globals)
  ExtMode["instance"] = static.numInstances
  static.numInstances = static.numInstances + 1

  function ExtMode:createImplicit()
    local driverLibTarget = (globals.target.getFamilyPrefix() ~= '2806x') and
                            (globals.target.getFamilyPrefix() ~= '2833x')

    local extModeCombo = {'off', 'serial', 'jtag'}
    local extMode = extModeCombo[Target.Variables.EXTERNAL_MODE + 1]

    if driverLibTarget and (extMode == 'serial') then
      for u=1,globals.target.getTargetParameters().scis.num_units do
        if globals.target.getFamilyPrefix() == '2837x' then
          rxgpio = 'GPIO_%i_SCIRXD%s' % {Target.Variables.extModeSciPins[1], string.char(64 + u)}
          txgpio = 'GPIO_%i_SCITXD%s' % {Target.Variables.extModeSciPins[2], string.char(64 + u)}
        else
          rxgpio = 'GPIO_%i_SCI%s_RX' % {Target.Variables.extModeSciPins[1], string.char(64 + u)}
          txgpio = 'GPIO_%i_SCI%s_TX' % {Target.Variables.extModeSciPins[2], string.char(64 + u)}
        end
        if globals.target.validateAlternateFunction(rxgpio) and globals.target.validateAlternateFunction(txgpio) then
          unit = string.char(64 + u)
          break
        end
      end
      if unit ~= nil then
        globals.syscfg:addEntry('sci', {
          unit = unit,
          pins = {Target.Variables.extModeSciPins[1], Target.Variables.extModeSciPins[2]},
          pinconf = {rxgpio, txgpio}
        })
      end
    end
  end


  function ExtMode:getDirectFeedthroughCode()
    return "Explicit use of EXTMODE via target block not supported."
  end

  function ExtMode:finalize(f)
    if static.numInstances ~= 1 then
      return
          'There should be only one (implicit) instance of the ExtMode block.'
    end

    f.Include:append('pil.h')
    f.Include:append('%s.h' % {Target.Variables.BASE_NAME})

    f.Declarations:append('PIL_Obj_t PilObj;')
    f.Declarations:append('PIL_Handle_t PilHandle = 0;')

    local extModeCombo = {'off', 'serial', 'jtag'}
    local extMode = extModeCombo[Target.Variables.EXTERNAL_MODE + 1]

    if (extMode ~= 'off') and (Target.Variables.SAMPLE_TIME > 1e-3) then
      return 'Discretizaton step size too large to support external mode communications.'
    end

    if extMode == 'off' then
      self:logLine('External mode disabled.')
      return
    elseif extMode == 'jtag' then
      self:logLine('Configuring external mode over JTAG.')
    else
      self:logLine('Configuring external mode over UART.')
    end

    if extMode == 'serial' then
      f.Include:append('plx_sci.h')
      f.Declarations:append('PLX_SCI_Obj_t SciObj;')
      f.Declarations:append('PLX_SCI_Handle_t SciHandle;')
    end

    -- determine scope buffer size
    local extModeSignalSize
    if Target.Variables.FLOAT_TYPE == 'float' then
      extModeSignalSize = 4
    elseif Target.Variables.FLOAT_TYPE == 'double' then
      extModeSignalSize = 8
    else
      return 'Unsupported external mode data type (%s).' %
                 {Target.Variables.FLOAT_TYPE}
    end

    local scopeMaxTraceWidthInWords = math.floor(
                                          Model.NumExtModeSignals *
                                              (extModeSignalSize / 2))
    local scopeBufSize = Target.Variables.extModeBufferSize +
                             scopeMaxTraceWidthInWords
    if scopeMaxTraceWidthInWords > (scopeBufSize / (extModeSignalSize / 2)) then
      return 'Excessive number of scope (external mode) signals.'
    end

    self:logLine('Allocating %i bytes for external mode buffer.' %
                     {2 * scopeBufSize})

	f.Declarations:append('#pragma DATA_SECTION(ScopeBuffer, "scope")')
    f.Declarations:append(
        'uint16_t ScopeBuffer[%i] /*__attribute__((aligned(16)))*/;' %
            {scopeBufSize})
    f.Declarations:append(
        'extern void PIL_setAndConfigScopeBuffer(PIL_Handle_t aPilHandle, uint16_t* aBufPtr, uint16_t aBufSize, uint16_t aMaxTraceWidthInWords);')
    f.Declarations:append('extern const char * const %s_checksum;\n' % {Target.Variables.BASE_NAME})

    -- external mode helper symbols
    f.Declarations:append('// external mode helper symbols\n')
    f.Declarations:append(
        'PIL_CONFIG_DEF(uint32_t, ExtMode_targetFloat_Size, sizeof(%s_FloatType));\n' %
            {Target.Variables.BASE_NAME})
    f.Declarations:append(
        'PIL_CONFIG_DEF(uint32_t, ExtMode_targetPointer_Size, sizeof(%s_FloatType*));\n' %
            {Target.Variables.BASE_NAME})
    -- note: the following assumes that the base-task sample time is the first value of the _sampleTime array
    f.Declarations:append(
        'PIL_CONFIG_DEF(uint32_t, ExtMode_sampleTime_Ptr, (uint32_t)&%s_sampleTime);\n' %
            {Target.Variables.BASE_NAME})
    f.Declarations:append(
        'PIL_CONFIG_DEF(uint32_t, ExtMode_checksum_Ptr, (uint32_t)&%s_checksum);\n' %
            {Target.Variables.BASE_NAME})
    f.Declarations:append(
        '#if defined(%s_NumTunableParameters) && (%s_NumTunableParameters >0)\n' %
            {Target.Variables.BASE_NAME, Target.Variables.BASE_NAME})
    f.Declarations:append(
        'PIL_CONFIG_DEF(uint32_t, ExtMode_P_Ptr, (uint32_t)&%s_P);\n' %
            {Target.Variables.BASE_NAME})
    f.Declarations:append(
        'PIL_CONFIG_DEF(uint32_t, ExtMode_P_Size, (uint32_t)%s_NumTunableParameters);\n' %
            {Target.Variables.BASE_NAME})
    f.Declarations:append('#endif\n')
    f.Declarations:append(
        '#if defined(%s_NumExtModeSignals) && (%s_NumExtModeSignals > 0)\n' %
            {Target.Variables.BASE_NAME, Target.Variables.BASE_NAME})
    f.Declarations:append(
        'PIL_CONFIG_DEF(uint32_t, ExtMode_ExtModeSignals_Ptr, (uint32_t)&%s_ExtModeSignals[0]);\n' %
            {Target.Variables.BASE_NAME})
    f.Declarations:append(
        'PIL_CONFIG_DEF(uint32_t, ExtMode_ExtModeSignals_Size, (uint32_t)%s_NumExtModeSignals);\n' %
            {Target.Variables.BASE_NAME})
    f.Declarations:append('#endif\n\n')

    f.Declarations:append('#define CODE_GUID %s;' % {globals.utils.guid()})
    f.Declarations:append('PIL_CONST_DEF(unsigned char, Guid[], %s);' %
                              {'CODE_GUID'})
    f.Declarations:append(
        'PIL_CONST_DEF(unsigned char, CompiledDate[], "%s");' %
            {os.date('%m/%d/%Y %I:%M %p')})
    f.Declarations:append('PIL_CONST_DEF(unsigned char, CompiledBy[], "%s");' %
                              {'PLECS Coder'})
    f.Declarations:append(
        'PIL_CONST_DEF(uint16_t, FrameworkVersion, PIL_FRAMEWORK_VERSION);')
    f.Declarations:append(
        'PIL_CONST_DEF(char, FirmwareDescription[], "TIC2000 Project");')
    f.Declarations:append('PIL_CONST_DEF(uint16_t, StationAddress, 0);')

    if extMode == 'jtag' then
      f.Declarations:append('#define PARALLEL_COM_PROTOCOL %i' % {3})
      f.Declarations:append(
          'PIL_CONST_DEF(uint16_t, ParallelComProtocol, PARALLEL_COM_PROTOCOL);')
      f.Declarations:append(
          'PIL_CONST_DEF(uint32_t, ParallelComBufferAddress, PARALLEL_COM_BUF_ADDR);')
      f.Declarations:append(
          'PIL_CONST_DEF(uint16_t, ParallelComBufferLength, PARALLEL_COM_BUF_LEN);')
      f.Declarations:append(
          'PIL_CONST_DEF(uint16_t, ParallelComTimeoutMs, 1000);')
      f.Declarations:append(
          'PIL_CONST_DEF(uint16_t, ExtendedComTimingMs, 2000);')
    else
      -- determine SCI pinset
      if (#Target.Variables.extModeSciPins ~= 2) then
        return 'Exactly two SCI pins must be specified.'
      end

      local unit, rxgpio, txgpio
      local sciPinset
      if (globals.target.getFamilyPrefix() == '2833x') or (globals.target.getFamilyPrefix() == '2806x') then
        -- older targets require hard-coded pin-sets
        sciPinset =
          globals.target.getTargetParameters().scis.pin_sets['GPIO%d_GPIO%d' %
              {
                Target.Variables.extModeSciPins[1],
                Target.Variables.extModeSciPins[2]
              }]
        if sciPinset == nil then
          return 'SCI pin-set not supported.'
        end
      else
        -- newer targets have driverlib
        for u=1,globals.target.getTargetParameters().scis.num_units do
          if globals.target.getFamilyPrefix() == '2837x' then
            rxgpio = 'GPIO_%i_SCIRXD%s' % {Target.Variables.extModeSciPins[1], string.char(64 + u)}
            txgpio = 'GPIO_%i_SCITXD%s' % {Target.Variables.extModeSciPins[2], string.char(64 + u)}
          else
            rxgpio = 'GPIO_%i_SCI%s_RX' % {Target.Variables.extModeSciPins[1], string.char(64 + u)}
            txgpio = 'GPIO_%i_SCI%s_TX' % {Target.Variables.extModeSciPins[2], string.char(64 + u)}
          end
          if globals.target.validateAlternateFunction(rxgpio) and globals.target.validateAlternateFunction(txgpio) then
            unit = string.char(64 + u)
            break
          end
        end
        if unit == nil then
          return 'Invalid GPIO configured for SCI communication.'
        end
        f.Require:add('SCI %s' % {unit}, -1, "External mode communication")
      end

      -- claim resources
      f.Require:add("GPIO", Target.Variables.extModeSciPins[1],
                    "External mode communication (Rx)")
      f.Require:add("GPIO", Target.Variables.extModeSciPins[2],
                    "External mode communication (Tx)")

      -- determine baud rate
      local sciBaud
      local maxRate = globals.target.getMaxSciBaudRate()
      local supportedRates = {
        256000, 128000, 115200, 57600, 38400, 19200, 14400, 9600, 4800
      }
      for _, rate in ipairs(supportedRates) do
        if maxRate >= rate then
          sciBaud = rate
          break
        end
      end
      if sciBaud == nil then
        return
            "The control task execution rate is too low to support external mode communication."
      end
      f.Declarations:append('PIL_CONST_DEF(uint32_t, BaudRate, %i);' % {sciBaud})

      -- generate UART polling code
      local code = [[
      static void SciPoll(PIL_Handle_t aHandle)
      {
	    if(PLX_SCI_breakOccurred(SciHandle)){
	        PLX_SCI_reset(SciHandle);
	    }

	    while(PLX_SCI_rxReady(SciHandle))
	    {
	        // assuming that there will be a "break" when FIFO is empty
	        PIL_SERIAL_IN(aHandle, (int16)PLX_SCI_getChar(SciHandle));
	    }

	    int16_t ch;
	    if(!PLX_SCI_txIsBusy(SciHandle)){
	        if(PIL_SERIAL_OUT(aHandle, &ch))
	        {
	            PLX_SCI_putChar(SciHandle, ch);
	        }
	    }
      }
      ]]
      f.Declarations:append(code)

      -- initialize SCI object
      f.PreInitCode:append('SciHandle = PLX_SCI_init(&SciObj, sizeof(SciObj));')
      if sciPinset ~= nil then
        -- legacy configuration
        f.PreInitCode:append('PLX_SCI_configureViaPinSet(SciHandle, %i, %i);' %
                                {sciPinset, globals.target.getLowSpeedClock()})
      else
        -- configuration using driverlib constants
        f.PreInitCode:append('PLX_SCI_configure(SciHandle, %(unit)s, %(clock)i);' % {
          unit = 'PLX_SCI_SCI_%s' % {unit},
          clock = globals.target.getLowSpeedClock()
         })
      end
      f.PreInitCode:append('(void)PLX_SCI_setupPort(SciHandle, %i);' % {sciBaud})
    end

    -- configure PIL framework
    f.PreInitCode:append('PilHandle = PIL_init(&PilObj, sizeof(PilObj));')
    f.PreInitCode:append('PIL_setGuid(PilHandle, PIL_GUID_PTR);')
    f.PreInitCode:append('PIL_setChecksum(PilHandle, %s_checksum);' %
                             {Target.Variables.BASE_NAME})
    f.PreInitCode:append(
        'PIL_setAndConfigScopeBuffer(PilHandle, (uint16_t *)&ScopeBuffer, %i, %i);' %
            {scopeBufSize, scopeMaxTraceWidthInWords})
    if extMode == 'jtag' then
      f.PreInitCode:append(
          'PIL_configureParallelCom(PilHandle, PARALLEL_COM_PROTOCOL, PARALLEL_COM_BUF_ADDR, PARALLEL_COM_BUF_LEN);')
    else
      f.PreInitCode:append(
          'PIL_setSerialComCallback(PilHandle, (PIL_CommCallbackPtr_t)SciPoll);')
    end

    return f
  end

  return ExtMode
end

return Module
