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
local U = {}

math.randomseed(os.time())
local random = math.random

local LogText = StringList:new()

function U.log(line)
  LogText:append(line)
end

function U.dumpLog(filename)
  local file, e = io.open(filename, "w")
  if file == nil then
    return e
  end
  io.output(file)
  for _, v in ipairs(LogText) do
    io.write(v);
  end
  file.close()
end

function U.fileOrDirectoryExists(file)
  return (Plecs:FileExists(file) or Plecs:DirectoryExists(file))
end

function U.copyTemplateFile(src, dest, subs)
  local file, e = io.open(src, "rb")
  if file == nil then
    return e
  end
  local src_content = file:read("*all")
  io.close(file)
  local dest_content

  file = io.open(dest, "rb")
  if (file == nil) then
    dest_content = nil
  else
    dest_content = file:read("*all")
    io.close(file)
    dest_content = string.gsub(dest_content, "\r", "")
  end

  if subs ~= nil then
    for _, v in pairs(subs) do
      local before = v["before"]
      local after = v["after"]
      src_content = string.gsub(src_content, before, after)
    end
  end

  src_content = string.gsub(src_content, "\r", "")

  if not (src_content == dest_content) then
    file, e = io.open(dest, "w")
    if file == nil then
      return e
    end
    io.output(file)
    io.write(src_content)
    file.close()
  end
end

function U.getFromArrayOrScalar(field, index, majordim)
  if #field == 1 then
    return field[1]
  elseif #field == majordim then
    return field[index]
  else
    return nil
  end
end

function U.round(num, numDecimalPlaces)
  if numDecimalPlaces and numDecimalPlaces > 0 then
    local mult = 10 ^ numDecimalPlaces
    return math.floor(num * mult + 0.5) / mult
  end
  return math.floor(num + 0.5)
end

function U.guid()
  local template = '{0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX, 0xXX}'
  return string.gsub(template, '[X]', function(c)
    local v = (c == 'X') and random(0, 0xf)
    return string.format('%x', v)
  end)
end

function U.isValidCName(name)
  if string.match(name, '[^a-zA-Z0-9_]') ~= nil then
    return false
  end
  if string.match(string.sub(name, 1, 1), '[0-9]') ~= nil then
    return false
  end
  return true
end

function U.isPositiveScalar(val)
  if type(val) ~= 'number' then
    return false
  end
  if val <= 0 then
    return false
  end
  return true
end

function U.isPositiveIntScalar(val)
  if type(val) ~= 'number' then
    return false
  end
  if math.floor(val) ~= val or val < 1 then
    return false
  end
  return true
end

function U.isNonNegativeIntScalar(val)
  if type(val) ~= 'number' then
    return false
  end
  if math.floor(val) ~= val or val < 0 then
    return false
  end
  return true
end

function U.isPositiveIntScalarOrArray(val)
  if type(val) == 'table' then
    for _, v in pairs(val) do
      if not U.isNonNegativeIntScalar(v) then
        return false
      end
    end
    return true
  else
    return U.isNonNegativeIntScalar(val)
  end
end

function U.getInstallDir()
  local installDir = Target.Variables.BUILD_ROOT

  if Target.Variables.genOnly == 1 then
    installDir = Target.Variables.installDir:gsub('%"+', ''):gsub('\\+', '/') -- remove quotes, make all forward slashes
    local tempDir = Target.Variables.BUILD_ROOT:gsub('%"+', ''):gsub('\\+', '/')
    if installDir .. Target.Variables.BASE_NAME .. "_codegen" == tempDir then -- when installDir entry is blank, returns current path
      installDir = Target.Variables.BUILD_ROOT --  use default codegen dir if installDir is blank
    end
  end
  return installDir
end

function U.copyTemplateToBuildDir(template, destname, dict)
  local installDir = U.getInstallDir()
  if not U.fileOrDirectoryExists(installDir .. "/") then
    return "The directory '%s' does not exist." % {installDir}
  end
  U.copyTemplateFile(template, installDir .. "/" .. destname, dict)
end

function U.determineCanBitTiming(args)
  local bitInTqMin, bitInTqMax
  if args.bit_length_tq ~= nil then
    bitInTqMin = args.bit_length_tq
    bitInTqMax = args.bit_length_tq
  else
    tseg1_r = {
     (args.sample_point*(1+args.tseg2_range[1])-1)/(1-args.sample_point),
     (args.sample_point*(1+args.tseg2_range[2])-1)/(1-args.sample_point),
    }
  
    tseg1_r = {
      math.max(math.ceil(tseg1_r[1]), args.tseg1_range[1]),
      math.min(math.floor(tseg1_r[2]), args.tseg1_range[2])
    }
  
    bitInTq1 = {
      1+tseg1_r[1]+args.tseg2_range[1],
      1+tseg1_r[2]+args.tseg2_range[2],
    }

    local tseg2_r = {
     (1-args.sample_point)*(args.tseg1_range[1]+1)/args.sample_point,
     (1-args.sample_point)*(args.tseg1_range[2]+1)/args.sample_point,
    }
   
    tseg2_r = {
      math.max(math.ceil(tseg2_r[1]), args.tseg2_range[1]),
      math.min(math.floor(tseg2_r[2]), args.tseg2_range[2])
    }
  
    bitInTq2 = {
      1+tseg2_r[1]+args.tseg1_range[1],
      1+tseg2_r[2]+args.tseg1_range[2],
    }
  
    bitInTqMin = math.max(bitInTq1[1], bitInTq2[1])
    bitInTqMax = math.min(bitInTq1[2], bitInTq2[2])
  end
  
  -- limit divider range to valid number of TQs
  local maxDiv = math.floor(args.clk / args.baud / bitInTqMin)
  local minDiv = math.ceil(args.clk / args.baud / bitInTqMax)

  maxDiv = math.min(maxDiv, args.brpMax)

  if minDiv > maxDiv then
    return 'Unable to find suitable baudrate divider.'
  end

  -- search for brp that provide exact bitrate matches
  local brp_options = {}
  for div = minDiv, maxDiv do
    local fq = args.clk / args.baud / div
    if fq == math.floor(fq) then
      table.insert(brp_options, div)
    end
  end
  if #brp_options == 0 then
    return 'Unable to find suitable baudrate divider.'
  end

  -- search for brp that provides best match for sample point
  local settings 
  local min_sample_point_abs_error
  for _, brp in ipairs(brp_options) do
    seg = math.floor(args.clk / brp / args.baud + 0.5)
    tseg1 = math.floor(args.sample_point * seg + 0.5) - 1
    if tseg1 < args.tseg1_range[1] then
      tseg1 = args.tseg1_range[1]
    elseif tseg1 > args.tseg1_range[2] then
      tseg1 = args.tseg1_range[2]
    end
    tseg2 = seg - 1 - tseg1
    if (tseg2 >= args.tseg2_range[1]) and (tseg2 <= args.tseg2_range[2]) and (tseg1 >= tseg2) then
      sample_point = (1+tseg1)/(1+tseg1+tseg2)
      sample_point_abs_error = math.abs(args.sample_point - sample_point)
      if (min_sample_point_abs_error == nil) or (sample_point_abs_error < min_sample_point_abs_error) then
        min_sample_point_abs_error = sample_point_abs_error
        settings = {
          brp = brp,
          tseg1 = tseg1,
          tseg2 = tseg2,
          sample_point = (1+tseg1)/(1+tseg1+tseg2),
          baud = args.clk/brp/(1+tseg1+tseg2),
        }
      end
    end
  end
  
  if settings == nil then
    return "Calculation of bit rate settings failed."
  end
  
  -- minimal prop segment size = maximal sjw
  sjw_max = math.min(settings.tseg1, settings.tseg2, args.sjw_range[2])
  
  sjw = args.sjw
  if sjw == nil then
    sjw = sjw_max
  end
  if (sjw < args.sjw_range[1]) or (sjw > sjw_max) then
    return 'SJW out of range [%i, %i].' % {args.sjw_range[1], sjw_max}
  end
  
  return {
    brp = settings.brp, 
    tseg1 = settings.tseg1,
    tseg2 = settings.tseg2,
    sjw = sjw,
    baud = settings.baud,
    sample_point = settings.sample_point
  }
end

function U.parseVersionString(vString)
  local vTable = {}
  for str in string.gmatch(vString, "([^.]+)") do
    table.insert(vTable, tonumber(str))
  end
  return vTable
end

function U.compareVersionStrings(versionA, versionB)
  -- returns 1 if (versionA > versionB)
  --        -1 if (versionA < versionB)
  --         0 otherwise
  local va = U.parseVersionString(versionA)
  local vb = U.parseVersionString(versionB)
  local numDigits = math.min(#va, #vb) -- if one version has extra digits they are ignored
  for i = 1, numDigits do
    if va[i] ~= vb[i] then
      if va[i] > vb[i] then
        return 1
      else
        return -1
      end
    end
  end
  return 0
end

function U.checkForUpate()
  local revisionHistoryTable = ""
  if Target.Version ~= "dev" then
    local file, error = io.open('%s/tsp_%s_versions.txt' % {Target.Variables.BUILD_ROOT, Target.Name}, "rb")
    if error == nil then
      revisionHistoryTable = file:read("*all")
      file:close()
    end
  end

  if (revisionHistoryTable ~= "") then
    local thisVersion = Target.Version
    local thisPlecsVersion = Target.Variables.PLECS_VERSION
    local revisionHistory = eval(revisionHistoryTable)['c2000']
    local mostRecentVersion = revisionHistory[1].version
    local mostRecentMinPlecs = revisionHistory[1].minplecs
    if U.compareVersionStrings(mostRecentVersion, thisVersion) > 0 then
      local msg
      if U.compareVersionStrings(mostRecentMinPlecs, thisPlecsVersion) <= 0 then
        -- yeah, we can get the latest and greatest!
        msg = [[
          You are using an outdated version of the C2000 TSP.
          - The most recent version is C2000 TSP %(mostRecentVersion)s.
            Please consider updating the TSP.
        ]] % {
          mostRecentVersion = mostRecentVersion
        }
      else
        local mostRecentSupported = "0.0.0"
        for _, rev in ipairs(revisionHistory) do
          if U.compareVersionStrings(mostRecentSupported, thisVersion) > 0 then
            break
          end
          if U.compareVersionStrings(rev.minplecs, thisPlecsVersion) <= 0 then
            mostRecentSupported = rev.version
          end
        end
        if U.compareVersionStrings(mostRecentSupported, thisVersion) > 0 then
          -- there is a newer version available for this version of PLECS
          msg = [[
            You are using an outdated version of the C2000 TSP.
            - The most recent version is C2000 TSP %(mostRecentVersion)s requiring PLECS %(mostRecentMinPlecs)s.
            - The last release supported by your version of PLECS is C2000 TSP %(mostRecentSupported)s.
            Please consider updating the TSP.
          ]] % {
            mostRecentVersion = mostRecentVersion,
            mostRecentMinPlecs = mostRecentMinPlecs,
            mostRecentSupported = mostRecentSupported
          }
        else
          -- PLECS must be upgraded to access a newer TSP version
          msg = [[
            You are using an outdated version of the C2000 TSP.
            - The most recent version is C2000 TSP %(mostRecentVersion)s requiring PLECS %(mostRecentMinPlecs)s.
            Please consider updating PLECS and the TSP.
          ]] % {
            mostRecentVersion = mostRecentVersion,
            mostRecentMinPlecs = mostRecentMinPlecs,
          }
        end
      end
  	  Target:LogMessage('warning', msg)
    end
  end
end

return U
