Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

if (-not ([System.Management.Automation.PSTypeName]"DesktopHostApi").Type) {
  Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class DesktopHostApi {
  [DllImport("user32.dll", SetLastError=true)]
  public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);

  [DllImport("user32.dll", SetLastError=true)]
  public static extern IntPtr FindWindowEx(IntPtr hwndParent, IntPtr hwndChildAfter, string lpszClass, string lpszWindow);

  [DllImport("user32.dll", SetLastError=true)]
  public static extern IntPtr SetParent(IntPtr hWndChild, IntPtr hWndNewParent);

  [DllImport("user32.dll", SetLastError=true)]
  public static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);

  [DllImport("user32.dll", SetLastError=true)]
  public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, IntPtr lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
}
"@
}

$ErrorActionPreference = "SilentlyContinue"

$dataDir = Join-Path $env:LOCALAPPDATA "CodexTodoWidget"
$dataPath = Join-Path $dataDir "tasks.json"
$settingsPath = Join-Path $dataDir "settings.json"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

function Get-DesktopHostHandle {
  $progman = [DesktopHostApi]::FindWindow("Progman", $null)
  if ($progman -ne [IntPtr]::Zero) {
    [UIntPtr]$result = [UIntPtr]::Zero
    [DesktopHostApi]::SendMessageTimeout($progman, 0x052C, [UIntPtr]::Zero, [IntPtr]::Zero, 0, 1000, [ref]$result) | Out-Null
  }

  $worker = [IntPtr]::Zero
  do {
    $worker = [DesktopHostApi]::FindWindowEx([IntPtr]::Zero, $worker, "WorkerW", $null)
    if ($worker -eq [IntPtr]::Zero) {
      break
    }

    $defView = [DesktopHostApi]::FindWindowEx($worker, [IntPtr]::Zero, "SHELLDLL_DefView", $null)
    if ($defView -ne [IntPtr]::Zero) {
      return $worker
    }
  } while ($true)

  return $progman
}

function Load-Settings {
  if (-not (Test-Path -Path $settingsPath)) {
    return [pscustomobject]@{}
  }

  try {
    $raw = Get-Content -Path $settingsPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
      return [pscustomobject]@{}
    }
    return ConvertFrom-Json $raw
  } catch {
    return [pscustomobject]@{}
  }
}

function Save-Settings {
  param([System.Windows.Forms.Form]$Form)

  [pscustomobject]@{
    x = $Form.Location.X
    y = $Form.Location.Y
    width = $Form.Width
    height = $Form.Height
  } | ConvertTo-Json -Depth 3 | Set-Content -Path $settingsPath -Encoding UTF8
}

function New-TaskId {
  return "task-{0}-{1}" -f ([DateTimeOffset]::Now.ToUnixTimeMilliseconds()), (Get-Random -Minimum 1000 -Maximum 9999)
}

function Load-Tasks {
  if (-not (Test-Path -Path $dataPath)) {
    return @()
  }

  try {
    $raw = Get-Content -Path $dataPath -Raw -Encoding UTF8
    if ([string]::IsNullOrWhiteSpace($raw)) {
      return @()
    }
    $items = ConvertFrom-Json $raw
    if ($null -eq $items) {
      return @()
    }
    return @($items)
  } catch {
    return @()
  }
}

function Save-Tasks {
  param([array]$Tasks)

  $Tasks | ConvertTo-Json -Depth 5 | Set-Content -Path $dataPath -Encoding UTF8
}

function Set-TaskDueDate {
  param(
    $Task,
    [string]$DueDate
  )

  if ($null -eq $Task.PSObject.Properties["dueDate"]) {
    $Task | Add-Member -NotePropertyName dueDate -NotePropertyValue $DueDate
    return
  }

  $Task.dueDate = $DueDate
}

function Ensure-TaskSchema {
  param([array]$Tasks)

  foreach ($task in $Tasks) {
    $dueDate = ""
    if ($null -ne $task.PSObject.Properties["dueDate"]) {
      $dueDate = [string]$task.dueDate
    }
    Set-TaskDueDate -Task $task -DueDate $dueDate
    if ($null -eq $task.PSObject.Properties["done"]) {
      $task | Add-Member -NotePropertyName done -NotePropertyValue $false
    }
  }

  return @($Tasks)
}

function New-Task {
  param(
    [string]$Title,
    [string]$DueDate
  )

  [pscustomobject]@{
    id = New-TaskId
    title = $Title
    dueDate = $DueDate
    done = $false
    createdAt = [DateTime]::Now.ToString("s")
  }
}

function Format-DueDate {
  param($Task)

  if ($null -eq $Task.PSObject.Properties["dueDate"]) {
    return "--"
  }

  if ([string]::IsNullOrWhiteSpace([string]$Task.dueDate)) {
    return "--"
  }

  try {
    return ([DateTime]::Parse([string]$Task.dueDate)).ToString("MM-dd")
  } catch {
    return [string]$Task.dueDate
  }
}

$tasks = @(Ensure-TaskSchema -Tasks @(Load-Tasks))
$settings = Load-Settings
$isRendering = $false

$form = New-Object System.Windows.Forms.Form
$form.Text = "桌面待办"
$form.Width = 420
$form.Height = 500
$form.MinimumSize = New-Object System.Drawing.Size(390, 420)
$form.StartPosition = "Manual"
$form.TopMost = $false
$form.ShowInTaskbar = $false
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.Opacity = 0.74
$form.BackColor = [System.Drawing.Color]::FromArgb(70, 92, 102)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
if ($settings.PSObject.Properties.Name -contains "x" -and $settings.PSObject.Properties.Name -contains "y") {
  $form.Location = New-Object System.Drawing.Point([int]$settings.x, [int]$settings.y)
} else {
$form.Location = New-Object System.Drawing.Point(($screen.Right - $form.Width - 22), ($screen.Top + 72))
}

$form.Add_Paint({
  param($sender, $event)
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150, 170, 195, 205), 1)
  $event.Graphics.DrawRectangle($pen, 0, 0, $form.Width - 1, $form.Height - 1)
  $pen.Dispose()
})

$dragging = $false
$dragStart = New-Object System.Drawing.Point(0, 0)
$formStart = New-Object System.Drawing.Point(0, 0)

$dragMouseDown = {
  param($sender, $event)
  if ($event.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
    $script:dragging = $true
    $script:dragStart = [System.Windows.Forms.Control]::MousePosition
    $script:formStart = $form.Location
  }
}

$dragMouseMove = {
  param($sender, $event)
  if ($script:dragging) {
    $current = [System.Windows.Forms.Control]::MousePosition
    $dx = $current.X - $script:dragStart.X
    $dy = $current.Y - $script:dragStart.Y
    $form.Location = New-Object System.Drawing.Point(($script:formStart.X + $dx), ($script:formStart.Y + $dy))
  }
}

$dragMouseUp = {
  $script:dragging = $false
  Save-Settings -Form $form
}

$headerPanel = New-Object System.Windows.Forms.Panel
$headerPanel.Location = New-Object System.Drawing.Point(0, 0)
$headerPanel.Width = $form.Width
$headerPanel.Height = 50
$headerPanel.Anchor = "Top,Left,Right"
$headerPanel.BackColor = $form.BackColor
$headerPanel.Add_MouseDown($dragMouseDown)
$headerPanel.Add_MouseMove($dragMouseMove)
$headerPanel.Add_MouseUp($dragMouseUp)
$form.Controls.Add($headerPanel)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "今日待办"
$titleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 13, [System.Drawing.FontStyle]::Bold)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(14, 15)
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(245, 249, 252)
$titleLabel.BackColor = $form.BackColor
$titleLabel.Add_MouseDown($dragMouseDown)
$titleLabel.Add_MouseMove($dragMouseMove)
$titleLabel.Add_MouseUp($dragMouseUp)
$headerPanel.Controls.Add($titleLabel)

$pinCheck = New-Object System.Windows.Forms.CheckBox
$pinCheck.Text = "置顶"
$pinCheck.Checked = $false
$pinCheck.AutoSize = $true
$pinCheck.Location = New-Object System.Drawing.Point(318, 18)
$pinCheck.BackColor = $form.BackColor
$pinCheck.ForeColor = [System.Drawing.Color]::FromArgb(235, 242, 247)
$pinCheck.Add_CheckedChanged({
  $form.TopMost = $pinCheck.Checked
})
$headerPanel.Controls.Add($pinCheck)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "×"
$closeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$closeButton.FlatAppearance.BorderSize = 0
$closeButton.BackColor = $form.BackColor
$closeButton.ForeColor = [System.Drawing.Color]::FromArgb(230, 238, 244)
$closeButton.Location = New-Object System.Drawing.Point(384, 10)
$closeButton.Width = 24
$closeButton.Height = 24
$closeButton.Anchor = "Top,Right"
$closeButton.Add_Click({ $form.Close() })
$headerPanel.Controls.Add($closeButton)

$input = New-Object System.Windows.Forms.TextBox
$input.Location = New-Object System.Drawing.Point(14, 54)
$input.Width = 166
$input.Height = 30
$input.Anchor = "Top,Left,Right"
$input.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$input.BackColor = [System.Drawing.Color]::FromArgb(236, 243, 247)
$input.ForeColor = [System.Drawing.Color]::FromArgb(30, 39, 52)
$form.Controls.Add($input)

$dueCheck = New-Object System.Windows.Forms.CheckBox
$dueCheck.Text = "截止"
$dueCheck.Checked = $false
$dueCheck.AutoSize = $true
$dueCheck.Location = New-Object System.Drawing.Point(186, 59)
$dueCheck.Anchor = "Top,Right"
$dueCheck.BackColor = $form.BackColor
$dueCheck.ForeColor = [System.Drawing.Color]::FromArgb(235, 242, 247)
$form.Controls.Add($dueCheck)

$duePicker = New-Object System.Windows.Forms.DateTimePicker
$duePicker.Location = New-Object System.Drawing.Point(236, 54)
$duePicker.Width = 84
$duePicker.Height = 30
$duePicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
$duePicker.CustomFormat = "MM-dd"
$duePicker.Enabled = $false
$duePicker.CalendarTitleBackColor = [System.Drawing.Color]::FromArgb(70, 92, 102)
$duePicker.Anchor = "Top,Right"
$form.Controls.Add($duePicker)

$dueCheck.Add_CheckedChanged({
  $duePicker.Enabled = $dueCheck.Checked
})

$addButton = New-Object System.Windows.Forms.Button
$addButton.Text = "添加"
$addButton.Location = New-Object System.Drawing.Point(328, 53)
$addButton.Width = 78
$addButton.Height = 31
$addButton.Anchor = "Top,Right"
$addButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$addButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(160, 182, 195)
$addButton.BackColor = [System.Drawing.Color]::FromArgb(207, 222, 230)
$addButton.ForeColor = [System.Drawing.Color]::FromArgb(25, 35, 48)
$form.Controls.Add($addButton)

$list = New-Object System.Windows.Forms.ListView
$list.Location = New-Object System.Drawing.Point(14, 94)
$list.Width = 392
$list.Height = 274
$list.Anchor = "Top,Bottom,Left,Right"
$list.View = "Details"
$list.CheckBoxes = $true
$list.FullRowSelect = $true
$list.HideSelection = $false
$list.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$list.BackColor = [System.Drawing.Color]::FromArgb(218, 230, 237)
$list.ForeColor = [System.Drawing.Color]::FromArgb(22, 31, 43)
$list.Columns.Add("任务", 210) | Out-Null
$list.Columns.Add("完成截止日期", 112) | Out-Null
$list.Columns.Add("状态", 58) | Out-Null
$form.Controls.Add($list)

$countLabel = New-Object System.Windows.Forms.Label
$countLabel.Text = "未完成 0 / 已完成 0"
$countLabel.AutoSize = $true
$countLabel.Location = New-Object System.Drawing.Point(14, 380)
$countLabel.Anchor = "Bottom,Left"
$countLabel.BackColor = $form.BackColor
$countLabel.ForeColor = [System.Drawing.Color]::FromArgb(235, 242, 247)
$form.Controls.Add($countLabel)

$deleteSelectedButton = New-Object System.Windows.Forms.Button
$deleteSelectedButton.Text = "删选中"
$deleteSelectedButton.Location = New-Object System.Drawing.Point(14, 410)
$deleteSelectedButton.Width = 82
$deleteSelectedButton.Height = 32
$deleteSelectedButton.Anchor = "Bottom,Left"
$deleteSelectedButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$deleteSelectedButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(160, 182, 195)
$deleteSelectedButton.BackColor = [System.Drawing.Color]::FromArgb(207, 222, 230)
$deleteSelectedButton.ForeColor = [System.Drawing.Color]::FromArgb(25, 35, 48)
$form.Controls.Add($deleteSelectedButton)

$clearDoneButton = New-Object System.Windows.Forms.Button
$clearDoneButton.Text = "清已完成"
$clearDoneButton.Location = New-Object System.Drawing.Point(104, 410)
$clearDoneButton.Width = 92
$clearDoneButton.Height = 32
$clearDoneButton.Anchor = "Bottom,Left"
$clearDoneButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$clearDoneButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(160, 182, 195)
$clearDoneButton.BackColor = [System.Drawing.Color]::FromArgb(207, 222, 230)
$clearDoneButton.ForeColor = [System.Drawing.Color]::FromArgb(25, 35, 48)
$form.Controls.Add($clearDoneButton)

$editDueButton = New-Object System.Windows.Forms.Button
$editDueButton.Text = "改日期"
$editDueButton.Location = New-Object System.Drawing.Point(210, 410)
$editDueButton.Width = 78
$editDueButton.Height = 32
$editDueButton.Anchor = "Bottom,Right"
$editDueButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$editDueButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(160, 182, 195)
$editDueButton.BackColor = [System.Drawing.Color]::FromArgb(207, 222, 230)
$editDueButton.ForeColor = [System.Drawing.Color]::FromArgb(25, 35, 48)
$form.Controls.Add($editDueButton)

$openFullButton = New-Object System.Windows.Forms.Button
$openFullButton.Text = "打开完整版"
$openFullButton.Location = New-Object System.Drawing.Point(294, 410)
$openFullButton.Width = 112
$openFullButton.Height = 32
$openFullButton.Anchor = "Bottom,Right"
$openFullButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$openFullButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(160, 182, 195)
$openFullButton.BackColor = [System.Drawing.Color]::FromArgb(207, 222, 230)
$openFullButton.ForeColor = [System.Drawing.Color]::FromArgb(25, 35, 48)
$form.Controls.Add($openFullButton)

function Render-Tasks {
  $script:isRendering = $true
  $list.BeginUpdate()
  $list.Items.Clear()

  foreach ($task in $script:tasks) {
    $status = if ($task.done) { "完成" } else { "待办" }
    $item = New-Object System.Windows.Forms.ListViewItem($task.title)
    $item.SubItems.Add((Format-DueDate -Task $task)) | Out-Null
    $item.SubItems.Add($status) | Out-Null
    $item.Checked = [bool]$task.done
    $item.Tag = $task.id
    if ($task.done) {
      $item.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
    }
    $list.Items.Add($item) | Out-Null
  }

  $list.EndUpdate()
  $open = @($script:tasks | Where-Object { -not $_.done }).Count
  $done = @($script:tasks | Where-Object { $_.done }).Count
  $countLabel.Text = "未完成 $open / 已完成 $done"
  $script:isRendering = $false
}

function Add-TaskFromInput {
  $title = $input.Text.Trim()
  if ([string]::IsNullOrWhiteSpace($title)) {
    return
  }

  $dueDate = ""
  if ($dueCheck.Checked) {
    $dueDate = $duePicker.Value.ToString("yyyy-MM-dd")
  }

  $script:tasks = @((New-Task -Title $title -DueDate $dueDate)) + @($script:tasks)
  $input.Text = ""
  Save-Tasks -Tasks $script:tasks
  Render-Tasks
  $input.Focus()
}

function Edit-TaskDueDate {
  param($TaskId)

  $task = $script:tasks | Where-Object { $_.id -eq $TaskId } | Select-Object -First 1
  if ($null -eq $task) {
    return
  }

  $dialog = New-Object System.Windows.Forms.Form
  $dialog.Text = "修改截止日期"
  $dialog.Width = 280
  $dialog.Height = 150
  $dialog.StartPosition = "CenterScreen"
  $dialog.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog
  $dialog.MaximizeBox = $false
  $dialog.MinimizeBox = $false
  $dialog.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

  $label = New-Object System.Windows.Forms.Label
  $label.Text = "完成截止日期"
  $label.AutoSize = $true
  $label.Location = New-Object System.Drawing.Point(16, 18)
  $dialog.Controls.Add($label)

  $editPicker = New-Object System.Windows.Forms.DateTimePicker
  $editPicker.Location = New-Object System.Drawing.Point(16, 44)
  $editPicker.Width = 230
  $editPicker.Format = [System.Windows.Forms.DateTimePickerFormat]::Custom
  $editPicker.CustomFormat = "yyyy-MM-dd"
  $hasDue = $task.PSObject.Properties.Name -contains "dueDate" -and -not [string]::IsNullOrWhiteSpace([string]$task.dueDate)
  if ($hasDue) {
    try {
      $editPicker.Value = [DateTime]::Parse([string]$task.dueDate)
    } catch {
      $editPicker.Value = [DateTime]::Today
    }
  }
  $dialog.Controls.Add($editPicker)

  $clearButton = New-Object System.Windows.Forms.Button
  $clearButton.Text = "无截止"
  $clearButton.Location = New-Object System.Drawing.Point(16, 78)
  $clearButton.Width = 76
  $clearButton.Add_Click({
    Set-TaskDueDate -Task $task -DueDate ""
    Save-Tasks -Tasks $script:tasks
    Render-Tasks
    $dialog.Close()
  })
  $dialog.Controls.Add($clearButton)

  $okButton = New-Object System.Windows.Forms.Button
  $okButton.Text = "保存"
  $okButton.Location = New-Object System.Drawing.Point(170, 78)
  $okButton.Width = 76
  $okButton.Add_Click({
    Set-TaskDueDate -Task $task -DueDate $editPicker.Value.ToString("yyyy-MM-dd")
    Save-Tasks -Tasks $script:tasks
    Render-Tasks
    $dialog.Close()
  })
  $dialog.Controls.Add($okButton)

  [void]$dialog.ShowDialog($form)
}

function Open-SelectedTaskDueDateEditor {
  if ($list.SelectedItems.Count -eq 0) {
    return
  }

  Edit-TaskDueDate -TaskId $list.SelectedItems[0].Tag
}

$addButton.Add_Click({ Add-TaskFromInput })

$input.Add_KeyDown({
  param($sender, $event)
  if ($event.KeyCode -eq [System.Windows.Forms.Keys]::Enter) {
    Add-TaskFromInput
    $event.SuppressKeyPress = $true
  }
})

$list.Add_ItemChecked({
  param($sender, $event)
  if ($script:isRendering) {
    return
  }

  foreach ($task in $script:tasks) {
    if ($task.id -eq $event.Item.Tag) {
      $task.done = [bool]$event.Item.Checked
      break
    }
  }
  Save-Tasks -Tasks $script:tasks
  Render-Tasks
})

$list.Add_DoubleClick({
  Open-SelectedTaskDueDateEditor
})

$editDueButton.Add_Click({ Open-SelectedTaskDueDateEditor })

$deleteSelectedButton.Add_Click({
  $ids = @()
  foreach ($item in $list.SelectedItems) {
    $ids += $item.Tag
  }
  if ($ids.Count -eq 0) {
    return
  }
  $script:tasks = @($script:tasks | Where-Object { $ids -notcontains $_.id })
  Save-Tasks -Tasks $script:tasks
  Render-Tasks
})

$clearDoneButton.Add_Click({
  $script:tasks = @($script:tasks | Where-Object { -not $_.done })
  Save-Tasks -Tasks $script:tasks
  Render-Tasks
})

$openFullButton.Add_Click({
  $projectRoot = Split-Path -Parent $PSScriptRoot
  $fullScript = Join-Path $PSScriptRoot "open-todo-plugin.ps1"
  if (Test-Path -Path $fullScript) {
    Start-Process -FilePath "powershell.exe" -ArgumentList @(
      "-NoProfile",
      "-ExecutionPolicy",
      "Bypass",
      "-File",
      $fullScript
    ) -WorkingDirectory $projectRoot
  }
})

$form.Add_Shown({
  $desktopHost = Get-DesktopHostHandle
  if ($desktopHost -ne [IntPtr]::Zero) {
    [DesktopHostApi]::SetParent($form.Handle, $desktopHost) | Out-Null
    [DesktopHostApi]::SetWindowPos(
      $form.Handle,
      [IntPtr]1,
      $form.Location.X,
      $form.Location.Y,
      $form.Width,
      $form.Height,
      0x0040 -bor 0x0010
    ) | Out-Null
  }
})

$form.Add_FormClosing({
  Save-Tasks -Tasks $script:tasks
  Save-Settings -Form $form
})

Render-Tasks
[void]$form.ShowDialog()






