const STORAGE_KEY = "local-todo-plugin-v1";

const defaultData = {
  activeListId: "today",
  filter: "all",
  lists: [
    {
      id: "today",
      name: "今日任务",
      tasks: [
        {
          id: "task-1",
          title: "整理 PVM/Raman 数据",
          note: "把 CSV 放到 data/，图像放到 figures/。",
          due: "",
          priority: "high",
          done: false,
          createdAt: new Date().toISOString(),
        },
        {
          id: "task-2",
          title: "检查本地 HTML 展示页",
          note: "运行 python -m http.server 8000 后打开页面。",
          due: "",
          priority: "normal",
          done: true,
          createdAt: new Date().toISOString(),
        },
      ],
    },
    {
      id: "meeting",
      name: "组会准备",
      tasks: [
        {
          id: "task-3",
          title: "列出本周实验结论",
          note: "重点写图像终点、Raman 终点和差值。",
          due: "",
          priority: "normal",
          done: false,
          createdAt: new Date().toISOString(),
        },
      ],
    },
  ],
};

let state = loadState();

const listForm = document.querySelector("#listForm");
const listName = document.querySelector("#listName");
const listNav = document.querySelector("#listNav");
const currentListTitle = document.querySelector("#currentListTitle");
const currentListLabel = document.querySelector("#currentListLabel");
const taskForm = document.querySelector("#taskForm");
const taskTitle = document.querySelector("#taskTitle");
const taskDue = document.querySelector("#taskDue");
const taskPriority = document.querySelector("#taskPriority");
const taskNote = document.querySelector("#taskNote");
const taskBoard = document.querySelector("#taskBoard");
const taskTemplate = document.querySelector("#taskTemplate");
const openCount = document.querySelector("#openCount");
const doneCount = document.querySelector("#doneCount");
const exportButton = document.querySelector("#exportButton");
const importFile = document.querySelector("#importFile");
const clearDoneButton = document.querySelector("#clearDoneButton");
const resetButton = document.querySelector("#resetButton");

function clone(value) {
  return JSON.parse(JSON.stringify(value));
}

function loadState() {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return clone(defaultData);
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed.lists) || !parsed.lists.length) return clone(defaultData);
    return parsed;
  } catch {
    return clone(defaultData);
  }
}

function saveState() {
  localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
}

function createId(prefix) {
  return `${prefix}-${Date.now()}-${Math.random().toString(16).slice(2)}`;
}

function getActiveList() {
  return state.lists.find((list) => list.id === state.activeListId) || state.lists[0];
}

function formatDate(value) {
  if (!value) return "无截止日期";
  const date = new Date(`${value}T00:00:00`);
  if (Number.isNaN(date.getTime())) return value;
  return date.toLocaleDateString("zh-CN", {
    month: "2-digit",
    day: "2-digit",
    weekday: "short",
  });
}

function priorityText(priority) {
  return {
    high: "重要",
    normal: "普通",
    low: "低优先级",
  }[priority || "normal"];
}

function taskMatchesFilter(task) {
  if (state.filter === "open") return !task.done;
  if (state.filter === "done") return task.done;
  return true;
}

function renderLists() {
  listNav.innerHTML = "";
  state.lists.forEach((list) => {
    const open = list.tasks.filter((task) => !task.done).length;
    const button = document.createElement("button");
    button.type = "button";
    button.className = `list-item${list.id === state.activeListId ? " active" : ""}`;
    button.innerHTML = `<span>${list.name}</span><span class="list-count">${open}</span>`;
    button.addEventListener("click", () => {
      state.activeListId = list.id;
      saveState();
      render();
    });
    listNav.append(button);
  });
}

function renderSummary() {
  const allTasks = state.lists.flatMap((list) => list.tasks);
  openCount.textContent = String(allTasks.filter((task) => !task.done).length);
  doneCount.textContent = String(allTasks.filter((task) => task.done).length);
}

function renderTasks() {
  const list = getActiveList();
  currentListTitle.textContent = list.name;
  currentListLabel.textContent = `${list.tasks.length} 项任务`;
  taskBoard.innerHTML = "";

  const visibleTasks = list.tasks.filter(taskMatchesFilter);
  if (!visibleTasks.length) {
    const empty = document.createElement("div");
    empty.className = "task-board-empty";
    empty.textContent = "当前筛选下没有任务。";
    taskBoard.append(empty);
    return;
  }

  visibleTasks.forEach((task) => {
    const node = taskTemplate.content.firstElementChild.cloneNode(true);
    const check = node.querySelector(".task-check");
    const titleInput = node.querySelector(".task-title-input");
    const noteInput = node.querySelector(".task-note-input");
    const badge = node.querySelector(".priority-badge");
    const due = node.querySelector(".due-text");
    const created = node.querySelector(".created-text");
    const remove = node.querySelector(".remove-task");

    node.classList.toggle("done", task.done);
    check.checked = task.done;
    titleInput.value = task.title;
    noteInput.value = task.note || "";
    badge.textContent = priorityText(task.priority);
    badge.className = `priority-badge priority-${task.priority || "normal"}`;
    due.textContent = `截止：${formatDate(task.due)}`;
    created.textContent = `创建：${new Date(task.createdAt).toLocaleDateString("zh-CN")}`;

    check.addEventListener("change", () => {
      task.done = check.checked;
      saveState();
      render();
    });

    titleInput.addEventListener("input", () => {
      task.title = titleInput.value.trim() || "未命名任务";
      saveState();
    });

    noteInput.addEventListener("input", () => {
      task.note = noteInput.value;
      saveState();
    });

    remove.addEventListener("click", () => {
      list.tasks = list.tasks.filter((item) => item.id !== task.id);
      saveState();
      render();
    });

    taskBoard.append(node);
  });
}

function renderFilters() {
  document.querySelectorAll(".segment").forEach((button) => {
    button.classList.toggle("active", button.dataset.filter === state.filter);
  });
}

function render() {
  renderLists();
  renderSummary();
  renderFilters();
  renderTasks();
}

function addList(name) {
  const trimmed = name.trim();
  if (!trimmed) return;
  const list = {
    id: createId("list"),
    name: trimmed,
    tasks: [],
  };
  state.lists.push(list);
  state.activeListId = list.id;
  saveState();
  render();
}

function addTask() {
  const list = getActiveList();
  const title = taskTitle.value.trim();
  if (!title) return;
  list.tasks.unshift({
    id: createId("task"),
    title,
    note: taskNote.value.trim(),
    due: taskDue.value,
    priority: taskPriority.value,
    done: false,
    createdAt: new Date().toISOString(),
  });
  taskForm.reset();
  taskPriority.value = "normal";
  saveState();
  render();
  taskTitle.focus();
}

function exportData() {
  const blob = new Blob([JSON.stringify(state, null, 2)], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const link = document.createElement("a");
  link.href = url;
  link.download = "todo-plugin-data.json";
  link.click();
  URL.revokeObjectURL(url);
}

function importData(file) {
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const parsed = JSON.parse(String(reader.result));
      if (!Array.isArray(parsed.lists) || !parsed.lists.length) {
        throw new Error("JSON 中没有有效清单。");
      }
      state = parsed;
      saveState();
      render();
    } catch (error) {
      alert(`导入失败：${error.message}`);
    }
  };
  reader.readAsText(file, "utf-8");
}

listForm.addEventListener("submit", (event) => {
  event.preventDefault();
  addList(listName.value);
  listName.value = "";
});

taskForm.addEventListener("submit", (event) => {
  event.preventDefault();
  addTask();
});

document.querySelectorAll(".segment").forEach((button) => {
  button.addEventListener("click", () => {
    state.filter = button.dataset.filter;
    saveState();
    render();
  });
});

clearDoneButton.addEventListener("click", () => {
  const list = getActiveList();
  list.tasks = list.tasks.filter((task) => !task.done);
  saveState();
  render();
});

resetButton.addEventListener("click", () => {
  state = clone(defaultData);
  saveState();
  render();
});

exportButton.addEventListener("click", exportData);

importFile.addEventListener("change", (event) => {
  const file = event.target.files[0];
  if (file) importData(file);
  importFile.value = "";
});

render();
