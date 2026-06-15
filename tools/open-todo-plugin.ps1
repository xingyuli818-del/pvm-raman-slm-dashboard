$ErrorActionPreference = "SilentlyContinue"

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Ports = 8000..8010

function Test-TodoPage {
  param([int]$Port)

  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri "http://localhost:$Port/todo-plugin/" -TimeoutSec 2
    return $response.StatusCode -eq 200
  } catch {
    return $false
  }
}

function Test-PortBusy {
  param([int]$Port)

  $connection = Get-NetTCPConnection -State Listen -LocalPort $Port -ErrorAction SilentlyContinue
  return $null -ne $connection
}

foreach ($port in $Ports) {
  if (Test-TodoPage -Port $port) {
    Start-Process "http://localhost:$port/todo-plugin/"
    exit 0
  }
}

foreach ($port in $Ports) {
  if (Test-PortBusy -Port $port) {
    continue
  }

  $logPath = Join-Path $ProjectRoot "server.log"
  $errPath = Join-Path $ProjectRoot "server.err.log"
  $command = "Set-Location -LiteralPath '$ProjectRoot'; python -m http.server $port"

  Start-Process -FilePath "powershell.exe" `
    -ArgumentList @("-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $command) `
    -WindowStyle Hidden `
    -RedirectStandardOutput $logPath `
    -RedirectStandardError $errPath

  for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 250
    if (Test-TodoPage -Port $port) {
      Start-Process "http://localhost:$port/todo-plugin/"
      exit 0
    }
  }
}

Add-Type -AssemblyName System.Windows.Forms
[System.Windows.Forms.MessageBox]::Show(
  "无法启动本地待办插件。请确认 Python 已安装，并检查 8000-8010 端口是否被占用。",
  "待办插件启动失败",
  [System.Windows.Forms.MessageBoxButtons]::OK,
  [System.Windows.Forms.MessageBoxIcon]::Error
) | Out-Null

exit 1

