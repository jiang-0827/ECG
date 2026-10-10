========================================================================
 17. 心电骨架（F407 移植版）  ——  由 16.ADC实验(STM32F103) 骨架移植而来
========================================================================

一、这是什么
------------------------------------------------------------------------
把 F103 工程(16.ADC实验)的分层骨架原样搬到立创·梁山派·天空星
STM32F407VET6 上，暂时不含任何心电算法。搬过来的东西：

  分层结构      ARM / HW / App / Alg(空，留给算法)
  采集链路      定时器定速触发 → ADC → DMA 搬运 → 中断写环形队列 → 主循环消费
  任务框架      2ms / 1s 时间片标志轮询(裸机时间片)
  协议层        10 字节帧(模块ID+数据头+二级ID+6字节数据+校验和)的打包/解包
  串口驱动      收/发双环形队列 + RXNE/TXE 中断驱动 + printf 重定向
  类型定义      u8/u16/u32/i8/i16/i32、TRUE/FALSE、LOBYTE/HIBYTE 等

二、目录与 F103 工程的对应关系
------------------------------------------------------------------------
  F407 骨架(本工程)                     F103 原工程
  ------------------------------------------------------------------
  App/Main/Main.c                       App/Main/Main.c
  App/DataType/DataType.h               App/DataType/DataType.h        (原样复制)
  App/PackUnpack/*                      App/PackUnpack/*               (原样复制)
  App/SendDataToHost/*                  App/SendDataToHost/*           (原样复制)
  App/ProcHostCmd/*                     App/ProcHostCmd/*              (命令表重写)
  HW/RCC/RCC.c                          HW/RCC/RCC.c                   (角色变了)
  HW/Timer/Timer.c                      HW/Timer/Timer.c               (TIM2→TIM4)
  HW/UART1/UART1.c + Queue.c            HW/UART1/UART1.c + Queue.c     (Queue原样复制)
  HW/ADC/ADC.c + U16Queue.c             HW/ADC/ADC.c + U16Queue.c      (U16Queue原样复制)
  HW/LED/LED.c                          App/LED/LED.c                  (PC4/PC5→PB2)
  ARM/NVIC/NVIC.c                       ARM/NVIC/NVIC.c                (分组不变)
  ARM/SysTick/SysTick.c                 ARM/SysTick/SysTick.c          (一致)
  libraries/                            FW/ + ARM/System/              (F4的CMSIS+SPL)
  module/stm32f4xx_conf.h / _it.c       ARM/System/stm32f10x_conf.h/_it.c
  Alg/                                  Alg/                           (空)

  没有搬的：HW/DAC、HW/DAC/Wave(F103里用于"上位机命令→DAC输出波形"的演示，
  与心电无关，先不搬；ProcHostCmd 里对应的命令已换成采样率/通道/上传开关)。

三、硬件资源占用
------------------------------------------------------------------------
  ADC1      CH5 / PA5   模拟输入(默认)      注意PA4/PA5同时是DAC_OUT1/2
  TIM2      TRGO更新事件触发ADC1 + 更新中断入队(=采样节拍)
  DMA2      Stream0 Channel0  循环模式，ADC1->DR → 变量
  TIM4      1ms中断 → 2ms时间片标志
  TIM5      1ms中断 → 1s时间片标志
  USART1    PA9-TX / PA10-RX  115200 8N1，板载调试串口
  LED       PB2(低电平点亮，兼BOOT1)
  SysTick   1ms中断，供DelayNms()
  中断优先级分组：NVIC_PriorityGroup_2(2位抢占+2位子优先级)，与F103一致

四、和 F103 在实现上的关键差异(移植时踩的点)
------------------------------------------------------------------------
  1) 系统时钟：F103在应用层手写ConfigRCC()配72MHz；F407的168MHz由启动文件
     调SystemInit()完成(PLL_M=8,N=336,P=2，HSE=8MHz)。所以HW/RCC不再配时钟，
     改为"查询+分发"，Timer/ADC的分频都按查到的真实频率算，不再写死71/999。
  2) ADC时钟：F1的RCC_ADCCLKConfig(PCLK2_Div6) → F4的ADC_Prescaler_Div4(21MHz)。
  3) ADC初始化结构体被拆成 ADC_CommonInitTypeDef + ADC_InitTypeDef，且多了
     ADC_Resolution 分辨率字段。
  4) 外部触发：F1一个字段搞定；F4要同时配 ADC_ExternalTrigConvEdge(边沿) 和
     ADC_ExternalTrigConv(源)。F1用的 TIM3_TRGO 在F4上对ADC1/2规则组不等价
     (那个编码属于ADC3)，故改用 TIM2_TRGO。
  5) F1的ADC上电必须做 RSTCAL/CAL 校准等待；F4没有这个流程，代码已删。
  6) GPIO：F4的GPIO在AHB1总线，且要额外配 GPIO_OType/GPIO_PuPd/GPIO_Speed，
     复用功能还要单独调 GPIO_PinAFConfig()。
  7) DMA：F1的ADC1固定绑DMA1_Channel1；F4是"DMA2 + Stream0 + Channel0"，
     并且要配 FIFO模式/突发长度，字段名全变。
  8) F4的SPL没有TIM_SetPrescaler()，运行中改采样率只能重做一次
     TIM_TimeBaseInit()并手动产生更新事件(见SetADCSampleRate)。
  9) 顺手修了F103版TIM3中断服务函数里"入队写在if外面"的写法，现在只在确认
     是更新中断后才入队。

五、怎么编译
------------------------------------------------------------------------
  工程文件：Project/MDK(V5)/Project.uvprojx
  Device  ：STM32F407VETx，宏 USE_STDPERIPH_DRIVER,STM32F40_41xxx
  分组    ：STARTUP / APP / HW / ARM / MODULE / CMSIS / Driver
            (Driver只挂了用到的7个SPL源文件，不是全库)
  源文件编码为GBK(与F103工程一致)，Keil里显示中文正常；用VS Code打开请选
  GB2312/GBK编码，否则注释是乱码。

  已经用命令行 AC5(armcc/armlink) 全量编译+链接验证过：
  22个源文件 0 error 0 warning，链接通过，产物见
  Project/MDK(V5)/Objects/ECG_Skeleton_precheck.hex(可直接烧录先看现象)。

六、测试步骤(按顺序做，每步都有明确的判据)
------------------------------------------------------------------------
 [T1] 上电看串口(USART1，PA9/PA10，115200)输出：
        SYSCLK = 168000000 Hz, PLL lock = 1
        APB1 TIM clk = 84000000 Hz, APB2(PCLK2) = 84000000 Hz
        ADC sample rate = 500 Hz, buffer = 256 points
      判据：PLL lock 必须为 1。若为0说明8MHz晶振没起振，芯片在跑16MHz内部RC，
            后面所有时间相关的量都会偏4倍，先解决硬件。

 [T2] 看每秒一行的状态打印：
        adc=xxxx  xxxmV  rate= 500Hz  cnt=500  drop=0  queue=1/256  wave=1
      判据：cnt 每秒增量 == rate(=500)；drop 恒为 0；queue 在个位数。
            这三条同时满足，说明"定时器触发→ADC→DMA→中断入队→主循环出队"
            整条链路和节拍都是对的。

 [T3] 内部基准自检(不用接任何线，用来确认ADC+DMA+队列本身是好的)：
      发“切到内部通道17(VREFINT)”：10 81 8D 91 80 80 80 80 80 AF
      判据：adc 应稳在 1489 左右(1.2V/3.3V×4095)；若算出来接近 1.2V 但 raw≈1642，
            说明板上 VREF+ 用的是 REF3030(3.000V)基准，把 ADC.h 里的
            ADC_VREF_MV 改成 3000 再往下测。
      测完切回PA5：      10 81 8D 85 80 80 80 80 80 A3
      再验证静态电压：PA5悬空/接0V/接3V3(经电阻，别硬碰)，adc 应分别接近
            0 / 中间 / 4095。
 
 [T4] 动态采样链路检查：PA5 接信号发生器(100Hz正弦，0~3V)或从电位器取变化电压，
      用串口工具的波形显示看 8 位波形帧，或直接看 adc 数值是否跟随变化。
      判据：数值跟随、无跳死、drop 仍为 0。
 
 [T5] 命令通道与采样率切换(串口助手按16进制发以下10字节帧)：
      设 1000Hz：10 83 8B E8 83 80 80 80 80 89
      设  250Hz：10 83 8B FA 80 80 80 80 80 98
      查询采样率：10 81 8C 80 80 80 80 80 80 9D
      查运行状态：10 81 8A 80 80 80 80 80 80 9B
      清零统计量：10 81 8E 80 80 80 80 80 80 9F
      停止波形上传：71 81 80 80 80 80 80 80 80 F2
      恢复波形上传：71 81 80 81 80 80 80 80 80 F3
      判据：每条命令都应回一帧 ACK，例如“设1000Hz”的应答是
            01 84 84 90 8B 80 80 80 80 A4
            (模块ID=0x01系统、二级ID=0x04应答、数据[0]=被应答模块、
             数据[1]=被应答命令、数据[2]=0表示成功)
            同时 T2 那行里的 rate 与 cnt 每秒增量同步变成新值，drop 仍为 0。
      注：帧格式=模块ID + 数据头 + 二级ID + 6字节数据 + 校验和，非首字节的
          最高位被“数据头”借走(协议与F103完全一致，用你原来的上位机即可)。
          上面这些帧已按打包规则算好，直接发就行；自己拼帧时参照
          App/PackUnpack/PackUnpack.c 的 PackWithCheckSum()。

 [T6] LED(PB2)每500ms翻转一次，证明主循环没被卡死。

七、下一步接心电算法时该动哪里
------------------------------------------------------------------------
  - Alg/  新建滤波与R峰检测模块(建议先做：0.5Hz去基线 → 陷50Hz → 40Hz低通 → R峰)
  - App/Main/Main.c 的 ProcWaveData()：从队列里取到的点先送算法再决定上传什么
    (上传 int16 原始/滤波值而不是现在的8位值，一帧3个点，波特率建议提到921600)
  - HW/ADC/ADC.c  的 ADC_SAMPLE_RATE_HZ：心电建议 500 或 1000
  - App/ProcHostCmd/ProcHostCmd.c：把 CMD_ECG_GAIN/CMD_FILTER_MODE/DAT_ECG_HR 等
    已有二级ID对应的处理函数补上(现在会回 CMD_ACK_BAD_CMD)

八、已知限制(不是bug，是骨架阶段的取舍)
------------------------------------------------------------------------
  1) 波形帧仍是F103那套"5个点×8位"，精度对心电偏低，接算法时按第七条改。
  2) ADC用"单变量+循环DMA"，与F103行为一致；以后要高采样率批处理，可改成
     双缓冲(DMA半传输+传输完成两个中断)，一次搬250点再算。
  3) DelayNus()是F103留下的空循环近似延时，168MHz下不准，仅用于非关键场合。
========================================================================
