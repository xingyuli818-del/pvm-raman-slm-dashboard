const REQUIRED_PVM_COLUMNS = [
  "time_min",
  "block_count",
  "total_count",
  "block_frequency",
  "threshold",
  "endpoint_min",
  "intensity_1624",
  "raman_endpoint_min",
];

const REQUIRED_SLM_COLUMNS = [
  "wavelength_nm",
  "gray_value",
  "grating_period_px",
  "image_path",
  "conclusion",
];

const state = {
  pvmRows: [],
  slmRows: [],
  pvmEndpoint: null,
  pvmAutoEndpoint: null,
  ramanEndpoint: null,
  ramanAutoEndpoint: null,
};

const charts = {
  overview: document.querySelector("#overviewChart"),
  pvm: document.querySelector("#pvmChart"),
  alignment: document.querySelector("#alignmentChart"),
  slm: document.querySelector("#slmChart"),
};

function parseCsv(text) {
  const rows = [];
  let cell = "";
  let row = [];
  let quoted = false;

  for (let index = 0; index < text.length; index += 1) {
    const char = text[index];
    const next = text[index + 1];

    if (char === '"' && quoted && next === '"') {
      cell += '"';
      index += 1;
    } else if (char === '"') {
      quoted = !quoted;
    } else if (char === "," && !quoted) {
      row.push(cell.trim());
      cell = "";
    } else if ((char === "\n" || char === "\r") && !quoted) {
      if (char === "\r" && next === "\n") index += 1;
      row.push(cell.trim());
      if (row.some(Boolean)) rows.push(row);
      row = [];
      cell = "";
    } else {
      cell += char;
    }
  }

  if (cell || row.length) {
    row.push(cell.trim());
    if (row.some(Boolean)) rows.push(row);
  }

  const headers = rows.shift() || [];
  return rows.map((values) => {
    return headers.reduce((record, header, index) => {
      record[header] = values[index] ?? "";
      return record;
    }, {});
  });
}

function assertColumns(rows, required, label) {
  const columns = new Set(Object.keys(rows[0] || {}));
  const missing = required.filter((column) => !columns.has(column));
  if (missing.length) {
    throw new Error(`${label} 缺少列：${missing.join(", ")}。请检查 CSV 表头。`);
  }
}

function toNumber(value) {
  const number = Number(value);
  return Number.isFinite(number) ? number : null;
}

async function loadCsv(path, required, label) {
  const response = await fetch(path);
  if (!response.ok) {
    throw new Error(`无法读取 ${path}。请通过 python -m http.server 8000 运行页面。`);
  }
  const rows = parseCsv(await response.text());
  assertColumns(rows, required, label);
  return rows;
}

function readUploadedCsv(file, required, label) {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      try {
        const rows = parseCsv(String(reader.result));
        assertColumns(rows, required, label);
        resolve(rows);
      } catch (error) {
        reject(error);
      }
    };
    reader.onerror = () => reject(new Error(`无法读取 ${file.name}`));
    reader.readAsText(file, "utf-8");
  });
}

function detectPvmEndpoint(rows) {
  const windowSize = 3;
  for (let start = 0; start <= rows.length - windowSize; start += 1) {
    const windowRows = rows.slice(start, start + windowSize);
    const threshold = toNumber(windowRows[0].threshold) ?? 0.12;
    const sustained = windowRows.every((row) => {
      return (toNumber(row.block_frequency) ?? 1) <= threshold;
    });
    if (!sustained) continue;

    const afterRows = rows.slice(start + windowSize);
    const noRebound = afterRows.every((row) => {
      return (toNumber(row.block_frequency) ?? 0) <= threshold * 1.15;
    });
    if (noRebound) return toNumber(windowRows[0].time_min);
  }
  return null;
}

function detectRamanEndpoint(rows) {
  const windowSize = 4;
  const values = rows.map((row) => ({
    time: toNumber(row.time_min),
    intensity: toNumber(row.intensity_1624),
  }));

  for (let start = 0; start <= values.length - windowSize; start += 1) {
    const windowRows = values.slice(start, start + windowSize);
    const intensities = windowRows.map((row) => row.intensity).filter(Number.isFinite);
    if (intensities.length < windowSize) continue;

    const mean = intensities.reduce((sum, value) => sum + value, 0) / intensities.length;
    const range = Math.max(...intensities) - Math.min(...intensities);
    const relativeWave = range / Math.max(1, Math.abs(mean));
    const first = windowRows[0];
    const last = windowRows[windowRows.length - 1];
    const slope = Math.abs((last.intensity - first.intensity) / Math.max(1, last.time - first.time));

    if (relativeWave <= 0.035 && slope <= 1.2) {
      return first.time;
    }
  }
  return null;
}

function firstNumeric(rows, column) {
  for (const row of rows) {
    const value = toNumber(row[column]);
    if (value !== null) return value;
  }
  return null;
}

function analyze() {
  state.pvmAutoEndpoint = detectPvmEndpoint(state.pvmRows);
  state.ramanAutoEndpoint = detectRamanEndpoint(state.pvmRows);
  state.pvmEndpoint = firstNumeric(state.pvmRows, "endpoint_min") ?? state.pvmAutoEndpoint;
  state.ramanEndpoint = firstNumeric(state.pvmRows, "raman_endpoint_min") ?? state.ramanAutoEndpoint;
}

function setMessage(message, type = "info") {
  const box = document.querySelector("#messageBox");
  box.textContent = message;
  box.dataset.type = type;
}

function resizeCanvas(canvas) {
  const rect = canvas.getBoundingClientRect();
  const dpr = window.devicePixelRatio || 1;
  canvas.width = Math.max(640, Math.floor(rect.width * dpr));
  canvas.height = Math.max(360, Math.floor(rect.height * dpr));
  const context = canvas.getContext("2d");
  context.setTransform(dpr, 0, 0, dpr, 0, 0);
  return { context, width: rect.width, height: rect.height };
}

function drawAxes(context, width, height, options = {}) {
  const pad = { left: 58, right: 28, top: 28, bottom: 44, ...options.pad };
  context.clearRect(0, 0, width, height);
  context.fillStyle = "#ffffff";
  context.fillRect(0, 0, width, height);
  context.strokeStyle = "#d8dee8";
  context.lineWidth = 1;
  context.fillStyle = "#64748b";
  context.font = "12px Inter, Microsoft YaHei, sans-serif";

  for (let i = 0; i <= 5; i += 1) {
    const y = pad.top + ((height - pad.top - pad.bottom) * i) / 5;
    context.beginPath();
    context.moveTo(pad.left, y);
    context.lineTo(width - pad.right, y);
    context.stroke();
  }

  return {
    pad,
    plotWidth: width - pad.left - pad.right,
    plotHeight: height - pad.top - pad.bottom,
  };
}

function drawLine(context, points, color, mapX, mapY, width = 2.5) {
  context.strokeStyle = color;
  context.lineWidth = width;
  context.beginPath();
  points.forEach((point, index) => {
    if (index === 0) context.moveTo(mapX(point.x), mapY(point.y));
    else context.lineTo(mapX(point.x), mapY(point.y));
  });
  context.stroke();
}

function drawEndpointLine(context, endpoint, color, label, minTime, maxTime, mapX, pad, height) {
  if (endpoint === null) return;
  const x = mapX((endpoint - minTime) / Math.max(1, maxTime - minTime));
  context.strokeStyle = color;
  context.lineWidth = 2;
  context.setLineDash([6, 6]);
  context.beginPath();
  context.moveTo(x, pad.top);
  context.lineTo(x, height - pad.bottom);
  context.stroke();
  context.setLineDash([]);
  context.fillStyle = color;
  context.font = "700 13px Inter, Microsoft YaHei, sans-serif";
  context.fillText(`${label}: ${endpoint} min`, x + 8, pad.top + 18);
}

function drawOverviewChart(canvas) {
  const rows = state.pvmRows;
  if (!rows.length) return;
  const { context, width, height } = resizeCanvas(canvas);
  const { pad, plotWidth, plotHeight } = drawAxes(context, width, height);
  const times = rows.map((row) => toNumber(row.time_min)).filter(Number.isFinite);
  const minTime = Math.min(...times);
  const maxTime = Math.max(...times);
  const ramanValues = rows.map((row) => toNumber(row.intensity_1624)).filter(Number.isFinite);
  const minRaman = Math.min(...ramanValues);
  const maxRaman = Math.max(...ramanValues);

  const mapX = (value) => pad.left + value * plotWidth;
  const mapY = (value) => pad.top + (1 - value) * plotHeight;
  const pvmPoints = rows.map((row) => ({
    x: (toNumber(row.time_min) - minTime) / Math.max(1, maxTime - minTime),
    y: toNumber(row.block_frequency) ?? 0,
  }));
  const ramanPoints = rows.map((row) => ({
    x: (toNumber(row.time_min) - minTime) / Math.max(1, maxTime - minTime),
    y: ((toNumber(row.intensity_1624) ?? minRaman) - minRaman) / Math.max(1, maxRaman - minRaman),
  }));

  drawLine(context, pvmPoints, "#0f8f72", mapX, mapY);
  drawLine(context, ramanPoints, "#2563eb", mapX, mapY);
  drawEndpointLine(context, state.pvmEndpoint, "#be3455", "图像终点", minTime, maxTime, mapX, pad, height);
  drawEndpointLine(context, state.ramanEndpoint, "#c77700", "Raman 终点", minTime, maxTime, mapX, pad, height);

  context.fillStyle = "#18212f";
  context.font = "700 13px Inter, Microsoft YaHei, sans-serif";
  context.fillText("绿色：block_frequency；蓝色：归一化 Raman 1624 cm^-1", pad.left, height - 14);
}

function drawPvmChart(canvas) {
  const rows = state.pvmRows;
  if (!rows.length) return;
  const { context, width, height } = resizeCanvas(canvas);
  const { pad, plotWidth, plotHeight } = drawAxes(context, width, height);
  const times = rows.map((row) => toNumber(row.time_min)).filter(Number.isFinite);
  const minTime = Math.min(...times);
  const maxTime = Math.max(...times);
  const mapX = (value) => pad.left + value * plotWidth;
  const mapY = (value) => pad.top + (1 - value) * plotHeight;

  drawLine(
    context,
    rows.map((row) => ({
      x: (toNumber(row.time_min) - minTime) / Math.max(1, maxTime - minTime),
      y: toNumber(row.block_frequency) ?? 0,
    })),
    "#0f8f72",
    mapX,
    mapY,
    3,
  );

  const threshold = firstNumeric(rows, "threshold") ?? 0.12;
  context.strokeStyle = "#be3455";
  context.lineWidth = 2;
  context.setLineDash([8, 6]);
  context.beginPath();
  context.moveTo(pad.left, mapY(threshold));
  context.lineTo(width - pad.right, mapY(threshold));
  context.stroke();
  context.setLineDash([]);
  drawEndpointLine(context, state.pvmEndpoint, "#be3455", "图像终点", minTime, maxTime, mapX, pad, height);
}

function drawSlmChart(canvas) {
  const rows = state.slmRows;
  if (!rows.length) return;
  const { context, width, height } = resizeCanvas(canvas);
  const { pad, plotWidth, plotHeight } = drawAxes(context, width, height, { pad: { left: 68 } });
  const wavelengths = rows.map((row) => toNumber(row.wavelength_nm)).filter(Number.isFinite);
  const periods = rows.map((row) => toNumber(row.grating_period_px)).filter(Number.isFinite);
  const minWave = Math.min(...wavelengths);
  const maxWave = Math.max(...wavelengths);
  const maxPeriod = Math.max(...periods) * 1.12;
  const mapX = (value) => pad.left + value * plotWidth;
  const mapY = (value) => pad.top + (1 - value) * plotHeight;

  const points = rows.map((row) => ({
    x: ((toNumber(row.wavelength_nm) ?? minWave) - minWave) / Math.max(1, maxWave - minWave),
    y: (toNumber(row.grating_period_px) ?? 0) / maxPeriod,
  }));
  drawLine(context, points, "#2563eb", mapX, mapY, 3);

  context.fillStyle = "#0f8f72";
  points.forEach((point) => {
    context.beginPath();
    context.arc(mapX(point.x), mapY(point.y), 5, 0, Math.PI * 2);
    context.fill();
  });
  context.fillStyle = "#18212f";
  context.font = "700 13px Inter, Microsoft YaHei, sans-serif";
  context.fillText("横轴：wavelength_nm；纵轴：grating_period_px", pad.left, height - 14);
}

function renderMetrics() {
  const delta =
    state.pvmEndpoint !== null && state.ramanEndpoint !== null
      ? state.ramanEndpoint - state.pvmEndpoint
      : null;
  document.querySelector("#pvmEndpoint").textContent =
    state.pvmEndpoint === null ? "-- min" : `${state.pvmEndpoint} min`;
  document.querySelector("#ramanEndpoint").textContent =
    state.ramanEndpoint === null ? "-- min" : `${state.ramanEndpoint} min`;
  document.querySelector("#endpointDelta").textContent = delta === null ? "-- min" : `${delta} min`;
  document.querySelector("#dataStatus").textContent = "已加载";
  document.querySelector("#dataRows").textContent = `CSV: ${state.pvmRows.length} 行`;
  document.querySelector("#alignmentConclusion").textContent =
    delta === null
      ? "终点数据不足，无法完成图像-Raman 对齐。"
      : `图像终点为 ${state.pvmEndpoint} min，Raman 终点为 ${state.ramanEndpoint} min，二者相差 ${delta} min。`;
}

function renderPvmImages() {
  const container = document.querySelector("#pvmImages");
  const selected = state.pvmRows.filter((row, index) => row.image_path && index % 3 === 0).slice(0, 3);
  container.innerHTML = selected
    .map((row) => {
      return `<figure>
        <img src="./${row.image_path}" alt="PVM ${row.time_min} min 示例图" />
        <figcaption>${row.time_min} min，block_frequency=${row.block_frequency}</figcaption>
      </figure>`;
    })
    .join("");
}

function renderSlmList() {
  const container = document.querySelector("#slmList");
  container.innerHTML = state.slmRows
    .map((row) => {
      return `<article class="slm-item">
        <img src="./${row.image_path}" alt="${row.wavelength_nm} nm SLM 标定图" />
        <p><strong>${row.wavelength_nm} nm</strong>：灰度 ${row.gray_value}，周期 ${row.grating_period_px} px。</p>
        <p>${row.conclusion}</p>
      </article>`;
    })
    .join("");
}

function renderAll() {
  renderMetrics();
  renderPvmImages();
  renderSlmList();
  drawOverviewChart(charts.overview);
  drawPvmChart(charts.pvm);
  drawOverviewChart(charts.alignment);
  drawSlmChart(charts.slm);
}

async function loadExampleData() {
  try {
    const [pvmRows, slmRows] = await Promise.all([
      loadCsv("./data/example_pvm_raman.csv", REQUIRED_PVM_COLUMNS, "PVM/Raman CSV"),
      loadCsv("./data/example_slm.csv", REQUIRED_SLM_COLUMNS, "SLM CSV"),
    ]);
    state.pvmRows = pvmRows;
    state.slmRows = slmRows;
    analyze();
    renderAll();
    setMessage("示例数据已加载。可替换为真实 CSV，列名不匹配时页面会提示缺少字段。");
  } catch (error) {
    setMessage(error.message, "error");
  }
}

function exportSummary() {
  const summary = {
    pvm_endpoint_min: state.pvmEndpoint,
    pvm_auto_endpoint_min: state.pvmAutoEndpoint,
    raman_endpoint_min: state.ramanEndpoint,
    raman_auto_endpoint_min: state.ramanAutoEndpoint,
    endpoint_delta_min:
      state.pvmEndpoint !== null && state.ramanEndpoint !== null
        ? state.ramanEndpoint - state.pvmEndpoint
        : null,
    generated_at: new Date().toISOString(),
  };
  const blob = new Blob([JSON.stringify(summary, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = "endpoint-summary.json";
  link.click();
  URL.revokeObjectURL(url);
}

document.querySelectorAll(".tab").forEach((button) => {
  button.addEventListener("click", () => {
    document.querySelectorAll(".tab").forEach((tab) => tab.classList.remove("active"));
    document.querySelectorAll(".slide-panel").forEach((panel) => panel.classList.remove("active"));
    button.classList.add("active");
    document.querySelector(`#${button.dataset.tab}`).classList.add("active");
    renderAll();
  });
});

document.querySelector("#reloadExample").addEventListener("click", loadExampleData);
document.querySelector("#exportSummary").addEventListener("click", exportSummary);
document.querySelector("#pvmCsv").addEventListener("change", async (event) => {
  const file = event.target.files[0];
  if (!file) return;
  try {
    state.pvmRows = await readUploadedCsv(file, REQUIRED_PVM_COLUMNS, "PVM/Raman CSV");
    analyze();
    renderAll();
    setMessage(`已加载 ${file.name}`);
  } catch (error) {
    setMessage(error.message, "error");
  }
});
document.querySelector("#slmCsv").addEventListener("change", async (event) => {
  const file = event.target.files[0];
  if (!file) return;
  try {
    state.slmRows = await readUploadedCsv(file, REQUIRED_SLM_COLUMNS, "SLM CSV");
    renderAll();
    setMessage(`已加载 ${file.name}`);
  } catch (error) {
    setMessage(error.message, "error");
  }
});

window.addEventListener("resize", renderAll);
loadExampleData();
