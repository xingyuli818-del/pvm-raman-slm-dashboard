# 本地待办插件

一个纯前端、本地优先的待办清单页面。数据默认保存在浏览器 `localStorage`，不上传到网络。

## 功能

- 新建多个任务清单
- 添加任务、备注、截止日期、优先级
- 勾选完成事项
- 按全部、未完成、已完成筛选
- 删除任务、清空已完成
- 导出/导入 JSON 备份

## 运行

在项目根目录运行：

```powershell
python -m http.server 8000
```

打开：

```text
http://localhost:8000/todo-plugin/
```

也可以直接双击 `todo-plugin/index.html` 打开，但推荐用本地服务预览。
