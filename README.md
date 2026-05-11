# PVM-Raman-SLM 科研展示面板

这是一个本地优先的 HTML 科研交互展示项目，用于组会汇报和 PPT 截图。当前示例覆盖：

- PVM 图像 block / urchin 数量统计
- `block_frequency` 图像终点判定
- Raman `1624 cm^-1` 曲线平台期终点判定
- 图像终点与 Raman 终点同时间轴对齐
- SLM 波长、灰度、光栅周期标定展示

## 运行

在项目根目录执行：

```powershell
python -m http.server 8000
```

然后打开：

```text
http://localhost:8000/
```

## 目录结构

```text
index.html
style.css
script.js
data/
assets/
figures/
README.md
```

## 数据格式

PVM/Raman 示例数据：`./data/example_pvm_raman.csv`

至少包含：

- `time_min`
- `block_count`
- `total_count`
- `block_frequency`
- `threshold`
- `endpoint_min`
- `intensity_1624`
- `raman_endpoint_min`

SLM 示例数据：`./data/example_slm.csv`

至少包含：

- `wavelength_nm`
- `gray_value`
- `grating_period_px`
- `image_path`
- `conclusion`

如果上传的 CSV 列名不匹配，页面会提示缺少的列名。

## 验证

1. 页面能通过 `python -m http.server 8000` 打开。
2. 首页显示图像终点、Raman 终点和二者时间差。
3. “PVM 图像终点”页能显示 `block_frequency` 曲线、阈值线和示例图。
4. “图像-Raman 对齐”页能在同一时间轴显示两个终点。
5. “SLM 标定”页能显示标定曲线和示例标定图。
