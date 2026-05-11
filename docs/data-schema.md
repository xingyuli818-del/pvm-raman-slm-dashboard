# Data Schema

## PVM / YOLO / Raman

默认 CSV 放在 `./data/`，推荐文件名：

```text
data/example_pvm_raman.csv
```

必需列：

```text
time_min,block_count,total_count,block_frequency,threshold,endpoint_min,intensity_1624,raman_endpoint_min
```

推荐扩展列：

```text
sample_id,frame_id,time_min,block_count,urchin_count,total_count,block_frequency,threshold,endpoint_min,intensity_1624,raman_endpoint_min,image_path,yolo_mask_path,note
```

兼容规则：

- 如果缺少 `block_frequency`，但存在 `block_count` 和 `total_count`，可以计算 `block_count / total_count`。
- 如果缺少 `endpoint_min`，页面应自动判定并标注为自动终点。
- 如果缺少 `raman_endpoint_min`，页面应自动判定并标注为自动 Raman 终点。
- 如果缺少图像路径，图表仍应正常显示，并在图像区域给出提示。

## Endpoint Logic

PVM 图像终点：

- 主指标：`block_frequency`
- 方法：滑动窗口、阈值、持续性、无回弹
- 输出：`endpoint_min`

Raman 终点：

- 主指标：`intensity_1624`
- 方法：平台期、相对波动、斜率、持续性
- 输出：`raman_endpoint_min`

图像-Raman 对齐：

- 统一横轴：`time_min`
- 输出：`raman_endpoint_min - endpoint_min`

## SLM

默认 CSV 放在 `./data/`，推荐文件名：

```text
data/example_slm.csv
```

必需列：

```text
wavelength_nm,gray_value,grating_period_px,image_path,conclusion
```

推荐扩展列：

```text
wavelength_nm,gray_value,grating_period_px,diffraction_order,spot_distance_px,calibration_error,exposure_ms,image_path,conclusion
```
