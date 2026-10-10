# ECG · 心电采集与实时分析系统

> 基于 **STM32F407** 的实时心电（ECG）采集、数字滤波、心率检测与导联脱落监测系统；配套 **MATLAB** 滤波器设计/仿真与上位机分析工具。核心算法以 C 语言实现，经 MATLAB ↔ C 逐点对拍验证，并在硬件上通过 **30~240 bpm 全档位实测**（对照《五参数验收标准》心电部分全部达标）。

## 特性

- **500 Hz 实时采集**：TIM2 触发 → ADC1 → DMA 环形搬运，稳定零丢样；
- **三级数字滤波链**：去直流偏置 → 50 Hz 工频陷波（DF2T biquad）→ 40 Hz FIR 低通（361 抽头，Kaiser −80 dB）；
- **逐点流式心率检测**：4 秒滑窗自适应门限 + R 峰状态机 + RR 中位数，实测 60/120/150/240 bpm 误差 0%；
- **导联脱落检测**：独立 ADC2 通道 + 100 ms 对称去抖，脱落时心率自动清零（监护规范）；
- **VOFA+ 四通道实时波形**：原始码值 / 滤波值 / 心率 / 导联状态，250 Hz 刷新；
- **算法可追溯**：MATLAB 设计 → C 实现 → 逐点对拍（误差达 float32 舍入极限 ~1e-5）。

## 系统架构

**信号链**

```
心电模拟器(RA/LA/RL)
      |
      v
心电前端板  -- TL062 仪放 + LMV358 有源滤波 + LMV324 导联判决/右腿驱动
      |        (±5V 供电, Uref=1.65V 中点偏置, AC 耦合, 增益≈100)
      |-- ECG 模拟输出 --------> STM32 PA5 (ADC1_IN5)
      +-- LEAD_OFF 模拟输出 ----> STM32 PA1 (ADC2_IN1)
```

**MCU 端数据流（500 Hz 主链）**

```
①TIM2 500Hz TRGO → ②ADC1(PA5)转换 → ③DMA 搬运 → s_arrADC1Data
  → ④TIM2 中断: 入队(256 环形) + OVR 自愈 + DMA 计数
  → ⑤主循环 ProcWaveData(每 2ms): 消费样本
  → ⑥滤波链(去直流→50Hz陷波→40Hz FIR) → s_filtDataLast
  → ⑦心率检测(逐样本) → s_heartBpm
  → ⑧导联检测(ADC2 独立采样 PA1) → s_leadOff
  → ⑨VofaWaveTick(每 2 样本/250Hz): 打包 4 通道
  → ⑩WriteUART1 队列 → TXE 中断 → 115200 → PC(VOFA+)
```

## 目录结构

```
ECGDynamicPrj/
├── EcgMcuC/                  # ★ STM32F407 C 算法（部署到 Keil 工程 Alg/）
│   ├── ecg_config.h          #   全部物理量与算法参数的唯一定义处
│   ├── ecg_filter.c/.h       #   三级滤波链：去直流→50Hz陷波→40Hz FIR
│   ├── ecg_coeffs.c/.h       #   滤波器系数（gen_ecg_coeffs.m 自动生成，勿手改）
│   ├── ecg_heart.c/.h        #   逐点流式心率检测
│   ├── ecg_leadoff.c/.h      #   导联脱落检测
│   ├── gen_ecg_coeffs.m      #   由 MATLAB 设计器生成系数
│   ├── verify/               #   MATLAB↔C 逐点对拍验证（含 Python float32 复刻）
│   ├── patch_*.py            #   历次工程修改补丁脚本（留档）
│   └── 心电通道开发文档.md    #   详细开发纪实 / 踩坑档案 / 参数表
├── EcgMcuSim/                # MATLAB 滤波器设计与逐点递推仿真
│   ├── ecg_config.m          #   配置（与 ecg_config.h 对应）
│   ├── design_ecg_filters.m  #   滤波器设计（butter/fir1/Kaiser）
│   ├── biquad_df2t_step.m    #   biquad DF2T 逐点递推
│   └── fir_circ_step.m       #   FIR 环形缓冲逐点递推
├── RecData/                  # 心电演示数据（csv）
├── *.m / *.fig               # MATLAB 上位机（GUIDE）：采集/滤波/心率/频谱/回放
├── LICENSE
└── README.md
```

## 核心算法

### 滤波链（逐样本）

```
原始码值 − 2048(1.65V 中点) → 50Hz 陷波 → 40Hz FIR 低通 → 输出
```

| 级 | 类型 | 参数 |
|---|---|---|
| 去直流 | 减偏置 | 中点码值 2048（对应 Uref 1.65V） |
| 陷波 | DF2T biquad | 50 Hz，b={1, −1.618, 1}，a={1, −1.553, 0.9216} |
| 低通 | FIR | 361 抽头，40 Hz，Kaiser −80 dB，群延迟 180 样本（360 ms 恒定） |

> 模拟高通由前端板隔直电容完成，MCU 端数字高通默认关闭。

### 心率检测（逐样本状态机）

1. **滑窗极值**：最近 2048 样本（4.1 s）按 64/块分块，环形存 32 块极值；
2. **自适应门限**：`thr = min + 0.6×(max − min)`；
3. **R 峰**：过阈 → 跟踪候选峰 → 回落 3 样本确认 → 不应期 100 样本（0.2 s）；
4. **心率**：最近 8 个 RR 取中位数 → `bpm = 30000 / 中位RR`；
5. **保护**：窗峰峰值 < 150 判信号丢失（清历史、输出 0）；上电 2 秒后才输出。

### 导联脱落检测

- ADC2 软件触发单次转换读 PA1（与 ADC1 主链完全独立）；
- 码值 > 2000 计数 +1、≤ 2000 计数 −1，满 50（100 ms）判脱落；
- 实测：正常 ≈ 25 码 / 脱落 ≈ 3723 码；脱落时心率强制显示 0。

## 快速开始

### 1. 硬件接线

| 从 | 到 | 说明 |
|---|---|---|
| 心电板 ECG 输出 | 天空星 **PA5**（丝印 A05） | ADC1_IN5，主信号 |
| 心电板 LEAD_OFF 输出 | 天空星 **PA1**（丝印 A01） | ADC2_IN1，导联信号 |
| 两板 GND | 互联 | 必须共地 |
| ST-Link SWDIO/SWCLK/GND | PA13/PA14/GND | 烧录调试 |
| USART1 PA9/PA10 | USB-TTL | 波形数据（115200） |

### 2. 编译烧录

将 `EcgMcuC/` 下的 `ecg_*.c/.h` 拷贝到 Keil 工程 `Alg/` 目录（**注意转 GBK 编码**），用 Keil MDK 打开工程 → Rebuild → Download（ST-Link，SWD 模式）。

### 3. VOFA+ 配置

- 协议：**FireWater**，波特率 **115200**；
- 四通道：`ch0=原始码值, ch1=滤波值, ch2=心率(bpm), ch3=导联状态(0/1)`；
- 建议 Δt 设 4 ms（数据实际 4 ms/帧），Y 轴手动固定便于观察。

## MATLAB 工具链

- **滤波器设计 / 系数生成**：改 `EcgMcuSim/ecg_config.m` → 运行 `EcgMcuC/gen_ecg_coeffs.m` → 生成新的 `ecg_coeffs.h/.c` → 拷贝到 `Alg/`；
- **逐点对拍验证**：`EcgMcuC/verify/run_verify.m`（生成双参考）+ `verify_python.py`（无编译器时的 float32 复刻对拍）；
- **上位机**：根目录 `ECG.m` 等 GUIDE 程序，支持串口实时采集、CSV 离线回放、波形显示、滤波与心率/频谱分析。

## 验收结果（对照《五参数验收标准》心电部分）

| 验收标准 | 状态 | 实测证据 |
|---|---|---|
| 滤除工频干扰 | 通过 | ch0 工频摆幅 ±270 码 → ch1 无 50 Hz 周期成分 |
| 滤除随机噪声 | 通过 | 噪声底仅数码级；逐样本变化 2~5 码 |
| 滤除基线漂移 | 通过 | 60 bpm 连续 3 分钟长跑基线稳定 |
| 心率 30~240 BPM ±5% | 通过 | 60/120/150/240 四档实测误差 0% |
| 导联脱落识别 | 通过 | 拔线 → 100 ms 后 ch3=1 且心率清零；插回恢复 |

## 开发文档

完整的开发纪实、踩坑档案（F4 ADC DDS 陷阱、串口竞争、心率不应期演进）、参数表与备份说明见：

**[`EcgMcuC/心电通道开发文档.md`](EcgMcuC/心电通道开发文档.md)**

## License

见 [LICENSE](LICENSE)。
