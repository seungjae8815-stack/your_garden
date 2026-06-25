$tools = @('flutter','dart','git','code','java','adb')
foreach ($t in $tools) {
  $c = Get-Command $t -ErrorAction SilentlyContinue
  if ($c) { Write-Output ("{0}: {1}" -f $t, $c.Source) }
  else    { Write-Output ("{0}: NOT FOUND" -f $t) }
}
$paths = @(
  'C:\Program Files\Android\Android Studio',
  'C:\src\flutter',
  "$env:LOCALAPPDATA\Android\Sdk",
  "$env:USERPROFILE\flutter",
  "$env:USERPROFILE\AppData\Local\Android\Sdk"
)
foreach ($p in $paths) {
  if (Test-Path $p) { Write-Output ("EXISTS: {0}" -f $p) }
  else              { Write-Output ("MISSING: {0}" -f $p) }
}
Write-Output ("PSVersion: " + $PSVersionTable.PSVersion.ToString())
