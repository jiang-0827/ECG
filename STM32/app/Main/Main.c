/*********************************************************************************************************
* 模 块 名 称：Main.c
* 摘        要：本文件包含所有硬件初始化的函数和main函数
* 当前版本：1.0.0
* 作        者：SZLY(COPYRIGHT 2018 - 2026 SZLY. All rights reserved.)
* 生成日期：2026年09月20日
* 说        明：本文件由STM32F103版本移植而来，任务框架(2ms/1s时间片)与F103保持一致
* 注        意：注意勾选Options for Target 'Target1'->Target->Use MicroLIB，否则printf无法使用
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
#include <stdio.h>
#include "Main.h"
#include "stm32f4xx_conf.h"
#include "DataType.h"
#include "NVIC.h"
#include "SysTick.h"
#include "RCC.h"
#include "Timer.h"
#include "UART1.h"
#include "LED.h"
#include "ProcHostCmd.h"
#include "PackUnpack.h"
#include "SendDataToHost.h"
#include "ADC.h"
#include "ecg_filter.h"
#include "ecg_heart.h"
#include "ecg_leadoff.h"

/*********************************************************************************************************
*                                              宏定义
*********************************************************************************************************/
#define  WAVE_POINT_NUM     5     //一个波形数据帧包含的采样点数(协议payload为6字节，留1字节备用)
/* ============ 调试输出模式选择 ============
 * 1 = VOFA+ 波形调试: 发送 FireWater 文本帧("原始码值,滤波值\n", 250Hz), 停发原协议帧
 * 0 = 原上位机协议模式(与MATLAB上位机联调时用)
 */
#define  ECG_VOFA_WAVE      1

#define  MAX_POINT_PER_TICK 8     //每个2ms任务最多处理的采样点数，防止高采样率时任务被拉长

/*********************************************************************************************************
*                                              内部变量
*********************************************************************************************************/
static  ecg_filt_t s_ecgFilter;           //心电滤波链(bias→0.5Hz高通→50Hz陷波→FIR低通)
static  float s_filtDataLast = 0.0f;      //最近一次滤波输出(ADC码值域)
static  ecg_heart_t s_heartDet;      //心率检测器(逐点流式, R峰+中位数RR)
static  int16_t s_heartBpm = 0;      //最新心率(bpm, 0=无效)
static  ecg_leadoff_t s_leadDet;     //导联脱落检测器(ADC2+PA1)
static  uint8_t s_leadOff = 0;       //导联状态(0=正常 1=脱落)
static  u8  s_iWaveSendEnable = 1;   //波形数据帧上传开关，默认开启，便于上电就能看到波形
static  u16 s_iLastAdcData    = 0;   //最近一个ADC采样点，供1s任务打印

/*********************************************************************************************************
*                                              枚举结构体定义
*********************************************************************************************************/

/*********************************************************************************************************
*                                              内部函数声明
*********************************************************************************************************/
static  void  InitSoftware(void);   //初始化软件相关的模块
static  void  InitHardware(void);   //初始化硬件相关的模块
static  void  Proc2msTask(void);    //2ms任务处理
static  void  Proc1SecTask(void);   //1s任务处理
static  void  ProcWaveData(void);   //从ADC队列取数并打包上传
static  void  PrintBootInfo(void);  //打印上电自检信息

/*********************************************************************************************************
*                                              内部函数实现
*********************************************************************************************************/
/*********************************************************************************************************
* 函数名称：InitSoftware
* 功能功能：所有的与软件相关的模块初始化工作在此函数完成
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2018年01月01日
* 注    意：
**********************************************************************************************************/
static  void  InitSoftware(void)
{
  ecg_filt_init(&s_ecgFilter);  //初始化心电滤波链(清空各级状态)
  ecg_heart_init(&s_heartDet);  //初始化心率检测器
  ecg_leadoff_init(&s_leadDet);  //初始化导联脱落检测(ADC2+PA1)
  InitPackUnpack();       //初始化PackUnpack模块
  InitProcHostCmd();      //初始化ProcHostCmd模块
  InitSendDataToHost();   //初始化SendDataToHost模块
}

/*********************************************************************************************************
* 函数名称：InitHardware
* 功能功能：所有的与硬件相关的模块初始化工作在此函数完成
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2018年01月01日
* 注    意：与F103的差异：F103要在这里手写SystemInit()+InitRCC()把时钟配到72MHz；
*           F407的168MHz已由启动文件里的SystemInit()完成，故这里只查询时钟不配置时钟。
*           顺序要求：InitRCC必须在InitTimer/InitADC之前(它们要按查到的时钟算分频)，
*           InitNVIC必须在所有开中断的模块之前
**********************************************************************************************************/
static  void  InitHardware(void)
{
  InitRCC();                  //查询系统时钟(168MHz由启动文件的SystemInit配置)
  InitNVIC();                 //初始化NVIC模块(设置中断优先级分组)
  InitSysTick();              //初始化SysTick模块(1ms节拍，供DelayNms使用)
  InitUART1(UART1_BAUD_RATE); //初始化UART模块
  InitTimer();                //初始化Timer模块(2ms/1s时间片标志)
  InitLED();                  //初始化LED模块
  InitADC();                  //初始化ADC模块(TIM2触发+DMA+环形队列)
}

/*********************************************************************************************************
* 函数名称：PrintBootInfo
* 功能功能：打印上电自检信息
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：PLL未锁定时说明8MHz晶振没起振，芯片在跑16MHz内部RC，此时采样率与波特率都会
*           偏4倍，必须先把这一行看对，再去看后面的数据
**********************************************************************************************************/
static  void  PrintBootInfo(void)
{
  printf("\r\n==============================================\r\n");
  printf(" ECG Skeleton on STM32F407VET6 (LCKFB Firebase-Tx)\r\n");
  printf(" SYSCLK = %lu Hz, PLL lock = %d\r\n",
         (unsigned long)GetSysClockFreq(), IsRunByPLL());
  printf(" APB1 TIM clk = %lu Hz, APB2(PCLK2) = %lu Hz\r\n",
         (unsigned long)GetAPB1TimClockFreq(), (unsigned long)GetAPB2ClockFreq());
  printf(" ADC sample rate = %d Hz, buffer = %d points\r\n",
         GetADCSampleRate(), ADC1_BUF_SIZE);
  printf(" UART1 baudrate = %d\r\n", UART1_BAUD_RATE);
#if (ECG_VOFA_WAVE != 0)
  printf(" Wave output: VOFA+ FireWater, raw,filt @250Hz\r\n");
#endif
  printf("==============================================\r\n");

  if(IsRunByPLL() == 0)
  {
    printf(" [WARN] PLL not locked! Check the 8MHz HSE crystal.\r\n");
  }
}

#if (ECG_VOFA_WAVE != 0)
/*********************************************************************************************************
* 函数名称：VofaWaveTick
* 功能功能：VOFA+ 波形调试输出(每2个样本发一帧, FireWater文本: 原始码值,滤波值)
* 输入参数：rawAdc-原始ADC码值; filtVal-滤波后值
* 输出参数：void
* 返 回 值：void
* 创建日期：2026年09月21日
* 注    记：走 WriteUART1 发送队列(非阻塞); 115200波特率下数据率约2.6KB/s
**********************************************************************************************************/
static  void  VofaWaveTick(u16 rawAdc, float filtVal)
{
  static u8 s_iVofaDiv = 0;  //降采样计数
  char arrLine[24];          //文本行缓冲
  int  len;                  //格式化长度

  s_iVofaDiv++;

  if(s_iVofaDiv < 2)         //每2个样本发送一帧 → 250Hz
  {
    return;
  }

  s_iVofaDiv = 0;

  len = sprintf(arrLine, "%u,%d,%d,%d\n", (unsigned int)rawAdc, (int)filtVal, (int)s_heartBpm, (int)s_leadOff);  //FireWater文本: 通道以逗号分隔

  WriteUART1((u8*)arrLine, (u8)len);  //写入发送队列(非阻塞)
}
#endif

/*********************************************************************************************************
* 函数名称：ProcWaveData
* 功能功能：从ADC环形队列取数，攒满一帧后上传上位机
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：不论上传开关是否打开都要把队列取空，否则采样数据会堆积并被丢弃；
*           开关只决定要不要发帧。后续接心电算法时，就在这里把取到的点送进滤波器
**********************************************************************************************************/
static  void  ProcWaveData(void)
{
  u16 adcData;                          //采样数据
  u8  waveData;                         //波形数据
  u8  pointCnt = 0;                     //本次任务处理的点数

  static u8 s_iPointCnt = 0;            //波形数据包的采样点计数器
  static u8 s_arrWaveData[WAVE_POINT_NUM] = {0};  //波形数据缓存

  while((pointCnt < MAX_POINT_PER_TICK) && ReadADCBuf(&adcData))  //从环形队列中读取1个数据
  {
    pointCnt++;

    s_iLastAdcData = adcData;           //记录最新一个采样点，供1s任务打印

    s_filtDataLast = ecg_filt_step(&s_ecgFilter, (float)adcData);  //心电滤波(bias→陷波→40Hz低通)
    s_heartBpm = ecg_heart_step(&s_heartDet, s_filtDataLast);   //心率检测(逐样本)
    s_leadOff = ecg_leadoff_step(&s_leadDet);   //导联脱落检测(逐样本)
    if(s_leadOff != 0)
    {
      s_heartBpm = 0;   //导联脱落时心率无意义, 强制显示0(监护规范)
    }

#if (ECG_VOFA_WAVE != 0)
    VofaWaveTick(adcData, s_filtDataLast);   //VOFA+ 波形帧(每2样本一帧, FireWater文本)
#endif

    if((ECG_VOFA_WAVE == 0) && GetWaveSendEnable())
    {
      waveData = (u8)((u32)adcData * 255 / 4095);  //12位右移成8位(缩小到0~255)
      s_arrWaveData[s_iPointCnt] = waveData;       //存放到数组

      s_iPointCnt++;                    //波形数据包的采样点计数器加1

      if(s_iPointCnt >= WAVE_POINT_NUM) //攒满一帧
      {
        s_iPointCnt = 0;                //清零采样点计数器
        SendWaveToHost(s_arrWaveData);  //发送采样数据包
      }
    }
  }
}

/*********************************************************************************************************
* 函数名称：Proc2msTask
* 功能功能：2ms任务处理
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2018年01月01日
* 注    意：
**********************************************************************************************************/
static  void  Proc2msTask(void)
{
  u8  uart1RecData; //串口数据

  if(Get2msFlag())  //判断2ms标志状态
  {
    while(ReadUART1(&uart1RecData, 1))  //串口有接收数据
    {
      ProcHostCmd(uart1RecData);        //处理命令
    }

    ProcWaveData();                     //处理ADC采样数据(取队列+打包上传)

    LEDFlicker(250);                    //每500ms翻转一次LED，表示程序在跑

    Clr2msFlag();                       //清除2ms标志
  }
}

/*********************************************************************************************************
* 函数名称：Proc1SecTask
* 功能功能：1s任务处理
* 输入参数：void
* 输出参数：void
* 返 回 值：void
* 生成日期：2018年01月01日
* 注    意：这一行打印就是骨架的自检：cnt每秒增量应等于采样率，drop应恒为0
**********************************************************************************************************/
static  void  Proc1SecTask(void)
{
  if(Get1SecFlag()) //判断1s标志状态
  {
    /* 状态行改走发送队列(与波形数据同一写者): 原printf直写DR会与TXE
     * 中断产生字节级竞争, 破坏接收端数据行的完整性(乱码) */
    char arrStat[160];
    int  statLen;

    statLen = sprintf(arrStat, "adc=%4d %5lumV  rate=%4dHz  cnt=%lu  drop=%lu  queue=%3d/%d  wave=%d  filt=%5d  dmacnt=%lu  ovr=%lu\r\n",
           s_iLastAdcData,
           (unsigned long)GetADCVoltageMv(s_iLastAdcData),
           GetADCSampleRate(),
           (unsigned long)GetADCSampleCnt(),
           (unsigned long)GetADCDropCnt(),
           GetADCQueueLen(),
           ADC1_BUF_SIZE,
           GetWaveSendEnable(),
           (int)s_filtDataLast,
           (unsigned long)GetADCDmaCnt(),
           (unsigned long)GetADCOvrCnt());
    WriteUART1((u8*)arrStat, (u8)statLen);

    Clr1SecFlag();  //清除1s标志
  }
}

/*********************************************************************************************************
*                                              API函数实现
*********************************************************************************************************/
/*********************************************************************************************************
* 函数名称：SetWaveSendEnable
* 功能功能：设置波形数据帧上传开关
* 输入参数：en，1-上传，0-停止
* 输出参数：void
* 返 回 值：void
* 生成日期：2026年09月20日
* 注    意：
**********************************************************************************************************/
void  SetWaveSendEnable(u8 en)
{
  s_iWaveSendEnable = (en == 0) ? 0 : 1;
}

/*********************************************************************************************************
* 函数名称：GetWaveSendEnable
* 功能功能：获取波形数据帧上传开关
* 输入参数：void
* 输出参数：void
* 返 回 值：开关状态
* 生成日期：2026年09月20日
* 注    意：
**********************************************************************************************************/
u8  GetWaveSendEnable(void)
{
  return(s_iWaveSendEnable);
}

/*********************************************************************************************************
* 函数名称：main
* 功能功能：主函数
* 输入参数：void
* 输出参数：void
* 返 回 值：int
* 生成日期：2018年01月01日
* 注    意：
**********************************************************************************************************/
int main(void)
{
  InitSoftware();   //初始化软件相关函数
  InitHardware();   //初始化硬件相关函数

  PrintBootInfo();  //打印上电自检信息

  while(1)
  {
    Proc2msTask();  //2ms任务处理
    Proc1SecTask(); //1s任务处理
  }
}
