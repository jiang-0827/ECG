$ErrorActionPreference = "Continue"
$root = (Get-Item "E:\BaiduNetdiskDownload\*STM32F407VET6*\*03*\*\011ADC*\STM32F407_ProjectTemplate").FullName
$tool = "D:\Keil_v5\ARM\ARMCC\bin"
$out  = Join-Path $env:TEMP "ecg_objs2"
if(Test-Path $out){ Remove-Item $out -Recurse -Force }
New-Item -ItemType Directory -Path $out | Out-Null

$incDirs = @("app\Main","app\DataType","app\PackUnpack","app\ProcHostCmd","app\SendDataToHost",
             "HW\RCC","HW\Timer","HW\UART1","HW\ADC","HW\LED","ARM\NVIC","ARM\SysTick","Alg","module",
             "libraries\CMSIS\Include","libraries\CMSIS\Device\ST\STM32F4xx\Include",
             "libraries\STM32F4xx_StdPeriph_Driver\inc")
$incArgs = @(); foreach($d in $incDirs){ $incArgs += @("-I" + (Join-Path $root $d)) }

$srcs = @("app\Main\Main.c","app\ProcHostCmd\ProcHostCmd.c","app\PackUnpack\PackUnpack.c","app\SendDataToHost\SendDataToHost.c",
          "HW\RCC\RCC.c","HW\Timer\Timer.c","HW\UART1\UART1.c","HW\UART1\Queue.c","HW\ADC\ADC.c","HW\ADC\U16Queue.c","HW\LED\LED.c",
          "ARM\NVIC\NVIC.c","ARM\SysTick\SysTick.c","module\stm32f4xx_it.c",
          "libraries\CMSIS\Device\ST\STM32F4xx\Source\Templates\system_stm32f4xx.c",
          "libraries\STM32F4xx_StdPeriph_Driver\src\misc.c",
          "libraries\STM32F4xx_StdPeriph_Driver\src\stm32f4xx_rcc.c",
          "libraries\STM32F4xx_StdPeriph_Driver\src\stm32f4xx_gpio.c",
          "libraries\STM32F4xx_StdPeriph_Driver\src\stm32f4xx_usart.c",
          "libraries\STM32F4xx_StdPeriph_Driver\src\stm32f4xx_tim.c",
          "libraries\STM32F4xx_StdPeriph_Driver\src\stm32f4xx_adc.c",
          "libraries\STM32F4xx_StdPeriph_Driver\src\stm32f4xx_dma.c")

$objs = @(); $err = 0
foreach($s in $srcs){
  $fi = Join-Path $root $s
  if(-not (Test-Path -LiteralPath $fi)){ "NOT FOUND: $s"; $err++; continue }
  $o = Join-Path $out ((Split-Path $fi -Leaf) -replace '\.c$','.o')
  $cargs = @("--cpu","Cortex-M4.fp","-c","-O1","--apcs=/interwork",
             "-DUSE_STDPERIPH_DRIVER","-DSTM32F40_41xxx") + $incArgs + @("-o",$o,$fi)
  $res = & "$tool\armcc.exe" @cargs 2>&1
  if($LASTEXITCODE -ne 0){ $err++; "FAIL: $s"; $res | ForEach-Object { "     " + ($_ -split "`n")[0] } }
  elseif((($res | Out-String).Trim()).Length -gt 0){ "WARN: $s"; $res | ForEach-Object { "     " + ($_ -split "`n")[0] } }
  if(Test-Path $o){ $objs += $o }
}
$sa = Join-Path $root "libraries\CMSIS\Device\ST\STM32F4xx\Source\Templates\arm\startup_stm32f40xx.s"
$so = Join-Path $out "startup.o"
& "$tool\armasm.exe" --cpu Cortex-M4.fp -o $so $sa | Out-Null
$objs += $so
"==== compile: $err failed / $($srcs.Count) ===="
$axf = Join-Path $out "ECG.axf"
$largs = @("--cpu","Cortex-M4.fp","--strict","--entry","Reset_Handler","--first","startup.o(RESET)",
           "--ro-base","0x08000000","--rw-base","0x20000000","--info=sizes","-o",$axf) + $objs
& "$tool\armlink.exe" @largs 2>&1 | Select-String -Pattern "Error|Warning|Total RW  Size" | ForEach-Object { $_.ToString().Trim() }
"link exit = $LASTEXITCODE"
if(Test-Path $axf){
  & "$tool\fromelf.exe" --i32 -o (Join-Path $out "ECG.hex") $axf | Out-Null
  $dst = Join-Path $root "project\MDK(V5)\Objects\ECG_Skeleton_precheck.hex"
  Copy-Item (Join-Path $out "ECG.hex") $dst -Force
  "hex updated -> $dst"
}
"UV4 running now = " + (Get-Process UV4 -ErrorAction SilentlyContinue | Measure-Object).Count
