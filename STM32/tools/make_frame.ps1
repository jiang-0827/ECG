function Pack($raw) {
  $p = @($raw.Clone())
  $cs = $p[0]; $dh = 0
  for($i=8; $i -ge 2; $i--){
    $dh = (($dh -shl 1) -bor (($p[$i] -band 0x80) -shr 7)) -band 0xFF
    $p[$i] = $p[$i] -bor 0x80
    $cs = ($cs + $p[$i]) -band 0xFF
  }
  $p[1] = ($dh -bor 0x80) -band 0xFF
  $cs = ($cs + $p[1]) -band 0xFF
  $p[9] = ($cs -bor 0x80) -band 0xFF
  return (($p | ForEach-Object { $_.ToString("X2") }) -join " ")
}
$out  = "set1000 : " + (Pack @(0x10,0,0x8B,0xE8,0x03,0,0,0,0,0))
$out += "`r`n" + "set250  : " + (Pack @(0x10,0,0x8B,0xFA,0x00,0,0,0,0,0))
$out += "`r`n" + "getrate : " + (Pack @(0x10,0,0x8C,0,0,0,0,0,0,0))
$out += "`r`n" + "getsts  : " + (Pack @(0x10,0,0x8A,0,0,0,0,0,0,0))
$out += "`r`n" + "clrCnt  : " + (Pack @(0x10,0,0x8E,0,0,0,0,0,0,0))
$out += "`r`n" + "waveOff : " + (Pack @(0x71,0,0x80,0,0,0,0,0,0,0))
$out += "`r`n" + "waveOn  : " + (Pack @(0x71,0,0x80,1,0,0,0,0,0,0))
$out += "`r`n" + "ch5_PA5 : " + (Pack @(0x10,0,0x8D,5,0,0,0,0,0,0))
$out += "`r`n" + "ch17ref : " + (Pack @(0x10,0,0x8D,17,0,0,0,0,0,0))
$out | Set-Content "$env:TEMP\frames.txt" -Encoding ASCII
Write-Output $out
