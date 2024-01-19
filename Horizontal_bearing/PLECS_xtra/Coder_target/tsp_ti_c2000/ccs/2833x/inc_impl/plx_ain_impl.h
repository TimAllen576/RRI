/*
   Copyright (c) 2014-2016 by Plexim GmbH
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

#ifndef PLX_AIN_IMPL_H_
#define PLX_AIN_IMPL_H_

#define PLX_AIN_NUM_CHANNELS 16

typedef enum PLX_AIN_UNIT {
	PLX_AIN_ADC=0
} PLX_AIN_Unit_t;

typedef struct PLX_AIN_ADC_PARAMS {
	union ADCTRL1_REG ADCTRL1;
	union ADCTRL2_REG ADCTRL2;
	union ADCTRL3_REG ADCTRL3;
	union ADCREFSEL_REG ADCREFSEL;
} PLX_AIN_AdcParams_t;

typedef struct PLX_AIN_CHANNEL_PARAMS {
    uint16_t trigsel;
    float scale;
    float offset;
} PLX_AIN_ChannelParams_t;

typedef struct PLX_AIN_OBJ
{
	volatile struct ADC_REGS *adc;
    float scale[PLX_AIN_NUM_CHANNELS];
    float offset[PLX_AIN_NUM_CHANNELS];
} PLX_AIN_Obj_t;

typedef PLX_AIN_Obj_t *PLX_AIN_Handle_t;

extern void PLX_AIN_getRegisterBase(PLX_AIN_Unit_t aAdcUnit, volatile struct ADC_REGS** aReg);

inline uint16_t PLX_AIN_getIn(PLX_AIN_Handle_t aHandle, uint16_t aChannel)
{
    PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;

    PLX_ASSERT(aChannel < PLX_AIN_NUM_CHANNELS);

    uint16_t adc_result;

    switch(aChannel)
    {
    	case 0:
    		adc_result = obj->adc->ADCRESULT0 >> 4;
    		break;
    	case 1:
    		adc_result = obj->adc->ADCRESULT1 >> 4;
			break;
    	case 2:
    		adc_result = obj->adc->ADCRESULT2 >> 4;
			break;
    	case 3:
    		adc_result = obj->adc->ADCRESULT3 >> 4;
			break;
    	case 4:
    		adc_result = obj->adc->ADCRESULT4 >> 4;
			break;
    	case 5:
    		adc_result = obj->adc->ADCRESULT5 >> 4;
			break;
    	case 6:
    		adc_result = obj->adc->ADCRESULT6 >> 4;
			break;
    	case 7:
    		adc_result = obj->adc->ADCRESULT7 >> 4;
			break;
    	case 8:
    		adc_result = obj->adc->ADCRESULT8 >> 4;
			break;
    	case 9:
    		adc_result = obj->adc->ADCRESULT9 >> 4;
			break;
    	case 10:
    		adc_result = obj->adc->ADCRESULT10 >> 4;
			break;
    	case 11:
    		adc_result = obj->adc->ADCRESULT11 >> 4;
			break;
    	case 12:
    		adc_result = obj->adc->ADCRESULT12 >> 4;
			break;
    	case 13:
    		adc_result = obj->adc->ADCRESULT13 >> 4;
			break;
    	case 14:
    		adc_result = obj->adc->ADCRESULT14 >> 4;
			break;
    	case 15:
    		adc_result = obj->adc->ADCRESULT15 >> 4;
			break;
    	default:
    		break;
    }
    return adc_result;
}

inline float PLX_AIN_getInF(PLX_AIN_Handle_t aHandle, uint16_t aChannel)
{
    PLX_AIN_Obj_t *obj = (PLX_AIN_Obj_t *)aHandle;
    return ((float)PLX_AIN_getIn(aHandle, aChannel) * obj->scale[aChannel] + obj->offset[aChannel]);
}

#endif /* PLX_AIN_IMPL_H_ */
