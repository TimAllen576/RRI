/*
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
 */

#include "pil.h"

// FIXME: Consider renaming aHandle, or aChannel?

extern bool PLXHAL_DIO_get(uint16_t aHandle);
extern void PLXHAL_DIO_set(uint16_t aHandle, bool aVal);

extern void PLXHAL_PWM_setDutyFreqPhase(uint16_t aChannel, float aDuty, float aFreqScaling, float aPhase);
extern void PLXHAL_PWM_setDuty(uint16_t aHandle, float aDuty);
extern void PLXHAL_PWM_setToPassive(uint16_t aChannel);
extern void PLXHAL_PWM_setToOperational(uint16_t aChannel);
extern void PLXHAL_PWM_setSequence(uint16_t aChannel, uint16_t aSequence);
extern void PLXHAL_PWM_setScaledDeadTimeCounts(uint16_t aChannel, float aScaling, uint16_t aNominalCounts);
extern void PLXHAL_PWM_setDutyAndPeak(uint16_t aHandle, float aDuty, float aPeak);
extern void PLXHAL_PWM_setDutyFreqPhaseAndPeak(uint16_t aHandle, float aDuty, float aFreqScaling, float aPhase, float aPeak);
extern void PLXHAL_PWM_enableAllOutputs();

extern void PLXHAL_PWR_setEnableRequest(bool aEnable);
extern void PLXHAL_PWR_syncdPwmEnable();
extern bool PLXHAL_PWR_isEnabled();

extern float PLXHAL_ADC_getIn(uint16_t aHandle, uint16_t aChannel);

extern void PLXHAL_DAC_set(uint16_t aHandle, float aValue);

extern uint32_t PLXHAL_QEP_getCounter(uint16_t aChannel);
extern bool PLXHAL_QEP_getAndCearIndexFlag(uint16_t aChannel);
extern uint32_t PLXHAL_QEP_getIndexLatchCounter(uint16_t aChannel);

bool PLXHAL_CAP_getNewValues(uint16_t aChannel, uint16_t aNewPrescale, uint32_t *aValues, bool *aOverflowFlag);

typedef struct PLXHAL_EST_INPUTS {
  float ia;
  float ib;
  float va;
  float vb;
  float rs;
  bool enable;
  int foreAngleDir;
} PLXHAL_EST_Inputs_t;

typedef struct PLXHAL_EST_OUTPUTS {
  float angle_rad;
  float fm_rps;
  int state;
  float flux_wb;
  float rs_ohm;
} PLXHAL_EST_Outputs_t;

extern void PLXHAL_EST_update(int16_t aChannel, const PLXHAL_EST_Inputs_t *aInputs, PLXHAL_EST_Outputs_t *aOutputs);

extern bool PLXHAL_CAN_getMessage(uint16_t aChannel, uint16_t aMailBox, unsigned char data[], unsigned char lenMax);
extern void PLXHAL_CAN_putMessage(uint16_t aChannel, uint16_t aMailBox, unsigned char data[], unsigned char len);
extern void PLXHAL_CAN_setBusOn(uint16_t aChannel, bool aBusOn);
extern bool PLXHAL_CAN_getIsBusOn(uint16_t aChannel);
extern bool PLXHAL_CAN_getIsErrorActive(uint16_t aChannel);

extern bool PLXHAL_MCAN_getMessage(uint16_t aChannel, uint16_t aMailBox, unsigned char data[], unsigned char lenMax, uint16_t *aFlags);
extern void PLXHAL_MCAN_putMessage(uint16_t aChannel, uint16_t aMailBox, unsigned char data[], unsigned char len);
extern void PLXHAL_MCAN_setBusOn(uint16_t aChannel, bool aBusOn);
extern bool PLXHAL_MCAN_getIsBusOn(uint16_t aChannel);
extern bool PLXHAL_MCAN_getIsErrorActive(uint16_t aChannel);

uint16_t PLXHAL_SPI_getRxFifoLevel(int16_t aChannel);
bool PLXHAL_SPI_putWords(int16_t aChannel, uint16_t *aData, uint16_t aLen);
bool PLXHAL_SPI_getWords(int16_t aChannel, uint16_t *aData, uint16_t aLen);
bool PLXHAL_SPI_getAndResetRxOverrunFlag(int16_t aChannel);

extern float PLXHAL_DISPR_getTask0LoadInPercent();

extern uint32_t PLXHAL_DISPR_getTimeStamp0();
extern uint32_t PLXHAL_DISPR_getTimeStamp1();
extern uint32_t PLXHAL_DISPR_getTimeStamp2();
extern uint32_t PLXHAL_DISPR_getTimeStamp3();
extern uint32_t PLXHAL_DISPR_getTimeStampB();
extern uint32_t PLXHAL_DISPR_getTimeStampD();
extern uint32_t PLXHAL_DISPR_getTimeStampP();
