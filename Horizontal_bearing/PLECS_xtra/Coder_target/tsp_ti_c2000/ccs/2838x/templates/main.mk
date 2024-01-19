#   Copyright (c) 2019 by Plexim GmbH
#   All rights reserved.
#
#   A free license is granted to anyone to use this software for any legal
#   non safety-critical purpose, including commercial applications, provided
#   that:
#   1) IT IS NOT USED TO DIRECTLY OR INDIRECTLY COMPETE WITH PLEXIM, and
#   2) THIS COPYRIGHT NOTICE IS PRESERVED in its entirety.
#
#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
#   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#   SOFTWARE.

include |>BASE_NAME<|_sources.mk

TARGET_ROOT=|>SRC_ROOT<|
TOOLS_PATH=|>CG_PATH<|
BIN_DIR=|>BIN_DIR<|
OUT_NAME=|>BASE_NAME<|
MAKEFILE=|>BASE_NAME<|.mk
LINKFILE=|>BASE_NAME<|.lkf
INSTALL_DIR=|>INSTALL_DIR<|
BASE_NAME=|>BASE_NAME<|
CCXML_FILE=|>CCXML_FILE<|
FLASH_EXE=|>FLASH_EXE<|
AUTO_START_OPTION=|>AUTO_START_OPTION<|
CHECK_FOR_UPDATE_COMMAND=|>CHECK_FOR_UPDATE_COMMAND<|

##############################################################

C_SOURCE_FILES=\
$(BASE_NAME)_hal.c \
$(BASE_NAME)_main.c\
dispatcher.c \
power.c \
f2838x_devinit.c\
f2838x_globalvariabledefs.c\
f2838x_adc.c\
dio_2838x.c \
sci_2838x.c \
pwm_2838x.c \
ain_2838x.c \
dac_2838x.c \
qep_2838x.c \
cap_2838x.c \
canbus_2838x.c \
mcan_2838x.c \
spi_2838x.c

CLA_SOURCE_FILES=\
$(BASE_NAME)_cla.cla

ASM_SOURCE_FILES=\
f2838x_codestartbranch.asm\
f2838x_usdelay.asm

HFILES=\
$(MAKEFILE)

##############################################################
space:=
space+=
# for MacOS - NOTE: not tolerant to leading spaces or already escaped spaces '\ '
EscapeSpaces=$(subst $(space),\$(space),$(1))
FlipSlashesBack=$(subst /,\,$(1))

ifeq ($(OS),Windows_NT)
# Windows
SHELL := cmd.exe
FixPath=$(call FlipSlashesBack,$(1))
ClearDir=del /F /Q "$(call FlipSlashesBack,$(1))\*.*"
MoveFile=move /Y "$(call FlipSlashesBack,$(1))" "$(call FlipSlashesBack,$(2))"
CopyFile=copy /Y "$(call FlipSlashesBack,$(1))" "$(call FlipSlashesBack,$(2))"

else
# Linux style
FixPath = $(1)
ClearDir=rm -Rf $(call EscapeSpaces,$(1))/*
MoveFile=mv $(call EscapeSpaces,$(1)) $(call EscapeSpaces,$(2))
CopyFile=cp $(call EscapeSpaces,$(1)) $(call EscapeSpaces,$(2))

endif 

CGT_EXE_PATH=$(TOOLS_PATH)/bin
CGT_LIB_PATH=$(TOOLS_PATH)/lib
CGT_INC_PATH=$(TOOLS_PATH)/include

BIN_DIR_OS=$(call FixPath,$(BIN_DIR))

# compiler / assembler
C_OPTIONS=\
-D_PLEXIM_\
-DCPU1\
-DBASE_NAME=$(BASE_NAME)\
-DEXTERNAL_MODE=1\
-fr$(BIN_DIR)\
-fs$(BIN_DIR)\
-v28 \
-ml \
-mt \
--float_support=fpu32 \
--fp_mode=relaxed \
--float_operations_allowed=all \
-O0 \
--include_path="$(TARGET_ROOT)/app" \
--include_path="$(TARGET_ROOT)/../pil" \
--include_path="$(TARGET_ROOT)/../shrd" \
--include_path="$(TARGET_ROOT)/../inc" \
--include_path="$(TARGET_ROOT)/inc_impl" \
--include_path="$(TARGET_ROOT)/tiinc" \
--include_path="$(TARGET_ROOT)/tiinc/driverlib" \
--include_path="$(TOOLS_PATH)/include" \
--include_path="./" \
-g \
--symdebug:dwarf_version=3\
--abi=eabi \
--cla_support=cla1 \
--tmu_support=tmu0 \
|>CFLAGS<|

L_OPTIONS=$(LINKFILE)

C_OBJFILES=$(patsubst %.c, $(BIN_DIR)/%.obj, $(C_SOURCE_FILES)) \
  $(patsubst %.c, $(BIN_DIR)/%.obj, $(SOURCE_FILES)) \
  $(patsubst %.cla, $(BIN_DIR)/%.obj, $(CLA_SOURCE_FILES))

ASM_OBJFILES=$(patsubst %.asm, $(BIN_DIR)/%.obj, $(ASM_SOURCE_FILES))

OBJFILES=$(C_OBJFILES) $(ASM_OBJFILES)

# make all variables available to sub-makes
export

# Top level 
##########################################################################
all:
ifneq ($(wildcard $(BIN_DIR_OS)),  $(BIN_DIR_OS))
	"$(MAKE)" -f $(MAKEFILE) clean
endif
	"$(MAKE)" -f $(MAKEFILE) $(BIN_DIR)/$(OUT_NAME).elf
	
# Download
##########################################################################rm C
$(BIN_DIR)/$(BASE_NAME).ccxml:	$(call EscapeSpaces,$(CCXML_FILE)) $(MAKEFILE)
							$(call CopyFile,$(CCXML_FILE),$(BIN_DIR)/$(BASE_NAME).ccxml)

ifneq ($(and $(FLASH_EXE),$(CCXML_FILE)),)
download: $(BIN_DIR)/$(OUT_NAME).out $(BIN_DIR)/$(BASE_NAME).ccxml
	"$(FLASH_EXE)" --flash --config=$(call FixPath,$(BIN_DIR)/$(BASE_NAME).ccxml) $(call FixPath,$(BIN_DIR)/$(OUT_NAME).out) $(AUTO_START_OPTION)
else
download:
	@echo "Download not configured."
endif 
 
# Linker
##########################################################################
$(BIN_DIR)/$(OUT_NAME).elf:  $(BIN_DIR)/$(OUT_NAME).out
						$(call CopyFile,$(BIN_DIR)/$(OUT_NAME).out,$(INSTALL_DIR)/$(OUT_NAME).elf)
						$(CHECK_FOR_UPDATE_COMMAND)

$(BIN_DIR)/$(OUT_NAME).out:  $(OBJFILES)
						"$(CGT_EXE_PATH)"/cl2000 -z -i"$(CGT_LIB_PATH)" $(OBJFILES) $(L_OPTIONS)

# Implicit Rules for generated files
##########################################################################
$(BIN_DIR)/%.obj:		%.c	$(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) $<

$(BIN_DIR)/%.obj:		%.cla	$(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) $<

# Explicit rules (we must use explicit rules to allow spaces in $(TARGET_ROOT))
##########################################################################
$(BIN_DIR)/main.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/app/main.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/dispatcher.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/../shrd/dispatcher.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/power.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/../shrd/power.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/f2838x_adc.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/tisrc/f2838x_adc.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/f2838x_globalvariabledefs.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/tisrc/f2838x_globalvariabledefs.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/f2838x_devinit.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/tisrc/f2838x_devinit.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/f2838x_codestartbranch.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/tisrc/f2838x_codestartbranch.asm $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/f2838x_usdelay.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/tisrc/f2838x_usdelay.asm $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/pwm_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/pwm_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/ain_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/ain_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/dio_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/dio_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/qep_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/qep_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/sci_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/sci_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/spi_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/spi_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/dac_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/dac_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"
						
$(BIN_DIR)/cap_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/cap_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"
						
$(BIN_DIR)/canbus_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/canbus_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

$(BIN_DIR)/mcan_2838x.obj:	$(call EscapeSpaces,$(TARGET_ROOT))/src/mcan_2838x.c $(HFILES)
						"$(CGT_EXE_PATH)"/cl2000 $(C_OPTIONS) "$<"

##########################################################################

clean:
ifeq ($(wildcard $(BIN_DIR_OS)),  $(BIN_DIR_OS))
		$(call ClearDir, $(BIN_DIR_OS))
else
		mkdir $(BIN_DIR_OS)
endif
