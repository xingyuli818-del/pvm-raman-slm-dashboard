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
$form.Text = "待办小窗"
$form.Width = 360
$form.Height = 520
$form.MinimumSize = New-Object System.Drawing.Size(320, 420)
$form.StartPosition = "Manual"
$form.TopMost = $true
$form.BackColor = [System.Drawing.Color]::FromArgb(246, 248, 251)
$form.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 9)

$screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
$form.Location = New-Object System.Drawing.Point(($screen.Right - $form.Width - 24), ($screen.Top + 80))

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "今日待办"
$titleLabel.Font = New-Object System.Drawing.Font("Microsoft YaHei UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.AutoSize = $true
$titleLabel.Location = New-Object System.Drawing.Point(16, 14)
$form.Controls.Add($titleLabel)

$pinCheck = New-Object System.Windows.Forms.CheckBox
$pinCheck.Text = "置顶"
$pinCheck.Checked = $true
$pinCheck.AutoSize = $true
$pinCheck.Location = New-Object System.Drawing.Point(286, 20)
$pinCheck.Add_CheckedChanged({
  $form.TopMost = $pinCheck.Checked
})
$form.Controls.Add($pinCheck)

$input = New-Object System.Windows.Forms.TextBox
$input.Location = New-Object System.Drawing.Point(16, 58)
$input.Width = 238
$input.Height = 30
$input.Anchor = "Top,Left,Right"
$form.Controls.Add($input)

$addButton = New-Object System.Windows.Forms.Button
$addButton.Text = "添加"
$addButton.Location = New-Object System.Drawing.Point(266, 56)
$addButton.Width = 62
$addButton.Height = 31
$addButton.Anchor = "Top,Right"
$form.Controls.Add($addButton)

$list = New-Object System.Windows.Forms.ListView
$list.Location = New-Object System.Drawing.Point(16, 102)
$list.Width = 312
$list.Height = 292
$list.Anchor = "Top,Bottom,Left,Right"
$list.View = "Details"
$list.CheckBoxes = $true
$list.FullRowSelect = $true
$list.HideSelection = $false
$list.Columns.Add("任务", 236) | Out-Null
$list.Columns.Add("状态", 58) | Out-Null
$form.Controls.Add($list)

$countLabel = New-Object System.Windows.Forms.Label
$countLabel.Text = "未完成 0 / 已完成 0"
$countLabel.AutoSize = $true
$countLabel.Location = New-Object System.Drawing.Point(16, 406)
$countLabel.Anchor = "Bottom,Left"
$form.Controls.Add($countLabel)

$deleteSelectedButton = New-Object System.Windows.Forms.Button
$deleteSelectedButton.Text = "删选中"
$deleteSelectedButton.Location = New-Object System.Drawing.Point(16, 434)
$deleteSelectedButton.Width = 88
$deleteSelectedButton.Height = 32
$deleteSelectedButton.Anchor = "Bottom,Left"
$form.Controls.Add($deleteSelectedButton)

$clearDoneButton = New-Object System.Windows.Forms.Button
$clearDoneButton.Text = "清已完成"
$clearDoneButton.Location = New-Object System.Drawing.Point(116, 434)
$clearDoneButton.Width = 96
$clearDoneButton.Height = 32
$clearDoneButton.Anchor = "Bottom,Left"
$form.Controls.Add($clearDoneButton)

$openFullButton = New-Object System.Windows.Forms.Button
$openFullButton.Text = "打开完整版"
$openFullButton.Location = New-Object System.Drawing.Point(224, 434)
$openFullButton.Width = 104
$openFullButton.Height = 32
$openFullButton.Anchor = "Bottom,Right"
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


