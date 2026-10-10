/* ============================================================================
 * ECG_LEADOFF  实现
 * LEAD_OFF 模拟输出 → ADC2 独立采样 → 去抖判决（详见 ecg_leadoff.h）
 * ==========================================================================*/

#include "ecg_leadoff.h"
#include "ecg_config.h"
#include "stm32f4xx_conf.h"

/* LEAD_OFF 接线: PA1 = ADC2_IN1（如需换引脚, 同步修改这两行即可） */
#define ECG_LO_GPIO_PIN      GPIO_Pin_1
#define ECG_LO_ADC_CHANNEL   ADC_Channel_1
#define ECG_LO_ADC           ADC2

/*********************************************************************************************************
* 函数名称：ecg_leadoff_init
* 功能功能：初始化导联脱落检测(配置 PA1 模拟输入 + ADC2 软件触发单次转换)
*********************************************************************************************************/
void ecg_leadoff_init(ecg_leadoff_t *h)
{
    GPIO_InitTypeDef      GPIO_InitStructure;
    ADC_CommonInitTypeDef ADC_CommonInitStruct;
    ADC_InitTypeDef       ADC_InitStructure;

    h->cnt      = 0;
    h->lastCode = 0;
    h->status   = 0;

    /* 时钟: GPIOA + ADC2 (ADC2在APB2总线上) */
    RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA, ENABLE);
    RCC_APB2PeriphClockCmd(RCC_APB2Periph_ADC2, ENABLE);

    /* PA1 模拟输入 */
    GPIO_InitStructure.GPIO_Pin   = ECG_LO_GPIO_PIN;
    GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_AN;
    GPIO_InitStructure.GPIO_PuPd  = GPIO_PuPd_NOPULL;
    GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz;
    GPIO_Init(GPIOA, &GPIO_InitStructure);

    /* ADC1/2/3 公用设置(与ADC.c相同参数: 独立模式/Div4/不用DMA) */
    ADC_CommonStructInit(&ADC_CommonInitStruct);
    ADC_CommonInitStruct.ADC_Mode             = ADC_Mode_Independent;
    ADC_CommonInitStruct.ADC_Prescaler        = ADC_Prescaler_Div4;
    ADC_CommonInitStruct.ADC_DMAAccessMode    = ADC_DMAAccessMode_Disabled;
    ADC_CommonInitStruct.ADC_TwoSamplingDelay = ADC_TwoSamplingDelay_5Cycles;
    ADC_CommonInit(&ADC_CommonInitStruct);

    /* ADC2: 软件触发单次转换(不占用TIM2/DMA, 与ADC1流水线完全独立) */
    ADC_StructInit(&ADC_InitStructure);
    ADC_InitStructure.ADC_Resolution           = ADC_Resolution_12b;
    ADC_InitStructure.ADC_ScanConvMode         = DISABLE;
    ADC_InitStructure.ADC_ContinuousConvMode   = DISABLE;
    ADC_InitStructure.ADC_ExternalTrigConvEdge = ADC_ExternalTrigConvEdge_None;
    ADC_InitStructure.ADC_ExternalTrigConv     = ADC_ExternalTrigConv_T1_CC1;
    ADC_InitStructure.ADC_DataAlign            = ADC_DataAlign_Right;
    ADC_InitStructure.ADC_NbrOfConversion      = 1;
    ADC_Init(ECG_LO_ADC, &ADC_InitStructure);

    ADC_RegularChannelConfig(ECG_LO_ADC, ECG_LO_ADC_CHANNEL, 1, ADC_SampleTime_480Cycles);

    ADC_Cmd(ECG_LO_ADC, ENABLE);
}

/*********************************************************************************************************
* 函数名称：ecg_leadoff_step
* 功能功能：采样一次 LEAD_OFF 并做去抖判决(每样本/500Hz 调用)
* 返 回 值：当前状态 0=正常 1=脱落
*********************************************************************************************************/
uint8_t ecg_leadoff_step(ecg_leadoff_t *h)
{
    uint32_t guard = 1000u;   /* EOC 等待超时保护(防异常卡死); 正常约1计数即过 */
    uint16_t code;

    /* 软件启动一次转换, 等待完成(480周期@21MHz≈23μs, 2ms节拍下开销≈1.2%) */
    ADC_SoftwareStartConv(ECG_LO_ADC);
    while((ADC_GetFlagStatus(ECG_LO_ADC, ADC_FLAG_EOC) == RESET) && (guard > 0u))
    {
        guard--;
    }
    code = ADC_GetConversionValue(ECG_LO_ADC);   /* 读DR同时清EOC */
    h->lastCode = code;

    /* 对称去抖: 高于阈值+1, 低于-1; 满 ECG_LO_DEBOUNCE 判脱落 */
    if(code > (uint16_t)ECG_LO_THR_CODE)
    {
        if(h->cnt < (uint16_t)ECG_LO_DEBOUNCE)
        {
            h->cnt++;
        }
    }
    else
    {
        if(h->cnt > 0u)
        {
            h->cnt--;
        }
    }
    h->status = (h->cnt >= (uint16_t)ECG_LO_DEBOUNCE) ? 1u : 0u;

    return h->status;
}
