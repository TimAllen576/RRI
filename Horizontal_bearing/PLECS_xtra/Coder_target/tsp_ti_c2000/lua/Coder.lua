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
local Coder = {}

if Target.Name == "TI2837xS" then
  -- deprecated target
  T = require("TI2837x")
else
  T = require(Target.Name)
end
local U = require('CoderUtils')
local C = require('CoderGenNativeFiles')

local Registry = {
  BlockInstances = {},
  ExternalLibraries = {},
  LinkerFlags = {},
  CompilerFlags = {},
  SystemConfiguration = {},
}

local SystemConfig = {}
function SystemConfig:addEntry(category, data)
  if Registry.SystemConfiguration[category] == nil then
     Registry.SystemConfiguration[category] = {}
  end
  table.insert(Registry.SystemConfiguration[category], data)
end
function SystemConfig:setEntry(name, data)
  Registry.SystemConfiguration[name] = data
end
function SystemConfig:get()
  return Registry.SystemConfiguration
end

local FactoryBlock = require('blocks.block').getBlock({
    target = T,
    utils = U,
    instances = Registry.BlockInstances,
    syscfg = SystemConfig
  })("")

function Coder.CreateTargetBlock(family, name)
  if (Target.Name ~= "Generic") and (Target.Family ~= family) then
    -- delegate error reporting to getDirectFeedthroughCode() call
    local errorFunction = {}
    function errorFunction:getDirectFeedthroughCode()
      return
          'This block is not compatible with the selected target family ("%s")' %
              {Target.Family}
    end
    return errorFunction
  end

  local TargetBlock = FactoryBlock:makeBlock(name)

  local error = TargetBlock:checkMaskParameters({target = T, utils = U})
  if error == nil then
    error = TargetBlock:checkTspVersion()
  end
  if error ~= nil then
    local errorFunction = {}
    function errorFunction:getDirectFeedthroughCode()
      return error
    end
    return errorFunction
  else
    return TargetBlock
  end
end

function Coder.RegisterExternalLibrary(name, params)
  if Registry.ExternalLibraries[name] == nil then
    Registry.ExternalLibraries[name] = params
  else
    return 'This library has already been registered.'
  end
end

function Coder.SetLinkerFlags(flags)
  if #Registry.LinkerFlags ~= 0 then
    return 'Linker flags can only be set once.'
  end
  for _, v in ipairs(flags) do
     table.insert(Registry.LinkerFlags, v)
  end
end

function Coder.SetCompilerFlags(flags)
  if #Registry.CompilerFlags ~= 0 then
    return 'Compiler flags can only be set once.'
  end
  for _, v in ipairs(flags) do
     table.insert(Registry.CompilerFlags, v)
  end
end

function Coder.GetTargetBlock(bid)
  return Registry.BlockInstances[bid]
end

function Coder.Initialize()
  if Target.Variables.CheckForUpdates == 1 then
    U.checkForUpate() -- generate warning if newer TSP version available
  end

  local Resources = ResourceList:new()
  local Require = ResourceList:new()

  local HeaderDeclarations = [=[
    typedef int_fast8_t int8_t;
    typedef uint_fast8_t uint8_t;
  ]=]
  HeaderDeclarations = HeaderDeclarations ..
                           "extern void %s_background(void);\n" %
                           {Target.Variables.BASE_NAME}

  -- do this before using any T methods
  T.configure(Resources)

  -- (implicit) clock module - MUST COME FIRST!
  local clockBlock = FactoryBlock:makeBlock("clock")

  -- (implicit) system configuration
  local sysCfg = FactoryBlock:makeBlock("syscfg")

  -- (implicit) external mode module
  if type(Target.Variables.EXTERNAL_MODE) == 'number' then
    local extModeBlock = FactoryBlock:makeBlock("extmode")
    extModeBlock:createImplicit()
  end

  -- PGAs
  if T.getTargetParameters()['pgas'] ~= nil then
    local gains = {3, 6, 12, 24};
    local rfs = {0, 200, 160, 130, 100, 80, 50}
    for i = 1, T.getTargetParameters()['pgas'].num_units do
      if Target.Variables["pga%iEn" % {i}] == 1 then
        local pga = FactoryBlock:makeBlock("pga")
        pga:createImplicit(i, {
          gain = gains[Target.Variables["pga%iGain" % {i}]],
          rf = rfs[Target.Variables["pga%iRf" % {i}]]
        })
      end
    end
  end

  -- (implicit) trip zone management module
  local tzs = FactoryBlock:makeBlock("tripzones")
  local error = tzs:createImplicit(Require)
  if error ~= nil then
    return error
  end

  -- (implicit) CPU2 management
  if (Target.Variables.SecondaryCore == 2) or (Target.Variables.targetCore == 2) then
    local cpu2 = FactoryBlock:makeBlock("cpu2")
    local error = cpu2:createImplicit(Require)
    if error ~= nil then
      return error
    end
  end

  return {HeaderDeclarations = HeaderDeclarations, Resources = Resources, Require = Require}
end

function Coder.Finalize()
  local Include = StringList:new()
  local Declarations = StringList:new()
  local PreInitCode = StringList:new()
  local PostInitCode = StringList:new()
  local TerminateCode = StringList:new()
  local Require = ResourceList:new()
  local HeaderDeclarations = StringList:new()

  local error
 
  Include:append('plx_hal.h')

  -- determine final destination for generated files
  local installDir = Target.Variables.BUILD_ROOT
  if Target.Variables.genOnly == 1 then
    installDir = Target.Variables.installDir:gsub('%"+', ''):gsub('\\+', '/') -- remove quotes, make all forward slashes
    if not U.fileOrDirectoryExists(installDir .. "/") then
      return "The directory '%s' does not exist." % {installDir}
    end
  end

  -- categorize block instances
  local blockInstancesByType = {}
  for _, b in ipairs(Registry.BlockInstances) do
    if blockInstancesByType[b:getType()] == nil then
      blockInstancesByType[b:getType()] = {}
    end
    table.insert(blockInstancesByType[b:getType()], b)
  end

  -- establish log file name
  local logFileName = "%s/%s_log.txt" % {installDir, Target.Variables.BASE_NAME}

  -- first make sure that an adequate base-task trigger timer is present
  local triggerOriginBlock, triggerOriginAbsFreqError
  for _, b in ipairs(Registry.BlockInstances) do
    local ts = b:requestImplicitTrigger(Target.Variables.SAMPLE_TIME)
    if (ts ~= nil) and (ts > 0) then
      local freqError = math.abs(1 / ts - 1 / Target.Variables.SAMPLE_TIME)
      if (triggerOriginBlock == nil) or (freqError < triggerOriginAbsFreqError) then
        -- (new) best fit
        triggerOriginBlock = b
        triggerOriginAbsFreqError = freqError
        U.log(
            'New best fit for default triggering block: bid=%d, Ts=%e, Ferror=%e\n' %
                {b:getId(), ts, freqError})
      end
    end
  end
  if (triggerOriginBlock == nil) or (triggerOriginAbsFreqError ~= 0) then
    -- no (perfectly) suitable block found - attempt to create invisible timer block
    U.log(
        '- No (perfectly) suitable triggering block found. Attempt creating implicit timer.\n')
    local timerCandidate = FactoryBlock:makeBlock("timer")
    local error = timerCandidate:createImplicit({
      f = 1 / Target.Variables.SAMPLE_TIME
    })
    if error == nil then
      local ts = timerCandidate:requestImplicitTrigger(Target.Variables
                                                           .SAMPLE_TIME)
      local freqError = math.abs(1 / ts - 1 / Target.Variables.SAMPLE_TIME)
      if (triggerOriginBlock == nil) or (freqError < triggerOriginAbsFreqError) then
        -- new timer is better fit
        U.log('- Retaining new implicit timer (Ferror=%e).\n' % {freqError})
        if blockInstancesByType[timerCandidate:getType()] == nil then
          blockInstancesByType[timerCandidate:getType()] = {}
        end
        table.insert(blockInstancesByType[timerCandidate:getType()],
                     timerCandidate)
        triggerOriginBlock = timerCandidate
      end
    end
  end
  if triggerOriginBlock == nil then
    return 'Unable to allocate implicit model trigger.'
  end

  -- provide implicit base trigger to blocks that might need it
  for _, b in ipairs(Registry.BlockInstances) do
    local f = b:setImplicitTriggerSource(triggerOriginBlock:getId())
  end

  -- inform all trigger sources about the sinks attached to them
  for _, b in ipairs(Registry.BlockInstances) do
    local f = b:setSinkForTriggerSource()
  end

  -- propagate all trigger connections
  for _, b in ipairs(Registry.BlockInstances) do
    local f = b:propagateTriggerSampleTime()
  end

  -- make sure model has a task trigger, if not create implicit
  if blockInstancesByType['tasktrigger'] == nil then
    -- create an implicit trigger
    local taskTrigger = FactoryBlock:makeBlock("tasktrigger")

    blockInstancesByType['tasktrigger'] = {}
    table.insert(blockInstancesByType['tasktrigger'], taskTrigger)

    -- connect to trigger block
    local blockForTaskTrigger
    -- connect to ADC, if possible
    if blockInstancesByType['adc'] ~= nil then
      local candiates = {}
      -- find ADCs at correct sample time
      for _, adc in ipairs(blockInstancesByType['adc']) do
        if adc:getTriggerSampleTime() == nil then
          U.dumpLog(logFileName)
          return 'ADC %i has undefined trigger time' % {adc:getId()}
        end
        U.log('- ADC %i detected at ts=%f.\n' %
                  {adc:getId(), adc:getTriggerSampleTime()})
        if adc:getTriggerSampleTime() == Target.Variables.SAMPLE_TIME then
          table.insert(candiates, adc)
        end
      end
      if #candiates ~= 0 then
        -- find ADC that takes the longest to complete conversions
        local maxConversionTime = 0
        for _, adc in ipairs(candiates) do
          if maxConversionTime < adc:getTotalConversionTime() then
            maxConversionTime = adc:getTotalConversionTime()
            blockForTaskTrigger = adc
          end
        end
      end
    end

    if blockForTaskTrigger == nil then
      -- no suitable ADC found, use timer
      blockForTaskTrigger = triggerOriginBlock
    end

    taskTrigger:setImplicitTriggerSource(blockForTaskTrigger:getId())
    local sink = {type = 'modtrig', bid = taskTrigger:getId()}
    blockForTaskTrigger:setSinkForTriggerSource(sink)
    for _, b in ipairs(Registry.BlockInstances) do
      local f = b:propagateTriggerSampleTime()
    end
  end

  -- final task trigger check
  if blockInstancesByType['tasktrigger'] == nil then
    U.dumpLog(logFileName)
    return "Exception: Model does not have a task trigger."
  else
    local ts = blockInstancesByType['tasktrigger'][1]:getTriggerSampleTime(
                   'modtrig')
    if ts == nil then
      U.dumpLog(logFileName)
      return "Exception: Task trigger does not have a defined sample time."
    else
      local relTol = 1e-6
      if Target.Variables.taskFreqTol == 2 then
        relTol = Target.Variables.SampleTimeRelTol/100
      end

      local absTsError =  math.abs(ts - Target.Variables.SAMPLE_TIME)
      local absTsTol = relTol*Target.Variables.SAMPLE_TIME

      if absTsError > absTsTol then
        local msg
        if Target.Variables.taskFreqTol == 1 then
          msg = [[
              Unable to accurately meet the desired step size:
              - desired value: %(ts_desired)e
              - closest achievable value: %(ts_actual)e

              You may want to modify the "Step size tolerance" parameter under Coder Options->Target->General.
          ]] % {
                ts_desired = Target.Variables.SAMPLE_TIME,
                ts_actual = ts
          }
        else
          msg = [[
              Unable to meet the allowable step size tolerance:
              - desired step size: %(ts_desired)e
              - closest achievable step size: %(ts_actual)e
              - relative error: %(rerror)i %%

              You may want to modify the trigger chain or adjust the "Step size tolerance" parameter under Coder Options->Target->General.
          ]] % {
                ts_desired = Target.Variables.SAMPLE_TIME,
                ts_actual = ts,
                rerror = math.ceil(100*math.abs((ts-Target.Variables.SAMPLE_TIME)/Target.Variables.SAMPLE_TIME))
          }
        end
        U.dumpLog(logFileName)
        return msg
      end
    end
  end

  -- finalize all blocks
  local f = {
    Require = Require,
    Include = StringList:new(),
    Declarations = StringList:new(),
    PreInitCode = StringList:new(),
    PostInitCode = StringList:new(),
    TerminateCode = StringList:new(),
    InterruptEnableCode = StringList:new(),
    TimerSyncCode = StringList:new(),
    BackgroundTaskCodeBlocks = StringList:new(),
    PilHeaderDeclarations = StringList:new(),
    ClaInclude = StringList:new(),
    ClaDeclarations = StringList:new(),
    ClaCode = StringList:new()
  }

  -- generate pre-init code for external libraries
  for name, par in pairs(Registry.ExternalLibraries) do
    if par.PreInitCode ~= nil then
      f.PreInitCode:append('// initialization of %s' % {par.LibFileName})
      for _, v in ipairs(par.PreInitCode) do
        f.PreInitCode:append(v)
      end
    end
  end

  for _, b in ipairs(Registry.BlockInstances) do
    local f = b:finalize(f)
    if type(f) == 'string' then
      U.dumpLog(logFileName)
      return f
    end
  end

  -- create PIL structure
  for _, v in ipairs(f.PilHeaderDeclarations) do
    HeaderDeclarations:append(v .. '\n')
  end

  U.log('\nBlock coding complete.\n\n')
  U.log('Blocks in model: %s\n' % {dump(blockInstancesByType)})
  U.log('\n\n')
  U.log('Target settings: %s\n' % {dump(Target)})

  local error = U.dumpLog(logFileName)
  if error ~= nil then
    return error
  end

  -- tag step function to allow special linking
  Declarations:append('#pragma CODE_SECTION(%s_step, "step")\n' % {Target.Variables.BASE_NAME})

  -- create sandboxed low-level code
  Declarations:append('extern void %s_initHal();\n' %
                          {Target.Variables.BASE_NAME})
  PreInitCode:append('%s_initHal();\n' % {Target.Variables.BASE_NAME})
  error = C.generateHalCode('%s/%s_hal.c' %
                        {
        Target.Variables.BUILD_ROOT, Target.Variables.BASE_NAME
      }, f)
  if error ~= nil then
    return error
  end

  -- create CLA code file
  if T.getTargetParameters()['clas'] ~= nil then
    error = C.generateClaCode('%s/%s_cla.cla' %
                        {
        Target.Variables.BUILD_ROOT, Target.Variables.BASE_NAME
      }, f)
    if error ~= nil then
      return error
    end
  end

  -- version ID
  local tspVerDef = '#undef TSP_VER'
  local mav, miv = string.match(Target.Version, '(%d+).(%d+)')
  if mav ~= nil and miv ~= nil then
    local versionHex = 256 * tonumber(mav) + tonumber(miv)
    tspVerDef = '#define TSP_VER 0x%X' % {versionHex}
  end

  -- process templates
  local dict = {}
  table.insert(dict,
               {before = "|>BASE_NAME<|", after = Target.Variables.BASE_NAME})
  table.insert(dict, {
    before = "|>TARGET_ROOT<|",
    after = Target.Variables.TARGET_ROOT
  })
  table.insert(dict, {before = "|>TSP_VER_DEF<|", after = tspVerDef})
  table.insert(dict,
               {before = "|>DATA_TYPE<|", after = Target.Variables.FLOAT_TYPE})

  if Target.Variables.genOnly ~= 1 and Target.Variables.buildConfig ~= 2 then
    table.insert(dict, {before = "|>FLASH_FLAG<|", after = "#define _FLASH"})
  else
    table.insert(dict, {before = "|>FLASH_FLAG<|", after = ""})
  end

  local targetDirDict = {
    TI28004x = '28004x',
    TI2806x = '2806x',
    TI2833x = '2833x',
    TI2837xS = '2837x',
    TI2837x = '2837x',
    TI2838x = '2838x'
  }
  local familySrcDir = Target.Variables.TARGET_ROOT .. "/ccs/" ..
                       targetDirDict[Target.Name]
   
  local corePostfix= ""
  if Target.Variables.targetCore == 2 then
    corePostfix = "_cpu2"
  end

  local coreTemplatesDir = familySrcDir .. "/templates" .. corePostfix
  local coreAppDir = familySrcDir .. "/app" .. corePostfix

  if Target.Variables.genOnly ~= 1 then
    --[[
        "One-click" build and flash
    --]]

    if Target.Variables.FLOAT_TYPE ~= 'float' then
      return
          "Double precision floating point format not supported. Please change the setting on the 'General' tab of the 'Coder options' dialog to 'float'."
    end

    local codegenDir = Target.FamilySettings.ExternalTools.codegenDir:gsub(
                           '%"+', ''):gsub('\\+', '/') -- remove quotes, make all forward slashes
    if not U.fileOrDirectoryExists(codegenDir) then
      return "Codegen tools directory '%s' not found." % {codegenDir}
    end

    local uniflashFile
    local board = T.getBoardNameFromComboIndex(Target.Variables.board)
    if board ~= 'custom' then
      uniflashFile = Target.Variables.TARGET_ROOT .. "/templates/uniflash/" ..
                         T.getUniflashConfig(board)
    else
      uniflashFile = Target.Variables.uniflashFile
    end

    local uniflashDir = Target.FamilySettings.ExternalTools.uniflashDir:gsub(
                            '%"+', ''):gsub('\\+', '/') -- remove quotes, make all forward slashes
    if not U.fileOrDirectoryExists(uniflashDir) then
      return "Uniflash directory '%s' not found." % {uniflashDir}
    end

    if not U.fileOrDirectoryExists(uniflashFile) then
      return "Uniflash configuration file '%s' not found." % {uniflashFile}
    end

    table.insert(dict, {before = "|>INSTALL_DIR<|", after = './'})
	table.insert(dict, {
	  before = "|>BIN_DIR<|",
	  after = "./output_%s%s" % {Target.Name, corePostfix}
	})
    table.insert(dict, {before = "|>CG_PATH<|", after = codegenDir})
    table.insert(dict, {before = "|>SRC_ROOT<|", after = familySrcDir})

    local uniflashExe = ""
    if Target.Variables.HOST_OS == "win" then
      uniflashExe = "%s/dslite.bat" % {uniflashDir}
    else
      uniflashExe = "%s/dslite.sh" % {uniflashDir}
    end
    if not U.fileOrDirectoryExists(uniflashExe) then
      return "Uniflash executable '%s' not found." % {uniflashExe}
    end

    if uniflashFile:sub(-#".ccxml") == ".ccxml" then
      table.insert(dict, {before = "|>CCXML_FILE<|", after = uniflashFile})
    else
      table.insert(dict, {before = "|>CCXML_FILE<|", after = ""})
    end

    table.insert(dict, {before = "|>FLASH_EXE<|", after = uniflashExe})

    -- handle instaSPIN as a special case
    local mk_postfix = ''
    if blockInstancesByType['est'] ~= nil then
      if Target.Variables.buildConfig ~= 1 then
        return "'Run from RAM' not supported for models with InstaSpin block."
      end
      mk_postfix = '_instaspin'
      table.insert(dict, {before = "|>INSTASPIN<|", after = "YES"})
    else
      table.insert(dict, {before = "|>INSTASPIN<|", after = "NO"})
    end
    table.insert(dict, {before = "|>INSTASPIN<|", after = "NO"})

    -- handle Uniflash version number

    local uniflashVerPath = Target.FamilySettings.ExternalTools.uniflashDir ..
                                "/uniflash/public/version.txt"
    local uniflashVersion
    if not U.fileOrDirectoryExists(uniflashVerPath) then
      uniflashVersion = 6.0 -- recommended UniFlash version in the C2000 manual
    else
      local file, error = io.open(uniflashVerPath, "rb"):read "*all" -- r read mode and b binary mode ; *all reads the whole file
      if file == nil then
        return error
      end
      if file == '' then
        uniflashVersion = 6.0 -- recommended UniFlash version in the C2000 manual
      else
        uniflashVersion = tonumber(file:sub(1, 3));
      end
    end

    if Target.Variables.buildConfig < 3 then
      table.insert(dict, {
        before = "|>LINKER_CMD_FILE<|",
        after = '%s/%s' %
            {coreAppDir, T.getLinkerFileName(Target.Variables.buildConfig)}
      })
    else
      if string.sub(Target.Variables.LinkerCommandFile, -4) ~= ".cmd" then
        return "Invalid linker command file."
      end
      if not U.fileOrDirectoryExists(Target.Variables.LinkerCommandFile) then
        return "Linker command file '%s' not found." %
                   {Target.Variables.LinkerCommandFile}
      end
      table.insert(dict, {
        before = "|>LINKER_CMD_FILE<|",
        after = Target.Variables.LinkerCommandFile
      })
    end

    -- the check for update command has to be executed as part of the make to
    -- avoid the flashing-up of a windows console
    local checkForUpdateCommand = ''
    local checkerToolDir = '%s/bin/tsp-ver-getter' % {Target.Variables.TARGET_ROOT}
    if (Target.Variables.CheckForUpdates == 1) and U.fileOrDirectoryExists(checkerToolDir) then
      checkForUpdateCommand = '"%s/bin/tsp-ver-getter/get-tsp-ver" /download/tsp_c2000 > "%s/tsp_%s_versions.txt"' 
                               % {Target.Variables.TARGET_ROOT, Target.Variables.BUILD_ROOT, Target.Name}
    end 
    table.insert(dict, {
      before = "|>CHECK_FOR_UPDATE_COMMAND<|",
      after = checkForUpdateCommand
    })   

    -- configure user defined flags for compiler and linker
    local compilerFlags = '\\'
    local linkerFlags = ''

    for _, v in ipairs(Registry.CompilerFlags) do
      compilerFlags = compilerFlags .. '\n' .. v .. '\\'
    end

    for _, v in ipairs(Registry.LinkerFlags) do
      linkerFlags = linkerFlags .. '\n' .. v
    end

    -- add external libraries
    for _, par in pairs(Registry.ExternalLibraries) do
       if par.IncludePath ~= nil then
         compilerFlags = compilerFlags .. '\n--include_path="%s" \\' % {par.IncludePath}
       end
       if par.LibFilePath ~= nil then
         linkerFlags = linkerFlags .. '\n-i "%s"' % {par.LibFilePath}
       end
       if par.LibFileName ~= nil then
         linkerFlags = linkerFlags .. '\n-l %s' % {par.LibFileName}
       end
    end
    table.insert(dict, {before = "|>LFLAGS<|", after = linkerFlags})
    table.insert(dict, {before = "|>CFLAGS<|", after = compilerFlags})

    -- generate make and linker files
    error = U.copyTemplateFile(coreTemplatesDir .. "/link%s.lkf" % {mk_postfix},
                       Target.Variables.BUILD_ROOT .. "/" ..
                           Target.Variables.BASE_NAME .. ".lkf", dict)
    if error ~= nil then
      return error
    end

    if uniflashVersion < 6.1 then -- https://e2e.ti.com/support/microcontrollers/c2000/f/171/p/933199/3448467#3448467
      table.insert(dict, {before = "|>AUTO_START_OPTION<|", after = ""})
    else
      table.insert(dict, {before = "|>AUTO_START_OPTION<|", after = "-u"})
    end
    error = U.copyTemplateFile(coreTemplatesDir .. "/main.mk", Target.Variables
                           .BUILD_ROOT .. "/" .. Target.Variables.BASE_NAME ..
                           ".mk", dict)
    if error ~= nil then
      return error
    end
    -- generate code entry
    error = U.copyTemplateFile(coreTemplatesDir .. "/main.c", Target.Variables.BUILD_ROOT .. "/" .. Target.Variables.BASE_NAME .. "_main.c", dict)
    if error ~= nil then
      return error
    end
  else
    --[[
        Generate files into Eclipse project and build/debug from there
    --]]
    table.insert(dict, {before = "|>INSTALL_DIR<|", after = installDir})
    table.insert(dict, {before = "|>RUN_PIL_PREP<|", after = 0}) -- PIL Prep Tool will likely not be needed
    table.insert(dict, {before = "|>BUILD_ROOT<|", after = Target.Variables.BUILD_ROOT})
    if T.getTargetParameters()['clas'] ~= nil then
       table.insert(dict, {before = "|>HAS_CLA<|", after = "TRUE"})
    else
       table.insert(dict, {before = "|>HAS_CLA<|", after = "FALSE"})
    end

    error = U.copyTemplateFile(Target.Variables.TARGET_ROOT .. "/templates/install.mk",
                       Target.Variables.BUILD_ROOT .. "/" ..
                           Target.Variables.BASE_NAME .. ".mk", dict)
    if error ~= nil then
      return error
    end

    error = U.copyTemplateFile(Target.Variables.TARGET_ROOT ..
                             "/templates/cg.mk",
                         installDir .. "/cg.mk", dict)
    if error ~= nil then
      return error
    end

    error = U.copyTemplateFile(coreTemplatesDir .. "/main.c", installDir ..
                          "/" .. Target.Variables.BASE_NAME .. "_main.c", dict)
    if error ~= nil then
      return error
    end
  end

  return {
    HeaderDeclarations = HeaderDeclarations,
    Declarations = Declarations,
    PreInitCode = PreInitCode,
    PostInitCode = PostInitCode,
    TerminateCode = TerminateCode,
    Include = Include,
    Require = Require
  }
end

return Coder
