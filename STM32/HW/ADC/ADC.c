/*********************************************************************************************************
* 模 块 名 称：ADC.c
* 摘        要：ADC模块，TIM2触发 + ADC1 + DMA2循环搬运 + u16环形队列
* 当前版本：1.0.0
* 作        者：SZLY(COPYRIGHT 2018 - 2026 SZLY. All rights reserved.)
* 生成日期：2026年09月20日
* 说        明：本文件由STM32F103版本移植而来
* 注        意：采集链路与F103一致：TIM2更新事件→TRGO触发ADC1→ADC结果由DMA搬到变量→
*               TIM2中断里把变量值写入环形队列。
*               与F103的四个关键差异见各Config函数注释
**********************************************************************************************************
* 取消版本：
* 作        者：
* 生成日期：
* 修改内容：
* 修改文件：
*********************************************************************************************************/
/*********************************************************************************************************
*                                              包含头文件
*********************************************************************************************************/
#include "ADC.h"
#include "stm32f4xx_conf.h"
#include "U16Queue.h"
#include "RCC.h"

/*********************************************************************************************************
*                                              宏定义
*********************************************************************************************************/
#define  ADC_TIM_CLK_HZ      GetAPB1TimClockFreq()  //触发定时器TIM2的计数时钟(HZ)
#define  ADC_TIM_PSC_MAX     65536                  //预分频可选的最大分频系数

/*********************************************************************************************************
*                                              枚举结构体定义
*********************************************************************************************************/

/*********************************************************************************************************
*                                              内部变量
*********************************************************************************************************/
static volatile u16 s_arrADC1Data;       //当前ADC转换结果(DMA后台写入,必须volatile防读缓存)
static StructU16CirQue  s_structADCCirQue; //ADC循环队列
static u16              s_arrADCBuf[ADC1_BUF_SIZE];   //ADC循环队列中的缓冲区

static u16 s_iSampleRateHz = ADC_SAMPLE_RATE_HZ;      //当前采样率(HZ)
static u16 s_iQueuePeak    = 0;                       //队列历史最高占用
static u32 s_iSampleCnt    = 0;                       //累计采集点数
static u32 s_iDropCnt      = 0;                       //累计丢弃点数(队列满)
static u32 s_iOvrCnt       = 0;                       //ADC溢出(OVR)次数(诊断,正常应保持0)
static u32 s_iDmaCnt       = 0;                       //DMA搬运次数(诊断,正常每秒增加约采样率个)

/*********************************************************************************************************
*                                              内部函数声明
*********************************************************************************************************/
static void ConfigADC1(void);                       //配置ADC1
static void ConfigDMA2Stream0(void);                //配置DMA2流0
static void ConfigTimer2(u16 psc, u16 arr);         //配置TIM2
static void CalcSampleDiv(u16 rateHz, u16* pPsc, u16* pArr); //算采样分频

/*********************************************************************************************************
*                                              内部函数实现
*********************************************************************************************************/
/*********************************************************************************************************
* 函数名称：CalcSampleDiv
* 功能功能：根据目标采样率计算TIM2的预分频值与自动重装值
* 输入参数：rateHz-目标采样率；pPsc-预分频寄存器值；pArr-自动重装寄存器值
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：先算出总分频数total = 定时器时钟 / 采样率，再把它拆成(psc+1)*(arr+1)，
*           保证arr不超过65536。F103里719/799是写死的，这里改成随时钟与采样率自动算
**********************************************************************************************************/
static void CalcSampleDiv(u16 rateHz, u16* pPsc, u16* pArr)
{
  u32 total;   //总分频系数 = (psc+1)*(arr+1)
  u32 prescal; //预分频系数

  if(rateHz == 0)
  {
    rateHz = 1;   //防止除零
  }

  total = ADC_TIM_CLK_HZ / rateHz;

  if(total == 0)
  {
    total = 1;    //采样率高于定时器时钟时，按1分频(实际达不到，由上层限制)
  }

  //向上取整，使 arr+1 = total/(psc+1) <= 65536
  prescal = (total + (ADC_TIM_PSC_MAX - 1)) / ADC_TIM_PSC_MAX;

  if((prescal == 0) || (prescal > ADC_TIM_PSC_MAX))
  {
    prescal = 1;
  }

  *pPsc = (u16)(prescal - 1);
  *pArr = (u16)((total / prescal) - 1);

  if(*pArr == 0xFFFF)   //极端情况下至少保证一个计数
  {
    *pArr = 0;
  }
}

/*********************************************************************************************************
* 函数名称：ConfigADC1
* 功能功能：配置ADC1
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：与F103的四处差异，逐条对应：
*           1、ADC时钟不再用RCC_ADCCLKConfig()，而是挪到ADC公共寄存器里由
*              ADC_Prescaler对PCLK2(84MHz)分频，Div4→ADCCLK=21MHz(F407上限42MHz)；
*           2、ADC_InitTypeDef被拆成"公共部分(ADC_CommonInitTypeDef)"和"单ADC部分"两个结构体，
*              且单ADC部分多了ADC_Resolution分辨率字段；
*           3、外部触发从"一个字段"变成"边沿+源"两个字段：ADC_ExternalTrigConvEdge与
*              ADC_ExternalTrigConv；
*           4、F4的ADC没有F1那种上电校准流程(RSTCAL/CAL)，因此删掉F103里的校准等待代码。
*           另外触发源：F103用的TIM3_TRGO在F407上对ADC1/2规则组并不等价(该映射属于ADC3)，
*           故这里改用ADC1/2都支持的TIM2_TRGO
**********************************************************************************************************/
static void ConfigADC1(void)
{
  GPIO_InitTypeDef        GPIO_InitStructure;     //GPIO_InitStructure用于存GPIO的参数
  ADC_CommonInitTypeDef   ADC_CommonInitStruct;   //ADC_CommonInitStruct用于存ADC公共部分的参数
  ADC_InitTypeDef         ADC_InitStructure;      //ADC_InitStructure用于存ADC的参数

  //使用RCC模块时钟
  RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_GPIOA, ENABLE);  //使能GPIOA时钟(F4的GPIO在AHB1)
  RCC_APB2PeriphClockCmd(RCC_APB2Periph_ADC1 , ENABLE);  //使能ADC1的时钟

  //配置ADC1的GPIO
  GPIO_InitStructure.GPIO_Pin   = GPIO_Pin_5;     //PA5，对应ADC123_IN5
  GPIO_InitStructure.GPIO_Mode  = GPIO_Mode_AN;   //模拟输入模式
  GPIO_InitStructure.GPIO_PuPd  = GPIO_PuPd_NOPULL; //模拟脚不需要上下拉
  GPIO_InitStructure.GPIO_Speed = GPIO_Speed_100MHz; //F4模拟输入也要给个速度参数，不影响功能
  GPIO_Init(GPIOA, &GPIO_InitStructure);          //根据参数初始化GPIO

  //配置ADC1公共部分
  ADC_CommonStructInit(&ADC_CommonInitStruct);
  ADC_CommonInitStruct.ADC_Mode             = ADC_Mode_Independent;            //独立模式
  ADC_CommonInitStruct.ADC_Prescaler        = ADC_Prescaler_Div4;              //ADCCLK=PCLK2/4=21MHz
  ADC_CommonInitStruct.ADC_DMAAccessMode    = ADC_DMAAccessMode_Disabled;      //单ADC，不用多ADC DMA模式
  ADC_CommonInitStruct.ADC_TwoSamplingDelay = ADC_TwoSamplingDelay_5Cycles;    //双ADC间隔，单ADC无意义
  ADC_CommonInit(&ADC_CommonInitStruct);

  //配置ADC1
  ADC_StructInit(&ADC_InitStructure);
  ADC_InitStructure.ADC_Resolution           = ADC_Resolution_12b;              //12位分辨率
  ADC_InitStructure.ADC_ScanConvMode         = DISABLE;                         //单通道，无需扫描
  ADC_InitStructure.ADC_ContinuousConvMode   = DISABLE;                         //单次转换，由定时器定速触发
  ADC_InitStructure.ADC_ExternalTrigConvEdge = ADC_ExternalTrigConvEdge_Rising; //上升沿触发(F1没有该字段)
  ADC_InitStructure.ADC_ExternalTrigConv     = ADC_ExternalTrigConv_T2_TRGO;    //TIM2的TRGO作为触发源
  ADC_InitStructure.ADC_DataAlign            = ADC_DataAlign_Right;             //数据右对齐
  ADC_InitStructure.ADC_NbrOfConversion      = 1;                               //规则组转换通道个数
  ADC_Init(ADC1, &ADC_InitStructure);

  //采样时间480周期：转换耗时约(480+12)/21MHz≈23.4us，即单次转换上限约42kHz，
  //对心电(250~1000Hz)绰绰有余；长采样时间对高阻抗信号源(电极经电阻网络)更友好
  ADC_RegularChannelConfig(ADC1, ADC_Channel_5, 1, ADC_SampleTime_480Cycles);

  ADC_DMACmd(ADC1, ENABLE);                   //使能ADC1的DMA
  ADC_DMARequestAfterLastTransferCmd(ADC1, ENABLE);  //关键: 设置DDS=1, 最后一次DMA传输后继续产生请求(否则只搬1次就停)
  ADC_Cmd(ADC1, ENABLE);                      //使能ADC1
}

/*********************************************************************************************************
* 函数名称：ConfigDMA2Stream0
* 功能功能：配置DMA2流0(ADC1的数据搬运通道)
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：与F103的差异：
*           1、F103的ADC1固定绑在DMA1_Channel1；F407的ADC1绑在DMA2的Stream0/3/4的Channel0，
*              且F4的DMA是"流+FIFO+通道"模型，初始化字段名与F1完全不同；
*           2、方向宏由DMA_DIR_PeripheralSRC改为DMA_DIR_PeripheralToMemory；
*           3、内存地址不递增(只搬到一个变量)，与F103行为一致
**********************************************************************************************************/
static void ConfigDMA2Stream0(void)
{
  DMA_InitTypeDef DMA_InitStructure;  //DMA_InitStructure用于存DMA的参数

  //使用RCC模块时钟
  RCC_AHB1PeriphClockCmd(RCC_AHB1Periph_DMA2, ENABLE);  //使能DMA2的时钟(ADC挂在DMA2上)

  //配置DMA2_Stream0
  DMA_DeInit(DMA2_Stream0);  //把DMA2 Stream0寄存器恢复为默认值
  DMA_InitStructure.DMA_Channel            = DMA_Channel_0;                     //ADC1对应Stream0的Channel0
  DMA_InitStructure.DMA_PeripheralBaseAddr = (uint32_t)&(ADC1->DR);             //外设地址
  DMA_InitStructure.DMA_Memory0BaseAddr    = (uint32_t)&s_arrADC1Data;          //存储器地址
  DMA_InitStructure.DMA_DIR                = DMA_DIR_PeripheralToMemory;        //外设到存储器
  DMA_InitStructure.DMA_BufferSize         = 1;                                 //一次搬运的数据个数
  DMA_InitStructure.DMA_PeripheralInc      = DMA_PeripheralInc_Disable;         //外设地址不递增
  DMA_InitStructure.DMA_MemoryInc          = DMA_MemoryInc_Disable;             //存储器地址不递增(单变量)
  DMA_InitStructure.DMA_PeripheralDataSize = DMA_PeripheralDataSize_HalfWord;   //外设数据宽度为半字
  DMA_InitStructure.DMA_MemoryDataSize     = DMA_MemoryDataSize_HalfWord;       //存储器数据宽度为半字
  DMA_InitStructure.DMA_Mode               = DMA_Mode_Circular;                 //循环模式
  DMA_InitStructure.DMA_Priority           = DMA_Priority_Medium;               //中等优先级
  DMA_InitStructure.DMA_FIFOMode           = DMA_FIFOMode_Disable;              //直模式(F1没有该字段)
  DMA_InitStructure.DMA_FIFOThreshold      = DMA_FIFOThreshold_HalfFull;        //FIFO关闭时该项无效
  DMA_InitStructure.DMA_MemoryBurst        = DMA_MemoryBurst_Single;            //存储器单拍传输
  DMA_InitStructure.DMA_PeripheralBurst    = DMA_PeripheralBurst_Single;        //外设单拍传输
  DMA_Init(DMA2_Stream0, &DMA_InitStructure);  //根据参数初始化DMA2 Stream0

  DMA_Cmd(DMA2_Stream0, ENABLE); //使能DMA2 Stream0
}

/*********************************************************************************************************
* 函数名称：ConfigTimer2
* 功能功能：配置用于触发ADC采样的定时器TIM2
* 输入参数：psc-时钟预分频值，arr-自动重装值
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：TIM2的更新事件通过TRGO触发ADC1，同时TIM2自身开更新中断用于把结果入队。
*           F103用的是TIM3，F407改用TIM2(因为ADC1/2的TRGO触发源里只有TIM2/TIM5等，
*           没有TIM3_TRGO)，TIM3留给以后可能的第二路采样
**********************************************************************************************************/
static void ConfigTimer2(u16 psc, u16 arr)
{
  TIM_TimeBaseInitTypeDef  TIM_TimeBaseStructure; //TIM_TimeBaseStructure用于存TIM2的参数
  NVIC_InitTypeDef NVIC_InitStructure;            //NVIC_InitStructure用于存NVIC的参数

  //使用RCC模块时钟
  RCC_APB1PeriphClockCmd(RCC_APB1Periph_TIM2, ENABLE);  //使能TIM2的时钟

  //配置TIM2
  TIM_TimeBaseStructure.TIM_Period        = arr;  //设置自动重装值
  TIM_TimeBaseStructure.TIM_Prescaler     = psc;  //设置预分频值
  TIM_TimeBaseStructure.TIM_ClockDivision = TIM_CKD_DIV1;       //设置时钟分割：tDTS = tCK_INT
  TIM_TimeBaseStructure.TIM_CounterMode   = TIM_CounterMode_Up; //计数器设置为向上计数模式
  TIM_TimeBaseInit(TIM2, &TIM_TimeBaseStructure);               //根据参数初始化定时器

  TIM_SelectOutputTrigger(TIM2, TIM_TRGOSource_Update);         //选择输出事件为更新触发(触发ADC)

  TIM_ITConfig(TIM2, TIM_IT_Update, ENABLE);                    //使能定时器的更新中断

  //配置NVIC
  NVIC_InitStructure.NVIC_IRQChannel      = TIM2_IRQn;          //中断通道号
  NVIC_InitStructure.NVIC_IRQChannelPreemptionPriority = 1;     //设置抢占优先级
  NVIC_InitStructure.NVIC_IRQChannelSubPriority        = 1;     //设置响应优先级
  NVIC_InitStructure.NVIC_IRQChannelCmd   = ENABLE;             //使能中断
  NVIC_Init(&NVIC_InitStructure);                               //根据参数初始化NVIC

  TIM_Cmd(TIM2, ENABLE);  //使能定时器
}

/*********************************************************************************************************
* 函数名称：TIM2_IRQHandler
* 功能功能：TIM2中断服务函数(采样节拍)
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：入队动作放在标志判断之内(修正了F103版本里写在if外的问题)；
*           中断里只做入队和计数，不做任何耗时运算，采样率越高越重要
**********************************************************************************************************/
void TIM2_IRQHandler(void)
{
  if (TIM_GetITStatus(TIM2, TIM_IT_Update) != RESET)  //判断定时器的更新中断是否发生
  {
    TIM_ClearITPendingBit(TIM2, TIM_IT_Update);       //清除定时器的更新中断标志

    s_iSampleCnt++;                                   //累计采集点数加1
    /* F4防御: 采样链溢出(OVR)若未及时清除会阻塞后续转换, 这里检测到即清(自愈) */
    if(ADC_GetFlagStatus(ADC1, ADC_FLAG_OVR) != RESET)
    {
      s_iOvrCnt++;
      ADC_ClearFlag(ADC1, ADC_FLAG_OVR);
    }

    /* DMA搬运计数(诊断): 每搬1个样本DMA置TCIF标志, 清标志并计数(判断搬运链死活) */
    if(DMA_GetFlagStatus(DMA2_Stream0, DMA_FLAG_TCIF0) != RESET)
    {
      DMA_ClearFlag(DMA2_Stream0, DMA_FLAG_TCIF0);
      s_iDmaCnt++;
    }

    if(WriteADCBuf(s_arrADC1Data) == 0)               //把ADC数据写入缓冲区，写不进说明队列满
    {
      s_iDropCnt++;                                   //累计丢弃点数加1
    }
  }
}

/*********************************************************************************************************
*                                              API函数实现
*********************************************************************************************************/
/*********************************************************************************************************
* 函数名称：InitADC
* 功能功能：初始化ADC模块
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：需先调用InitRCC()与InitNVIC()
**********************************************************************************************************/
void InitADC(void)
{
  u16 psc, arr;

  InitU16Queue(&s_structADCCirQue, s_arrADCBuf, ADC1_BUF_SIZE); //初始化ADC缓存队列

  CalcSampleDiv(s_iSampleRateHz, &psc, &arr);  //按默认采样率算分频
  ConfigDMA2Stream0();                         //配置DMA2的流0
  ConfigADC1();                                //配置ADC1
  ConfigTimer2(psc, arr);                      //配置TIM2(触发+入队节拍)
}

/*********************************************************************************************************
* 函数名称：SetADCSampleRate
* 功能功能：设置ADC采样率
* 输入参数：rateHz，采样率(HZ)，有效范围1~20000
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：运行中可随时改，改完会重装TIM2的分频并立即生效；
*           上限受单次转换时间约束(480周期采样时约42kHz)，心电用不到那么高
**********************************************************************************************************/
void SetADCSampleRate(u16 rateHz)
{
  u16 psc, arr;

  if((rateHz == 0) || (rateHz > 20000))
  {
    return;  //参数非法，保持原采样率
  }

  CalcSampleDiv(rateHz, &psc, &arr);

  TIM_Cmd(TIM2, DISABLE);

  s_iSampleRateHz = rateHz;

  //F4的SPL没有TIM_SetPrescaler()，只能重新做一次TimeBase初始化
  {
    TIM_TimeBaseInitTypeDef  TIM_TimeBaseStructure;

    TIM_TimeBaseStructure.TIM_Period        = arr;
    TIM_TimeBaseStructure.TIM_Prescaler     = psc;
    TIM_TimeBaseStructure.TIM_ClockDivision = TIM_CKD_DIV1;
    TIM_TimeBaseStructure.TIM_CounterMode   = TIM_CounterMode_Up;
    TIM_TimeBaseInit(TIM2, &TIM_TimeBaseStructure);
  }

  TIM_SelectOutputTrigger(TIM2, TIM_TRGOSource_Update);  //重新配置后TRGO设置会被清掉，需再设一次
  TIM_GenerateEvent(TIM2, TIM_EventSource_Update);       //产生更新事件，让PSC/ARR立即装载
  TIM_ClearITPendingBit(TIM2, TIM_IT_Update);       //clear the pending flag set by the software update event

  TIM_Cmd(TIM2, ENABLE);
}

/*********************************************************************************************************
* 函数名称：GetADCSampleRate
* 功能功能：获取当前ADC采样率
* 输入参数：void
* 输出参数：void
* 返 回 值：采样率(HZ)
* 生成日期：2026年09月20日
* 注    意：
**********************************************************************************************************/
u16  GetADCSampleRate(void)
{
  return(s_iSampleRateHz);
}

/*********************************************************************************************************
* 函数名称：SetADCChannel
* 功能功能：切换ADC规则采样通道
* 输入参数：channel，取值为库里的ADC_Channel_0~ADC_Channel_18
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：只改ADC的规则组配置，GPIO仍需自行配置为模拟输入；
*           温度传感器(ADC_Channel_16)/内部参考电压(ADC_Channel_17)可用来自检
**********************************************************************************************************/
void SetADCChannel(u8 channel)
{
  ADC_Cmd(ADC1, DISABLE);

  ADC_RegularChannelConfig(ADC1, channel, 1, ADC_SampleTime_480Cycles);

  ADC_Cmd(ADC1, ENABLE);
}

/*********************************************************************************************************
* 函数名称：WriteADCBuf
* 功能功能：把ADC数据写入缓冲区
* 输入参数：d-待写入的数
* 输出参数：void
* 返 回 值：成功标志位，1为成功，0为不成功
* 生成日期：2018年01月01日
* 注    意：
**********************************************************************************************************/
u8 WriteADCBuf(u16 d)
{
  u8 ok = 0;  //数据取成功标志位数值，默认为0

  ok = (EnU16Queue(&s_structADCCirQue, &d, 1) == 1) ? 1 : 0;  //入队

  if(ok)
  {
    u16 len = (u16)U16QueueLength(&s_structADCCirQue);  //统计队列最高占用，用于判断消费能力

    if(len > s_iQueuePeak)
    {
      s_iQueuePeak = len;
    }
  }

  return ok;  //返回数据取成功标志位数值
}

/*********************************************************************************************************
* 函数名称：ReadADCBuf
* 功能功能：从ADC缓冲区中读取数据
* 输入参数：p-读取数据存放的首地址
* 输出参数：void
* 返 回 值：成功标志位，1为成功，0为不成功
* 生成日期：2018年01月01日
* 注    意：
**********************************************************************************************************/
u8 ReadADCBuf(u16* p)
{
  u8 ok = 0;  //数据取成功标志位数值，默认为0

  ok = (DeU16Queue(&s_structADCCirQue, p, 1) == 1) ? 1 : 0;  //出队

  return ok;  //返回数据取成功标志位数值
}

/*********************************************************************************************************
* 函数名称：GetADCQueueLen
* 功能功能：获取当前队列中的点数
* 输入参数：void
* 输出参数：void
* 返 回 值：队列中的点数
* 生成日期：2026年09月20日
* 注    意：
**********************************************************************************************************/
u16  GetADCQueueLen(void)
{
  return((u16)U16QueueLength(&s_structADCCirQue));
}

/*********************************************************************************************************
* 函数名称：GetADCQueuePeak
* 功能功能：获取队列历史最高占用点数
* 输入参数：void
* 输出参数：void
* 返 回 值：最高占用点数
* 生成日期：2026年09月20日
* 注    意：若该值长期等于ADC1_BUF_SIZE，说明生产者快于消费者，数据在被丢弃
**********************************************************************************************************/
u16  GetADCQueuePeak(void)
{
  return(s_iQueuePeak);
}

/*********************************************************************************************************
* 函数名称：GetADCSampleCnt
* 功能功能：获取累计采集点数
* 输入参数：void
* 输出参数：void
* 返 回 值：累计点数
* 生成日期：2026年09月20日
* 注    意：1秒内增量应等于采样率，可用来验证TIM2触发节拍是否正确
**********************************************************************************************************/
u32  GetADCSampleCnt(void)
{
  return(s_iSampleCnt);
}

/*********************************************************************************************************
* 函数名称：GetADCDropCnt
* 功能功能：获取因队列满而丢弃的点数
* 输入参数：void
* 输出参数：void
* 返 回 值：累计丢弃点数
* 生成日期：2026年09月20日
* 注    意：
**********************************************************************************************************/
u32  GetADCDropCnt(void)
{
  return(s_iDropCnt);
}

/*********************************************************************************************************
* 函数名称：GetADCOvrCnt
* 功能功能：读取ADC溢出(OVR)累计次数(诊断用, 正常应保持0)
* 输入参数：void
* 输出参数：void
* 返 回 值：OVR累计次数
* 创建日期：2026年09月21日
* 注    记：
**********************************************************************************************************/
u32  GetADCOvrCnt(void)
{
  return(s_iOvrCnt);
}

/*********************************************************************************************************
* 函数名称：GetADCDmaCnt
* 功能功能：读取DMA搬运累计次数(诊断用, 正常每秒增加约采样率个)
* 输入参数：void
* 输出参数：void
* 返 回 值：DMA搬运累计次数
* 创建日期：2026年09月21日
* 注    记：
**********************************************************************************************************/
u32  GetADCDmaCnt(void)
{
  return(s_iDmaCnt);
}

/*********************************************************************************************************
* 函数名称：GetADCVoltageMv
* 功能功能：把ADC原始码换算成毫伏
* 输入参数：raw，ADC转换结果(0~4095)
* 输出参数：void
* 返 回 值：电压值(mV)
* 生成日期：2026年09月20日
* 注    意：12位满量程4095对应ADC_VREF_MV
**********************************************************************************************************/
u16  GetADCVoltageMv(u16 raw)
{
  return((u16)((u32)raw * ADC_VREF_MV / 4095));
}

/*********************************************************************************************************
* 函数名称：ClearADCStatic
* 功能功能：清零统计量
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：只清统计，不动队列内容
**********************************************************************************************************/
void  ClearADCStatic(void)
{
  s_iQueuePeak = 0;
  s_iSampleCnt = 0;
  s_iDropCnt   = 0;
}
