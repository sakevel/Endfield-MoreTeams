# 自动化测试与验证

本项目包含完善的自动化测试套件（共 9 项 CTest 用例），用于覆盖核心模型、原生 UI 模拟、补丁契约及打包交付规范。

## 测试套件清单

| 测试名称 | 测试文件 | 覆盖内容 |
| :--- | :--- | :--- |
| **contract** | `tests/contract.cpp` | 验证 Lua 补丁规则与当前游戏原生脚本锚点的唯一性与完整性。 |
| **package_manifest** | `tests/package.py` | 验证打包白名单文件、`zml-package.json` 清单及图标规格（256×256 RGBA）。 |
| **behavior** | `tests/behavior.py` / `tests/behavior.lua` | 验证本地编队数据的编解码、序列化完整性、状态机流转与异常回滚。 |
| **marks_sheet** | `tests/marks.py` | 校验 15 个战术标记的 PNG 图集、Chunk CRC、RGB 单色遮罩与内嵌数据一致性。 |
| **native_adapter** | `tests/native.py` / `tests/native_scenarios.lua` | 校验 Native 适配器对游戏原生数据结构的读取、角色 ID 转换与网络状态反馈。 |
| **editor_scenarios** | `tests/editor_scenarios.lua` | 覆盖 5–20 队干员编辑、单人替换、空/满队限制与默认技能解析逻辑。 |
| **native_ui** | `tests/ui.py` / `tests/ui_scenarios.lua` | 模拟 UGUI 环境，验证 4×5 网格布局、层级恢复、弹窗安全区域与调色盘操作。 |
| **install_rollback** | `tests/install.py` | 验证模组解压安装、版本覆盖升级、历史配置备份及异常回滚。 |
| **public_services** | `tests/services.py` | 验证与 ZML 运行时环境的交互，包含日志上报与状态目录隔离。 |

---

## 运行测试

使用 CMake 和 CTest 执行全部测试套件：

```powershell
# 1. 配置构建目录
cmake -S . -B build -A x64

# 2. 编译项目 (Release 配置)
cmake --build build --config Release

# 3. 运行完整测试
ctest --test-dir build -C Release --output-on-failure
```
