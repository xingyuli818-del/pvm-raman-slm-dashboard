Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "SilentlyContinue"

$dataDir = Join-Path $env:LOCALAPPDATA "CodexTodoWidget"
$dataPath = Join-Path $dataDir "tasks.json"
New-Item -ItemType Directory -Force -Path $dataDir | Out-Null

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

function New-Task {
  param([string]$Title)

  [pscustomobject]@{
    id = New-TaskId
    title = $Title
    done = $false
    createdAt = [DateTime]::Now.ToString("s")
  }
}

$tasks = @(Load-Tasks)
$isRendering = $false

$form = New-Object System.Windows.Forms.Form
$form.Text = "桌面待办"
$form.Width = 330
$form.Height = 468
$form.MinimumSize = New-Object System.Drawing.Size(300, 390)
$form.StartPosition = "Manual"
$form.TopMost = $false
$form.ShowInTaskbar = $false
$form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::None
$form.Opacity = 0.86
$form.BackColor = [System.Drawing.Color]::FromArgb(243, 246, 250)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object System.Drawing.Point(($screen.Right - $form.Width - 22), ($screen.Top + 72))

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
$titleLabel.ForeColor = [System.Drawing.Color]::FromArgb(32, 41, 57)
$titleLabel.BackColor = $form.BackColor
$titleLabel.Add_MouseDown($dragMouseDown)
$titleLabel.Add_MouseMove($dragMouseMove)
$titleLabel.Add_MouseUp($dragMouseUp)
$headerPanel.Controls.Add($titleLabel)

$pinCheck = New-Object System.Windows.Forms.CheckBox
$pinCheck.Text = "置顶"
$pinCheck.Checked = $false
$pinCheck.AutoSize = $true
$pinCheck.Location = New-Object System.Drawing.Point(228, 18)
$pinCheck.BackColor = $form.BackColor
$pinCheck.ForeColor = [System.Drawing.Color]::FromArgb(82, 96, 115)
$pinCheck.Add_CheckedChanged({
  $form.TopMost = $pinCheck.Checked
})
$headerPanel.Controls.Add($pinCheck)

$closeButton = New-Object System.Windows.Forms.Button
$closeButton.Text = "×"
$closeButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$closeButton.FlatAppearance.BorderSize = 0
$closeButton.BackColor = $form.BackColor
$closeButton.ForeColor = [System.Drawing.Color]::FromArgb(100, 116, 139)
$closeButton.Location = New-Object System.Drawing.Point(294, 10)
$closeButton.Width = 24
$closeButton.Height = 24
$closeButton.Anchor = "Top,Right"
$closeButton.Add_Click({ $form.Close() })
$headerPanel.Controls.Add($closeButton)

$input = New-Object System.Windows.Forms.TextBox
$input.Location = New-Object System.Drawing.Point(14, 54)
$input.Width = 214
$input.Height = 30
$input.Anchor = "Top,Left,Right"
$input.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
$input.BackColor = [System.Drawing.Color]::FromArgb(250, 252, 255)
$form.Controls.Add($input)

$addButton = New-Object System.Windows.Forms.Button
$addButton.Text = "添加"
$addButton.Location = New-Object System.Drawing.Point(238, 53)
$addButton.Width = 78
$addButton.Height = 31
$addButton.Anchor = "Top,Right"
$addButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$addButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(210, 218, 229)
$addButton.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$form.Controls.Add($addButton)

$list = New-Object System.Windows.Forms.ListView
$list.Location = New-Object System.Drawing.Point(14, 94)
$list.Width = 302
$list.Height = 248
$list.Anchor = "Top,Bottom,Left,Right"
$list.View = "Details"
$list.CheckBoxes = $true
$list.FullRowSelect = $true
$list.HideSelection = $false
$list.BorderStyle = [System.Windows.Forms.BorderStyle]::None
$list.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$list.ForeColor = [System.Drawing.Color]::FromArgb(32, 41, 57)
$list.Columns.Add("任务", 224) | Out-Null
$list.Columns.Add("状态", 58) | Out-Null
$form.Controls.Add($list)

$countLabel = New-Object System.Windows.Forms.Label
$countLabel.Text = "未完成 0 / 已完成 0"
$countLabel.AutoSize = $true
$countLabel.Location = New-Object System.Drawing.Point(14, 354)
$countLabel.Anchor = "Bottom,Left"
$countLabel.BackColor = $form.BackColor
$countLabel.ForeColor = [System.Drawing.Color]::FromArgb(82, 96, 115)
$form.Controls.Add($countLabel)

$deleteSelectedButton = New-Object System.Windows.Forms.Button
$deleteSelectedButton.Text = "删选中"
$deleteSelectedButton.Location = New-Object System.Drawing.Point(14, 382)
$deleteSelectedButton.Width = 82
$deleteSelectedButton.Height = 32
$deleteSelectedButton.Anchor = "Bottom,Left"
$deleteSelectedButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$deleteSelectedButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(214, 222, 232)
$deleteSelectedButton.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$form.Controls.Add($deleteSelectedButton)

$clearDoneButton = New-Object System.Windows.Forms.Button
$clearDoneButton.Text = "清已完成"
$clearDoneButton.Location = New-Object System.Drawing.Point(104, 382)
$clearDoneButton.Width = 92
$clearDoneButton.Height = 32
$clearDoneButton.Anchor = "Bottom,Left"
$clearDoneButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$clearDoneButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(214, 222, 232)
$clearDoneButton.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$form.Controls.Add($clearDoneButton)

$openFullButton = New-Object System.Windows.Forms.Button
$openFullButton.Text = "打开完整版"
$openFullButton.Location = New-Object System.Drawing.Point(204, 382)
$openFullButton.Width = 112
$openFullButton.Height = 32
$openFullButton.Anchor = "Bottom,Right"
$openFullButton.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
$openFullButton.FlatAppearance.BorderColor = [System.Drawing.Color]::FromArgb(214, 222, 232)
$openFullButton.BackColor = [System.Drawing.Color]::FromArgb(248, 250, 252)
$form.Controls.Add($openFullButton)

function Render-Tasks {
  $script:isRendering = $true
  $list.BeginUpdate()
  $list.Items.Clear()

  foreach ($task in $script:tasks) {
    $status = if ($task.done) { "完成" } else { "待办" }
    $item = New-Object System.Windows.Forms.ListViewItem($task.title)
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

  $script:tasks = @((New-Task -Title $title)) + @($script:tasks)
  $input.Text = ""
  Save-Tasks -Tasks $script:tasks
  Render-Tasks
  $input.Focus()
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

$form.Add_FormClosing({
  Save-Tasks -Tasks $script:tasks
})

Render-Tasks
[void]$form.ShowDialog()



