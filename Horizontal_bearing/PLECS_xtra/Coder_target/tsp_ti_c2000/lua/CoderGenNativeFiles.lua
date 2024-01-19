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
local C = {}

function C.generateHalCode(filename, recipe)
  local file, e = io.open(filename, "w")
  if file == nil then
    return e
  end
  io.output(file)
  local header = [[
  /*
  * Hardware configuration file for: |<TARGET>|
  * Generated with                 : PLECS |<PLECS_VER>|
  * Generated on                   : |<DATE>|
  */
  ]]
  header = string.gsub(header, '|<TARGET>|', '%s' % {Target.Name})
  header = string.gsub(header, '|<DATE>|', '%s' % {os.date()})
  header = string.gsub(header, '|<PLECS_VER>|',
                       '%s' % {Target.Variables.PLECS_VERSION})
  io.write(header .. '\n')

  io.write('#include "%s"\n' % {'plx_hal.h'});
  io.write('#include "%s"\n' % {'plx_dispatcher.h'})
  local includes_posted = {}
  for _, v in ipairs(recipe.Include) do
    if includes_posted[v] == nil then
      includes_posted[v] = true
      io.write('#include "%s"\n' % {v})
    end
  end
  io.write('\n')

  for _, v in ipairs(recipe.Declarations) do
    io.write('%s\n' % {v});
  end
  io.write('\n')

  -- interrupt enable code
  io.write("void %s_enableTasksInterrupt(void)\n" % {Target.Variables.BASE_NAME})
  io.write('{\n')
  for _, v in ipairs(recipe.InterruptEnableCode) do
    io.write('%s\n' % {v});
  end
  io.write('}\n\n')

  -- timer synchronization code
  io.write("void %s_syncTimers(void)\n" % {Target.Variables.BASE_NAME})
  io.write('{\n')
  for _, v in ipairs(recipe.TimerSyncCode) do
    io.write('%s\n' % {v});
  end
  io.write('}\n\n')

  -- background tasks
  io.write("void %s_background(void)\n" % {Target.Variables.BASE_NAME})
  io.write("{\n")
  if #recipe.BackgroundTaskCodeBlocks ~= 0 then
    io.write("static int task = 0;\n")
    io.write("switch(task){\n")
    for task, code in pairs(recipe.BackgroundTaskCodeBlocks) do
      io.write("    case %i: \n" % {task - 1})
      io.write("    {\n")
      io.write("  %s\n" % {code})
      io.write("    }\n")
      io.write("    break;\n")
    end
    io.write("    default:\n")
    io.write("        break;\n")
    io.write("}\n")
    io.write("task++;\n")
    io.write("if(task >= %i){\n" % {#recipe.BackgroundTaskCodeBlocks})
    io.write("    task = 0;\n")
    io.write("}")
  end
  io.write("\n}\n")

  -- hal initialization code
  io.write('\n')
  io.write('static bool HalInitialized = false;\n')
  io.write('void %s_initHal()\n' % {Target.Variables.BASE_NAME})
  io.write('{\n')
  io.write('  if(HalInitialized == true){\n')
  io.write('    return;\n')
  io.write('  }\n')
  io.write('  HalInitialized = true;\n')
  for _, v in ipairs(recipe.PreInitCode) do
    io.write('%s\n' % {v});
  end
  io.write("\n")
  io.write("// Post init code (for modules that depend on other modules)\n")
  io.write("\n")
  for _, v in ipairs(recipe.PostInitCode) do
    io.write('%s\n' % {v});
  end
  io.write('}\n')

  io.close(file)

  Plecs:Beautify(filename)
end

function C.generateClaCode(filename, recipe)
  local file, e = io.open(filename, "w")
  if file == nil then
    return e
  end
  io.output(file)
  local header = [[
  /*
  * CLA code file
  * Generated with                 : PLECS |<PLECS_VER>|
  * Generated on                   : |<DATE>|
  */
  ]]
  header = string.gsub(header, '|<TARGET>|', '%s' % {Target.Name})
  header = string.gsub(header, '|<DATE>|', '%s' % {os.date()})
  header = string.gsub(header, '|<PLECS_VER>|',
                       '%s' % {Target.Variables.PLECS_VERSION})
  io.write(header .. '\n')

  local includes_posted = {}
  for _, v in ipairs(recipe.ClaInclude) do
    if includes_posted[v] == nil then
      includes_posted[v] = true
      io.write('#include "%s"\n' % {v})
    end
  end
  io.write('\n')

  for _, v in ipairs(recipe.ClaDeclarations) do
    io.write('%s\n' % {v});
  end
  io.write('\n')

  for _, v in ipairs(recipe.ClaCode) do
    io.write('%s\n' % {v});
  end
  io.write('\n')
  
  io.close(file)

  Plecs:Beautify(filename)
end

return C
