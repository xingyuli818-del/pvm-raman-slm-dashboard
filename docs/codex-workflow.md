# Codex Workflow

本项目用于本地 HTML 科研交互展示，主要服务 PVM、YOLO、Raman、SLM、SIM/显微图像和组会/PPT 汇报。

## 本地预览

在项目根目录运行：

```powershell
python -m http.server 8000
```

访问：

```text
http://localhost:8000/
```

## 推荐插件

已启用或建议启用：

- GitHub：版本管理、diff、commit、远程同步。
- Browser / in-app browser：普通本地 HTML 预览和页面验证。
- Chrome：需要登录态、Cookie、复杂网页操作时使用。
- Google Drive：读取实验记录、CSV、PPT、Word、申请材料。仅在明确要求时读取或修改。
- Documents：处理 Word 文档。
- Spreadsheets：处理 CSV/XLSX 表格。
- Presentations：处理 PPT/PPTX 组会材料。
- Gmail：邮件整理可选；当前 HTML 项目不依赖。

## 推荐 Skills

用户级 skills 中应包含：

- `html-research-dashboard`
- `research-crystallization-analysis`
- `playwright`
- `screenshot`
- `pdf`
- `jupyter-notebook`
- `transcribe`
- `security-best-practices`
- `using-superpowers`
- `brainstorming`
- `systematic-debugging`
- `verification-before-completion`
- `test-driven-development`
- `writing-plans`
- `executing-plans`
- `requesting-code-review`
- `receiving-code-review`
- `using-git-worktrees`

重启 Codex App 后，新安装的 skills 才会稳定加载。

## Git 工作流

查看状态：

```powershell
git status
```

查看修改：

```powershell
git diff
```

提交：

```powershell
git add .
git commit -m "describe change"
git push
```

回滚未提交的单个文件：

```powershell
git restore path/to/file
```

回滚所有未提交修改：

```powershell
git restore .
```

使用 `git restore .` 前先确认没有需要保留的实验数据或手动修改。

## Codex 修改后必须说明

- 改了哪些文件。
- 如何运行。
- 如何验证页面是否正常。
- 是否提交到 Git。
- 是否需要重启 Codex App。
