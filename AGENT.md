# DataHookClaws Agent Operating Context

## Mandatory Read Order For Every Future Agent Run

1. Read `/Users/zhouzhenghang/Desktop/DataHookClaws/AGENT.md`
2. Read `/Users/zhouzhenghang/Desktop/DataHookClaws/docs/PROJECT_PLAN.md`
3. If architecture detail is needed, read `/Users/zhouzhenghang/Desktop/DataHookClaws/docs/production_architecture_spec.md`

## Mandatory Update Rule

After every agent run that changes code, tests, architecture, importer coverage, or roadmap status:

1. Update this `AGENT.md`
2. Update `/Users/zhouzhenghang/Desktop/DataHookClaws/docs/PROJECT_PLAN.md` if plan status or sequencing changed
3. Record what was completed, what remains, and what verification was run

Latest run note:
- 2026-08-17：compare 回放与单位归一化回归门禁接入到 `tool/ci_checks.sh` 与 GitHub CI（非 CI 环境软降级，CI 环境 strict 失败）。
- 2026-08-17（继续）：`home_page.dart` 已补齐 compare 回放失败状态（Missing IDs / Retry / Draft）语义标注与 chip semanticsLabel；`tool/check_compare_accessibility.dart` 已补充重放恢复语义回归断言。
- 2026-08-17（继续）：`tool/ci_checks.sh` 进入更严格的 Flutter 二进制约束：当 `DHC_FLUTTER_BIN` 指向不可执行路径时直接失败（而非退回 PATH flutter），避免本地误配置下静默软跳过。
- 2026-08-17（继续）：新增 `tool/parse_compare_accessibility_report.dart`，把 compare 无障碍模板统计输出转为 CI 可解析指标；CI step 已接入该 parser，并补充阈值/严格模式环境变量（`DHC_A11Y_*`）。
- 2026-08-17（继续）：`tool/parse_compare_accessibility_report.dart` 已升级为 v1.0.1 契约解析器，补充 schemaVersion 严格校验、未知 severity bucket 告警与 summary payload 长度告警；同步更新 `docs/compare_replay_accessibility_ci_contract.md` 与模板版本。
- 2026-08-17（继续）：新增趋势治理预研脚本 `tool/analyze_compare_accessibility_trends.dart` 与
  [compare_replay_accessibility_trend_guide.md](docs/compare_replay_accessibility_trend_guide.md)，支持对 `COMPARE_REPLAY_A11Y_PARSED_JSON` 进行最近 N 次运行聚合。
- 2026-08-17（继续）：趋势治理脚本升级为 `--window-runs` 与 `--window-days` 双模式（支持时间戳驱动窗口 + 回退策略），并同步到 [README](README.md) 与
  [upgrade_queue.md](docs/upgrade_queue.md)。
- 2026-08-17（继续）：趋势治理工具补齐告警通道：`tool/analyze_compare_accessibility_trends.dart` 增加 `alerts` 结构化输出与阈值环境变量（schemaMismatch / unknownSeverity / pass/语义/可见率告警）；`tool/parse_compare_accessibility_report.dart` 注入 `runTimestampUtc` 以支持时间窗回放。
- 2026-08-17（继续）：趋势工具继续补强：新增首尾 `rateTrend` 输出（含 pass/phraseSuccess/semantics/liveRegion 的 first/last/delta/direction），用于后续窗口下滑告警研究与阈值化。
- 2026-08-17（继续）：趋势脚本完成告警执行闭环：新增 `maxDrop` 与 `maxConsecutiveDownRuns` 阈值化规则、`DHC_A11Y_TREND_*` 环境变量，以及 `DHC_A11Y_TREND_FAIL_ON_ALERTS`/`CI=true` 严格退出策略；已把趋势检查纳入 `.github/workflows/flutter-ci.yml` 与 `tool/ci_checks.sh`。
- 2026-08-17（继续）：趋势脚本再升级：增加趋势历史文件持久化参数（`--history-file`、`--history-max-entries`）与抖动抑制参数（`--trend-noise-window`），支持连续窗口重复度量后才阻断；`trendHistory` 与抑制元数据已写入趋势摘要。
- 2026-08-17（继续）：新增趋势看板脚本 `tool/build_compare_accessibility_trend_digest.dart`，支持基于 `trend_history.jsonl` 的日报/周报聚合与 `--regression-window` 稳定告警候选识别，并同步更新 trend guide / contract / project plan / upgrade queue。
- 2026-08-17（继续）：趋势看板继续补全文档契约：补齐 `DHC_A11Y_TREND_DASHBOARD_*` env alias、`dashboardMeta` 与 `stableAlertCandidates` 结构说明，并将“抖动窗口外复发率”研究任务写入升级队列。
- 2026-08-17（继续）：CI 与本地治理链路同步参数外置化：`tool/ci_checks.sh` / GitHub CI 的趋势看板调用已改为通过 `DHC_A11Y_TREND_DASHBOARD_*` 环境变量注入 `daily/weekly/regression` 约束，`tool/build_compare_accessibility_trend_digest.dart` 调用已改为 `--output-json` 输出。
- 2026-08-17（继续）：compare accessibility 门禁继续收敛：`tool/check_compare_accessibility.dart` 改为按语义 anchor 校验动态状态短语，补齐模板 `requiresLiveRegion` 声明并同步 `home_page.dart` compare replay chip 的 compare-scope live-region。
- 2026-08-17（继续）：通过 HOME/`DART_SUPPRESS_ANALYTICS` 离线构建路径，用 AOT 方式复核 compare 无障碍/趋势/看板三段闭环（均通过），并再次确认 `test/domain/ci_workflow_test.dart` 与 `tool/ci_checks.sh` 的严格失败传播与趋势链路断言不再出现静态歧义。
- 2026-08-17（继续）：新增离线复现说明与 `ci_workflow_test.dart` 的 `DART_CHECKS_HOME`/`HOME + DART_SUPPRESS_ANALYTICS` 保护校验，降低 hook 限制环境下的误报风险。
- 2026-08-17（继续）：补充 `README` AOT 重放文档为可复用变量化写法（`FLUTTER_DART_BIN`），并再次通过 AOT 编译链路实测 compare 无障碍与趋势闭环通过。
- 2026-08-17（继续）：修复 `tool/analyze_compare_accessibility_trends.dart` 在 `--help` 场景下的非交互环境返回码问题（新增显式 help 标志），并同步收敛 `test/domain/ci_workflow_test.dart` 中相关断言前置判断。
- 2026-08-17（继续）：收敛 `tool/check_compare_accessibility.dart` 的语义锚点映射，补齐“retry-limit / 重建提示”动态短语到 `Text(_exportStatusMessage!)` 的静态检测路径，避免 compare 可访问性快照中的动态短语因位置偏移产生误报。
- 2026-08-17（继续）：补齐 compare 提醒行为会话漏斗研究闭环，新增 `tool/analyze_compare_replay_prompt_funnel.dart` 与
  `test/domain/analyze_compare_replay_prompt_funnel_test.dart`，用于按 `scopeKey + promptSessionIndex` 聚合
  `urgent_prompt` 提示触发与抑制行为，并完成对应回归验证。
- 2026-08-17（继续）：把 compare replay prompt 漏斗检查接入 `tool/ci_checks.sh` 与 GitHub CI，新增 `tool/fixtures/compare_replay_prompt_funnel_trace.json`；
  workflow 与本地 wrapper 均包含 `tool/analyze_compare_replay_prompt_funnel.dart --output-json`，并在
  `test/domain/ci_workflow_test.dart` 新增闭环断言；当前环境下 `tool/ci_checks.sh` 包含该步骤并通过。
- 2026-08-17（继续）：继续收敛 compare 提醒漏斗脚本：
  - 删除 session summary 冗余 `scope` 字段，仅保留 `scopeKey + promptSessionIndex` 作为聚合口径；
  - 增补缺失输入文件/负载超长失败场景的本地单测；
  - 使用 `HOME=/tmp/dhc_dart_home`、`DART_SUPPRESS_ANALYTICS=true` 后，`dart analyze/format` 已通过静态检查（当前沙箱仍受 sqlite3 hook 与权限限制，无法在该环境完成运行时闭环）。
- 2026-08-17（继续）：`tool/ci_checks.sh` 已改为在本地离线环境下通过最小 `--packages` 配置文件运行 compare 门禁脚本（`dart --packages=<config>`），并成功跑通 compare 无障碍、趋势治理与 prompt 漏斗闭环；同时保留 CI/force 条件下的严格失败传播。
- 2026-08-17（继续）：CI workflow compare 阶段也同步到 `dart --packages` 离线路径（新增临时 package config，`HOME=/tmp/dhc_dart_checks_home` + `DART_SUPPRESS_ANALYTICS=true`），并将本地 `tool/ci_checks.sh` 与 workflow 的 compare 命令形态对齐以降低环境漂移。
- 2026-08-17（继续）：将 `test/domain/ci_workflow_test.dart` 与 `test/domain/analyze_compare_replay_prompt_funnel_test.dart` 中的工具 CLI 断言从 `dart run` 改为直接调用 Dart 二进制（`DHC_DART_BIN`/`DART_BIN` + 脚本文件路径），并在 `HOME=/tmp/dhc_dart_checks_home` + `DART_SUPPRESS_ANALYTICS=true` 下复核帮助/异常路径；本地直接命令验证 `help` 脚本输出通道正常。
- 2026-08-17（继续）：进一步补强上述测试链路健壮性：`runDartTool` 增加 `ProcessException` 降级返回，加入失败原因断言；并将 workflow 关键命令断言从逐行缩进匹配改为关键片段包含匹配，降低 CI 脚本排版变动引起的脆弱性。
- 2026-08-17（继续）：新增 `runDartTool` AOT 回退分支：当脚本执行命中 `sqlite3` build hook/network 或 telemetry 文件系统阻断时，测试内先 `dart run` 再自动降级为 `dart compile exe` + 二进制执行，确保在离线受限环境也能完成 `--help`/负样本回归断言验证。
- 2026-08-17（继续）：补充 `ci_workflow_test.dart` AOT 回退可观测性测试：在本地 `Process.runSync` 前置报错（模拟 build-hook 失败文本）时，验证回退分支仍按脚本退出码返回，避免假阳性隐性掩盖。
- 2026-08-17（继续）：补充 CI 严格模式门禁回归：`test/domain/ci_workflow_test.dart` 增加 DART/FLUTTER 二进制失效场景（含 CI=true 场景）回归，并使用临时目录隔离创建失败路径，覆盖 `ci_checks.sh` fail-fast 关键路径。
- 2026-08-17（继续）：修复 `tool/check_compare_accessibility.dart` 的语义锚点漂移，新增 export 状态短语到 `Export status message:` 容器的映射并补充 host fallback（`Text(_exportStatusMessage!)` 旧锚点下线），减少“动态短语 + 渲染容器不同步”导致的假失败；当前离线沙箱仍因 Flutter SDK 缓存写权限触发 `update_engine_version` 权限错误，无法直接重放闭环。
- 2026-08-17（继续）：修复 `tool/check_compare_accessibility.dart` 的 null-aware 集合字面量 lint，完成 `dart analyze` 清零；在离线最小 packages 配置下复核了
  `check_compare_accessibility -> parse -> 趋势 -> 看板` 四阶段闭环，均通过（无 exit=1）。
- 2026-08-17（继续）：修复 `tool/ci_checks.sh` 在 `run_local_dart_check` 的 set -u 下对空参数和空参数数组展开的未绑定变量风险，新增 guard 并使用可空展开写法；在非 CI 模式下本地脚本复核通过（`draft cleanup`/unit/accessibility/trend/prompt funnel 全链路均可运行），并保留 CI/force 下严格失败传播行为。
- 2026-08-17（继续）：`tool/ci_checks.sh` 新增 Flutter 命令解析链（`DHC_FLUTTER_BIN`/`DHC_DART_BIN` 反推），通过 `FLUTTER_CMD` 统一调度，避免 PATH 未含 `flutter` 时只出现 command-not-found 的 false-skip；同时保留原有软跳过与 CI 严格策略。
- 2026-08-17（继续）：修正 `tool/ci_checks.sh` 的 Flutter 严格触发条件，使 `DHC_FORCE_DART_CHECKS` 不再联动 Flutter 步骤；非 CI 下 Flutter 缺失仅在 `DHC_FORCE_FLUTTER_CHECKS` 或 CI 时阻断，保持 Dart 强制检查与 Flutter 可执行性检查的职责分离。
- 2026-08-17（继续）：进一步收紧 `tool/ci_checks.sh`：`DART_BIN` 与 `flutter` 命令都改为显式 `-x` 可执行性校验；补充 `ci_workflow_test.dart` 对“`DART_BIN` 存在但不可执行”场景的 fail-fast 回归覆盖。
- 2026-08-17（继续）：修复 `tool/check_compare_accessibility.dart` 的语义锚点对齐缺口：动态 `compare` 状态短语（如 `Compare replay unavailable / still missing after / Unavailable (manual rebuild required)`）改用语义 host 映射到 `Export status message:`，避免模板短语因 `Text(_exportStatusMessage!)` 位置漂移导致的静态误报。
- 2026-08-17（继续）：继续收敛文档执行链路可复现性，将 compare 无障碍/趋势脚本的本地手工验证示例统一改为显式 `DART_BIN`/`FLUTTER_DART_BIN` 路径驱动，避免 PATH 漏洞。
- 2026-08-17（继续）：补齐 `docs/compare_replay_accessibility_trend_guide.md` 命令示例与实际 CLI 参数映射（`--max-recurrence-count` / `--max-absence-runs`），并补充 env/CLI 等价阐述，降低本地 trend 复验误配置风险。
- 2026-08-17（继续）：清理 trend guide 文档中 `maxConsecutive` 命名误差：将复发抖动文档表述统一为 `maxConsecutiveDownRuns`，并明确阈值变量 `DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS`。
- 2026-08-26：补齐 compare 单位归一化门禁 fixture 外置路径：`tool/ci_checks.sh` 与 GitHub CI 均支持 `DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE`（带默认 `tool/fixtures/compare_unit_normalization_cases.json`），并在 `test/domain/ci_workflow_test.dart` 增加静态一致性断言。
- 2026-08-26（继续）：补齐同轮测试闭环：新增 `compare unit smoke check honors override fixture path`，验证 `check_compare_unit_normalization.dart` 在 CI 测试环境可通过 `DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE` 自定义样例；并在 `README` / `docs/compare_unit_normalization_release_checklist.md` 明确该变量与默认路径约定。
- 2026-08-26（继续）：补充 `compare unit smoke check falls back when custom fixture path is missing`，验证 `DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE` 指向缺失文件时脚本自动回退到内置默认用例并可通过。
- 2026-08-26（继续）：修正上述回退测试：`Normalization fixture not found` 在脚本 `stderr` 输出，`ci_workflow_test.dart` 断言已改为从 `stderr` 读取该提示，避免流方向误判。
- 2026-08-30：收紧 compare 单位 fixture 加载边界：JSON 解码/文件读取错误、非对象数组项与零用例 fixture 现在统一输出 stderr 诊断并回退到内置回归集；`ci_workflow_test.dart` 新增三类运行时回归，避免损坏 fixture 崩溃或静默丢样例。
- 2026-08-30（继续）：修复 compare 草稿提醒 `promptInstanceId` 的时间戳插值错误，ID 现由 scope + 已求值毫秒时间 + `promptSessionIndex` 组成；同步增加源码回归，避免 `$DateTime.now()` 被当作字面尾缀。
- 2026-08-30（继续）：修复 prompt funnel 人类可读汇总的 action 词表漂移：`deferred` 统一统计 `remind_later` / `dismissed_by_user` / `dismissed_no_action`，`clearNow` 读取 `clear_from_prompt`，并用真实 snake_case trace 回归覆盖。
- 2026-08-30（继续）：统一 compare 方差与极值高亮的 1e-6 容差来源，移除精确 `double.toSet()` 去重；空单位现在明确标记为 `(empty unit)` 的 non-comparable mismatch，避免显示“aligned and comparable”。
- 2026-08-30（继续）：GitHub workflow 显式把 repository variable `DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE` 映射到 job 环境，远端覆盖路径不再只停留在未注入的 shell 变量约定。
- 2026-08-30（验证）：`flutter analyze` 通过；`flutter test` 全量 132 项通过；`CI=true ./tool/ci_checks.sh` 严格全链通过（含 analyze、全量/目标 importer 测试、compare 门禁、prompt funnel 与 Web build）。
- 2026-08-30（继续）：Operations `Data quality review` 新增严重度 × issue type 的持久化组合筛选、可见/已加载计数与清除入口；筛选配置以 versioned JSON 写入 `app_meta.merge_review_filter_v1`，损坏/未知 schema 或枚举值 fail-open 到 All，快速连续修改按顺序落盘。筛选范围明确限定为 repository 已加载的最近 100 条 issue；新增纯模型与重建恢复/非法配置 widget 回归，并将 review card 操作区改为窄屏可换行布局。
- 2026-08-30（Operations filter 验证）：目标模型/widget 测试 7 项通过，`flutter analyze` 0 issue，`flutter test` 全量 138 项通过，`CI=true ./tool/ci_checks.sh` 严格全链通过（含目标 importer、compare 门禁与 Web build）。
- 2026-08-30（继续）：新增共享 `ActivityTraceStore`，Home/Operations 对 `activity_trace_v1` 的 load/append/clear 现在按同一 repository 实例串行执行，避免并发 read-modify-write 丢事件；成功写入广播最新快照给后台 Home，写失败不污染后续队列或主操作。损坏/超长 payload fail-open、无效 map 先过滤再计入 12 条窗口、超大新事件保留可编码旧历史；并发/广播/清除排序/失败恢复/尺寸压缩目标回归 11 项通过，页面目标回归合计 21 项通过，`flutter analyze` 0 issue。
- 2026-08-30（ActivityTraceStore 验证）：`flutter test` 全量 149 项通过；`CI=true ./tool/ci_checks.sh` 严格全链通过，覆盖 analyze、全量/目标 importer、compare draft/unit/accessibility/parser/trend/dashboard/prompt-funnel 与 Web build。
- 2026-08-30（继续）：MergeReview 筛选/分页下沉到 `FoodRepository.queryMergeReviewIssues`；Memory/SQLite 都在完整派生 issue 集合上按 `createdAt DESC, id ASC` 稳定排序，先执行严重度 × type AND 筛选，再计算总数/匹配数并应用 offset/limit。Operations 以 100 条为一页提供 Previous/Next，筛选可命中旧版首 100 条窗口之外的 issue；旧 `getMergeReviewIssues(limit:)` 保留兼容，`limit: 0` 仍返回空列表。
- 2026-08-30（MergeReview repository query 边界）：当前 SQLite 路径仍会完整物化 backlog，且 review 页面筛选/翻页仍触发 Operations 全量刷新；这轮保证语义与可达性，不宣称 SQL-native 性能或跨查询事务快照。后续优先拆分 review-only refresh，并批量/事务化 SQLite 派生读取。
- 2026-08-30（MergeReview repository query 验证）：模型、Memory、SQLite 与 Operations widget 定向回归通过；`flutter analyze` 0 issue，`flutter test` 全量 156 项通过，`CI=true ./tool/ci_checks.sh` 严格全链通过（含 14 项 source importer、compare 门禁与 Web build）。
- 2026-08-30（继续）：Operations 将 review 筛选/翻页改为 `_refreshReviewPage()` 局部读取，不再重复 jobs/artifacts/logs/exports/governance/budget 全链；工具栏刷新和会改变数据的治理/import 操作仍保留全量 `_refresh()`。review lane 使用独立 generation、内联 loading/error 与同查询 Retry，旧请求晚返回不会覆盖新筛选，等待期间分页器禁用，失败请求仍可按原 filter/offset 重试且不会覆盖上方 operation status。
- 2026-08-30（review-only refresh 边界）：这轮只隔离交互型筛选/翻页；初始化、工具栏和治理动作的全量 refresh 仍把 review 查询放在统一 try 中，SQLite review 派生也仍是完整物化。后续再拆分首次/全量加载的 operations 与 review 错误域，并优化 SQLite 批量读取。
- 2026-08-30（review-only refresh 验证）：Operations 专项 10 项通过，覆盖无关读取计数、工具栏全量读取、乱序响应、loading 分页禁用、内联失败与同 offset 重试；`flutter analyze` 0 issue，`flutter test` 全量 160 项通过，严格 CI、14 项 source importer、compare 门禁与 Web build 全部通过。
- 2026-08-30（继续）：Operations 全量刷新改为并行、独立 generation 的 operations/review 双 lane；任一读取失败只显示本区内联错误/Retry，另一 lane 的成功快照仍可提交。首次 Operations 尝试结束后，后续刷新保留旧内容并显示顶部线性进度，不再整页闪回 spinner；action status 与 refresh error 分离，读取失败不会覆盖已完成治理动作的结果文本。
- 2026-08-30（动作刷新路由）：retry/re-prepare 始终双 lane 刷新；artifact soft-remove 仅刷新 operations；merge/split/override 仅成功后双刷新，失败直接渲染状态；share 不再做无效 repository 重读。所有动作状态经 mounted-safe `_setStatus` 立即 repaint，retry 初始/失败 job 写入与 artifact 写入错误也不再泄漏为未处理 callback Future。
- 2026-08-30（双 lane 验证）：Operations 专项 13 项通过，包含首次/工具栏的双向部分失败；`flutter analyze` 0 issue，`flutter test` 全量 163 项通过，严格 CI、14 项 source importer、compare 门禁与 Web build 全部通过。
- 2026-08-30（继续）：SQLite MergeReview 派生从 `getAllFoods()` 后逐条 `getFoodDetails()` 的 N+1 路径改为单一 read transaction 内的批量快照；eligible root 保持 `foods INNER JOIN canonical_food` 旧语义，source/alias/nutrient/observation/audit/candidate 均用零动态占位符 join 在 SQL 层排除孤儿行。logger 回归确认数据量从 2 扩到 32 条时仍固定 8 次 SELECT，且全部共享同一非空 transaction ID。
- 2026-08-30（SQLite review 确定性/规模边界）：重复 merge audit 统一按 `created_at DESC, id DESC` first-wins；source/alias/observation 读取补齐稳定 tie-break。1005 个 canonical/source/audit/candidate fixture 可筛选分页且不会触发 SQLite 变量上限。当前仍在 Dart 内完整物化 FoodDetails/issue backlog 后筛选分页，不宣称 SQL-native filter pushdown 或常量内存。
- 2026-08-30（SQLite bulk review 验证）：bulk 与旧逐食物 hydration oracle 的完整 issue 签名、四类 issue、filter/page/count 一致；专项 17 项通过，`flutter analyze` 0 issue，`flutter test` 全量 167 项通过，`CI=true ./tool/ci_checks.sh` 严格全链、14 项 source importer、compare 门禁与 Web build 全部通过。
- 2026-08-30（继续）：Operations `Data quality review` 新增命名保存视图，可保存当前非 All 严重度/type 组合、应用或删除；视图以 versioned JSON 独立写入 `app_meta.merge_review_saved_views_v1`，不会覆盖当前活动筛选键。名称去首尾/折叠空白且最长 80 字符；同名（忽略大小写）保存视为更新并保留 id/createdAt，最多 12 项，按 updatedAt/name/id 确定性排序。
- 2026-08-30（保存视图交互/可靠性）：加载活动筛选与视图列表使用独立失败域；应用视图复用 review-only lane 并回到 offset 0，删除视图不改变当前筛选也不触发 repository review query。store 在同一 repository 对象上串行化写入，失败不毒化后续队列；损坏/未来 schema/超长 payload fail-open。保存对话框不持有跨 route 退出的 controller，避免关闭期间 use-after-dispose。
- 2026-08-30（保存视图边界/验证）：队列只覆盖同 isolate、同 repository 对象；独立 wrapper/进程仍是 last-writer-wins。当前不含重命名、导出/共享或批量治理动作。模型/store/Operations 定向 36 项通过，`flutter analyze` 0 issue，`flutter test` 全量 187 项通过，`CI=true ./tool/ci_checks.sh` 严格全链、14 项 source importer、compare 门禁与 Web build 全部通过。
- 2026-08-30（继续）：Operations MergeReview 新增当前可见页选择基础：每张 issue card 有独立 Checkbox，筛选卡提供 `Select visible`、live-region 选择计数与 `Clear selection`。选择只存在页面内存，不读写 repository/app_meta；筛选、翻页和应用保存视图会同步清空，同一保存视图重复应用也只清选择、不重查。
- 2026-08-30（选择刷新/竞态）：同 filter + 同实际 offset 的最新成功刷新只保留新页仍可见的 selected IDs；自动 offset 纠正视为换页并清空。失败/过期响应不修剪；加载期间逐卡与 Select visible 禁用，但 Clear 保持可用，所有 mutation 方法另有 current-results/loading 守卫。
- 2026-08-30（当前页选择边界/验证）：当前能力不包含跨页/全匹配选择、重启持久化、状态队列或任何批量 merge/split/override。`MergeReviewIssue.id` 是运行时派生字符串，并非数据库主键且尚不能保证不碰撞；真实批量写入前必须建立 versioned 结构化唯一身份并执行目标重验。Operations 专项 21 项、`flutter analyze` 0 issue、`flutter test` 全量 191 项通过；严格 CI、14 项 source importer、compare 门禁与 Web build 全部通过。
- 2026-08-30（继续）：生成型 MergeReview issue ID 切换为 `MergeReviewIssueIdentity` v1：`merge-review-issue:` 前缀 + unpadded base64url canonical JSON，严格 decoder 校验 exact keys/schema/type/枚举/必填字段并以 re-encode 拒绝非规范表示。type wire token 由显式 switch 冻结，不直接把未来 enum 重命名当作协议变更。
- 2026-08-30（identity 语义/去重）：low-confidence reuse 与 created-with-candidates 使用 source + type + `audit`；category conflict 再加入 candidate canonical ID；nutrient variance 使用 canonical + type + exact nutrient label，并刻意把 first observation source 排除出身份。reason、candidateSummary、数值/单位、source display name、observation order 和时间不参与身份。同一逻辑 ID 的重复派生按 severity、最新时间、ID、reason、summary、suggested target 固定排序后只保留首项。
- 2026-08-30（identity 边界/验证）：这是可解析的逻辑派生身份，仍不是数据库 PK、target revision 或幂等执行令牌；source 移动、candidate/nutrient 维度改变或 schema 升级会换 ID。旧 activity trace/governance note 中的拼接 ID 保留原值且不能自动与 v1 join，同时间戳分页 tie-break 发生一次性 cutover。codec/生成稳定性/营养碰撞/重复去重/Memory-SQLite 乱序 parity 定向 17 项通过，`flutter analyze` 0 issue，`flutter test` 全量 204 项通过；严格 CI、14 项 source importer、compare 门禁与 Web build 全部通过。

This rule is part of the project workflow and should be treated as required project maintenance.

## Project Definition

DataHookClaws is a Flutter/Dart app for building a local-first nutrition database from official national food composition sources. The working target is:

`an immediately usable, locally searchable, progressively enriched, provenance-first official nutrition database client`

The app is not intended to ship with a full world database preloaded. It is intended to:

- search local data first
- fetch official source data on demand
- continue background enrichment while the user is browsing
- archive normalized results into a reusable local database
- preserve provenance and exportability

## Current Operating Principles

- Local database is the primary user-facing data layer.
- Official source records are the source of truth.
- AI is assistive only. It may expand queries or suggest routing, but it must not invent nutrient facts.
- Canonical merge must be deterministic first. Do not replace it with AI merge without an explicit new phase.
- Legacy `foods` remains as the fast search snapshot model.
- Provenance tables remain the detailed source-tracking model.

## What Has Been Implemented So Far

### Foundation And Early Import Pipeline

- Created the Flutter app foundation and initial search/import workflow.
- Defined the project flow around:
  - source ingestion
  - normalization
  - persistence
  - search
  - UI presentation
- Established importer abstractions so each official source can be integrated separately.

### Persistence And Local Data Layer

- Replaced the original in-memory-only demo behavior with SQLite persistence.
- Added and stabilized a repository layer with both memory and SQLite implementations.
- Preserved legacy fast-read tables:
  - `foods`
  - `food_tags`
  - `nutrients`
  - `import_logs`
- Added provenance-oriented tables:
  - `canonical_food`
  - `source_record`
  - `nutrient_observation`
  - `food_alias`
  - `dataset_artifact`
  - `fetch_job`
  - `ai_suggestion_log`

### Import Logs And Operational Traceability

- Added import log storage and retrieval.
- Added import history UI on the home page.
- Made importer execution traceable by source, query, status, count, and timestamp.
- Added home-page action trace log (search/import/favorite/compare/export) with
  persistence in `app_meta` and immediate replay entry points.
- Extended governance operations path to append action-trace records from Operations
  (retry, merge, split, override, share export) into the same activity feed.
- Added a shared `ActivityTraceStore` for Home and Operations:
  - same-repository appends and clears are serialized across store instances
  - each append reads the latest persisted snapshot before writing
  - successful writes broadcast snapshots so a mounted Home reflects Operations events
  - malformed/oversized payloads fail open and invalid records do not consume retention slots
  - trace persistence failures are isolated from the primary user operation and do not poison later writes
- Serialization is same-isolate and keyed by repository object identity; separate repository wrappers or direct `activity_trace_v1` writes bypass this queue.

### Official Importers Implemented

- USDA FoodData Central importer
- Canada CNF CSV importer
- UK CoFID Excel importer
- Japan MEXT 2023 Excel importer
- Switzerland Excel importer
- France CIQUAL 2025 Excel importer
- Denmark Frida spreadsheet importer
- Australia AFCD multi-file Excel importer
- Germany BLS 4.0 Excel importer
- Italy CREA web portal importer

### Official Dataset Grabber Layer

- Added official dataset grabber infrastructure so importers can consume local prepared files while download logic stays separate.
- Implemented manifest-driven preparation for:
  - direct file downloads
  - zip packages
  - pre-expanded directories
- Current auto-prepared sources:
  - UK CoFID
  - Japan MEXT 2023
  - Canada CNF
- Switzerland
- France CIQUAL 2025
- Australia AFCD
- Current grabber-ready but importer-pending sources:
  - New Zealand FOODfiles, currently blocked by source terms

### National Source Catalog

- Refactored source governance into a national layered catalog.
- Sources are now organized by country/administrative entity instead of a flat list.
- Catalog distinguishes implemented sources from cataloged sources.
- National source catalog currently includes:
  - United States
  - Canada
  - United Kingdom
  - Japan
  - Australia
  - New Zealand
  - France
  - Finland
  - Denmark
  - Germany
  - Switzerland
  - Spain
  - Italy

### Importer Registry And Scaffold Layer

- Added a descriptor-driven importer registry so importer wiring and home-page source controls no longer rely on hardcoded per-country branches.
- Added a local importer expansion queue:
  - `tool/importer_expansion_queue.json`
- Added template-driven importer scaffold support:
  - `tool/importer_templates/`
  - `tool/scaffold_importer.dart`
- Added reusable scaffold logic in:
  - `lib/src/tooling/importer_scaffold.dart`
- This scaffold layer is intended to support temporary Codex automation that advances importer work one country at a time.

### Normalization Toolkit

- Built a reusable normalization pipeline instead of ad hoc importer-specific mapping.
- Split the normalization logic into modular subparts, including:
  - nutrient dictionary
  - category mapper
  - unit converter
  - label cleaning
  - alias key normalization
  - text normalization helpers
- Added tests for:
  - alias key normalization
  - unit conversion
  - label cleaning

### API And Search Layer

- Added API-facing DTOs and a service layer for search and details.
- Added reusable search indexing support.
- Added summary DTO and detail DTO separation.
- Preserved lightweight list behavior while enabling provenance-first detail reads.

### Query Expansion And Local AI Entry

- Added Ollama client integration targeting local `http://127.0.0.1:11434`
- Added `QueryExpansionService`
- AI is currently restricted to query expansion and source-hint assistance
- AI output is logged to `ai_suggestion_log`
- AI failure degrades silently to non-AI behavior

### Phase 0-1: Controlled Search Bus

- Added `SearchOrchestrator` as the main search entrypoint.
- Search now follows:
  - local query first
  - foreground fetch if budget rules allow
  - archive new results into the local database
- Added `FetchBudgetPlanner`
- Added `ForegroundFetchRunner`
- Search state now exposes:
  - `idle`
  - `local`
  - `fetching`
  - `archived`
  - `failed`
- Home page search was moved away from direct repository-only behavior into orchestrated search.

### Phase 2.5: Background Enrichment Queue

- Added session-local `BackgroundEnrichmentQueue`
- Added dwell-triggered enrichment after archived search results
- Added queue behaviors:
  - single concurrency
  - same-query deduplication
  - queued cancellation
  - graceful stop after current source when a new query supersedes an old one
- Background enrichment writes `fetch_job` records
- Results auto-refresh after successful enrichment writes
- Added lightweight background enrichment UI state card

### Phase 3: Provenance-First Read Chain

- Added provenance-first repository read interfaces:
  - `searchFoodSummaries`
  - `getFoodDetails`
- Added dedicated read models:
  - `FoodSummary`
  - `FoodDetails`
  - `SourceRecordView`
  - `NutrientObservationView`
- Added provenance detail DTOs
- Added clickable food cards and bottom-sheet detail presentation
- Detail panel now shows:
  - overview
  - aggregated nutrients
  - official sources
  - aliases

### Phase 4: Deterministic Canonical Merge

- Added `CanonicalMergeService`
- Canonical merge is currently deterministic and rule-based.
- Merge inputs are based on:
  - alias-normalized name
  - normalized category
  - normalized serving basis
- Nutrient similarity is used only as a secondary confirmation signal.
- Repository write paths now merge imported source records under shared canonical foods when rules match.
- `foods` now acts as a canonical snapshot table, not a per-source row table.
- Multi-source canonical snapshots now:
  - collapse duplicate search results
  - preserve multiple `source_record` entries
  - preserve `nutrient_observation` provenance
  - expand `food_alias`
- SQLite now has a lightweight canonical merge state marker and rebuild path for old source-as-canonical layouts.

### Phase 5: Merge Audit Surface And Explainability

- Extended deterministic merge so every merge decision now produces a full audit envelope, not just a final action.
- Added candidate-level evaluation output covering:
  - alias match
  - category match
  - serving match
  - nutrient similarity
  - accepted/rejected state
  - explicit reason
- Added persistent merge audit storage in SQLite:
  - `merge_audit`
  - `merge_audit_candidate`
- Added merge audit rebuild on open for existing databases that predate Phase 5.
- Extended provenance details so each `source_record` now carries source-level merge audit data.
- Extended API detail DTOs to expose merge audit fields.
- Extended `FoodDetailSheet` so each official source card now shows:
  - merge decision
  - matchedBy
  - confidence
  - reason
  - candidate review
- Added a canonical summary message in the detail sheet showing how many official source records are merged into the canonical entry.

### Phase L: More Official Sources

- Added `SwissFoodCompositionExcelImporter`
- Added `FranceCiqualExcelImporter`
- Added `DenmarkFridaExcelImporter`
- Added `AustraliaAfcdImporter`
- Kept both sources out of `FetchBudgetPlanner` foreground/background priorities for now so importer expansion does not silently increase search-time cost
- Refactored `HomePage` source controls to render from importer descriptors instead of four hardcoded importer cards
- Added importer parser and sync-flow tests for Switzerland, France, Denmark, and Australia
- Added scaffold tests for the importer queue/template layer
- Reviewed New Zealand FOODfiles Terms of Use and marked the NZ importer as blocked for the current architecture because the data must be presented in original and unaltered form
- Integrated Germany BLS 4.0 importer and Italy CREA web portal importer from the recent automation work
- Germany BLS reads the official workbook layout from a user-provided `.xlsx` path
- Italy CREA imports live search/detail records from the official AlimentiNUTrizione portal
- Added and verified Germany/Italy importer parser and sync-flow tests
- Marked Finland Fineli as blocked because the official open-data URL currently redirects to THL maintenance, preventing verification of the CSV package and current license path
- Advanced the actionable importer queue beyond CH/AU/FR/DK/DE/IT; remaining queued sources are blocked pending source-shape or license/product decisions

### Phase K: Export Layer

- Added a local file export service:
  - `FoodCatalogExportService`
- Added export models:
  - `ExportFormat`
  - `ExportDetailLevel`
  - `ExportArtifact`
- Implemented export targets:
  - search summary JSON
  - search detailed JSON
  - search summary CSV
  - search detailed CSV
  - SQLite snapshot copy
- Added country-slice export capability in the service layer.
- Added repository support for:
  - `searchFoodSummariesByCountry`
  - `copyDatabaseSnapshot`
- SQLite snapshot export now copies the active database file as-is, preserving provenance, merge audit, logs, and artifacts.
- Added a minimal export UI section on the home page.
- Export results now surface file path and record count in the UI.
- Export files are written into the app document directory under `exports/`.

### Phase M/P: Budget Governance And Operations Surface

- Added source capability governance:
  - `SourceCapabilityRegistry`
  - `SourceRoutingService`
- Automatic search-time routing is now constrained by source capability metadata instead of only hardcoded planner order.
- First automatic route remains limited to:
  - `usda`
  - `canada-cnf`
  - `uk-mccance`
  - `jp-standard`
- Switzerland, Australia, France, Denmark, Germany, Italy, Spain, and Finland remain outside automatic foreground/background routing unless a later phase explicitly enables them.
- New Zealand FOODfiles is now surfaced as `Blocked` rather than merely cataloged.
- Spain BEDCA is now surfaced as `Blocked` because the queued `single_excel` shape does not match the official public web/database access path and BEDCA reuse conditions require attribution plus preservation of original meaning.
- Finland Fineli is now surfaced as `Blocked` because the official open-data URL currently redirects to THL maintenance, so the CSV package and current license path cannot be verified.
- Added `StorageBudgetManager` with first-pass default budgets:
  - database: `512MB`
  - dataset artifacts: `2GB`
  - exports: `1GB`
  - cache/prepared downloads: `512MB`
- Added `ModelBudgetController` for Ollama query expansion:
  - maximum `6` calls per minute
  - `3s` timeout policy
  - `256` max predicted tokens
  - cooldown after model failures
  - fallback logging when the model is unavailable or budget-denied
- Extended repository operations support:
  - fetch job filtering by importer/status/phase/query
  - dataset artifact listing
  - artifact soft removal
  - storage path discovery
- Added an independent Operations page with:
  - fetch job inspection and retry for eligible automatic sources
  - dataset artifact inspection, soft removal, and re-prepare action
  - importer diagnostics
  - storage and model budget status
- Artifact removal is intentionally soft-delete only. Local files are not deleted.

### Phase O/P2: Data Quality Review And Observation-Level Search

- Added read-only data quality review support:
  - `MergeReviewIssue`
  - `MergeReviewIssueType`
  - `MergeReviewSeverity`
  - repository `getMergeReviewIssues`
  - repository `queryMergeReviewIssues` with `MergeReviewIssueQuery` / `MergeReviewIssuePage`
- Operations page now includes `Data quality review` for:
  - low-confidence canonical reuse
  - category-conflict candidates
  - created canonical records that had rejected candidates
  - multi-source nutrient variance
- Added a persisted Operations review filter workbench:
  - severity and issue type are combined with AND semantics
  - visible/loaded counts and a single clear action are exposed
  - `merge_review_filter_v1` stores schema-versioned enum names in `app_meta`
  - malformed, unsupported-schema, or unknown-enum payloads fail open to All
  - filtering is applied across the complete derived backlog before offset/limit paging
  - deterministic `createdAt DESC, id ASC` ordering and 100-item Previous/Next pages keep page boundaries stable
  - SQLite currently derives and materializes the complete issue set before paging; this is semantic repository pushdown, not yet SQL-native pagination
- Added advanced local search models:
  - `FoodSearchQuery`
  - `FoodSearchFilters`-style fields through query lists
  - `NutrientRangeFilter`
  - nutrient presets for protein, sodium, energy, fat, carbohydrate, and fiber
- Added repository advanced search interfaces:
  - `searchFoodsAdvanced`
  - `searchFoodSummariesAdvanced`
- Advanced search is local-only and does not trigger foreground fetch or background enrichment.
- Home page now has an `Advanced filters` panel for:
  - country
  - source/importer id
  - category
  - nutrient preset
  - min/max nutrient range
- Detail DTOs and `FoodDetailSheet` now expose `Nutrient source comparison` with:
  - aggregated snapshot value
  - per-source observation values
  - source name and country
  - variance status
- Alias and multilingual-friendly matching is strengthened by reusing normalization toolkit alias keys across advanced local search.

### Phase Q: Manual Data Governance Writeback

- Added controlled manual governance writeback for review issues.
- Added repository interfaces for:
  - manual source-record merge into an existing canonical food
  - manual source-record split into a new canonical food
  - manual canonical field override
  - manual governance log reads
- Added SQLite persistence for manual governance:
  - `manual_governance_log`
  - `manual_canonical_override`
- Manual merge/split actions update provenance ownership, refresh canonical snapshots, and write source-level merge audit entries with `matched_by='manual-governance'`.
- Manual canonical overrides are reapplied during snapshot refresh so later imports do not immediately erase curated display/category/country/description/serving fields.
- Operations `Data quality review` issue cards now expose manual actions:
  - merge suggested candidate
  - split source record
  - override canonical fields
  - open detail sheet
- Operations now includes a `Manual governance log` section for recent human actions.
- Memory and SQLite repositories both implement the writeback surface for tests and runtime parity.

### Phase N/R: AI Cautious Expansion And Production Engineering

- Added Settings persistence through SQLite `app_meta`:
  - `AppSettings`
  - `SettingsService`
  - configurable Ollama endpoint/model
  - configurable model call budget, timeout, and max tokens
  - configurable storage budgets
  - configurable export directory
  - source enabled/disabled map with blocked sources forced disabled
- Added a Settings page accessible from Home and Operations.
- `main.dart` now constructs Ollama, model budget, storage budget, export service, and automatic source routing from persisted settings.
- Added cautious AI suggestion services:
  - `SourceRoutingSuggestionService`
  - `MergeCandidateExplanationService`
  - `ExportSummaryService`
- AI suggestions remain non-authoritative:
  - no AI nutrient facts
  - no AI canonical-field overwrite
  - no AI merge decisions
  - all AI outputs continue to be logged in `ai_suggestion_log`
- Added persistent export history:
  - `export_history`
  - JSON/CSV/SQLite snapshot exports record path, format, detail level, record count, scope, status, and summary
- Added `share_plus`-backed export file sharing through `ExportShareService`.
- Home export card now exposes the latest export and Share action.
- Operations page now includes an Export history section.
- Added GitHub Actions CI:
  - `flutter analyze`
  - `flutter test`
  - targeted source importer tests
  - `flutter build web`
  - Web build artifact upload
- Added release packaging notes in `docs/release_packaging.md`.

### Public Repository Preparation

- Rewrote the public `README.md` in English for GitHub publication.
- Added repository governance and legal boundary files:
  - `LICENSE`
  - `NOTICE`
  - `CONTRIBUTING.md`
  - `SECURITY.md`
  - `CODE_OF_CONDUCT.md`
- The repository license covers project source code only. Official nutrition datasets, downloaded artifacts, trademarks, and source database rights remain governed by their respective official source terms.

## Current User-Facing Capabilities

- Local nutrition search
- Foreground official-source fetch on search
- Session-local background enrichment while browsing results
- Import history viewing
- Provenance detail bottom sheet
- Canonical search result deduplication across sources already merged
- Local persistence of imported data
- Merge audit explanation for each source record in detail view
- Operations data quality review
- Manual merge/split/override writeback from review issues
- Manual governance action log
- Advanced local filters and nutrient range search
- Nutrient source comparison in details
- Local JSON / CSV export
- Local SQLite snapshot export
- Settings page for model, storage, export, and source controls
- Export history and system share entry
- GitHub CI and Web artifact build workflow
- English public repository documentation and code-license boundary files

## Current Known Boundaries

- Canonical merge is deterministic by default. Manual merge/split/override writeback now exists, but AI still cannot make merge decisions.
- Background enrichment is session-local only. It does not survive app restart.
- Remote upload exports are not implemented.
- New Zealand is grabber-ready but blocked by source terms.
- Spain is blocked pending web/API and license review, and Finland is blocked while the official Fineli open-data path is under maintenance.
- Operations page is inspection-first. It does not include destructive cleanup.
- Manual governance is first-pass writeback only. It does not yet include undo/redo, batch approval, role-based authorization, or a dedicated conflict resolution workspace.
- Advanced nutrient filtering is local-only and does not trigger proactive source fetching.
- Settings changes that affect already-constructed runtime services are applied on next app start in the first implementation.

## Verification Status At Last Update

The latest completed verification after Phase 4 was:

- `flutter analyze` passed
- `flutter test` passed

The latest completed verification after Phase 5 was:

- `flutter test` passed
- `flutter analyze` passed

The latest completed verification after Phase K was:

- `flutter analyze` passed
- `flutter test` passed

The latest completed verification after Phase L France expansion was:

- `flutter analyze` passed
- `flutter test test/domain/source_importers_test.dart` passed
- `flutter test test/domain/official_dataset_grabber_test.dart` passed

The latest completed verification after Phase L Denmark expansion was:

- `flutter analyze` passed
- `flutter test test/domain/source_importers_test.dart` passed
- `flutter test` passed

The latest completed verification after Phase M/P budget and operations work was:

- `flutter analyze` passed
- `flutter test` passed

The latest completed verification after Phase O/P2 data quality and observation search work was:

- `flutter analyze` passed
- `flutter test` passed

The latest completed verification after Phase N/R AI cautious expansion and production engineering work was:

- `flutter analyze` passed
- `flutter test` passed
- `flutter test test/domain/source_importers_test.dart` passed
- `flutter build web` passed

The latest completed verification after Phase Q manual data governance writeback was:

- `flutter analyze` passed
- `flutter test test/domain/manual_governance_test.dart test/operations_page_test.dart` passed
- `flutter test` passed
- `flutter build web` passed

The latest completed repository publication preparation was:

- English `README.md` rewrite completed
- `LICENSE`, `NOTICE`, `CONTRIBUTING.md`, `SECURITY.md`, and `CODE_OF_CONDUCT.md` added
- pending final publish-time validation and GitHub push

## Next Recommended Focus

The next technically coherent phase is:

- Phase R+ goal-parity rollout (complete-app experience and workflow loop):
  - search-result favorites (MVP complete)
  - result comparison panel (MVP in progress)
  - session/task replay and behavior traceability
  - governance undo/redo groundwork planning

After that:

- governance undo/history detail and safer confirmation flows
- cross-page worklist inventory, revision/CAS revalidation, and controlled batch governance execution
- AI-assisted but non-authoritative review explanations

## Files That Matter Most Right Now

- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/search_orchestrator.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/background_enrichment_queue.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/canonical_merge_service.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/source_capability_registry.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/source_routing_service.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/storage_budget_manager.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/model_budget_controller.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/settings_service.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/ai_assist_services.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/domain/food_quality_service.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/data/sqlite_food_repository.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/data/memory_food_repository.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/models/manual_governance.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/features/home/home_page.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/features/operations/operations_page.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/lib/src/features/settings/settings_page.dart`
- `/Users/zhouzhenghang/Desktop/DataHookClaws/docs/PROJECT_PLAN.md`

## Update Log

### 2026-08-26

- 成功复现完整闭环验证（无需新改动）：
  - `flutter test test/domain/ci_workflow_test.dart --reporter compact` 通过
  - `CI=true ./tool/ci_checks.sh` 通过，覆盖 analyze / test / importer / compare accessibility / 趋势 / 漏斗 / web build 全链路
  - 无需再次修改趋势告警分离逻辑即可保持 `warning` 与 `strict` 分支行为正确分离。
- 继续把 queue 任务状态从「阻塞执行」收窄为「可复验通过」：`docs/upgrade_queue.md` 中
  `M4 比较营养单位归一化脚本执行` 标记为已完成；证据来自本轮 `ci_checks + ci_workflow_test` 的严格/降级双路径验证。
- 继续补齐 M4 compare 单位归一化边界样本（反例/空值/分母冲突），更新 `tool/check_compare_unit_normalization.dart` 与
  `test/domain/nutrient_comparison_units_test.dart`，并新增
  `docs/compare_unit_normalization_release_checklist.md` 作为发布复核清单。
- 本轮环境下，`DHC_FORCE_DART_CHECKS=true CI=false ./tool/ci_checks.sh` 通过（Flutter 阶段按策略软跳过，Dart 阶段严格通过）。

### 2026-08-17

- Began goal-aligned "complete-app parity" backlog updates for this goal.
- Expanded the upgrade queue with concrete M0 and high-priority UX closure tasks.
- Added research tasks for future upgrade candidates (competitive workflow study, persistence impact, quota/log-size sizing).
- Recorded a UTF-8 payload safety bound (`1048576`) for queue/audit text fields in goal docs.
- Implemented home-page favorites (persisted) and result comparison selection panel with lightweight nutrient diff list.
- Added a 3-item comparison workflow and synchronized queue/research notes for future parity upgrades.
- Confirmed compare-selection and favorites states are reconciled on each search refresh.
- Added home activity-trace action filtering with replay gating for non-safe governance actions.
- Added governance trace replay-idempotence and failure-recovery research item to `docs/upgrade_queue.md`.
- Added trace recovery-session research for search/import/favorite/compare replay (fingerprint, checkpointing, partial-commit recovery).
- Implemented home-page recent export recall chips to re-run exported-search queries directly.
- Marked "recent export recall" queue task completed and added replay-consistency research in `docs/upgrade_queue.md`.
- Extended recent export recall replay to preserve scope type (`search` / `country`) with deterministic replay entry behavior.
- Added Home-page clear-all control for recent export recall chips plus export action-trace entry for the operation.
- Persisted recent export recall chips in `app_meta` so clear-all survives app restart and added export-history seeding fallback from persisted memory.
- Added activity-trace temporal session grouping on Home (20-minute session windows) with session summary chips and session-level replay action for near-cycle task-loop review.

### Verification status for this run slice

- Full verification confirmed with elevated local environment: `flutter analyze` / `flutter test` / `tool/ci_checks.sh` all pass; `./tool/ci_checks.sh` also passes in strict mode (`CI=true`).
- `lib/src/features/home/home_page.dart` updated for replay session UX and behavior trace grouping.
- `flutter test test/domain/analyze_compare_replay_prompt_funnel_test.dart test/domain/ci_workflow_test.dart` passed after修复 `tool/analyze_compare_replay_prompt_funnel.dart` 的类型转换和 help 返回码问题。
- `tool/ci_checks.sh` 当前环境完整通过，且已包含 compare prompt funnel check 与 web 构建步骤（含 fixture 数据文件）。
- compare prompt 漏斗脚本 `tool/analyze_compare_replay_prompt_funnel.dart` 结构口径已统一（`scopeKey`），并补充了缺失文件/输出长度上限静态回归测试。
- `tool/ci_checks.sh` 本轮完成职责分离验证：`DHC_FORCE_DART_CHECKS` 仅约束 Dart 检查路径，Flutter 步骤改为仅受 `CI` / `DHC_FORCE_FLUTTER_CHECKS` 触发；通过 mock command 复核 non-CI/strict 组合分支和本地软跳过行为。
- 本轮补齐 `test/domain/ci_workflow_test.dart` 两个趋势治理边界回归用例（strict fail 与无有效行退出码），同时修复文件内 `runDartToolWithEnv` 调用顺序/导入问题，确认单文件用例全绿。
- 本次继续轮次额外修复：`test/domain/ci_workflow_test.dart` analyzer 信息项（`unnecessary_string_escapes`）并恢复 `flutter analyze` 零告警；该测试文件再次独立验证通过。
- 继续补齐 strict 边界覆盖：`ci_workflow_test.dart` 新增 CI=true 下 `DART_BIN` 缺失 fail-fast 用例，验证与本地环境对齐；该用例通过。
- 本次继续补齐 `ci_workflow_test.dart` 趋势告警边界：把趋势警告场景中的脚本调用显式 `CI=false`，确保“warning”路径不被 `ci_checks.sh` 的 strict 变量短路；非严格分支可继续通过且仅在 strict 分支验证阈值回退失败。
- 计划内验证更新：`CI=true ./tool/ci_checks.sh` 与 `flutter test test/domain/ci_workflow_test.dart` 的本地闭环均继续通过；本轮新增趋势告警模式分支被证实不再误触发严格失败。

### 2026-05-23

- Consolidated project history into `AGENT.md`
- Established mandatory future workflow:
  - always read `AGENT.md`
  - always read `docs/PROJECT_PLAN.md`
  - always update `AGENT.md` after meaningful agent work
- Implemented Phase 5 merge audit surface:
  - persistent merge audit tables
  - merge audit rebuild for existing DBs
  - detail/API merge explainability
  - Phase 5 tests and verification
- Implemented Phase K export layer:
  - local JSON / CSV exports
  - SQLite snapshot export
  - home-page export UI
  - export service and repository coverage
  - Phase K tests and verification

### 2026-05-24

- Implemented France CIQUAL 2025 importer
- Added direct CIQUAL workbook auto-grab wiring
- Fixed Excel numeric parsing so decimal-comma and `traces` / `< 0,2` values normalize correctly
- Added France importer parser and sync-flow tests
- Marked France as integrated and advanced the queue target to Denmark
- Implemented Denmark Frida importer
- Kept Denmark auto-download disabled because official dataset links are sent via the Frida form
- Added Denmark importer parser and sync-flow tests
- Marked Denmark as integrated and advanced the queue target to Germany
- Integrated Germany BLS 4.0 importer wiring and parser from the automation work
- Integrated the Italy CREA importer against the official AlimentiNUTrizione HTML search/detail portal
- Removed Germany scaffold placeholder leftovers after real source importer coverage was added to `source_importers_test.dart`
- Fixed Italy importer mocked response encoding so UTF-8 nutrient labels and units are testable
- Marked Germany and Italy queue items completed
- Implemented Phase M/P budget governance and operations surface
- Added source capability routing, storage/model budget controls, Operations page, artifact soft removal, and job retry support
- Marked New Zealand as explicitly blocked in source status and operations diagnostics
- Verified with `flutter analyze` and `flutter test`
- Implemented Phase O/P2 data quality review and observation-level search
- Added advanced local filters, nutrient range search, review issue derivation, and detail nutrient source comparison
- Verified with `flutter analyze` and `flutter test`
- Implemented Phase N/R AI cautious expansion and production engineering
- Added Settings persistence/page, source enable controls, export history, share support, cautious AI suggestion services, CI workflow, and release packaging notes
- Verified with `flutter analyze`, `flutter test`, targeted importer tests, and `flutter build web`
- Integrated the recent worktree automation outputs for Germany and Italy
- Verified with `flutter analyze`, `flutter test test/domain/source_importers_test.dart test/domain/it_crea_importer_test.dart`, `flutter test`, and `flutter build web`
- Implemented Phase Q manual data governance writeback
- Added manual source-record merge, source-record split, canonical override, manual governance logs, and Operations review actions
- Verified with `flutter analyze`, `flutter test test/domain/manual_governance_test.dart test/operations_page_test.dart`, `flutter test`, and `flutter build web`
- Prepared GitHub publication materials in English and added source-code license/governance files


## Recent upgrade note
- Implemented home-page recent-search persistence and replay using app_meta-backed query history chips to improve re-search flow.
- Added homepage favorites (collect/replay) and comparison-workspace slice in `home_page.dart`.
- Home activity-trace now supports action-type filtering and explicit replay-safety for governance actions.
- Added home-page export-history query recall chips for quick re-search from recent exports.
- Added scope-aware export-recall support for `search`/`country` scopes and deterministic replay reset behavior.
- Added Home-page clear-all action for recent export recalls and queued recall-memory governance follow-up research.
- Added persistent recall-memory persistence for export recents with clear-all durable state and meta fallback load path.


## Goal-maintenance note
- Added `docs/upgrade_queue.md` and linked it as the long-horizon upgrade queue for complete-app parity work.
- Continued goal-scoped work: preserve local-first/provenance-first boundaries while planning future user-facing features for production-grade parity.
- Linked current /goal execution to a structured M0+ backlog in `docs/upgrade_queue.md`, including searchable research notes and a conservative text-size governance bound.
- Reflected this slice execution in `PROJECT_PLAN.md` and this goal notes, including the completed favorites baseline and comparison-workflow progression.
- Added operations-side governance actions to the trace feed and captured trace-expansion research in upgrade queue updates.
- Added home activity-trace action filtering and replay gating for non-idempotent governance operations.
- Added trace recovery-session research item for replay safety and resumable actions in `docs/upgrade_queue.md`.
- Added home export-recall experience to close exported-search quick-reselect flow and updated queue completion status.
- Added country-scope replay behavior and advanced-filter reset path for deterministic export recall.
- Added recall-list clear action on Home and expanded queue research for recall memory persistence vs temporary session behavior.
- Made recall clear state durable in `app_meta` and switched export success path to append recall metadata directly instead of reloading export history.
- Updated CI wrapper strictness boundary documentation/tests so `DHC_FORCE_DART_CHECKS` and `DHC_FORCE_FLUTTER_CHECKS` are independently asserted; added test coverage in `ci_workflow_test.dart` for Flutter-step variable isolation.

### 2026-08-30 MergeReview non-executing worklist foundation

- Added `MergeReviewWorkItem` and a strict schema-v1 codec for `queued` / `deferred` review snapshots. Each item keeps the structured logical issue ID, identity source, current actionable target, frozen type/status tokens, evidence text, issue time, and worklist creation/update times.
- Source-scoped work items require the actionable target to equal the non-empty identity source. Canonical-level nutrient variance identities keep an empty identity source and may refresh an independent actionable target.
- Added `MergeReviewWorklistStore` on `app_meta.merge_review_worklist_v1`: atomic batch upsert with last duplicate mutation winning, original `createdAt` retention, refreshed issue snapshots, monotonic `updatedAt` under clock rollback, queued-before-deferred stable ordering, remove/removeAll, and explicit clear.
- Store limits are 500 items and 1,048,576 UTF-8 bytes for the encoded envelope. Runtime constructor checks also apply in release builds. Capacity or byte overflow rejects the whole batch without replacing prior data.
- Public loads fail open for malformed or unsupported data. Mutations refuse to overwrite malformed envelopes, invalid items, duplicate identities, or over-limit storage; explicit clear is the recovery path. Failed reads/writes do not poison later queued operations.
- This layer is deliberately non-executing: it does not merge, split, override, revalidate revisions, or run background work. Serialization covers only the same isolate and repository object; separate wrappers/processes/direct `app_meta` writes remain last-writer-wins.
- Verification: 26 focused model/store tests, `flutter analyze` with zero issues, 230 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, compare gates, and Web build all passed.
- Follow-up completed in the section below: current-page Queue / Defer / Untrack UI, per-card status, and stored-snapshot change indicators now consume this data layer without governance execution.

### 2026-08-30 MergeReview worklist Operations UI

- Connected the latest successful review page selection to atomic `Queue selected`, `Defer selected`, and exact-ID `Untrack selected` operations. Successful writes remove only submitted IDs from the selection; failed writes preserve both selection and the last good per-card status snapshot.
- Added whole-worklist queued/deferred counts, exact-ID per-card status chips, and a `Review snapshot changed` marker when the currently rendered issue differs from the stored evidence fields. This marker is only a stored-snapshot comparison; it is not a database revision check, live source revalidation, or proof that an item is safe or unsafe to execute.
- Added an independent worklist load/error/retry lane that can render before saved-view initialization completes and preserves the last good worklist snapshot on later read failure. Mutation results and failures are announced inline through a live region rather than being mixed into generic Operations status.
- Added confirmed `Clear worklist` recovery. It removes only queued/deferred snapshots, never food or governance data, and is the explicit escape hatch after the store correctly refuses to mutate a malformed persisted envelope.
- Worklist writes freeze review selection/filter/view/page and app refresh controls. Manual merge/split/override and worklist writes are mutually exclusive in both widget state and method guards; a refresh requested by a stale callback during a worklist write is coalesced and run once afterward.
- Queue, defer, untrack, and clear do not call merge/split/override, append governance logs, or append activity traces. Their input is limited to the current successful visible page, while the persisted worklist may retain identities no longer visible under the active page/filter.
- At this slice boundary there was no cross-page inventory; the follow-up below closes only that read-only browsing gap. Orphan or identity-migration discovery, background synchronization, database revision/CAS validation, and batch governance execution remain absent, and disappeared review issues are not automatically reconciled.
- Verification: 26 focused model/store tests plus 33 Operations widget tests (59 combined), `flutter analyze` with zero issues, 242 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.

### 2026-08-30 MergeReview read-only worklist inventory

- Added a default-collapsed inventory over the complete loaded worklist snapshot, independent of the current review filter/page. It preserves the store's queued-first, newest-update, exact-ID order and exposes 20 items per local page without repository reads, writes, review queries, governance calls, or activity traces.
- Each inventory item displays its stored status, issue type, canonical and target source IDs, subject key, suggested canonical, reason, candidate summary, issue/saved/updated times, and full structured issue identity. It deliberately exposes no checkbox, details lookup, Untrack, merge, split, or override action.
- Paging is guarded during worklist load/write. Every successful load/upsert/remove/clear normalizes the offset to the latest valid 20-item page, so shrinking a 21-item second page returns to the remaining first page instead of rendering an empty range.
- Initial worklist read failure does not fabricate an empty inventory. A later refresh failure retains the last successful readable snapshot, and the explicitly parent-controlled expansion state keeps the inspection panel open across loading/error rebuilds without sharing a PageStorage slot with nested selectable text.
- Boundary text states that these are loaded stored snapshots only. Absence from the live review page is not labeled orphan/resolved/stale because it may reflect filtering or paging; the inventory performs no live issue-existence check, identity migration, revision/CAS revalidation, background sync, or governance execution.
- Verification: 36 Operations widget tests, `flutter analyze` with zero issues, 245 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: local All / Queued / Deferred filtering now narrows this same loaded snapshot without changing its persistence or execution boundary.

### 2026-08-30 MergeReview worklist inventory status filters

- Added local `All`, `Queued`, and `Deferred` choice chips to the read-only inventory. Chip counts describe the complete loaded worklist, while the range and page labels describe the active matching subset; filtering preserves the store's item order.
- Filter state is private, ephemeral page state and is never written to `app_meta`. Changing status returns to the first matching page, and reconstructing the page defaults to `All`.
- Successful load/upsert/remove/clear snapshots clamp the offset against the current filtered subset. A zero-match filter renders a bounded empty-state message with both pagers disabled instead of fabricating a range or page.
- Filter and pager callbacks are disabled during worklist load/write, and method guards reject a previously captured callback while a write is held. Controls remain usable against the last good snapshot after a later read error because no stored data was replaced.
- Filtering is read-only and local: it adds no repository read/write, review query, governance mutation, activity trace, identity migration, or orphan/resolved/stale/current inference.
- Verification: 39 Operations widget tests, `flutter analyze` with zero issues, 248 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: bounded local text search now composes with the status filter and paging over the same loaded snapshots.

### 2026-08-30 MergeReview worklist inventory local search

- Added an ephemeral `Search stored snapshot fields` input and clear action. Search scans only the loaded worklist, whose store limit remains 500 items; it performs no repository or live issue lookup.
- The whitelist is exact: canonical food ID, target source record ID, subject key, non-null suggested canonical ID, reason, candidate summary, and full issue identity. Status, type, timestamps, identity-source duplication, display labels, and placeholders such as `(none)` or `(canonical-level)` are excluded.
- Matching trims only the query edges, lowercases query and each field, then applies literal substring matching within one field. It does not split terms, join field boundaries, use regex/fuzzy matching, normalize accents, or decode identity into a live-data claim.
- Composition is loaded store order -> All/Queued/Deferred predicate -> search predicate -> 20-item local page. Query changes and clear return to the first matching page; successful load/upsert/remove/clear snapshots clamp the current combined subset.
- Query/controller state is page-local, disposed with the page, never written to `app_meta`, and reconstructs empty with status `All`. A later read failure keeps the last successful snapshot and query usable; initial failure still does not fabricate inventory.
- Search and clear are disabled during worklist load/write and protected by matching method guards. A held-write regression calls previously captured search/clear callbacks and verifies that neither raw query nor controller text changes before the write finishes.
- Search is read-only and local: it adds no repository read/write, review query, governance mutation, activity trace, orphan/resolved/stale/current inference, identity migration, revision validation, or execution action.
- Verification: 41 Operations widget tests, `flutter analyze` with zero issues, 250 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed. Independent diff review found no correctness blocker.
- Follow-up completed in the section below: a held-read regression now proves the loading gate and successful refreshed-snapshot shrink/clamp with active status/query state.

### 2026-08-30 MergeReview inventory held-read hardening

- Added a test-only controlled worklist-read repository; production interfaces and behavior were unchanged.
- The regression starts from 21 query-matching queued snapshots plus one deferred snapshot, selects `Queued`, searches `needle`, and moves to the one-item second page. It then replaces persistence with a 20-queued/one-deferred snapshot and holds the toolbar worklist refresh.
- While the read is held, search, Clear, status chips, and paging are all disabled. Previously captured search/clear/filter/previous callbacks are invoked directly and cannot change query, controller text, filter, page, or trigger additional operations/review reads.
- After the read completes, the latest snapshot keeps the active `Queued + needle` view, updates the total from 22 to 21, and clamps the matching queued page from `21-21 / Page 2` to `1-20 / Page 1`; controls re-enable.
- Verification: 42 Operations widget tests, `flutter analyze` with zero issues, 251 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: exact-ID loaded-review-page presence is now visible without adding a presence filter or changing the worklist execution boundary.

### 2026-08-30 MergeReview inventory loaded-review-page presence

- Added a full-inventory summary and per-snapshot chips for exact issue-ID membership in the latest successfully loaded review page. Counts always describe the complete loaded worklist, independent of inventory status/search/local paging.
- Comparison is available only when the selected review filter/page has completed successfully and is neither loading nor in an error state. Initial absence, same-context refresh, changed filter/page requests, retained-page failures, and retries remain explicitly unavailable until success; a successful empty review page is a valid `0 on page` result.
- Membership is full-string `issueId` equality only. It never falls back to canonical food ID, source record ID, issue type, subject fragments, or decoded identity components. A regression proves that otherwise matching canonical/source/type snapshots remain distinct, and another proves markers swap across review pages.
- `Outside loaded review page` uses a neutral other-page icon and explicitly means only another review page or exclusion by the active review filter. It does not determine orphan, resolved, stale, current, live existence, or governance safety. No presence filter is included in this slice.
- Pending -> failed -> retry-success coverage proves that a retained old review page cannot leak a stale presence result. The summary is a live region; item chips remain labeled, non-interactive, and read-only.
- Presence adds no repository read/write, review query beyond existing review navigation/refresh, governance mutation, activity trace, identity migration, revision validation, or execution action.
- Verification: 45 Operations widget tests, `flutter analyze` with zero issues, 254 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed. Independent diff review found no correctness blocker.
- Follow-up completed in the section below: the availability-safe local presence filter now composes with status, search, and paging without turning unavailable review data into an absence claim.

### 2026-08-30 MergeReview inventory availability-safe presence filter

- Added page-local `All / On loaded page / Outside loaded page` inventory chips. The selection is ephemeral, is never written to `app_meta`, and reconstructs as `All`.
- Filtering preserves loaded store order and composes as status -> bounded literal snapshot search -> exact full-string review-page issue-ID membership -> 20-item local page. Presence chip counts still describe the complete loaded worklist; the displayed result range describes the three-filter intersection. Any local filter change returns to the first matching page, and successful worklist snapshots clamp the active intersection.
- `On` and `Outside` are available only for a successful current review request. Starting any real review request atomically resets a non-`All` presence selection and inventory offset to `All`/zero; pending, failure, and retry keep the comparison unavailable with disabled, explicitly labeled chips. A successful empty review page remains a valid zero-membership comparison.
- Worklist reads and writes remain a separate lane: they lock every local inventory callback and reject stale captured callbacks without resetting presence. A later worklist-read error retains the last good inventory and active presence selection; a successful smaller snapshot retains the selection and clamps its page.
- The three chips are exposed as one labeled semantics group, and the boundary text states that chip counts cover all loaded stored snapshots while result counts combine status, search, and presence. `Outside` remains only a page/filter-exclusion statement, never an orphan/resolved/stale/current/live or governance-safety inference.
- The filter adds no repository read/write, review query, governance mutation, activity trace, identity migration, revision validation, or execution action. Test coverage includes composition across two local pages, zero-result search, a successful empty review page, review pending/failure/retry recovery, initial review failure, held worklist write, active-presence held read, stale callbacks, persistence shrink, and reconstruction.
- Verification: 47 Operations widget tests, `flutter analyze` with zero issues, 256 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed. Independent review found no correctness blocker.
- Follow-up completed in the section below: overlapping successful responses now have a focused presence-ownership regression.

### 2026-08-30 MergeReview inventory stale-success presence ownership

- Added one test-only regression around the existing controlled review-query repository; production code, interfaces, and behavior were unchanged.
- The fixture stores two warning worklist snapshots, one category-conflict and one low-confidence-reuse. It holds an older `Warning` query whose result would yield presence `2 on / 0 outside`, then a newer `Warning + Low-confidence reuse` query whose result yields `1 on / 1 outside`.
- The newer request completes first. The test verifies its one-item review result, exact-ID 1/1 summary, outside/on item markers, and then selects the local `On` presence chip so only the reuse snapshot remains visible.
- When the older broad query completes afterward, generation ownership keeps the newer review page. The regression proves the 1/1 summary, active `On` selection, one-item inventory range, reuse item, and absence of the category item do not roll back; review loading also remains cleared.
- The test records that the interaction adds only the two expected review queries/filter persistence writes: no operations reread, worklist rewrite, governance mutation, or presence persistence occurs. Independent review confirmed the 2/0-versus-1/1 fixture materially detects count, membership, and active-filter rollback and found no blocker.
- Verification: 48 Operations widget tests, `flutter analyze` with zero issues, 257 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: newest-failure ownership is now covered through stale success and current-context retry recovery.

### 2026-08-30 MergeReview inventory newest-failure presence ownership

- Added one test-only mirror regression using the controlled review-query repository; production code and interfaces remain unchanged.
- Starting from an active local `On` selection, an older `Warning` request and newer `Warning + Low-confidence reuse` request are held. Request start atomically returns presence to `All` and unavailable before the newer request fails.
- After the newest failure, the regression locks the review error, unavailable summary and item marker, full two-item inventory, selected `All`, and disabled `On`/`Outside`. Completing the older successful request afterward cannot clear the error, publish its retained page as current, or re-enable presence.
- Inline retry is then asserted to query the newest `Warning + Low-confidence reuse` context. Only that success clears the error and restores the exact 1-on/1-out summary, category `Outside` marker, reuse `On` marker, and enabled presence chips; the local selection remains `All` rather than resurrecting the pre-request `On` value.
- The no-settle filter helper now performs a bounded lazy-list materialization pass when a pending-state layout has evicted the target dropdown. This is test navigation only and stabilizes all three latest-review race regressions without business-state side effects.
- Operations reads, worklist writes, filter/presence persistence, governance actions, query count, and retry context are explicitly locked. Independent review found no blocker.
- Verification: 49 Operations widget tests, `flutter analyze` with zero issues, 258 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: newest-success ownership now rejects a stale older failure without changing review or presence state.

### 2026-08-30 MergeReview inventory stale-failure presence ownership

- Added the final success/failure mirror regression around the controlled review-query repository; this slice is test-only and changes no production interface or behavior.
- An older broad `Warning` request and newer `Warning + Low-confidence reuse` request are held. The newer request succeeds first and establishes the one-item review page, exact-ID 1-on/1-out summary, category `Outside` marker, and reuse `On` marker.
- The test then activates `Outside`, yielding only the category snapshot. When the older request fails afterward, the stale error cannot publish: no review error or retry appears, the newest review count and 1/1 presence remain current, `Outside` stays selected and enabled, and the category-only inventory/marker remains unchanged.
- Side-effect locks prove there are only the two expected review queries and filter writes, with no operations reread, worklist rewrite, governance mutation, presence persistence, or lingering loading state. Independent review found no blocker and confirmed the assertions detect error injection, unavailable fallback, membership rollback, and local-filter reset.
- Together with the preceding slices, the core two-request outcome matrix now covers latest success + stale success, latest failure + stale success, and latest success + stale failure while preserving exact presence ownership.
- Verification: 50 Operations widget tests, `flutter analyze` with zero issues, 259 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: distinguishable double failures now prove that only the newest error owns the retry lane while presence remains `All` and unavailable.

### 2026-08-30 MergeReview inventory double-failure error ownership

- Added one test-only double-failure regression and an optional error-message parameter to the controlled review-query fake; production code, interfaces, and behavior remain unchanged.
- Starting from active `On`, an older broad `Warning` request and a newer `Warning + Low-confidence reuse` request are held. The newer request fails with `LATEST_REVIEW_FAILURE`, establishing the sole visible review error, full two-item inventory, unavailable presence summary and item marker, selected `All`, and disabled `On`/`Outside` chips.
- The older request then fails with the distinguishable `STALE_REVIEW_FAILURE`. Its stale callback cannot replace or duplicate the newest error, publish retry ownership, alter inventory membership, re-enable presence, or change the unavailable marker.
- Inline retry is locked to the newest filter. Pending clears the old error while presence remains unavailable; only the current-context success restores the exact 1-on/1-out summary and enabled presence chips, with the local selection still `All`.
- The `app_meta` baseline is captured between the newest and stale failures and checked immediately after the stale completion, then again after retry success. Together with operations-read, query-count, worklist-key, and governance locks, this detects stale-failure or retry side effects rather than absorbing them into a late baseline.
- Independent review identified the original late-baseline gap; the assertion was moved to the ownership boundary and follow-up review confirmed it closed with no blocker.
- Verification: 51 Operations widget tests, `flutter analyze` with zero issues, 260 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: an already-dispatched corrective second query can be superseded without publishing review or presence state.

### 2026-08-30 MergeReview corrective second-query publication ownership

- Added one test-only out-of-bounds race regression plus a controlled custom-page completion helper; production code and interfaces remain unchanged.
- A 102-issue page starts with one tracked high issue on offset 0 and one tracked warning-reuse issue outside it. Active local `On` initially exposes only the high snapshot.
- A held `All` request for offset 100 receives a semantically valid shrunken empty page (`matchingCount: 1`) and therefore legitimately dispatches `_loadReviewPage`'s corrective `All` request at offset 0. While that correction is pending, a newer `Warning` request at offset 0 takes ownership.
- The newest request succeeds first, establishing the one warning review result, exact-ID 1-on/1-out summary, high `Outside` marker, warning `On` marker, and active local `On` subset containing only the warning snapshot. Completing the older correction afterward cannot publish its broad page, make presence unavailable, reverse membership, reset the local filter, or restore loading/error.
- Query topology is locked to primary offset 100 -> corrective offset 0 -> latest Warning offset 0. Operations reads remain unchanged; the only new metadata write is the expected review-filter persistence; worklist-key writes and governance mutations remain unchanged.
- The custom-page helper asserts response offset/limit match the held query. `_expectReviewCount` now reuses the lazy-list-aware control locator so a long Operations list cannot evict the count widget and create a false navigation failure.
- Independent review found no correctness or false-pass blocker and confirmed the ownership and side-effect baselines. Verification: 52 Operations widget tests, `flutter analyze` with zero issues, 261 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a stale primary now stops before dispatching a new corrective repository query.

### 2026-08-30 MergeReview stale-primary corrective dispatch guard

- Added a captured-generation parameter to the private `_loadReviewPage` path and a mounted/generation ownership check immediately before its optional corrective repository query.
- If the primary response proves its offset is out of bounds but the request has already lost ownership, `_loadReviewPage` returns that first page without another read; the existing outer success guard discards it. The check and second dispatch have no intervening `await`, so a newer UI generation cannot interleave between them.
- Failure-first evidence reproduced the gap: held `All@100`, newer `Warning@0` success, then the stale shrunken primary produced an unwanted third `All@0` query. After the guard, the exact query suffix remains only `All@100` and `Warning@0`.
- The preceding complementary regression remains green: when the primary still owns generation, it may legitimately dispatch `All@0`; if ownership changes while that correction is in flight, the outer guard still prevents its late result from publishing.
- Lifecycle and error semantics remain bounded: disposal before primary completion avoids the extra read and all state publication; primary errors and owned corrective errors still reach the outer catch, while already-dispatched stale corrective success/error remains isolated by the existing generation guards.
- Latest Warning count/identity, loading/error state, operations reads, the one expected filter metadata write, worklist-key writes, query topology, and zero governance mutation are locked after stale-primary completion.
- Independent review found no correctness blocker. Verification: 53 Operations widget tests, `flutter analyze` with zero issues, 262 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: an owned corrective failure reaches inline error/retry and a retried correction publishes its distinct recovered page.

### 2026-08-30 MergeReview owned corrective failure and retry ownership

- Added one test-only controlled failure/retry regression; production code and interfaces remain unchanged.
- A 102-issue structured fixture tracks one high item on page 0 and one warning-reuse item outside it. The test first proves active `On` is selected and exposes only the high snapshot, so the subsequent request's reset to `All` is not a default-state false pass.
- The owned request follows `All@100 -> All@0`, with the corrective query failing as `OWNED_CORRECTIVE_FAILURE`. The current request publishes that sole inline error and Retry, stops loading, reports review results unavailable, keeps the full two-item inventory under selected `All`, disables `On`/`Outside`, and marks both items comparison-unavailable.
- Retry starts from the still-requested offset rather than the prior applied page, producing `All@100 -> All@0` again. The second correction returns a distinct one-warning page, proving its response—not the retained old high page—owns recovery.
- Recovery clears error/retry/loading, reports 1/1 total 1, swaps exact membership from high `On` / warning `Outside` to high `Outside` / warning `On`, retains selected `All`, re-enables presence, and then permits local `On` to expose only the warning snapshot.
- The exact four-query topology is locked. Operations reads, all metadata writes, worklist-key writes, and governance mutations remain unchanged, with a second baseline captured at corrective failure to isolate retry side effects; every held query is completed or failed.
- Independent review found and closed two false-pass gaps: the final correction now returns distinct content, and the initial active `On` state is explicitly proven before request start. No blocker remains.
- Verification: 54 Operations widget tests, `flutter analyze` with zero issues, 263 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: disposal while an out-of-bounds primary is held now has an explicit no-correction/no-exception lifecycle regression.

### 2026-08-30 MergeReview disposed-primary corrective lifecycle ownership

- Added one test-only lifecycle regression around the existing mounted/generation guard; production code, interfaces, and behavior remain unchanged.
- After the normal 102-issue review page loads, `All@100` is held and the Operations page is explicitly disposed. The test proves the widget is absent before allowing the primary response to continue.
- The late primary response is an empty, semantically out-of-bounds page (`matchingCount: 1`, offset/limit `100/100`), so it necessarily reaches the corrective-query decision. Because the state is unmounted, the exact query suffix remains only `All@100`; no `All@0` repository read is dispatched.
- The held primary completer changes from pending to completed, two pumps flush its continuation, the Operations page remains absent, and Flutter's captured exception queue is empty both before disposal and after completion. These locks prevent an unflushed Future or incomplete disposal from creating a false pass.
- Operations reads, all metadata writes, worklist-key writes, and governance mutations remain unchanged. Independent review confirmed the trigger semantics, disposal proof, query topology, completion state, exception check, and side-effect baselines are minimally sufficient with no blocker.
- Verification: 55 Operations widget tests, `flutter analyze` with zero issues, 264 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: an already-dispatched corrective failure is now isolated after a newer success without disturbing review or presence ownership.

### 2026-08-30 MergeReview stale-corrective-failure ownership

- Added one test-only failure mirror for the already-dispatched corrective-query race; production code, interfaces, and behavior remain unchanged.
- A structured 102-issue fixture drives the exact held topology `All@100 primary -> All@0 corrective -> Warning@0 newer request`. The primary is completed with a semantically out-of-bounds empty page, and the corrective is explicitly proven pending before the newer request succeeds.
- The newer Warning success establishes a distinct one-warning review page, exact-ID 1-on/1-out presence, high `Outside` and warning `On` markers, and an active local `On` subset containing only the warning snapshot. Completer state is locked as `[completed, pending, completed]` before the stale failure.
- The old corrective then fails with the distinguishable `STALE_CORRECTIVE_FAILURE`. Its catch path cannot publish the message or a generic error/Retry, restore loading, make presence unavailable, disable the chips, reset local `On`, or alter review/inventory identity. Flutter captures no exception.
- All three held completers finish, and the exact query suffix remains `All@100 -> All@0 -> Warning@0`. Operations reads, worklist-key writes, and governance mutations remain unchanged; the sole metadata increment is the expected Warning-filter persistence, with a second baseline proving the stale failure adds nothing.
- Independent review confirmed the index ownership, asynchronous ordering, latest-success preconditions, active-filter evidence, completion state, query topology, and side-effect baselines with no blocker.
- Verification: 56 Operations widget tests, `flutter analyze` with zero issues, 265 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a newer failure followed by an older corrective failure now preserves the latest error and Retry ownership through current-context recovery.

### 2026-08-31 MergeReview latest-failure stale-corrective error ownership

- Added one test-only four-query failure/retry regression; production code, interfaces, and behavior remain unchanged.
- A structured 102-issue fixture locks the exact topology `All@100 primary -> All@0 corrective -> Warning@0 newer failure -> Warning@0 retry success`. The primary returns a semantically out-of-bounds empty page, and the corrective is explicitly pending before the newer failure starts.
- The newer request fails with `LATEST_CORRECTIVE_RACE_FAILURE`, establishing the sole visible error/Retry owner, selected `All`, full inventory, unavailable presence summary/markers, and disabled `On`/`Outside`. The older corrective then fails with `STALE_CORRECTIVE_FAILURE`; its stale callback cannot replace or duplicate the error, take Retry ownership, re-enable presence, reset local state, or alter review/inventory.
- Before the stale failure the held states are `[completed, pending, completed]`; after it all three settle with no Flutter exception. Retry remains locked to `Warning@0`, clears the stale error while loading, and current success publishes a distinct warning-only page with 1 matching/102 total, 1-on/1-out, high `Outside` and warning `On`; `All` remains selected and `On` then shows only warning.
- Exact query suffix and side effects are locked: `All@100`, `All@0`, `Warning@0`, `Warning@0`; operations reads, worklist-key writes, and governance remain unchanged, with only the expected Warning-filter metadata write. The latest-failure metadata baseline catches any stale-failure mutation.
- Local review confirms the asynchronous ordering, error/retry ownership, retry context, settled completers, identity/membership markers, query topology, and side-effect baselines; no blocker was found.
- Verification: 57 Operations widget tests, `flutter analyze` with zero issues, 266 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a disposed Operations page now ignores a late failure from an already-dispatched corrective query.

### 2026-08-31 MergeReview disposed corrective failure lifecycle ownership

- Added one test-only lifecycle regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture starts with the normal review page, then holds `All@100`. The primary completes with a semantically out-of-bounds empty page (`matchingCount: 1`, offset/limit `100/100`), forcing the corrective `All@0` query to dispatch and remain pending.
- The Operations page is explicitly disposed while that corrective is pending. A subsequent `DISPOSED_CORRECTIVE_FAILURE` is completed on the held Future; the unmounted path publishes no error/retry/loading or review state and Flutter captures no exception.
- Both held completers settle, and the exact query suffix remains only `All@100 -> All@0`. Operations reads, metadata writes, worklist-key writes, and governance mutations remain at their baselines.
- Local review confirms the corrective was genuinely dispatched before disposal, remained pending across the unmount, and was failed after disposal; no blocker was found.
- Verification: 58 Operations widget tests, `flutter analyze` with zero issues, 267 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: an already-dispatched corrective success after disposal is equally unable to repopulate the page or mutate side effects.

### 2026-08-31 MergeReview disposed corrective success lifecycle ownership

- Added one test-only lifecycle mirror; production code, interfaces, and behavior remain unchanged.
- The 102-issue backlog fixture holds `All@100`, completes a semantically out-of-bounds empty primary (`matchingCount: 1`, offset/limit `100/100`), and proves the corrective `All@0` query is dispatched and pending.
- The Operations page is explicitly disposed while that corrective is pending. Completing the corrective with its normal broad success page after disposal cannot repopulate the page, publish review/presence state, or trigger a setState exception; Flutter captures no exception.
- Both held completers settle, and the exact query suffix remains only `All@100 -> All@0`. Operations reads, metadata writes, worklist-key writes, and governance mutations remain at their baselines.
- Local review confirms the symmetric success path is tested after genuine corrective dispatch and post-dispose completion; no blocker was found.
- Verification: 59 Operations widget tests, `flutter analyze` with zero issues, 268 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a stale corrective success after a newer failure cannot clear the latest error or take Retry ownership.

### 2026-08-31 MergeReview stale corrective success after newer failure ownership

- Added one test-only corrective-specific failure/success/retry regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> stale All@0 success -> Warning@0 retry`. The primary returns a semantically out-of-bounds empty page, so the corrective is genuinely dispatched before the newer request.
- The newer Warning request fails with `LATEST_CORRECTIVE_RACE_FAILURE`, establishing the sole error/Retry owner and unavailable review result. Completing the older corrective successfully afterward cannot clear or duplicate the error, publish its broad page, restore loading, or alter the requested retry context.
- Retry remains pinned to `Warning@0`; while it is pending the count is loading and the prior error is cleared, and only that current-context success publishes the one-warning page (`1 matching/102 total`). All four held completers settle with no Flutter exception.
- Exact query suffix is `All@100 -> All@0 -> Warning@0 -> Warning@0`; operations reads, metadata beyond the expected Warning-filter write, worklist-key writes, and governance mutations remain unchanged.
- Local review confirms the stale response is a real corrective success completed after the latest failure, with ownership, retry, settle, identity, and side-effect baselines locked; no blocker was found.
- Verification: 60 Operations widget tests, `flutter analyze` with zero issues, 269 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a stale corrective success that arrives during an active newer retry cannot clear current loading or replace the retry response.

### 2026-08-31 MergeReview stale corrective success during active retry ownership

- Added one test-only corrective-specific retry race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> Warning@0 retry pending`. The primary returns a semantically out-of-bounds empty page, so the corrective is genuinely dispatched before the newer request and remains pending through retry start.
- After the current Warning retry clears the error and shows loading, the stale broad `All@0` success completes. It cannot stop current loading, publish the broad page, clear or replace retry context, or settle the current Warning retry; no Flutter exception occurs.
- The current Warning retry then succeeds and alone publishes the one-warning page (`1 matching/102 total`); all four held completers settle. Exact query suffix is `All@100 -> All@0 -> Warning@0 -> Warning@0`.
- Operations reads, metadata beyond the expected Warning-filter write, worklist-key writes, and governance mutations remain unchanged.
- Local review confirms the stale completion occurs after retry dispatch and before current success, with loading/Future/identity/topology/side-effect baselines locked; no blocker was found.
- Verification: 61 Operations widget tests, `flutter analyze` with zero issues, 270 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: the symmetric stale corrective failure during an active retry cannot surface an error or stop current loading before current success.

### 2026-08-31 MergeReview stale corrective failure during active retry ownership

- Added one test-only corrective-specific retry race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> Warning@0 retry pending`. The primary returns a semantically out-of-bounds empty page, so the corrective is genuinely dispatched before the newer request and remains pending through retry start.
- After the current Warning retry clears the error and shows loading, the stale broad `All@0` corrective failure completes with `STALE_CORRECTIVE_FAILURE`. It cannot surface an error, take Retry ownership, stop current loading, or settle the current Warning retry; no Flutter exception occurs.
- The current Warning retry then succeeds and alone publishes the one-warning page (`1 matching/102 total`); all four held completers settle. Exact query suffix is `All@100 -> All@0 -> Warning@0 -> Warning@0`.
- Operations reads, metadata beyond the expected Warning-filter write, worklist-key writes, and governance mutations remain unchanged.
- Local review confirms the stale failure occurs after retry dispatch and before current success, with loading/Future/identity/topology/side-effect baselines locked; no blocker was found.
- Verification: 62 Operations widget tests, `flutter analyze` with zero issues, 271 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a stale corrective failure arriving after current retry success remains isolated once the new page is published.

### 2026-08-31 MergeReview stale corrective failure after retry success ownership

- Added one test-only late-error regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> Warning@0 retry success`, with the corrective genuinely dispatched before the newer request and held until after the retry publishes.
- The current Warning retry first publishes the one-warning page (`1 matching/102 total`) and clears error/retry/loading. The stale broad `All@0` corrective then fails with `STALE_CORRECTIVE_FAILURE`; it cannot surface an error, restore Retry or loading, replace the page, or alter the selected Warning context; no Flutter exception occurs.
- The late failure settles the final held corrective Future without adding a query. Exact query suffix remains `All@100 -> All@0 -> Warning@0 -> Warning@0`, and the one-warning page remains visible.
- Operations reads, metadata beyond the expected Warning-filter write, worklist-key writes, and governance mutations remain unchanged.
- Local review confirms the current retry success is observed before the stale failure, with page/error/loading/Future/identity/topology/side-effect baselines locked; no blocker was found.
- Verification: 63 Operations widget tests, `flutter analyze` with zero issues, 272 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: the symmetric stale corrective success arriving after current retry success cannot republish or alter the current page.

### 2026-08-31 MergeReview stale corrective success after retry success ownership

- Added one test-only late-publication regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `All@100 primary -> All@0 corrective pending -> Warning@0 newer failure -> Warning@0 retry success`, with the corrective genuinely dispatched before the newer request and held until after the retry publishes.
- The current Warning retry first publishes the one-warning page (`1 matching/102 total`) and clears error/retry/loading. The stale broad `All@0` corrective then succeeds; it cannot republish the broad page, alter the selected Warning context, restore loading, or change the published one-warning identity; no Flutter exception occurs.
- The late success settles the final held corrective Future without adding a query. Exact query suffix remains `All@100 -> All@0 -> Warning@0 -> Warning@0`, and the one-warning page remains visible.
- Operations reads, metadata beyond the expected Warning-filter write, worklist-key writes, and governance mutations remain unchanged.
- Local review confirms the current retry success is observed before the stale success, with page/error/loading/Future/identity/topology/side-effect baselines locked; no blocker was found.
- Verification: 64 Operations widget tests, `flutter analyze` with zero issues, 273 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: the toolbar-refresh generation race now keeps a newer page authoritative over a stale corrective failure.

### 2026-08-31 MergeReview toolbar refresh stale corrective failure ownership

- Added one test-only toolbar-refresh generation race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `All@100 primary -> All@0 corrective pending -> toolbar Refresh -> All@100 newer request`. The primary returns a semantically out-of-bounds empty page, so the corrective is genuinely dispatched before the refresh request.
- The toolbar refresh’s newer `All@100` response publishes the page `Showing 101-102 of 102 matching review issues (102 total)` with `BACKLOG_TARGET`. The older corrective then fails with `STALE_TOOLBAR_CORRECTIVE_FAILURE`; it cannot surface a review error/retry/loading state, replace the page, or alter the current offset/identity; no Flutter exception occurs.
- The late failure settles the old corrective Future without adding a query. Exact query suffix is `All@100 -> All@0 -> All@100`; operations reads are exactly the expected toolbar-refresh increment and unchanged after stale completion.
- Review-filter metadata, worklist-key writes, and governance mutations remain unchanged.
- Local review confirms the genuine corrective dispatch, refresh-generation supersession, newer page publication, stale failure ordering, and query/side-effect baselines; no blocker was found.
- Verification: 65 Operations widget tests, `flutter analyze` with zero issues, 274 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: Clear review filters now keeps the newer All page authoritative over a stale corrective success.

### 2026-08-31 MergeReview Clear review filters stale corrective success ownership

- Added one test-only filter-clear generation race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `High@0 -> High@100 -> High@0 corrective pending -> Clear review filters -> All@0 newer request`. The High primary returns a semantically out-of-bounds empty page, so the corrective is genuinely dispatched before Clear.
- Clear review filters’ newer `All@0` response publishes `Showing 1-100 of 102 matching review issues (102 total)` with `All severities`. The older High corrective then succeeds; it cannot republish the High page, restore the High filter, alter the count/page identity, or surface review error/retry/loading; no Flutter exception occurs.
- The stale success settles the old corrective Future without adding a query. Exact query suffix is `High@0 -> High@100 -> High@0 -> All@0`; operations reads and metadata writes are unchanged after stale completion.
- Worklist-key writes and governance mutations remain unchanged.
- Local review confirms the genuine corrective dispatch, Clear-generation supersession, newer All-page publication, stale success ordering, Future settlement, query, and side-effect baselines; no blocker was found.
- Verification: 66 Operations widget tests, `flutter analyze` with zero issues, 275 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view apply now keeps the newer Warning page authoritative over a stale corrective failure.

### 2026-08-31 MergeReview saved-view stale corrective failure ownership

- Added one test-only saved-view generation race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `All@100 -> All@0 corrective pending -> saved Warning@0 newer request`. The All primary returns a semantically out-of-bounds empty page, so the corrective is genuinely dispatched before saved-view apply.
- Applying the `Warning saved` view publishes `Showing 1 of 1 matching review issues (102 total)` with `BACKLOG_TARGET` and keeps the saved-view chip selected. The older broad corrective then fails with `STALE_SAVED_VIEW_CORRECTIVE_FAILURE`; it cannot surface review error/retry/loading, replace the Warning page, or clear saved-view selection; no Flutter exception occurs.
- The stale failure settles the old corrective Future without adding a query. Exact query suffix is `All@100 -> All@0 -> Warning@0`; operations reads and filter metadata remain unchanged after stale completion.
- Worklist-key writes and governance mutations remain unchanged.
- Local review confirms the genuine corrective dispatch, saved-view generation supersession, newer Warning-page publication, stale failure ordering, selection identity, query, and side-effect baselines; no blocker was found.
- Verification: 67 Operations widget tests, `flutter analyze` with zero issues, 276 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view re-apply now keeps the newer page authoritative over a stale corrective failure.

### 2026-08-31 MergeReview saved-view re-apply stale corrective failure ownership

- Added one test-only saved-view re-apply generation race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `High@0 -> High@100 -> High@0 corrective pending -> re-apply High saved view@0 newer request`. The High primary returns a semantically out-of-bounds empty page, so the corrective is genuinely dispatched before re-apply.
- Re-applying the active `High saved` view resets the offset and publishes `Showing 1-100 of 101 matching review issues (102 total)`, keeping the saved-view chip selected. The older corrective then fails with `STALE_SAVED_VIEW_REAPPLY_CORRECTIVE_FAILURE`; it cannot surface review error/retry/loading, replace the page, or clear saved-view selection; no Flutter exception occurs.
- The stale failure settles the old corrective Future without adding a query. Exact query suffix is `High@0 -> High@100 -> High@0 -> High@0`; operations reads and the two expected filter-metadata writes are unchanged after stale completion.
- Worklist-key writes and governance mutations remain unchanged.
- Local review confirms the genuine corrective dispatch, re-apply generation supersession, newer High-page publication, stale failure ordering, saved-view identity, Future settlement, query, and side-effect baselines; no blocker was found.
- Verification: 68 Operations widget tests, `flutter analyze` with zero issues, 277 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: deleting a saved view leaves a current-context corrective owned by the active review generation.

### 2026-08-31 MergeReview saved-view delete current corrective ownership

- Added one test-only saved-view deletion lifecycle regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `High@0 -> High@100 -> High@0 corrective pending`, then deletes the selected `High delete` view while the corrective remains in flight. Saved-view deletion only changes saved-view metadata; it does not change the active High filter or review generation.
- The selected chip and saved-view payload are removed, while the High filter remains active and no review query is added. The still-owned corrective then fails with `OWNED_SAVED_VIEW_DELETE_CORRECTIVE_FAILURE`; the failure correctly surfaces review error/Retry and unavailable count instead of being treated as stale; no Flutter exception occurs.
- The owned failure settles all three held query Futures. Exact query suffix is `High@0 -> High@100 -> High@0`; operations reads remain unchanged, and the only post-baseline metadata writes are the expected High filter write and saved-view deletion write.
- Worklist-key writes and governance mutations remain unchanged.
- Local review confirms saved-view identity removal, active-filter preservation, current-generation ownership, owned failure publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 69 Operations widget tests, `flutter analyze` with zero issues, 278 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view deletion failure now preserves saved-view identity while the in-flight corrective remains current-context owned.

### 2026-08-31 MergeReview saved-view deletion failure current corrective ownership

- Added one test-only saved-view deletion failure regression and a controlled metadata-write failure fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `High@0 -> High@100 -> High@0 corrective pending`, then fails deletion of the selected `High delete failure` view while the corrective remains in flight. The failed metadata write does not change the active High filter, saved-view payload, selected chip, or review generation.
- The deletion failure is surfaced as an operation-status message, while no review query is added and the corrective remains loading. The still-owned corrective then fails with `OWNED_SAVED_VIEW_DELETE_FAILURE_CORRECTIVE_FAILURE`; review error/Retry and unavailable count are shown, and the saved-view chip remains selected; no Flutter exception occurs.
- The owned failure settles all three held query Futures. Exact query suffix is `High@0 -> High@100 -> High@0`; operations reads remain unchanged, and the only successful post-baseline metadata write is the expected High filter write.
- Worklist-key writes and governance mutations remain unchanged.
- Local review confirms failed deletion attempt, metadata/selection preservation, active-filter identity, current-generation ownership, owned failure publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 70 Operations widget tests, `flutter analyze` with zero issues, 279 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view metadata read failure now preserves identity while the in-flight corrective remains current-context owned.

### 2026-08-31 MergeReview saved-view metadata read failure current corrective ownership

- Added one test-only saved-view metadata read failure regression and a controlled read-failure fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture locks `High@0 -> High@100 -> High@0 corrective pending`, then fails the metadata read needed to delete the selected `High read failure` view while the corrective remains in flight. The failed read does not change the active High filter, saved-view payload, selected chip, or review generation.
- The deletion read failure is surfaced as an operation-status message, while no review query is added and the corrective remains loading. The still-owned corrective then fails with `OWNED_SAVED_VIEW_READ_FAILURE_CORRECTIVE_FAILURE`; review error/Retry and unavailable count are shown, and the saved-view chip remains selected; no Flutter exception occurs.
- The owned failure settles all three held query Futures. Exact query suffix is `High@0 -> High@100 -> High@0`; operations reads remain unchanged, and the only post-baseline metadata write is the expected High filter write.
- Worklist-key writes and governance mutations remain unchanged.
- Local review confirms failed read attempt, metadata/selection preservation, active-filter identity, current-generation ownership, owned failure publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 71 Operations widget tests, `flutter analyze` with zero issues, 280 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: initial saved-view metadata read failure now fails open without blocking the persisted review filter.

### 2026-08-31 MergeReview saved-view initial metadata read fail-open

- Added one test-only initial saved-view metadata read failure regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and a named `High initial read failure` view, then fails the saved-view metadata read during page initialization. The failure is isolated to saved-view configuration: the persisted High filter still loads and the review lane publishes the single `High@0` page.
- Initialization fails open with `Could not load saved review views`; no saved-view chip is fabricated, no review error is raised, and the page shows `Showing 1-100 of 101 matching review issues (102 total)` with no extra query or metadata write.
- Operations reads remain the expected initial tuple `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)`, no Flutter exception occurs, and the saved-view read failure is observed exactly once.
- Local review confirms fail-open isolation, persisted-filter identity, absent saved-view selection, single-query topology, and side-effect baselines; no blocker was found.
- Verification: 72 Operations widget tests, `flutter analyze` with zero issues, 281 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: transient initial saved-view metadata read failure now recovers after page reconstruction.

### 2026-08-31 MergeReview transient initial saved-view read recovery

- Added one test-only transient initial saved-view metadata read recovery regression and a read-call counter in the controlled fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and a named `High transient recovery` view. The first page instance fails its saved-view metadata read, fails open, and still publishes the persisted High `High@0` page without a fabricated chip.
- Reconstructing the page against the same repository after the transient failure succeeds on the second saved-view read: the named saved-view chip reappears, the High filter remains authoritative, and the page again shows `Showing 1-100 of 101 matching review issues (102 total)`.
- The failure counter records exactly one failed attempt across two saved-view reads; both review queries are `High@0`, no review error remains after recovery, no Flutter exception occurs, and no metadata write is added.
- Operations reads move only with the intentional page reconstruction, from `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` to `(jobs:2, artifacts:4, logs:2, exports:2, governance:2)`; worklist and governance side effects remain unchanged.
- Local review confirms fail-open recovery, saved-view identity restoration, persisted-filter continuity, query topology, read-call counts, and side-effect baselines; no blocker was found.
- Verification: 73 Operations widget tests, `flutter analyze` with zero issues, 282 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: transient saved-view recovery now isolates disposed in-flight review requests across reconstruction.

### 2026-08-31 MergeReview transient saved-view recovery with disposed in-flight request

- Added one test-only reconstruction race regression and a spinner-safe loading assertion helper; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High in-flight recovery` view. The first page starts a held `High@100` request, then is disposed; the replacement page fails its saved-view metadata read and starts a held `High@0` request.
- Completing the disposed first-page request cannot alter the replacement page. A second reconstruction succeeds on the saved-view read while the replacement request is still pending, restores the saved-view chip, and starts the current `High@0` request.
- The disposed replacement request is settled next without changing the current page or loading state; only the final current request publishes `Showing 1-100 of 101 matching review issues (102 total)` with the saved-view identity restored.
- Exact query topology is `[High@0, High@100, High@0, High@0]`; three held Future instances settle, the read counter records three saved-view reads with exactly one failure, no Flutter exception or metadata write occurs, and the two intentional reconstructions alone move operations reads from `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` to `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`.
- The shared loading helper avoids `pumpAndSettle` while the review spinner is active, stabilizing the existing held saved-view initialization regression without weakening its loading assertion.
- Local review confirms disposed-request isolation, transient read recovery, saved-view identity restoration, current-generation page ownership, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 74 Operations widget tests, `flutter analyze` with zero issues, 283 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: filter mutation recovery now isolates a disposed request while saved-view metadata fails and later recovers.

### 2026-08-31 MergeReview saved-view read recovery with disposed filter-mutation request

- Added one test-only filter-mutation reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists High review filter and `High filter recovery` view. The first page changes the review filter to Warning, persists that filter, and holds the resulting Warning@0 request; the page is then disposed.
- The replacement page fails its saved-view metadata read and holds a Warning@0 request; completing the disposed filter-mutation request cannot alter the replacement page or fabricate the saved-view chip.
- A second reconstruction succeeds on the saved-view read while the replacement request is pending, restores the saved-view chip as unselected (the persisted active filter remains Warning), and starts the current Warning@0 request. Settling the disposed replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0]`; three held Futures settle, three saved-view reads include exactly one failure, the filter metadata write is the only post-baseline write, no review error/exception occurs, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms filter-mutation persistence, disposed-request isolation, saved-view identity/selection semantics, current-generation ownership, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 75 Operations widget tests, `flutter analyze` with zero issues, 284 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: filter-mutation recovery now observes a completed persisted filter write across saved-view read failure and reconstruction.

### 2026-08-31 MergeReview saved-view read recovery with a disposed filter mutation and pending filter write

- Added one test-only pending filter-write reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High filter write recovery` view. The first page changes the review filter to Warning, queues the filter metadata write, holds the resulting Warning@0 request, and is then disposed.
- The replacement page fails its saved-view metadata read while the filter write is still pending, therefore reads the committed High filter and starts a held High@0 request. Completing the disposed Warning@0 request cannot alter the replacement page or fabricate the saved-view chip.
- Completing the pending filter write is the only post-baseline metadata write and commits Warning. A second reconstruction then reads the committed Warning filter and saved-view metadata successfully while the High@0 request is still pending, restores the saved-view chip as unselected, and starts the current Warning@0 request.
- Settling the disposed High@0 request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, High@0, Warning@0]`; three held review-query Futures and the held filter-write Future settle, three saved-view reads include exactly one failure, no review error/exception occurs, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms pending-write persistence, disposed-request isolation, committed-filter continuity, saved-view identity/selection semantics, current-generation ownership, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 76 Operations widget tests, `flutter analyze` with zero issues, 285 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view read recovery now isolates a disposed filter retry request after a failed filter mutation.

### 2026-08-31 MergeReview saved-view read recovery with a disposed filter retry request

- Added one test-only filter-retry reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High filter retry recovery` view. The first page changes the review filter to Warning, the Warning@0 request fails, and an inline retry starts a held Warning@0 request before the page is disposed.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request. Completing the disposed retry request cannot alter the replacement page, surface the old failure, or fabricate a saved-view chip.
- A second reconstruction succeeds on the saved-view read while the replacement request remains pending, restores the saved-view chip as unselected, and starts the current Warning@0 request. Settling the disposed replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), three saved-view reads include exactly one failure, the filter metadata write is the only post-baseline write, no review error/exception remains, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms failed-filter retry ownership, disposed-request isolation, saved-view identity/selection semantics, current-generation ownership, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 77 Operations widget tests, `flutter analyze` with zero issues, 286 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: toolbar refresh now owns the page over a disposed retry and stale saved-view-read request, then recovery restores metadata identity.

### 2026-08-31 MergeReview toolbar refresh ownership across saved-view read recovery and disposed retry

- Added one test-only toolbar/retry/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High toolbar retry recovery` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts an inline retry, and is then disposed.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request. Toolbar Refresh starts the current Warning@0 request and the full operations refresh; completing the disposed retry and the stale pre-toolbar Warning@0 request cannot alter the toolbar-owned page.
- The toolbar-owned request publishes `Showing 1 of 1 matching review issues (102 total)` with saved-view metadata still fail-open. A later reconstruction succeeds on the saved-view read, restores the chip as unselected, and publishes the same current Warning result.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0, Warning@0]`; five held review-query Futures settle (the first as the intentional filter failure), three saved-view reads include exactly one failure, the filter metadata write is the only post-baseline write, no review error/exception remains, and two reconstructions plus one toolbar refresh move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+3, artifacts:+6, logs:+3, exports:+3, governance:+3)`.
- Local review confirms toolbar generation ownership, failed-filter retry isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 78 Operations widget tests, `flutter analyze` with zero issues, 287 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view deletion failure now preserves identity across active retry and reconstruction recovery.

### 2026-08-31 MergeReview saved-view deletion failure across retry recovery

- Added one test-only saved-view deletion/retry reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High delete retry recovery` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts a held inline retry, and attempts saved-view deletion while that retry is active.
- The saved-view deletion write fails once; the existing unselected chip and active retry/loading state remain intact, no deletion write is recorded, and the page is then disposed.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request. Completing the disposed retry cannot surface the old failure or alter the replacement page.
- A second reconstruction succeeds on the saved-view read while the replacement request remains pending, restores the saved-view chip as unselected (the persisted view was never deleted), and starts the current Warning@0 request. Settling the disposed replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), four saved-view reads include exactly one failure (the deletion mutation performs one read), the filter metadata write is the only post-baseline metadata write, the saved-view write fails exactly once without a persisted write, no review error/exception remains, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms deletion-failure identity preservation, active retry ownership, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 79 Operations widget tests, `flutter analyze` with zero issues, 288 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view deletion success now remains authoritative across active retry and reconstruction recovery.

### 2026-08-31 MergeReview saved-view deletion success across retry recovery

- Added one test-only saved-view deletion/retry reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High delete success retry recovery` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts a held inline retry, and deletes the saved view while that retry is active.
- The deletion succeeds once: the saved-view metadata is persisted as an empty list, the chip disappears, and the active retry/loading state remains intact. The page is then disposed.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request. Completing the disposed retry cannot resurrect the deleted chip or alter the replacement page.
- A second reconstruction succeeds on the saved-view read while the replacement request remains pending; the deleted view stays absent and the current Warning@0 request remains authoritative. Settling the disposed replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), four saved-view reads include exactly one failure (the successful deletion mutation performs one read), the filter metadata write and the empty saved-view write are the only post-baseline metadata writes, no saved-view write fails, no review error/exception remains, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms deletion-success persistence, absence identity, active retry ownership, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 80 Operations widget tests, `flutter analyze` with zero issues, 289 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view apply success now owns the page across active retry and reconstruction recovery.

### 2026-08-31 MergeReview saved-view apply success across retry recovery

- Added one test-only saved-view apply/retry reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High apply success retry recovery` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts a held inline retry, and applies the saved High view while that retry is active.
- Applying the saved view persists High, starts a new High@0 request, and selects the chip; the active Warning retry remains held and the page is then disposed.
- The replacement page fails its saved-view metadata read and starts a held High@0 request. Completing the disposed Warning retry cannot surface the old failure or alter the replacement page.
- A second reconstruction succeeds on the saved-view read while the replacement request remains pending, restores the saved-view chip as present but unselected, and starts the current High@0 request. Settling the disposed apply request and replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1-100 of 101 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`; five held review-query Futures settle (the first as the intentional filter failure), three saved-view reads include exactly one failure, the two filter metadata writes are the only post-baseline metadata writes, no review error/exception remains, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms apply-success generation ownership, selection identity, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 81 Operations widget tests, `flutter analyze` with zero issues, 290 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view apply failure now preserves the committed filter boundary across active retry and reconstruction recovery.

### 2026-08-31 MergeReview saved-view apply failure across retry recovery

- Added one test-only saved-view apply/filter-write/reconstruction race regression and a controlled filter-write failure fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High apply failure retry recovery` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts a held inline retry, and applies the saved High view while that retry is active.
- The in-memory apply starts High@0 and selects the saved-view chip, but its filter metadata write fails exactly once; only the earlier Warning filter write remains committed. The active page stays loading and is then disposed.
- The replacement page fails its saved-view metadata read, reloads the committed Warning filter, and starts a held Warning@0 request. Completing the disposed Warning retry cannot surface the old failure or alter the replacement page.
- A second reconstruction succeeds on the saved-view read while the replacement request remains pending, restores the saved-view chip as present but unselected against the committed Warning filter, and starts the current Warning@0 request. Settling the disposed High apply request and old replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, High@0, Warning@0, Warning@0]`; five held review-query Futures settle (the first as the intentional filter failure), three saved-view reads include exactly one failure, one filter metadata write succeeds and one apply write fails, no review error/exception remains, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms apply-failure persistence boundary, in-memory selection identity, active retry ownership, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 82 Operations widget tests, `flutter analyze` with zero issues, 291 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view save success now preserves the new view across active retry and reconstruction recovery.

### 2026-08-31 MergeReview saved-view save success across retry recovery

- Added one test-only saved-view save/retry reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High save success retry recovery` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts a held inline retry, and saves a new `Warning saved during retry` view while that retry is active.
- The save succeeds once, persists the new Warning view alongside the existing High view, and leaves the active retry/loading state intact; the new chip is present but unselected before the page is disposed.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request. Completing the disposed retry cannot surface the old failure or alter the replacement page.
- A second reconstruction succeeds on the saved-view read while the replacement request remains pending, restores the newly saved chip as present but unselected, and starts the current Warning@0 request. Settling the disposed replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), four saved-view reads include exactly one failure (the save mutation performs one read), the Warning filter write and saved-view write are the only post-baseline metadata writes, no mutation fails, no review error/exception remains, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms save-success persistence, new-view identity, active retry ownership, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 83 Operations widget tests, `flutter analyze` with zero issues, 292 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view save failure now preserves the prior view and committed filter boundary across active retry and reconstruction recovery.

### 2026-08-31 MergeReview saved-view save failure across retry recovery

- Added one test-only saved-view save/retry reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High save failure retry recovery` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts a held inline retry, and attempts to save a new view while that retry is active.
- The saved-view write fails once; no new chip or saved-view metadata write is recorded, the existing High view remains present and unselected, and the committed Warning filter plus active retry/loading state remain intact.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request. Completing the disposed retry cannot surface the old failure or alter the replacement page.
- A second reconstruction succeeds on the saved-view read while the replacement request remains pending, restores the existing High view as present but unselected, and starts the current Warning@0 request. Settling the disposed replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), four saved-view reads include exactly one failure (the failed save mutation performs one read), the Warning filter write is the only post-baseline metadata write, the saved-view write fails exactly once without persistence, no review error/exception remains, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms save-failure identity preservation, committed-filter continuity, active retry ownership, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 84 Operations widget tests, `flutter analyze` with zero issues, 293 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: successful metadata-read reconstruction after a failed save now preserves the prior view identity and current retry boundary.

### 2026-08-31 MergeReview save failure with immediate successful reconstruction read

- Added one test-only post-save-failure reconstruction regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High save failure success read` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts a held inline retry, and attempts to save a new view while that retry is active.
- The saved-view write fails exactly once after its metadata read; no new view is persisted or shown, the existing High view remains present and unselected, and the committed Warning filter plus active retry/loading state remain intact.
- Reconstruction immediately succeeds on the saved-view metadata read and starts a held Warning@0 request. Completing the disposed retry cannot surface the old failure or alter the reconstructed page; the existing view remains present but unselected.
- Only the current Warning request publishes `Showing 1 of 1 matching review issues (102 total)`, with no review error or Flutter exception.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0]`; three held review-query Futures settle (the first as the intentional filter failure), three saved-view reads include no read failure, the Warning filter write is the only post-baseline metadata write, the saved-view write fails exactly once without persistence, and the one intentional reconstruction moves operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+1, artifacts:+2, logs:+1, exports:+1, governance:+1)`.
- Local review confirms failed-save identity preservation, immediate read recovery, committed-filter continuity, active retry ownership, disposed-request isolation, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 85 Operations widget tests, `flutter analyze` with zero issues, 294 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a disposed in-flight saved-view save now settles before read recovery without losing the committed new view.

### 2026-08-31 MergeReview disposed saved-view save completion before read recovery

- Added one test-only pending saved-view-write/disposal/reconstruction race regression and a controlled saved-view-write fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High disposed save recovery` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts a held inline retry, and begins saving `Warning disposed save recovery` while that retry is active.
- The saved-view write remains pending while the page is disposed; completing that Future afterward is the only saved-view mutation completion and persists the new Warning view. The disposed save callback cannot update UI state.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request. Completing the disposed retry cannot surface the old failure or alter the replacement page.
- A second reconstruction succeeds on the saved-view read while the replacement request remains pending, restores the newly persisted view as present but unselected, and starts the current Warning@0 request. Settling the disposed replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), four saved-view reads include exactly one failure (the pending save mutation performs one read), the Warning filter write and completed saved-view write are the only post-baseline metadata writes, no review error/exception remains, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms pending-write settlement, disposed-save callback isolation, new-view persistence, active retry ownership, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 86 Operations widget tests, `flutter analyze` with zero issues, 295 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: pending saved-view deletion is gated until save completion, then deletion and reconstruction preserve the new view.

### 2026-08-31 MergeReview pending saved-view save with deletion gate and recovery

- Added one test-only pending saved-view-write/deletion/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending save delete` view. The first page changes the review filter to Warning, fails the Warning@0 request, starts a held inline retry, and begins saving `Warning pending save then delete` while that retry is active.
- While the saved-view write is pending, the existing view's delete control is absent/blocked and no deletion metadata write occurs. Completing the save persists the new Warning view; only then does deletion of the old High view proceed during the active retry.
- The post-delete persisted list contains only the new Warning view; the old chip disappears and the new chip remains. The replacement page fails its saved-view metadata read and starts a held Warning@0 request; completing the disposed retry cannot surface the old failure or alter the replacement page.
- A second reconstruction succeeds on the saved-view read while the replacement request remains pending, restores only the new view as present but unselected, and starts the current Warning@0 request. Settling the stale replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), five saved-view reads include exactly one failure, the Warning filter write plus one save and one delete are the only post-baseline metadata writes, no review error/exception remains, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms deletion gating, save/delete sequencing, new-view persistence, old-view removal, active retry ownership, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 87 Operations widget tests, `flutter analyze` with zero issues, 296 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view deletion remains independent while a filter metadata write is pending, then reconstruction preserves the deletion.

### 2026-08-31 MergeReview saved-view deletion independent from pending filter write

- Added one test-only pending filter-write/saved-view-deletion/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter delete` view. The first page changes the review filter to Warning, holds its filter metadata write, fails the Warning@0 request, and starts a held inline retry.
- While the filter metadata write remains pending, deleting the saved view proceeds independently: the saved-view metadata write completes first, the chip disappears, and the retry/loading state remains owned by the current page. Completing the held filter write afterward persists Warning without clobbering the empty saved-view list.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request; completing the disposed retry cannot restore the deleted view or alter the replacement page. A second reconstruction succeeds on saved-view read and keeps the deleted view absent while the current Warning@0 request owns publication.
- Settling the stale replacement request still leaves current loading/page unchanged; only the final current request publishes `Showing 1 of 1 matching review issues (102 total)`. No review error or Flutter exception remains.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), four saved-view reads include exactly one failure, the post-baseline metadata writes are one saved-view delete followed by one Warning filter write, and the two intentional reconstructions move operations reads from baseline `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` by `(jobs:+2, artifacts:+4, logs:+2, exports:+2, governance:+2)`.
- Local review confirms independent metadata-key sequencing, deletion persistence, filter-write settlement, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 88 Operations widget tests, `flutter analyze` with zero issues, 297 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view apply queues behind a pending filter write, owns the current query, and reconstruction retains saved-view presence without inventing selection.

### 2026-08-31 MergeReview saved-view apply queued behind pending filter write

- Added one test-only pending filter-write/saved-view-apply/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists High filter plus High and Warning saved views. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held retry; applying the High saved view then queues a High filter write and starts the current High query.
- The stale Warning retry failure is ignored after High saved-view apply owns the page. Releasing the filter-write queue persists Warning first and High second; the final High filter is not clobbered, the High chip is selected on the current page, and the current result publishes `Showing 1-100 of 101 matching review issues (102 total)`.
- A replacement page fails its saved-view metadata read and starts a held High@0 request; a successful reconstruction restores both saved views as present but unselected (selection is page-local), while stale replacement completion cannot alter the current page. Only the final current High@0 publishes.
- Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`; five held review-query Futures settle (the first filter request and retry are intentionally stale failures), three saved-view reads include exactly one failure, and the two post-baseline metadata writes are Warning then High filter payloads.
- Local review confirms queued filter-write ordering, apply ownership, stale failure isolation, persisted final filter, reconstruction presence/selection semantics, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 89 Operations widget tests, `flutter analyze` with zero issues, 298 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view save remains independent while a filter metadata write is pending, then reconstruction preserves both views and the committed filter.

### 2026-08-31 MergeReview saved-view save independent from pending filter write

- Added one test-only pending filter-write/saved-view-save/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter save` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- While the filter write remains pending, saving `Warning pending filter save` completes independently: its saved-view read/write persists the new Warning view, the new chip appears, and current retry/loading ownership is unchanged. Releasing the filter write afterward persists Warning without clobbering either saved view.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request; completing the disposed retry cannot remove or alter either view. A successful reconstruction restores both views as present but unselected (selection remains page-local), and only the current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), four saved-view reads include exactly one failure (the save mutation performs one read), and the two post-baseline metadata writes are one saved-view save followed by one Warning filter write.
- Local review confirms independent metadata-key sequencing, saved-view persistence, filter-write settlement, disposed-request isolation, fail-open/recovery identity, page-local selection semantics, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 90 Operations widget tests, `flutter analyze` with zero issues, 299 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view save failure leaves the pending filter write and existing view identity intact through reconstruction.

### 2026-08-31 MergeReview saved-view save failure with pending filter write

- Added one test-only pending filter-write/saved-view-save-failure/reconstruction race regression and a controlled mutation-failure fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter save failure` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- A new Warning saved-view save then fails exactly once after its metadata read while the filter write remains pending: no new chip or saved-view write appears, the existing view remains present/unselected, and current retry/loading ownership is unchanged. Releasing the filter write persists Warning independently.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request; completing the disposed retry cannot surface the failed save or alter the replacement page. A successful reconstruction restores only the existing view as present but unselected, and the current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), four saved-view reads include exactly one failure (the failed save mutation performs one read), the only post-baseline metadata write is the Warning filter payload, and the failed saved-view write is attempted exactly once without persistence.
- Local review confirms mutation-failure isolation, pending filter-write settlement, existing-view identity, active retry ownership, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 91 Operations widget tests, `flutter analyze` with zero issues, 300 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view deletion failure leaves the pending filter write and existing view identity intact through reconstruction.

### 2026-08-31 MergeReview saved-view deletion failure with pending filter write

- Added one test-only pending filter-write/saved-view-deletion-failure/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter delete failure` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- Deleting the saved view then fails exactly once after its metadata read while the filter write remains pending: no saved-view write occurs, the existing chip remains present/unselected, and current retry/loading ownership is unchanged. Releasing the filter write persists Warning independently.
- The replacement page fails its saved-view metadata read and starts a held Warning@0 request; completing the disposed retry cannot surface the deletion failure or alter the replacement page. A successful reconstruction restores the existing view as present but unselected, and only the current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), four saved-view reads include exactly one failure (the failed deletion performs one read), the only post-baseline metadata write is the Warning filter payload, and the saved-view delete is attempted exactly once without persistence.
- Local review confirms mutation-failure isolation, pending filter-write settlement, existing-view identity, active retry ownership, disposed-request isolation, saved-view fail-open/recovery identity, current-page publication, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 92 Operations widget tests, `flutter analyze` with zero issues, 301 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view save then deletion serialize correctly while a filter write is pending, preserving only the new view through recovery.

### 2026-08-31 MergeReview saved-view save then deletion with pending filter write

- Added one test-only pending filter-write/two-saved-view-mutations/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter save delete` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- While the filter write remains pending, saving `Warning pending filter save delete` completes, then deleting the old High view completes through the serialized saved-view store. The old chip disappears, the new chip remains, and retry/loading ownership is unchanged.
- Releasing the filter write afterward persists Warning as a separate metadata write; the final saved-view payload contains only the new Warning view. The replacement page fails its saved-view metadata read, and a successful reconstruction restores only that new view as present but unselected.
- Completing the disposed retry cannot resurrect the old view or alter the replacement page; only the current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`, with no review error or Flutter exception.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), five saved-view reads include exactly one failure, and the three post-baseline metadata writes are saved-view save, saved-view delete, then Warning filter.
- Local review confirms saved-view serialization, independent filter-write ordering, final persisted identity, disposed-request isolation, fail-open/recovery identity, page-local selection, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 93 Operations widget tests, `flutter analyze` with zero issues, 302 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a saved-view deletion failure after a prior save preserves the prior save while the pending filter write settles.

### 2026-08-31 MergeReview saved-view deletion failure after prior save with pending filter write

- Added one test-only pending filter-write/save-success/delete-failure/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter save delete failure` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- Saving `Warning pending filter save delete failure` succeeds while the filter write is pending; deleting the old High view then fails exactly once after its metadata read. Both old and new views remain present/unselected, no failed deletion write is recorded, and retry/loading ownership is unchanged.
- Releasing the filter write persists Warning independently. The replacement page fails its saved-view metadata read and starts a held Warning@0 request; a successful reconstruction restores both views as present but unselected, and only the current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`.
- Completing the disposed retry cannot surface the deletion failure or alter the reconstructed page; no review error or Flutter exception remains.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), five saved-view reads include exactly one failure, the two post-baseline writes are the successful saved-view save only plus the Warning filter write, and the failed deletion is attempted exactly once without persistence.
- Local review confirms prior-save retention, deletion-failure isolation, independent filter-write settlement, active retry ownership, disposed-request isolation, saved-view fail-open/recovery identity, page-local selection, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 94 Operations widget tests, `flutter analyze` with zero issues, 303 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a failed first saved-view save does not poison the following delete while the filter write is pending.

### 2026-08-31 MergeReview failed saved-view save followed by deletion with pending filter write

- Added one test-only pending filter-write/save-failure/delete-success/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter failed save delete` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- The first Warning saved-view save fails exactly once after its metadata read while the filter write remains pending; no new view is persisted. The subsequent delete succeeds through the saved-view store, clears the old view, and leaves retry/loading ownership unchanged.
- Releasing the filter write persists Warning independently. The replacement page fails its saved-view metadata read and starts a held Warning@0 request; a successful reconstruction keeps the saved-view list empty, and only the current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`.
- Completing the disposed retry cannot resurrect the deleted view or alter the replacement page; no review error or Flutter exception remains.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), five saved-view reads include exactly one failure, the post-baseline metadata writes are one successful saved-view delete followed by one Warning filter write, and the failed save is attempted exactly once without persistence.
- Local review confirms failed-first-mutation recovery, saved-view queue drainage, independent filter-write settlement, deleted identity, active retry ownership, disposed-request isolation, fail-open/recovery identity, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 95 Operations widget tests, `flutter analyze` with zero issues, 304 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a successful delete followed by a failed save drains the saved-view queue while the filter write remains pending.

### 2026-08-31 MergeReview deletion followed by failed save with pending filter write

- Added one test-only pending filter-write/delete-success/save-failure/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter delete save failure` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- Deleting the old High view succeeds while the filter write is pending, then the following Warning saved-view save fails exactly once after its metadata read. The list remains empty, no failed save is persisted, and retry/loading ownership is unchanged.
- Releasing the filter write persists Warning independently. The replacement page fails its saved-view metadata read and starts a held Warning@0 request; a successful reconstruction keeps the list empty and only the current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`.
- Completing the disposed retry cannot resurrect the deleted view or alter the replacement page; no review error or Flutter exception remains.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first as the intentional filter failure), five saved-view reads include exactly one failure, the post-baseline metadata writes are one successful saved-view delete followed by one Warning filter write, and the failed save is attempted exactly once without persistence.
- Local review confirms queue drainage after the first mutation, second-mutation failure isolation, independent filter-write settlement, empty-list identity, active retry ownership, disposed-request isolation, fail-open/recovery identity, Future settlement, query topology, and side-effect baselines; no blocker was found.
- Verification: 96 Operations widget tests, `flutter analyze` with zero issues, 305 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: the first saved-view save remains persisted when a same-name second save fails while the filter write is pending.

### 2026-08-31 MergeReview second saved-view save failure preserves first with pending filter write

- Added one test-only pending filter-write/double-save/reconstruction race regression and a controlled mutation-failure fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter double save` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- Saving `Warning pending filter double save` succeeds while the filter write remains pending. A same-name second save then fails exactly once after its metadata read; the first saved view remains persisted/present, no second write occurs, and current retry/loading ownership is unchanged.
- Releasing the filter write persists Warning after the successful saved-view write. The replacement page fails its saved-view metadata read and starts a held Warning@0 request; successful reconstruction restores both views as present but unselected (selection remains page-local).
- Completing the disposed retry/replacement request cannot surface the second-save failure or alter the current page; only current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`, with no review error/exception.
- Exact query topology is `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`; four held review-query Futures settle (the first intentional filter failure), five saved-view reads include exactly one failure, post-baseline writes are one successful saved-view save followed by one Warning filter payload, and the second save is attempted once without persistence.
- Local review confirms first-save retention, same-name second-save failure isolation, independent filter-write settlement, active retry ownership, disposed-request isolation, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 97 Operations widget tests, `flutter analyze` with zero issues, 306 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a filter metadata write that fails when released does not roll back a successful saved-view save or change reconstruction identity.

### 2026-08-31 MergeReview filter-write failure after saved-view save

- Added one test-only pending filter-write/release-failure/reconstruction race regression and a controlled post-release filter-write-failure fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High pending filter write failure after save` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- Saving `Warning pending filter write failure after save` succeeds while the filter write remains pending. Releasing that filter write then fails exactly once: the operation status reports the filter persistence failure, no filter payload is recorded, persisted filter remains High, both saved views remain present, and current retry/loading ownership is unchanged.
- A replacement page fails its saved-view metadata read and starts a held High@0 request because the failed filter write left High authoritative. Successful reconstruction restores both views as present but unselected (selection remains page-local); disposed retry/replacement completion cannot surface the filter failure or alter the current page.
- Only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception. Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0]`; four held review-query Futures settle, four saved-view reads include exactly one failure, and only the successful saved-view write is persisted after baseline.
- Local review confirms filter-write failure visibility, saved-view persistence retention, independent queue settlement, active retry ownership, disposed-request isolation, persisted-filter authority, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 98 Operations widget tests, `flutter analyze` with zero issues, 307 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: after a released filter-write failure, a later queued filter write succeeds while a saved-view mutation remains queued, without cross-queue ownership drift.

### 2026-08-31 MergeReview filter-write failure recovery with queued saved-view mutation

- Added one test-only cross-queue pending filter-write/failure-recovery/queued-saved-view/reconstruction race regression and a controlled failure-then-success fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High filter failure queued save` view. The first page changes to Warning, holds the first Warning filter metadata write, fails Warning@0, and starts a held retry.
- Saving `Warning filter failure queued save` is held in the serialized saved-view store. Changing the filter to High queues a second filter write; releasing the first filter write fails exactly once, then the queued High filter write succeeds while the saved-view write remains pending.
- The filter failure is visible in Operation status, persisted filter is High, and the saved-view mutation remains pending without changing retry/loading ownership. Releasing the saved-view write then persists both views after the successful High filter write.
- A failed saved-view metadata read during replacement starts a held High@0 request; successful reconstruction restores both views as present but unselected (selection remains page-local). Disposed Warning/High requests and the stale replacement request cannot override the final current page.
- Only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception. Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`; five held review-query Futures settle, four saved-view reads include exactly one failure, and post-baseline writes are successful High filter then saved-view payload.
- Local review confirms first-filter failure isolation, later-filter recovery, cross-queue independence, saved-view persistence retention, active retry ownership, disposed-request isolation, persisted-filter authority, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 99 Operations widget tests, `flutter analyze` with zero issues, 308 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a queued saved-view deletion remains isolated while filter-write failure recovers and a later filter write succeeds.

### 2026-08-31 MergeReview filter-write failure recovery with queued saved-view deletion

- Added one test-only cross-queue pending filter-write/queued-deletion/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High filter failure queued delete` view. The deletion is held after its metadata read, leaving the chip present and the saved-view payload unchanged.
- While deletion remains pending, the page changes Warning, fails Warning@0, retries, then changes back to High. Releasing the first filter write fails exactly once; the queued High filter write succeeds, while the saved-view deletion remains pending and current retry/loading ownership is unchanged.
- The filter failure is visible in Operation status. Releasing the deletion afterward persists the empty saved-view payload after the successful High filter write; the chip disappears and persisted filter authority remains High.
- A replacement page fails its saved-view metadata read and starts a held High@0 request; successful reconstruction keeps the saved-view list empty. Disposed Warning/High requests and the stale replacement request cannot override the final current page.
- Only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception. Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`; five held review-query Futures settle, four saved-view reads include exactly one failure, and post-baseline writes are successful High filter then saved-view delete payload.
- Local review confirms first-filter failure isolation, later-filter recovery, queued deletion retention/drainage, cross-queue independence, persisted-filter authority, active retry ownership, disposed-request isolation, fail-open/recovery identity, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 100 Operations widget tests, `flutter analyze` with zero issues, 309 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: queued saved-view apply preserves selected-page ownership while filter-write failure recovery completes the later filter write.

### 2026-08-31 MergeReview queued saved-view apply after filter-write failure

- Added one test-only queued saved-view-apply/filter-write-failure/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists High and Warning saved views with High as the authoritative filter. The first page changes to Warning, holds the first Warning filter metadata write, fails Warning@0, and starts a held retry.
- Applying the High saved view queues a High filter write behind the pending Warning write, starts the current High@0 request, and selects the High chip on the current page. Releasing the first write fails exactly once; the queued High write succeeds and the selected chip/current retry ownership remain coherent.
- The filter failure is visible in Operation status. A replacement page fails its saved-view metadata read and starts a held High@0 request; successful reconstruction restores both views as present but unselected (selection remains page-local), while disposed Warning/High requests cannot override the current page.
- Only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception. Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`; five held review-query Futures settle, three saved-view reads include exactly one failure, and only the successful High filter write is persisted after baseline.
- Local review confirms queued apply ownership, first-filter failure isolation, later-filter recovery, selected-page semantics, persisted-filter authority, disposed-request isolation, fail-open/recovery identity, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 101 Operations widget tests, `flutter analyze` with zero issues, 310 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: queued saved-view apply retains current-page ownership during filter failure while a deletion mutation is pending, then the deletion drains without reviving the removed view.

### 2026-08-31 MergeReview queued apply with pending deletion during filter failure

- Added one test-only queued apply/pending deletion/filter-write-failure/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists High and Warning saved views with High as the authoritative filter. Warning-view deletion is held after its metadata read, leaving both chips present and the saved-view payload unchanged.
- While deletion remains pending, the page changes Warning, fails Warning@0, retries, and applies the High saved view. The High write is queued behind the failed Warning write; releasing the first write fails exactly once, then High persists and the High chip remains selected on the current page.
- Releasing deletion afterward persists only the High view; the Warning chip disappears and the filter-failure status does not resurrect it. A replacement page fails its saved-view read, then successful reconstruction keeps only High present and unselected (selection remains page-local).
- Disposed Warning/High requests and the stale replacement request cannot override the current page. Only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception.
- Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`; five held review-query Futures settle, four saved-view reads include exactly one failure, and post-baseline writes are successful High filter then saved-view delete payload.
- Local review confirms queued apply ownership, pending deletion retention/drainage, first-filter failure isolation, later-filter recovery, persisted-filter authority, page-local selection, disposed-request isolation, fail-open/recovery identity, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 102 Operations widget tests, `flutter analyze` with zero issues, 311 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: repeated queued apply interactions remain ordered after filter failure while deletion is pending, and reconstruction preserves the resulting view set without selection.

### 2026-08-31 MergeReview repeated queued applies with pending deletion after filter failure

- Added one test-only repeated-apply/pending-deletion/multi-filter-write/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists High, Warning, and Info saved views with High as the authoritative filter. Info deletion is held after its metadata read, leaving all three chips present and the saved-view payload unchanged.
- While deletion remains pending, the page changes Warning, fails Warning@0, retries, then applies High and Warning saved views in sequence. The two queued filter writes persist in order after the first Warning write fails; Warning remains selected on the current page and deletion remains pending.
- Releasing deletion persists only High and Warning views. A failed saved-view read during replacement starts a held Warning@0 request; successful reconstruction restores High and Warning as present but unselected (selection remains page-local), with Info absent.
- Disposed Warning/High/Warning requests and the stale replacement request cannot override the final current page. Only current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`, with no review error/exception.
- Exact query topology is `[High@0, Warning@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`; six held review-query Futures settle, four saved-view reads include exactly one failure, and post-baseline writes are High filter, Warning filter, then saved-view delete payload.
- Local review confirms repeated apply ordering, pending deletion retention/drainage, first-filter failure isolation, later-filter recovery, persisted-filter authority, current-page selection, page-local reconstruction semantics, disposed-request isolation, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 103 Operations widget tests, `flutter analyze` with zero issues, 312 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: after filter-write failure, a successful saved-view save and subsequent delete retain queue ownership and reconstruction identity.

### 2026-08-31 MergeReview saved-view mutations recover after filter-write failure

- Added one test-only pending filter-write/save-success/delete-after-failure/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High mutations after filter failure` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- Saving `Warning mutations after filter failure` succeeds while the filter write is pending; releasing the filter write then fails exactly once without persisting a filter payload. The saved view remains present and the persisted filter remains High.
- Deleting the newly saved Warning view succeeds after the filter failure, leaving only the original High view. A replacement page fails its saved-view metadata read and starts a held High@0 request; successful reconstruction restores only High as present but unselected (selection remains page-local).
- Completing disposed/replacement requests cannot resurrect the deleted view or alter the current page; only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception.
- Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0]`; four held review-query Futures settle, five saved-view reads include exactly one failure, post-baseline writes are saved-view save then saved-view delete, and the failed filter write is attempted once without persistence.
- Local review confirms saved-view mutation recovery, filter-write failure isolation, persisted-filter authority, active retry ownership, disposed-request isolation, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 104 Operations widget tests, `flutter analyze` with zero issues, 313 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: repeated saved-view save/delete attempts after filter-write failure remain ordered and preserve reconstruction identity.

### 2026-08-31 MergeReview repeated saved-view mutations survive filter-write failure

- Added one test-only repeated saved-view save/delete/filter-failure/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High repeated mutations after filter failure` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- Saving `Warning before filter failure repeated` succeeds while the filter write is pending. Releasing that filter write then fails exactly once without persisting a filter payload; the persisted filter remains High and the failure status is visible.
- After the filter failure, a first Warning saved view is saved and deleted, then a second Warning saved view is saved and deleted. Each mutation drains in order; the final persisted list retains only the original High view and the pre-failure Warning view.
- A replacement page fails its saved-view metadata read and starts a held High@0 request; successful reconstruction restores those two views as present but unselected (selection remains page-local). Completing disposed/replacement requests cannot resurrect either deleted view or alter the current page.
- Only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception. Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0]`; four held review-query Futures settle, eight saved-view reads include exactly one failure, five post-baseline writes are save/delete/save/delete plus the pre-failure save, and the failed filter write is attempted once without persistence.
- Local review confirms repeated mutation ordering, post-failure queue ownership, filter-write failure isolation, persisted-filter authority, saved-view identity retention, active retry ownership, disposed-request isolation, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 105 Operations widget tests, `flutter analyze` with zero issues, 314 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a saved-view save held across filter failure/recovery and a subsequent delete remain serialized without changing the recovered filter authority.

### 2026-08-31 MergeReview saved-view save/delete queue survives filter-write failure recovery

- Added one test-only saved-view save/delete plus queued filter-failure/recovery/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High save delete filter recovery` view. The first page changes to Warning, holds the Warning filter metadata write, fails Warning@0, and starts a held inline retry.
- A new Warning saved-view write remains pending while the page changes back to High and queues a second filter write. Releasing the first filter write fails exactly once; the queued High filter write succeeds while the saved-view write remains pending.
- Completing the saved-view write persists both views; deleting the old High view then drains the next serialized saved-view mutation, leaving only the new Warning view. The failed filter write produces no payload and persisted filter authority remains High.
- A replacement page fails its saved-view metadata read and starts a held High@0 request; successful reconstruction restores only the new Warning view as present but unselected (selection remains page-local). Completing disposed/replacement requests cannot resurrect the deleted High view or alter the current page.
- Only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception. Exact query topology is `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`; five held review-query Futures settle, five saved-view reads include exactly one failure, post-baseline writes are successful High filter then saved-view save/delete, and the failed filter write is attempted once without persistence.
- Local review confirms cross-queue failure/recovery ordering, saved-view save/delete serialization, persisted-filter authority, saved-view identity retention, active retry ownership, disposed-request isolation, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 106 Operations widget tests, `flutter analyze` with zero issues, 315 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a later filter failure leaves a second saved-view mutation pending, and its eventual success preserves the recovered filter authority and both saved-view identities.

### 2026-08-31 MergeReview later filter failure isolates a queued saved-view mutation

- Added one test-only repeated cross-queue filter-failure/saved-view-mutation/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and `High later filter failure` view. The first Warning filter write fails, a held Warning retry remains active, and a first Warning saved-view write stays pending while the queued High filter write recovers successfully.
- Completing the first saved-view write and deleting the old High view leaves one Warning view. A later Warning filter write then fails while a second Warning saved-view write remains pending; completing that write persists both Warning views without a filter payload from the second failure.
- Persisted filter authority remains High and the second filter failure is visible. A replacement page fails its saved-view metadata read and starts a held High@0 request; successful reconstruction restores both Warning views as present but unselected (selection remains page-local).
- Completing all disposed/replacement requests cannot resurrect the deleted High view or alter the current page. Only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception.
- Exact query topology is `[High@0, Warning@0, Warning@0, High@0, Warning@0, High@0, High@0]`; six held review-query Futures settle, six saved-view reads include exactly one failure, post-baseline writes are High filter, saved-view save, saved-view delete, saved-view save, and both failed filter writes produce no payload.
- Local review confirms repeated cross-queue failure isolation, later saved-view queue ownership, saved-view identity retention, persisted-filter authority, active retry ownership, disposed-request isolation, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 107 Operations widget tests, `flutter analyze` with zero issues, 316 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: saved-view deletion during a third filter recovery remains independent after a later filter failure and does not revive the deleted identity.

### 2026-08-31 MergeReview saved-view deletion survives third filter recovery after later failure

- Added one test-only later-filter-failure/queued-deletion/third-filter-recovery/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and two Warning saved views. The first Warning filter write succeeds; a later High filter write then fails exactly once, leaving Warning as persisted authority and the failure status visible.
- A third Warning filter write is held while the second Warning saved view is deleted. The deletion persists first and the third filter write then succeeds; the deleted view stays absent and only the first Warning view remains.
- A replacement page fails its saved-view metadata read and starts a held Warning@0 request; successful reconstruction restores only the first Warning view as present but unselected (selection remains page-local). Completing all disposed/replacement requests cannot resurrect the deleted view or alter the current page.
- Only current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`, with no review error/exception. Exact query topology is `[High@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`; five held review-query Futures settle, four saved-view reads include exactly one failure, post-baseline writes are Warning filter, saved-view delete, Warning filter, and the failed High filter produces no payload.
- Local review confirms later filter-failure isolation, third-filter recovery, concurrent deletion ordering, saved-view identity retention, persisted-filter authority, disposed-request isolation, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 108 Operations widget tests, `flutter analyze` with zero issues, 317 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: a saved-view deletion failure during a subsequent filter recovery preserves both identities, then retries cleanly after the third filter write succeeds.

### 2026-08-31 MergeReview saved-view deletion failure preserves identity across filter recovery

- Added one test-only deletion-failure/third-filter-recovery/retry/reconstruction race regression and a controlled saved-view mutation-failure fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and two Warning saved views. The first Warning filter write succeeds; a later High filter write fails exactly once, leaving Warning as persisted authority and exposing the filter failure.
- A third Warning filter write is held while deletion of the second Warning view fails exactly once. The failed deletion leaves both saved views and produces no saved-view payload; the third filter write then succeeds without changing those identities.
- Retrying the deletion succeeds after filter recovery, leaving only the first Warning view. A replacement page fails its saved-view metadata read and starts a held Warning@0 request; successful reconstruction restores only the remaining view as present but unselected (selection remains page-local).
- Completing all disposed/replacement requests cannot resurrect the deleted view or alter the current page. Only current Warning@0 publishes `Showing 1 of 1 matching review issues (102 total)`, with no review error/exception.
- Exact query topology is `[High@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`; five held review-query Futures settle, five saved-view reads include exactly one failure, post-baseline writes are Warning filter, Warning filter, saved-view delete, and the failed High filter plus failed deletion produce no payload.
- Local review confirms deletion-failure identity retention, third-filter recovery ordering, retry ownership, persisted-filter authority, disposed-request isolation, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 109 Operations widget tests, `flutter analyze` with zero issues, 318 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: after a failed deletion, a later saved-view save and retry delete remain isolated while a fourth filter write recovers.

### 2026-08-31 MergeReview failed deletion survives later saved-view mutation and filter recovery

- Added one test-only failed-deletion/later-save/retry-delete/fourth-filter-recovery/reconstruction race regression and a controlled saved-view mutation-failure fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and two Warning saved views. The first Warning filter write succeeds; a later High filter write fails exactly once, leaving Warning as persisted authority and exposing the filter failure.
- A third Warning filter write is pending while deletion of the second Warning view fails exactly once, preserving both identities. After that recovery, a fourth High filter write is held while a new High saved view is saved and the failed deletion is retried successfully.
- The final persisted list contains the first Warning view and the new High view; the failed High filter and failed deletion produce no extra payload, and the fourth High filter write restores High authority.
- A replacement page fails its saved-view metadata read and starts a held High@0 request; successful reconstruction restores both remaining views as present but unselected (selection remains page-local). Completing disposed/replacement requests cannot resurrect the deleted view or alter the current page.
- Only current High@0 publishes `Showing 1-100 of 101 matching review issues (102 total)`, with no review error/exception. Exact query topology is `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`; six held review-query Futures settle, six saved-view reads include exactly one failure, post-baseline writes are Warning filter, Warning filter, saved-view save, saved-view delete, High filter, and the failed High filter plus failed deletion produce no payload.
- Local review confirms failed-deletion identity retention, later saved-view mutation ordering, fourth-filter recovery, persisted-filter authority, retry ownership, disposed-request isolation, fail-open/recovery identity, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 110 Operations widget tests, `flutter analyze` with zero issues, 319 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: after retry-delete, a later saved-view save failure remains isolated while the fourth filter recovery completes, then retry save restores the intended identities.

### 2026-08-31 MergeReview failed save recovers after deletion retry and filter recovery

- Added one test-only failed-deletion/retry-delete/later-save-failure/fourth-filter-recovery/reconstruction race regression and reused the controlled saved-view mutation-failure fixture; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and two Warning saved views. The first Warning filter write succeeds; a later High filter write fails once, leaving Warning as persisted authority and exposing the filter failure.
- A third Warning filter write is held while deletion of the second Warning view fails once. The third write recovers, retry deletion succeeds, and only the first Warning view remains.
- A fourth High filter write is held while saving a replacement High view fails once. Releasing the fourth write restores High authority; retry save then persists the first Warning plus replacement High identities. Failed filter, deletion, and save attempts produce no payload.
- A replacement saved-view read fails then recovers; current High@0 publishes only `Showing 1-100 of 101 matching review issues (102 total)`. Disposed and replacement requests cannot override the current page; no review error or exception remains.
- Exact query topology is `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`; six held review-query Futures settle, seven saved-view reads include exactly one failure, and successful post-baseline writes are Warning filter, Warning filter, saved-view delete, High filter, then saved-view save. The final app-meta write-key order is asserted.
- Local review confirms failed-save isolation, retry-delete ordering, fourth-filter recovery, saved-view identity retention, persisted-filter authority, reconstruction fail-open/recovery, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 111 Operations widget tests, `flutter analyze` with zero issues, 320 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: after retry-delete, a later saved-view deletion remains independent while the next High filter write is pending, then both settle in order.

### 2026-08-31 MergeReview post-retry saved-view deletion survives a later filter write

- Added one test-only failed-deletion/retry-delete/post-retry-deletion/later-filter-write/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and two Warning saved views. Warning filter metadata is held while deletion of the second Warning view fails once; releasing the filter write succeeds, and retry deletion leaves only the first Warning view.
- A later High filter write is then held while deleting the remaining first Warning view. The deletion succeeds independently and persists an empty saved-view list before the pending High filter write is released; the in-flight filter Future remains unsettled until explicitly completed.
- Releasing the later High filter write persists High authority. Failed deletion produces no payload; successful writes are exactly Warning filter, saved-view delete, saved-view delete, then High filter, with the final app-meta write-key order asserted.
- Replacement saved-view read fails then recovers; current High@0 publishes only `Showing 1-100 of 101 matching review issues (102 total)`. Disposed and replacement requests cannot override the current page; no review error or exception remains and both deleted identities stay absent.
- Exact query topology is `[High@0, Warning@0, High@0, High@0, High@0]`; four held review-query Futures settle, six saved-view reads include exactly one failure, and the final page count is `Showing 1-100 of 101 matching review issues (102 total)`.
- Local review confirms retry-delete ordering, post-retry deletion independence, later filter-write ownership, saved-view identity absence, persisted-filter authority, reconstruction fail-open/recovery, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 112 Operations widget tests, `flutter analyze` with zero issues, 321 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: after the saved-view list becomes empty, a later save remains independent during another filter recovery and reconstruction restores only the new identity.

### 2026-08-31 MergeReview empty saved-view list accepts a later save during filter recovery

- Added one test-only failed-deletion/retry-delete/empty-list/later-save/filter-recovery/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and one Warning saved view. Warning filter metadata is held while the only saved-view deletion fails once; releasing the filter succeeds, and retry deletion persists an empty saved-view list.
- A later High filter write is held after the list is empty. Saving a replacement High view succeeds independently and persists the one new identity before the pending High filter Future is released; the persisted filter remains Warning until release.
- Releasing the later High filter restores High authority. Failed deletion produces no payload; successful writes are exactly Warning filter, saved-view delete, saved-view save, then High filter, with the final app-meta write-key order asserted.
- Replacement saved-view read fails then recovers; current High@0 publishes only `Showing 1-100 of 101 matching review issues (102 total)`. Disposed and replacement requests cannot override the current page; the deleted identity stays absent, the replacement is present/unselected, and no review error or exception remains.
- Exact query topology is `[High@0, Warning@0, High@0, High@0, High@0]`; four held review-query Futures settle and six saved-view reads include exactly one failure.
- Local review confirms empty-list transition, post-empty save independence, later filter-write ownership, retry-delete ordering, saved-view identity replacement, persisted-filter authority, reconstruction fail-open/recovery, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 113 Operations widget tests, `flutter analyze` with zero issues, 322 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Follow-up completed in the section below: after the empty-list save failure, retry save and a later deletion remain isolated across another filter recovery.

### 2026-08-31 MergeReview post-empty saved-view save failure recovers before later deletion

- Added one test-only failed-deletion/retry-delete/empty-list/save-failure/retry-save/later-deletion/filter-recovery/reconstruction race regression; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and one Warning saved view. Warning filter metadata is held while the only deletion fails once; releasing the filter succeeds, and retry deletion persists an empty saved-view list.
- A later High filter write is held while the first replacement save fails once. The failed save leaves the list empty and creates no payload; releasing the High filter restores authority, and retry save persists exactly one replacement High view.
- A subsequent Warning filter write is held while deleting that replacement view. Deletion succeeds independently and persists an empty list before the filter Future is released; releasing the filter then restores Warning authority.
- Replacement saved-view read fails then recovers; current Warning@0 publishes only `Showing 1 of 1 matching review issues (102 total)`. Disposed and replacement requests cannot override the current page; both deleted identities stay absent and no review error or exception remains.
- Exact query topology is `[High@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`; five held review-query Futures settle, eight saved-view reads include exactly one failure, and successful post-baseline writes are Warning filter, saved-view delete, High filter, saved-view save, saved-view delete, then Warning filter. The final app-meta write-key order is asserted.
- Local review confirms post-empty save failure isolation, retry-save ordering, later deletion independence, filter-write ownership, saved-view identity absence, persisted-filter authority, reconstruction fail-open/recovery, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 114 Operations widget tests, `flutter analyze` with zero issues, 323 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Next slice: inspect whether a post-empty retry-save can race a later saved-view apply during filter recovery, then add one bounded regression if a distinct gap remains.

### 2026-08-31 MergeReview post-empty retry-save survives a queued saved-view apply

- Added one test-only failed-deletion/retry-delete/empty-list/save-failure/retry-save/queued-apply/third-filter-recovery/reconstruction race regression and reused the controlled saved-view mutation fixtures; production code, interfaces, and behavior remain unchanged.
- A 102-issue backlog fixture persists the High review filter and one Warning saved view. Warning filter metadata is held while the first deletion fails once; releasing the write succeeds, retry deletion persists an empty saved-view list, and the failed deletion produces no payload.
- A later High filter write is held while the first replacement save fails once. The failed save leaves the list empty and creates no payload; releasing the High write restores High authority, and retry save persists exactly one replacement High view.
- A subsequent Warning filter write is held while the replacement High view is applied. The apply queues behind the active Warning filter write; releasing that write fails once, then the queued High apply filter write succeeds and persists High authority. The replacement chip remains selected during the queued apply and after recovery.
- Replacement saved-view metadata read fails then recovers; current High@0 publishes only `Showing 1-100 of 101 matching review issues (102 total)`. Disposed and replacement requests cannot override the current page; the replacement view is restored present but unselected (selection remains page-local), with no review error or exception.
- Exact query topology is `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`; six held review-query Futures settle, seven saved-view reads include exactly one failure, and successful post-baseline writes are Warning filter, saved-view delete, High filter, saved-view save, then High filter. The final app-meta write-key order is asserted.
- Local review confirms post-empty retry-save isolation, queued saved-view apply ordering, active filter-failure ownership, persisted-filter authority, saved-view identity retention, reconstruction fail-open/recovery, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 115 Operations widget tests, `flutter analyze` with zero issues, 324 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Next slice: inspect whether repeated queued saved-view applies after a recovered retry-save can leave a stale chip selection or extra filter write, then add one bounded regression if a distinct gap remains.

### 2026-08-31 MergeReview recovered retry-save drains repeated queued saved-view applies

- Added one test-only recovered-retry-save/repeated-queued-apply/third-filter-recovery/reconstruction race regression; the controlled saved-view store is preconditioned through failed deletion and failed High save retries plus a second Warning view, while production code, interfaces, and behavior remain unchanged.
- The precondition leaves one recovered High view and one second Warning view after an empty-list transition. A held Warning filter write then receives High, Warning, and High saved-view applies in sequence; only the first active Warning write fails, and all three queued filter writes drain in order as High, Warning, High.
- Persisted filter authority therefore converges to High, the High chip remains selected through the active failure and queued recovery, and no failed filter payload is recorded. The saved-view mutation retry baseline records exactly two failed writes during preconditioning and no page-side mutation.
- Replacement saved-view metadata read fails then recovers; current High@0 publishes only `Showing 1-100 of 101 matching review issues (102 total)`. Disposed and replacement requests cannot override the current page; both saved views return present but unselected (selection remains page-local), with no review error or exception.
- Exact page query topology is `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`; six held review-query Futures settle, the page lifecycle adds three saved-view reads with exactly one failure, and successful page-side writes are High filter, Warning filter, then High filter. The final app-meta write-key and value order is asserted.
- Local review confirms recovered retry-save preconditioning, repeated queued apply ordering, active filter-failure ownership, persisted-filter authority, selection convergence, reconstruction fail-open/recovery, page-local selection, Future settlement, topology, and side-effect baselines; no blocker was found.
- Verification: 117 Operations widget tests, `flutter analyze` with zero issues, 326 full tests, `git diff --check`, and strict `CI=true ./tool/ci_checks.sh` including 14 importer tests, all compare gates, and Web build passed.
- Next slice: inspect whether a saved-view deletion or save queued behind repeated applies can commit after the final filter authority and leave an obsolete identity, then add one bounded regression if a distinct gap remains.

### 2026-08-31 Canonical release adoption and local old-ref cleanup

- Adopted the latest local release/development ref `codex/public-github-launch` at `534ffdf`; no duplicate release files, archives, package artifacts, backup/copy files, or same-content source/document pairs were found in the workspace.
- Removed only four local Git refs that were verified strict ancestors of the adopted ref: `main` (`0405fcd`), `codex/initial-import` (`6f8fb87`), `automation/importer-de-20260525` (`6f8fb87`), and `automation/importer-fi-20260525` (`6f8fb87`). No source, test, build artifact, or remote branch was deleted.
- Kept `origin/codex/initial-import` as an untouched remote tracking ref because upstream branch deletion needs separate remote authority; the exact hash and local-ref recreation procedure are recorded in `docs/timeline/2026-08-31-slice88-release-prune-audit.md`.
- Updated the existing release notes with a canonical-version retention rule: future iterations modify canonical files, add only an incremental unique timeline entry, and verify ancestor status before any local old-ref cleanup.
- Verification inheritance: the Slice87/cleanup baseline has 117 Operations widget tests, 326 full tests, zero `flutter analyze` issues, `git diff --check`, and strict CI with 14 importer tests, compare gates, and Web build; Slice88 itself changes only release documentation, timeline metadata, and local refs.
- Rollback: recreate any removed local ref from its recorded commit hash; do not reset or overwrite unrelated working-tree changes.
- Next slice: inspect production release readiness gaps that are not duplicate artifacts (for example, reproducible version metadata and a clean release preflight) using the same incremental-file and timeline rules.

### 2026-08-31 Reproducible release metadata and clean preflight

- Added the incremental `tool/check_release_metadata.dart` preflight; it validates the single top-level SemVer `pubspec.yaml` version with a positive build number, the generated `pubspec.lock` SDK section, and Android/iOS/macOS version handoff placeholders without changing workspace files.
- Added optional `--require-clean` and `--canonical-ref <ref>` gates for an intentional release cut. The default local check remains non-mutating and does not reject this ongoing working tree; GitHub Actions runs the clean-worktree gate on its clean checkout.
- Wired the preflight into the existing `tool/ci_checks.sh` and `.github/workflows/flutter-ci.yml`; extended the existing CI workflow tests with current-metadata, malformed-version, and wiring regressions.
- Updated the existing release notes with the reproducible command and deterministic JSON contract. No full-content copy or release snapshot was created; `docs/timeline/2026-08-31-slice89-release-metadata-preflight.md` is the only new iteration log.
- Verification: focused `ci_workflow_test.dart` passed (`+25`), `flutter analyze` reported zero issues, full Flutter tests passed (`+329`), `git diff --check` passed, and strict `CI=true ./tool/ci_checks.sh` passed with 14 importer tests, all compare gates, deterministic release metadata output, and Web build.
- Rollback: remove only the preflight invocation/docs/test additions and the unique Slice89 timeline entry; preserve the canonical source and release files.
- Next slice: inspect another bounded production-readiness gap (artifact provenance or release configuration drift) without duplicating canonical content.

### 2026-08-31 Deterministic Web artifact provenance

- Added the incremental `tool/build_release_provenance.dart` generator. It walks a built artifact without following symlinks, sorts relative paths, records byte counts and SHA-256 digests, and writes only a JSON manifest outside the artifact directory; the self-contained hash implementation keeps the custom CI package config portable.
- Wired the existing local CI wrapper to generate `build/datahookclaws-web.provenance.json` after the Web build. GitHub Actions generates the same manifest with `GITHUB_SHA` as optional source provenance and uploads it alongside `build/web`.
- Extended existing CI workflow tests with deterministic ordering/byte-for-byte regeneration, known SHA-256 coverage, output-boundary protection, and upload wiring. No application runtime behavior or full-content copy changed.
- Updated the existing release notes with the manifest command and retention boundary; `docs/timeline/2026-08-31-slice90-release-provenance.md` is the only new iteration log.
- Verification: focused `ci_workflow_test.dart` passed (`+27`), `flutter analyze` reported zero issues, full Flutter tests passed (`+331`), `git diff --check` passed, strict CI passed with 14 importer tests, all compare gates, Web build, and provenance generation; all 39 Web manifest digests matched system `shasum`.
- Rollback: remove only the provenance generator/invocations, incremental docs/test lines, and this unique timeline entry; preserve the Web build and canonical source files.
- Next slice: inspect one bounded release-configuration drift or artifact-consumption gap without creating duplicate canonical content.

### 2026-08-31 Web artifact provenance verification

- Extended the existing `tool/build_release_provenance.dart` generator with a read-only `--verify` mode. It recomputes the artifact snapshot and rejects manifest schema, metadata, file-order, byte-count, SHA-256, or supplied source-revision drift before upload.
- Wired verification directly after generation in both `tool/ci_checks.sh` and GitHub Actions; the upload now has a tested build→generate→verify→upload sequence. No extra manifest copy or runtime application change was introduced.
- Extended the existing CI workflow test with successful verification and tampered-artifact failure coverage, and documented the verification command in the existing release notes. `docs/timeline/2026-08-31-slice91-provenance-verification.md` is the only new iteration log.
- Verification: focused `ci_workflow_test.dart` passed (`+27`), `flutter analyze` reported zero issues, full Flutter tests passed (`+331`), `git diff --check` passed, strict CI passed with 14 importer tests, all compare gates, Web build, provenance generation, and provenance verification.
- Rollback: remove only the verify mode, CI verification invocations, incremental docs/test lines, and this unique timeline entry; keep the already-established provenance generator and canonical Web build path.
- Next slice: inspect one bounded release-configuration drift or artifact-consumption gap without creating duplicate canonical content.

### 2026-08-31 Android release signing gate

- Extended the existing `tool/check_release_metadata.dart` preflight with the
  opt-in `--require-release-signing` gate. It parses the Android `release`
  build-type block, requires an explicit `signingConfig`, and rejects debug
  signing or the template TODO before a distributable artifact is cut.
- Kept the default local/GitHub CI metadata invocation unchanged because the
  checked-in development configuration intentionally uses the debug key for
  local release runs; the intentional release-cut command in
  `docs/release_packaging.md` now enables the production gate explicitly.
- Extended the existing `test/domain/ci_workflow_test.dart` with a regression
  proving the current debug configuration fails fast and with release-command
  wiring coverage. No runtime code or full-content copy was added; the unique
  iteration log is `docs/timeline/2026-08-31-slice92-release-signing-gate.md`.
- Verification: focused `ci_workflow_test.dart` passed (`+28`), full Flutter
  tests passed (`+332`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  14 importer tests, all compare gates, Web build, provenance generation, and
  provenance verification; the production gate correctly returns exit 1 with
  a debug-signing diagnostic.
- Rollback: remove only the optional signing checker, its focused regressions,
  release-note flag, and this timeline entry; preserve default metadata and
  provenance checks.
- Next slice: inspect one bounded iOS/macOS release-signing or artifact
  consumption contract without duplicating canonical content.

### 2026-08-31 Apple release signing gate

- Extended the existing `tool/check_release_metadata.dart` preflight with the
  opt-in `--require-apple-signing` gate. It inspects every iOS and macOS Xcode
  `Release` configuration, rejects development/placeholder identities, and
  requires either a `DEVELOPMENT_TEAM` or an explicit distribution identity.
- Kept Apple credentials, provisioning profiles, and notarization external to
  the repository. The intentional release-cut command in
  `docs/release_packaging.md` now enables both Android and Apple safety gates;
  ordinary local/GitHub CI remains unchanged.
- Extended the existing `test/domain/ci_workflow_test.dart` with a regression
  proving the checked-in iOS/macOS template is rejected and with release-command
  wiring coverage. No runtime code or full-content copy was added; the unique
  iteration log is `docs/timeline/2026-08-31-slice93-apple-signing-gate.md`.
- Verification: focused `ci_workflow_test.dart` passed (`+29`), full Flutter
  tests passed (`+333`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  14 importer tests, all compare gates, Web build, provenance generation, and
  provenance verification; the production gate returns exit 1 with actionable
  iOS/macOS identity diagnostics.
- Rollback: remove only the optional Apple checker, its focused regression,
  release-note flag, and this timeline entry; preserve Android/default metadata
  and provenance checks.
- Next slice: inspect one bounded release artifact consumption or platform
  packaging contract without duplicating canonical content.

### 2026-08-31 Web artifact upload contract

- Tightened the existing GitHub Actions `datahookclaws-web` upload contract:
  `if-no-files-found: error` now fails the job when either the Web build or
  provenance manifest is absent, and `retention-days: 14` makes the CI artifact
  lifecycle explicit.
- Kept the artifact contents bounded to `build/web` plus its sibling
  `datahookclaws-web.provenance.json`; no source copy or second packaging path
  was introduced. The existing CI workflow test now locks the upload options,
  and the Web release notes document the extraction/retention contract.
- No application runtime behavior changed; the unique iteration log is
  `docs/timeline/2026-08-31-slice94-web-artifact-upload-contract.md`.
- Verification: focused `ci_workflow_test.dart` passed (`+29`), full Flutter
  tests passed (`+333`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  14 importer tests, all compare gates, Web build, provenance generation, and
  provenance verification.
- Rollback: remove only the two upload options, the incremental test/docs
  assertions, and this timeline entry; preserve the existing build,
  provenance, and verification steps.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web title parity contract

- Added the bounded `--require-web-title-parity` provenance gate. It requires
  exactly one non-empty `<title>` in canonical and generated `index.html` and
  compares the trimmed title text to prevent browser-title drift after a Web
  build.
- Wired the gate into local and GitHub provenance generation and verification,
  with focused regressions for a valid title, changed title, duplicate titles,
  and an empty title. The unique iteration log is
  `docs/timeline/2026-09-01-slice119-web-title-parity.md`.
- Verification: focused workflow tests passed (`+53`), full Flutter tests
  passed (`+357`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/base-href/metadata/PWA/identity/viewport/
  language/title/icon/theme/service-worker/version/manifest/revision gates,
  provenance generation, and provenance verification.
- Rollback: remove only the title-parity checker, its local/CI arguments,
  focused test/docs lines, and this timeline entry; preserve the existing shell,
  language, accessibility, PWA, and hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web shell product metadata

- Replaced the default Flutter template description in `web/manifest.json` and
  `web/index.html` with the verified product-facing description used by the
  README: a local-first nutrition database built from official
  food-composition sources.
- Added a focused regression for both Web shell source files and documented the
  boundary in the existing release notes. The unique iteration log is
  `docs/timeline/2026-09-01-slice106-web-shell-metadata.md`.
- Verification: focused workflow tests passed (`+40`), full Flutter tests
  passed (`+344`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/version/manifest gates, provenance generation, and
  provenance verification.
- Rollback: restore the prior description strings, remove the focused
  assertion, release-note sentence, and this timeline entry; preserve manifest
  identity and provenance gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Checkout credential isolation

- Set `persist-credentials: false` on the existing `actions/checkout@v4` step,
  preventing the release-evidence job from leaving a GitHub token in its
  workspace after source retrieval.
- Added a focused workflow regression and documented the boundary in the
  existing release notes. The unique iteration log is
  `docs/timeline/2026-09-01-slice103-checkout-credential-isolation.md`.
- Verification: focused workflow tests passed (`+37`), full Flutter tests
  passed (`+341`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, provenance generation, and provenance verification.
- Rollback: remove only the checkout option, focused assertion, release-note
  sentence, and this timeline entry; preserve the other release-evidence
  gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Explicit Web release-mode packaging

- Changed the GitHub Actions and local CI Web build commands to
  `flutter build web --release`, making the release-evidence build mode
  explicit rather than relying on a default.
- Added a focused workflow/script regression and updated the existing Web
  packaging command. The unique iteration log is
  `docs/timeline/2026-09-01-slice102-web-release-mode.md`.
- Verification: focused workflow tests passed (`+36`), full Flutter tests
  passed (`+340`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, provenance generation, and provenance verification.
- Rollback: restore the prior build arguments, remove the focused assertion,
  documentation change, and this timeline entry; preserve provenance/version
  gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Release-evidence lockfile reproducibility

- Changed GitHub Actions and the local strict-check wrapper to run
  `flutter pub get --enforce-lockfile`, so release evidence cannot silently
  resolve a dependency set different from checked-in `pubspec.lock`.
- Added a focused workflow/script regression and documented the boundary in the
  existing release notes. The unique iteration log is
  `docs/timeline/2026-09-01-slice101-lockfile-reproducibility.md`.
- Verification: focused workflow tests passed (`+35`), full Flutter tests
  passed (`+339`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, Web build,
  provenance generation, and provenance verification.
- Rollback: restore plain `flutter pub get`, remove the local gate, focused
  assertion, release-note paragraph, and this timeline entry; preserve other
  release-evidence gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 CI release-evidence timeout contract

- Added a 30-minute timeout to the existing release-evidence job, preventing a
  stalled dependency or Web build from consuming CI capacity indefinitely.
- Added a focused workflow regression and documented the boundary in the
  existing release notes. The unique iteration log is
  `docs/timeline/2026-09-01-slice100-ci-timeout.md`.
- Verification: focused workflow tests passed (`+34`), full Flutter tests
  passed (`+338`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  14 importer tests, all compare gates, Web build, provenance generation, and
  provenance verification.
- Rollback: remove only the timeout, focused assertion, release-note sentence,
  and this timeline entry; preserve permissions, concurrency, and
  artifact/provenance checks.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 CI release-evidence concurrency contract

- Added workflow-level concurrency grouping by workflow and Git ref with
  `cancel-in-progress: true`, so a superseded run cannot keep producing
  competing release evidence. Already uploaded artifacts are not deleted.
- Added a focused workflow regression and documented the cancellation boundary
  in the existing release notes. The unique iteration log is
  `docs/timeline/2026-09-01-slice99-ci-concurrency.md`.
- Verification: focused workflow tests passed (`+33`), full Flutter tests
  passed (`+337`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  14 importer tests, all compare gates, Web build, provenance generation, and
  provenance verification.
- Rollback: remove only the concurrency block, focused assertion, release-note
  paragraph, and this timeline entry; preserve permissions and
  artifact/provenance checks.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 CI release-evidence read-only permissions

- Added a workflow-level `permissions: contents: read` contract to the
  existing GitHub Actions workflow. The release-evidence job can check out
  source and upload its scoped CI artifact without repository-write authority;
  future deployment must use a separately reviewed permission grant.
- Added a focused workflow regression and documented the boundary in the
  existing release notes. The unique iteration log is
  `docs/timeline/2026-09-01-slice98-ci-read-only-permissions.md`.
- Verification: focused workflow tests passed (`+32`), full Flutter tests
  passed (`+336`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  14 importer tests, all compare gates, Web build, provenance generation, and
  provenance verification.
- Rollback: remove only the permission block, focused assertion, release-note
  paragraph, and this timeline entry; preserve artifact/provenance checks.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-08-31 Hidden Web build metadata parity

- Audited the existing Web artifact against the provenance generator and found
  Flutter's `build/web/.last_build_id` hidden file. The generator hashes it,
  while `actions/upload-artifact@v4` otherwise excludes hidden files, which
  could make a downloaded artifact diverge from its manifest.
- Added `include-hidden-files: true` to the existing upload step and extended
  the existing CI workflow regression. The release notes now state that hidden
  build metadata is intentionally included; no source copy or second artifact
  path was introduced. The unique iteration log is
  `docs/timeline/2026-08-31-slice95-hidden-artifact-parity.md`.
- Verification: focused `ci_workflow_test.dart` passed (`+29`), full Flutter
  tests passed (`+333`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  14 importer tests, all compare gates, Web build, provenance generation, and
  provenance verification.
- Rollback: remove only the hidden-file upload option, incremental test/docs
  assertions, and this timeline entry; preserve the existing artifact,
  provenance, and fail-on-missing-input contract.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-08-31 Production platform identifiers

- Extended the existing `tool/check_release_metadata.dart` preflight with the
  opt-in `--require-production-identifiers` gate. It rejects template or
  unresolved Android `applicationId` and iOS/macOS Release
  `PRODUCT_BUNDLE_IDENTIFIER` values, while ignoring test-only bundle IDs.
- Added the flag to the intentional release-cut command and documented the
  current `com.example...` values as a deliberate fail-fast blocker. Default
  local/GitHub CI remains unchanged; no runtime code or full-content copy was
  added.
- Extended the existing `test/domain/ci_workflow_test.dart` with a three-
  platform rejection regression and command-wiring assertion. The unique
  iteration log is
  `docs/timeline/2026-08-31-slice96-production-identifiers.md`.
- Verification: focused `ci_workflow_test.dart` passed (`+30`), full Flutter
  tests passed (`+334`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  14 importer tests, all compare gates, Web build, provenance generation, and
  provenance verification.
- Rollback: remove only the optional identifier checker, focused regression,
  release-note flag, and this timeline entry; preserve all existing signing,
  metadata, artifact, and provenance gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-08-31 Web version provenance contract

- Extended the existing `tool/build_release_provenance.dart` with opt-in
  `--require-web-version` validation. It parses Flutter's generated
  `version.json` and requires `app_name`, `package_name`, semantic version, and
  build number to match canonical `pubspec.yaml` metadata.
- Enabled the flag for both local and GitHub Web provenance generation and
  verification, so a stale or hand-edited build version fails before artifact
  upload. The existing provenance manifest remains the only evidence file; no
  source copy or second artifact path was added.
- Extended `test/domain/ci_workflow_test.dart` with a positive version-file
  check, verify-mode tamper failure, and local/workflow wiring assertions. The
  unique iteration log is
  `docs/timeline/2026-08-31-slice97-web-version-provenance.md`.
- Verification: focused `ci_workflow_test.dart` passed (`+31`), full Flutter
  tests passed (`+335`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  14 importer tests, all compare gates, Web build, provenance generation, and
  provenance verification (including the Web version gate).
- Rollback: remove only the optional version-file checker, its CI arguments,
  focused test/docs lines, and this timeline entry; preserve base provenance
  generation and verification.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Core Web shell provenance contract

- Extended the existing provenance CLI with opt-in `--require-web-shell`,
  requiring `index.html`, `flutter_bootstrap.js`, `main.dart.js`, and
  `manifest.json` to be regular files before Web release evidence is accepted.
- Enabled the gate for local/GitHub provenance generation and verification, and
  added positive/missing-entry regression coverage. The unique iteration log is
  `docs/timeline/2026-09-01-slice104-web-shell-provenance.md`.
- Verification: focused workflow tests passed (`+38`), full Flutter tests
  passed (`+342`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/version gates, provenance generation, and provenance
  verification.
- Rollback: remove only the optional shell checker, its CLI arguments, focused
  test/docs lines, and this timeline entry; preserve the version gate and base
  provenance generation/verification.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web manifest identity provenance

- Extended the existing provenance CLI with opt-in `--require-web-manifest`,
  requiring generated `manifest.json` `name` and `short_name` to match the
  canonical package name.
- Enabled the gate for local/GitHub provenance generation and verification, and
  added positive/tampered-identity regression coverage. The unique iteration
  log is `docs/timeline/2026-09-01-slice105-web-manifest-identity.md`.
- Verification: focused workflow tests passed (`+39`), full Flutter tests
  passed (`+343`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/version/manifest gates, provenance generation, and
  provenance verification.
- Rollback: remove only the optional manifest checker, its CLI arguments,
  focused test/docs lines, and this timeline entry; preserve shell, version,
  and base provenance gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Source revision provenance gate

- Extended the existing provenance CLI with opt-in `--require-revision`, which
  rejects an empty or missing `--revision` value before hashing an artifact.
- GitHub Actions now binds both provenance commands to `$GITHUB_SHA`; the local
  wrapper uses `DHC_SOURCE_REVISION` when supplied or resolves the checked-out
  `git rev-parse --verify HEAD`. The manifest therefore cannot be produced by
  the release-evidence path without a source commit reference.
- Added focused missing/success coverage and wiring assertions. The unique
  iteration log is
  `docs/timeline/2026-09-01-slice107-source-revision-provenance.md`.
- Verification: focused workflow tests passed (`+41`), full Flutter tests
  passed (`+345`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/version/manifest gates, source-revision provenance
  generation, and provenance verification.
- Rollback: remove only the optional revision flag, its local/CI arguments,
  focused test/docs lines, and this timeline entry; preserve the existing
  artifact hashing and Web shell/version/manifest gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web manifest icon asset provenance

- Extended the existing provenance CLI with opt-in
  `--require-web-manifest-assets`. It requires a non-empty `icons` array and
  checks every `icons[].src` for a safe relative path resolving to a regular
  file inside the Web artifact; absolute, traversal, external-URL, and missing
  references fail before hashing or verification.
- Enabled the gate for local/GitHub provenance generation and verification, and
  added positive, missing-file, and unsafe-path regression coverage. The unique
  iteration log is
  `docs/timeline/2026-09-01-slice108-web-manifest-assets.md`.
- Verification: focused workflow tests passed (`+42`), full Flutter tests
  passed (`+346`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/version/manifest/revision gates, icon-asset provenance
  generation, and provenance verification.
- Rollback: remove only the optional icon-assets checker, its local/CI
  arguments, focused test/docs lines, and this timeline entry; preserve the
  existing Web shell, identity, revision, and hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web shell reference integrity

- Extended the existing provenance CLI with opt-in
  `--require-web-shell-references`. It requires `index.html` to reference the
  Flutter bootstrap script, manifest, favicon, and Apple touch icon, and checks
  each target resolves to a regular file inside the Web artifact.
- Enabled the gate for local/GitHub provenance generation and verification, and
  added positive, missing-target, and missing-reference regression coverage.
  The unique iteration log is
  `docs/timeline/2026-09-01-slice109-web-shell-references.md`.
- Verification: focused workflow tests passed (`+43`), full Flutter tests
  passed (`+347`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/version/manifest/revision gates, icon-asset
  provenance generation, and provenance verification.
- Rollback: remove only the optional shell-reference checker, its local/CI
  arguments, focused test/docs lines, and this timeline entry; preserve the
  existing shell, icon, identity, revision, and hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web metadata parity provenance

- Extended the existing provenance CLI with opt-in
  `--require-web-metadata-parity`. It reads the single non-empty description
  from canonical `web/index.html` and `web/manifest.json`, then requires the
  generated Web `index.html` and `manifest.json` to carry the same value.
- Enabled the gate for local/GitHub provenance generation and verification, and
  added positive plus index/manifest tamper regressions. The unique iteration
  log is `docs/timeline/2026-09-01-slice110-web-metadata-parity.md`.
- Verification: focused workflow tests passed (`+44`), full Flutter tests
  passed (`+348`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/metadata/version/manifest/revision gates,
  icon-asset provenance generation, and provenance verification.
- Rollback: remove only the optional metadata-parity checker, its local/CI
  arguments, focused test/docs lines, and this timeline entry; preserve the
  existing shell, icon, identity, revision, and hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web PWA startup/display contract

- Extended the existing provenance CLI with opt-in
  `--require-web-pwa-contract`. It requires a safe relative `start_url`, a
  recognized `display` mode, and non-empty `background_color` and `theme_color`
  values in the generated manifest.
- Enabled the gate for local/GitHub provenance generation and verification, and
  added valid, external-start, unknown-display, and missing-color regressions.
  The unique iteration log is
  `docs/timeline/2026-09-01-slice111-web-pwa-contract.md`.
- Verification: focused workflow tests passed (`+45`), full Flutter tests
  passed (`+349`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/metadata/PWA/version/manifest/revision gates,
  icon-asset provenance generation, and provenance verification.
- Rollback: remove only the optional PWA-contract checker, its local/CI
  arguments, focused test/docs lines, and this timeline entry; preserve the
  existing shell, icon, metadata, identity, revision, and hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web manifest icon metadata contract

- Extended the existing provenance CLI with opt-in
  `--require-web-manifest-icon-metadata`. It validates every icon's `sizes`
  (`WIDTHxHEIGHT` or `any`), supported image MIME `type`, and optional
  `purpose` tokens (`any`, `maskable`, or `monochrome`).
- Enabled the gate for local/GitHub provenance generation and verification, and
  added valid, missing-file, invalid-size, invalid-type, and invalid-purpose
  regressions. The unique iteration log is
  `docs/timeline/2026-09-01-slice112-web-manifest-icon-metadata.md`.
- Verification: focused workflow tests passed (`+46`), full Flutter tests
  passed (`+350`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/metadata/PWA/icon/version/manifest/revision
  gates, icon-asset provenance generation, and provenance verification.
- Rollback: remove only the optional icon-metadata checker, its local/CI
  arguments, focused test/docs lines, and this timeline entry; preserve the
  existing shell, icon-assets, PWA, identity, revision, and hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web theme-color parity contract

- Added the canonical `<meta name="theme-color" content="#0175C2">` to the
  existing Web shell and extended the provenance CLI with opt-in
  `--require-web-theme-color-parity`.
- The gate requires source `web/index.html`, source `web/manifest.json`,
  generated `index.html`, and generated `manifest.json` to carry one identical
  non-empty theme color. It is enabled for local/GitHub generation and
  verification, with focused source/tamper coverage. The unique iteration log
  is `docs/timeline/2026-09-01-slice113-web-theme-color-parity.md`.
- Verification: focused workflow tests passed (`+47`), full Flutter tests
  passed (`+351`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/metadata/PWA/icon/theme/version/manifest/
  revision gates, provenance generation, and provenance verification.
- Rollback: remove only the theme-color source tag, optional parity checker,
  local/CI arguments, focused test/docs lines, and this timeline entry;
  preserve the existing shell, icon, metadata, PWA, identity, revision, and
  hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web service-worker cleanup contract

- Extended the existing provenance CLI with opt-in
  `--require-web-service-worker-contract`. It requires the generated
  `flutter_bootstrap.js` to expose exactly one safe, non-empty
  `serviceWorkerVersion` token and requires `flutter_service_worker.js` to
  implement the expected install/activate lifecycle.
- The worker contract is intentionally cleanup-only: it must call
  `self.skipWaiting()`, unregister itself during activation, and avoid both
  CacheStorage access and fetch interception. This makes Flutter's current
  deprecation worker behavior explicit and prevents accidental stale-cache
  policy drift. Local/GitHub provenance generation and verification both
  enable the gate, with positive, cache-interception, and unsafe-version
  regressions. The unique iteration log is
  `docs/timeline/2026-09-01-slice114-web-service-worker-contract.md`.
- Verification: focused workflow tests passed (`+48`), full Flutter tests
  passed (`+352`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/metadata/PWA/icon/theme/service-worker/
  version/manifest/revision gates, provenance generation, and provenance
  verification.
- Rollback: remove only the optional service-worker checker, its local/CI
  arguments, focused test/docs lines, and this timeline entry; preserve the
  existing shell, metadata, PWA, manifest, revision, and hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Web root base-href contract

- Extended the existing provenance CLI with opt-in
  `--require-web-root-base-href`. It requires generated `index.html` to carry
  exactly one `<base>` tag whose `href` is `/`, matching the current root
  deployment contract and rejecting unresolved `$FLUTTER_BASE_HREF` or subpath
  drift before artifact upload.
- Enabled the gate for local/GitHub provenance generation and verification, and
  added positive, unresolved-placeholder, and duplicate-base-tag regressions.
  The unique iteration log is
  `docs/timeline/2026-09-01-slice115-web-root-base-href.md`.
- Verification: focused workflow tests passed (`+49`), full Flutter tests
  passed (`+353`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/base-href/metadata/PWA/icon/theme/
  service-worker/version/manifest/revision gates, provenance generation, and
  provenance verification.
- Rollback: remove only the optional root-base-href checker, its local/CI
  arguments, focused test/docs lines, and this timeline entry; preserve the
  existing shell, metadata, PWA, service-worker, manifest, revision, and
  hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Root PWA identity contract

- Added canonical root PWA `id: "/"` and `scope: "/"` fields to the existing
  `web/manifest.json`, then extended the provenance CLI with opt-in
  `--require-web-pwa-identity`.
- The gate requires source and generated manifests to carry exactly those root
  identity values, preventing browser installation scope drift or duplicate
  installs when the artifact is consumed by the current root deployment.
  Local/GitHub provenance generation and verification both enable the gate,
  with positive and generated-id/scope tamper regressions. The unique
  iteration log is
  `docs/timeline/2026-09-01-slice116-web-pwa-identity.md`.
- Verification: focused workflow tests passed (`+50`), full Flutter tests
  passed (`+354`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/base-href/metadata/PWA/identity/icon/theme/
  service-worker/version/manifest/revision gates, provenance generation, and
  provenance verification.
- Rollback: remove only the canonical id/scope fields, optional PWA-identity
  checker, its local/CI arguments, focused test/docs lines, and this timeline
  entry; preserve the existing shell, metadata, PWA startup, base-href,
  service-worker, manifest, revision, and hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Responsive Web viewport contract

- Added the canonical responsive viewport meta tag to the existing Web shell:
  `width=device-width, initial-scale=1.0`.
- Extended the provenance CLI with opt-in `--require-web-viewport`, requiring
  exactly one canonical and generated `index.html` viewport value. Local/GitHub
  provenance generation and verification both enable the gate, with positive,
  mismatched, and duplicate-meta regressions. The unique iteration log is
  `docs/timeline/2026-09-01-slice117-web-viewport.md`.
- Verification: focused workflow tests passed (`+51`), full Flutter tests
  passed (`+355`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/base-href/metadata/PWA/identity/viewport/
  icon/theme/service-worker/version/manifest/revision gates, provenance
  generation, and provenance verification.
- Rollback: remove only the viewport source tag, optional viewport checker,
  its local/CI arguments, focused test/docs lines, and this timeline entry;
  preserve the existing shell, deployment-path, PWA, identity, and hashing
  gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 English Web language contract

- Added the canonical `<html lang="en">` attribute to the existing Web shell
  and extended the provenance CLI with opt-in `--require-web-language`.
- The gate requires exactly one HTML root tag with `lang="en"` in both
  canonical and generated shells, preventing screen-reader and browser
  language inference drift. Local/GitHub provenance generation and
  verification both enable the gate, with positive, foreign-language, and
  missing-attribute regressions. The unique iteration log is
  `docs/timeline/2026-09-01-slice118-web-language.md`.
- Verification: focused workflow tests passed (`+52`), full Flutter tests
  passed (`+356`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, all compare gates, explicit Web
  release build, shell/reference/base-href/metadata/PWA/identity/viewport/
  language/icon/theme/service-worker/version/manifest/revision gates,
  provenance generation, and provenance verification.
- Rollback: remove only the language source attribute, optional language
  checker, its local/CI arguments, focused test/docs lines, and this timeline
  entry; preserve the existing shell, deployment-path, metadata, PWA, and
  hashing gates.
- Next slice: inspect one bounded platform packaging or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Activity trace UTF-8 byte budget

- Updated `ActivityTraceStore` to measure the persisted `activity_trace_v1`
  payload in UTF-8 bytes for both oversized-input rejection and append fitting.
  This keeps the configured cap meaningful for multilingual and emoji-rich
  summaries/details instead of counting Dart string code units.
- Added a focused regression proving a multibyte record is rejected when its
  UTF-8 payload exceeds the cap while the store remains recoverable. The unique
  iteration log is `docs/timeline/2026-09-01-slice120-activity-trace-utf8.md`.
- Verification: focused ActivityTraceStore tests passed (`+12`), full Flutter
  tests passed (`+358`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, compare gates, Web release build,
  provenance generation, and provenance verification.
- Rollback: restore the two payload-length checks to character length, remove
  the focused regression/docs lines, and remove this timeline entry; preserve
  serialized queues, fail-open decoding, and existing item limits.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Favorite filter persistence ordering

- Hardened `favorite_filters_v1` decoding so a wrongly typed `sortMode`
  defaults to `recent` instead of aborting the payload. Favorite foods,
  filters, and templates now load through one ordered, per-loader-isolated
  sequence; filters are applied only after the favorite list exists, avoiding
  a startup race that previously pruned valid persisted dimensions.
- Added a widget regression covering cross-country favorites with a malformed
  sort mode. The unique iteration log is
  `docs/timeline/2026-09-02-slice132-favorite-filter-ordering.md`.
- Verification: focused widget tests passed (10 cases), full Flutter tests
  passed (`+372`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file restored; the run included lockfile,
  importer, compare/accessibility, Web build, and provenance generate/verify
  checks.
- Rollback: remove the safe sort-mode decode and ordered favorite loader,
  focused regression, docs references, and this timeline entry; preserve
  favorite metadata keys, valid filter semantics, UTF-8 budgets, and the
  write queue.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Recent export recall scope validation

- Hardened `recent_export_recalls_v1` scope decoding: surrounding whitespace is
  normalized, search/favorites `all-local-foods` markers map to their existing
  empty-value semantics, and empty/reserved country, favorites, or compare
  scopes are rejected instead of becoming misleading replay chips.
- Added a widget regression with malformed scopes before valid country, search,
  favorites, and compare recalls. The unique iteration log is
  `docs/timeline/2026-09-02-slice133-recent-export-recall-validation.md`.
- Verification: focused widget tests passed (11 cases), full Flutter tests
  passed (`+373`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the scope normalization/validation, focused regression,
  docs references, and this timeline entry; preserve valid export recall
  replay behavior, metadata keys, UTF-8 budgets, and the per-key write queue.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Compare replay draft integer timestamps

- Hardened `recent_export_replay_drafts_v1` decoding so persisted draft
  timestamps accept only integers or integer strings. Fractional, non-finite,
  and otherwise typed values are skipped rather than silently truncated into a
  plausible epoch-millisecond value; the existing archive path then marks the
  draft as requiring manual rebuild.
- Added a widget regression with a future fractional timestamp and a valid
  compare draft status. The unique iteration log is
  `docs/timeline/2026-09-02-slice134-compare-replay-draft-integer-time.md`.
- Verification: focused widget tests passed (12 cases), full Flutter tests
  passed (`+374`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove the persisted-integer parser, focused regression, docs
  references, and this timeline entry; preserve valid draft retention,
  status/archive semantics, metadata keys, UTF-8 budgets, and the write queue.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Recent-search metadata read isolation

- Isolated the `recent_searches_v1` repository read in HomePage startup. A
  storage exception now leaves recent searches unavailable while allowing the
  rest of the shell and independent persistence loaders to finish normally;
  malformed JSON handling remains unchanged.
- Added a widget regression with a repository that fails only the recent-search
  metadata read. The unique iteration log is
  `docs/timeline/2026-09-02-slice135-recent-search-read-isolation.md`.
- Verification: focused widget tests passed (13 cases), full Flutter tests
  passed (`+375`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the recent-search read guard, focused regression, docs
  references, and this timeline entry; preserve recent-search parsing,
  metadata keys, other startup loaders, and write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Compare prompt-config read isolation

- Isolated the `compare_replay_draft_prompt_config_v1` repository read from
  HomePage export-recall restoration. A configuration storage exception now
  retains the in-memory default and allows valid export recalls to load instead
  of aborting the entire loader.
- Added a widget regression with a repository that fails only the prompt-config
  metadata read while a valid country recall is persisted. The unique iteration
  log is `docs/timeline/2026-09-02-slice136-prompt-config-read-isolation.md`.
- Verification: focused widget tests passed (14 cases), full Flutter tests
  passed (`+376`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the prompt-config read guard, focused regression, docs
  references, and this timeline entry; preserve default config semantics, export
  recall restoration, metadata keys, and write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Recent export recall history fallback

- Isolated the `recent_export_recalls_v1` metadata read in HomePage startup.
  When the recall cache is unavailable, the existing export-history fallback
  now rebuilds valid recall chips instead of aborting the loader.
- Added a widget regression with a repository that fails only the recall-cache
  read while a country export-history entry remains available. The unique
  iteration log is
  `docs/timeline/2026-09-02-slice137-recent-export-history-fallback.md`.
- Verification: focused widget tests passed (15 cases), full Flutter tests
  passed (`+377`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the recall-cache read guard, focused regression, docs
  references, and this timeline entry; preserve history fallback semantics,
  valid replay behavior, metadata keys, and write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Replay-status read isolation

- Isolated the `recent_export_replay_statuses_v1` metadata read in HomePage
  startup. A status-cache storage exception now leaves the valid compare recall
  visible without a status suffix, while the rest of replay restoration and
  archive handling continues normally.
- Added a widget regression with a repository that fails only the replay-status
  metadata read. The unique iteration log is
  `docs/timeline/2026-09-02-slice138-replay-status-read-isolation.md`.
- Verification: focused widget tests passed (16 cases), full Flutter tests
  passed (`+378`), `flutter analyze` reported zero issues, and `git diff --check`
  passed. Strict `CI=true ./tool/ci_checks.sh` passed with the canonical
  dependency file; the run included lockfile, 14 importer, compare/accessibility,
  Web build, and provenance generate/verify checks.
- Rollback: remove only the replay-status read guard, focused regression, docs
  references, and this timeline entry; preserve valid recall chips, status
  semantics, metadata keys, and write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Replay-draft timestamp read isolation

- Isolated the `recent_export_replay_drafts_v1` metadata read in HomePage
  startup. A draft-timestamp storage exception now clears only the optional
  timestamp layer, allowing replay statuses to restore and missing timestamps
  to be archived as an explicit manual-rebuild requirement.
- Added a widget regression with a repository that fails only the draft
  timestamp metadata read while a persisted Draft status remains available.
  The unique iteration log is
  `docs/timeline/2026-09-02-slice139-replay-draft-timestamp-read-isolation.md`.
- Verification: focused widget tests passed (17 cases), full Flutter tests
  passed (`+379`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the draft-timestamp read guard, focused regression,
  docs references, and this timeline entry; preserve status restoration,
  archival semantics, metadata keys, and write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Export-history read isolation

- Isolated the export-history fallback read in HomePage startup. When both the
  recent-recall cache and `getExportHistory` are unavailable, startup now keeps
  the shell healthy with an empty recall list instead of surfacing an
  unhandled asynchronous failure.
- Added a widget regression with a repository that fails only the export-history
  read. The unique iteration log is
  `docs/timeline/2026-09-02-slice140-export-history-read-isolation.md`.
- Verification: focused widget tests passed (18 cases), full Flutter tests
  passed (`+380`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the export-history read guard, focused regression, docs
  references, and this timeline entry; preserve recall-cache behavior, empty
  recall semantics, metadata keys, and write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Compare-detail read isolation

- Hardened HomePage compare replay detail hydration with per-ID read
  isolation. A failed `getFoodDetails` call now skips only that ID so later
  compare items can still hydrate and the replay reports a truthful partial
  restoration instead of aborting the interaction.
- Added a widget regression with the first compare detail read failing while a
  second detail remains available. The unique iteration log is
  `docs/timeline/2026-09-02-slice141-compare-detail-read-isolation.md`.
- Verification: focused widget tests passed (19 cases), full Flutter tests
  passed (`+381`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the per-ID detail read guard, focused regression, docs
  references, and this timeline entry; preserve partial-restoration status
  semantics, compare IDs, metadata keys, and write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Import-log read isolation

- Centralized HomePage import-log reads behind a safe supplemental loader for
  refresh, standard search, and advanced search. A `getImportLogs` failure now
  preserves the last visible log state while result and count updates continue.
- Added a widget regression with seeded results and a repository that fails only
  import-log reads. The unique iteration log is
  `docs/timeline/2026-09-02-slice142-import-log-read-isolation.md`.
- Verification: focused widget tests passed (20 cases), full Flutter tests
  passed (`+382`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the safe import-log loader and focused regression, docs
  references, and this timeline entry; preserve result/count reads, prior log
  state, metadata keys, and write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Food-count read isolation

- Centralized HomePage food-count reads behind a safe supplemental loader for
  refresh, standard search, and advanced search. A `countFoods` failure now
  preserves the last visible count while result updates continue.
- Added a widget regression with seeded results and a repository that fails only
  food-count reads. The unique iteration log is
  `docs/timeline/2026-09-02-slice143-food-count-read-isolation.md`.
- Verification: focused widget tests passed (21 cases), full Flutter tests
  passed (`+383`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the safe food-count loader and focused regression, docs
  references, and this timeline entry; preserve result/log reads, prior count
  state, metadata keys, and write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Initial results read recovery

- Wrapped the HomePage initial refresh in a safe boundary so a primary
  `searchFoods` failure no longer leaves the shell in an endless loading state
  or becomes an unhandled asynchronous error.
- Added an explicit local-results-unavailable card with a retry action, plus a
  transient-failure widget regression that verifies recovery after storage
  becomes available. The unique iteration log is
  `docs/timeline/2026-09-02-slice144-initial-results-read-recovery.md`.
- Verification: focused widget tests passed (22 cases), full Flutter tests
  passed (`+384`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the initial-refresh safety boundary, error card, retry
  regression, docs references, and this timeline entry; preserve standard and
  advanced search behavior, result/log/count reads, metadata keys, and
  write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Recent-search persistence isolation

- Made recent-search metadata persistence best-effort so a failed
  `recent_searches_v1` write no longer blocks the requested search; the updated
  in-memory recent-search state remains available for the session.
- Added a widget regression with seeded results and a repository that fails only
  recent-search writes. The unique iteration log is
  `docs/timeline/2026-09-02-slice145-recent-search-persistence-isolation.md`.
- Verification: focused widget tests passed (23 cases), full Flutter tests
  passed (`+385`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the recent-search persistence catch, focused
  regression, docs references, and this timeline entry; preserve search
  execution, in-memory recent-search state, metadata keys, and write-queue
  behavior for other state.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Recent-search management persistence isolation

- Routed recent-search removal and clear-all actions through the same
  best-effort persistence boundary as search recording. A failed
  `recent_searches_v1` write no longer turns a management button callback into
  an unhandled Future; the in-memory list still updates immediately.
- Added a widget regression that clears a populated recent-search list while
  persistence fails. The unique iteration log is
  `docs/timeline/2026-09-02-slice146-recent-search-management-persistence-isolation.md`.
- Verification: focused widget tests passed (24 cases), full Flutter tests
  passed (`+386`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the recent-search management helper and focused
  regression, docs references, and this timeline entry; preserve search
  recording, in-memory state, metadata keys, and other write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Favorite persistence isolation

- Routed favorite toggle, remove, and clear-all mutations through a safe
  persistence helper. A failed `favorite_foods_v1` write now leaves the
  in-memory favorite state responsive without an unhandled Future.
- Added a widget regression with seeded results and a repository that fails only
  favorite writes. The unique iteration log is
  `docs/timeline/2026-09-02-slice147-favorite-persistence-isolation.md`.
- Verification: focused widget tests passed (25 cases), full Flutter tests
  passed (`+387`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the favorite persistence helper, focused regression,
  docs references, and this timeline entry; preserve favorite in-memory state,
  metadata keys, and other write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Favorite-filter persistence isolation

- Wrapped favorite country/source/category/sort metadata persistence in a
  best-effort boundary. Filter choices now remain immediately usable when
  `favorite_filters_v1` cannot be written, without unhandled Futures.
- Added a widget regression with a seeded favorite and a repository that fails
  only favorite-filter writes. The unique iteration log is
  `docs/timeline/2026-09-02-slice148-favorite-filter-persistence-isolation.md`.
- Verification: focused widget tests passed (26 cases), full Flutter tests
  passed (`+388`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the favorite-filter persistence boundary, focused
  regression, docs references, and this timeline entry; preserve in-memory
  selections, metadata keys, and other write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Favorite-template persistence isolation

- Wrapped favorite template save/delete persistence in a best-effort boundary.
  A failed `favorite_templates_v1` write now leaves the in-memory template
  list live without an unhandled Future.
- Added a widget regression with a seeded favorite and a repository that fails
  only favorite-template writes. The unique iteration log is
  `docs/timeline/2026-09-02-slice149-favorite-template-persistence-isolation.md`.
- Verification: focused widget tests passed (27 cases), full Flutter tests
  passed (`+389`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the favorite-template persistence boundary, focused
  regression, docs references, and this timeline entry; preserve in-memory
  template state, metadata keys, and other write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Replay-status persistence isolation

- Wrapped `recent_export_replay_statuses_v1` persistence in a best-effort
  boundary. A failed status write now leaves the live compare replay status
  visible without an unhandled Future during replay or archival.
- Added a widget regression with a short-ID compare recall and a repository
  that fails only replay-status writes. The unique iteration log is
  `docs/timeline/2026-09-02-slice150-replay-status-persistence-isolation.md`.
- Verification: focused widget tests passed (28 cases), full Flutter tests
  passed (`+390`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the replay-status persistence boundary, focused
  regression, docs references, and this timeline entry; preserve compare
  replay state, metadata keys, and other write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Replay-draft timestamp persistence isolation

- Wrapped `recent_export_replay_drafts_v1` timestamp persistence in a
  best-effort boundary. A failed draft-timestamp write now leaves the live
  compare replay status usable without an unhandled Future.
- Added a widget regression with a short-ID compare recall and a repository
  that fails only replay-draft timestamp writes. The unique iteration log is
  `docs/timeline/2026-09-02-slice151-replay-draft-timestamp-persistence-isolation.md`.
- Verification: focused widget tests passed (29 cases), full Flutter tests
  passed (`+391`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the replay-draft timestamp persistence boundary,
  focused regression, docs references, and this timeline entry; preserve
  compare replay state, metadata keys, and other write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Export-recall persistence isolation

- Wrapped `recent_export_recalls_v1` list persistence in a best-effort
  boundary. Clearing or mutating the live export-recall list now remains
  responsive when its supplemental metadata write fails.
- Added a widget regression with a seeded search recall and a repository that
  fails only export-recall writes. The unique iteration log is
  `docs/timeline/2026-09-02-slice152-export-recall-persistence-isolation.md`.
- Verification: focused widget tests passed (30 cases), full Flutter tests
  passed (`+392`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the export-recall persistence boundary, focused
  regression, docs references, and this timeline entry; preserve the live
  recall list, metadata keys, and other write-queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Provenance symlink containment

- Hardened release provenance output and verification containment checks to
  resolve existing path components before comparing them with the artifact.
  A symlink redirect can no longer make a destination appear external while
  pointing back into the hashed artifact.
- Added a CI workflow regression that attempts a symlinked artifact-directory
  redirect and requires the stable containment diagnostic. The unique
  iteration log is
  `docs/timeline/2026-09-02-slice153-provenance-symlink-containment.md`.
- Verification: focused `ci_workflow_test.dart` passed (55 cases), full
  Flutter tests passed (`+393`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the containment resolver, focused symlink regression,
  docs references, and this timeline entry; preserve deterministic manifest
  hashing, output/verify semantics, and Web contract checks.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Provenance artifact-root symlink rejection

- Added a fail-closed release provenance check requiring the artifact input
  itself to be a regular directory rather than a symlink. This keeps the
  hashed release root explicit and prevents an external directory from being
  silently adopted as the artifact.
- Extended the existing provenance path-safety regression with a symlinked
  artifact-root case. The unique iteration log is
  `docs/timeline/2026-09-02-slice154-provenance-artifact-root-symlink.md`.
- Verification: focused `ci_workflow_test.dart` passed (55 cases), full
  Flutter tests passed (`+393`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the artifact-root type guard, focused regression,
  docs references, and this timeline entry; preserve destination containment,
  deterministic hashing, and Web contract checks.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Provenance dangling-path resolution

- Added a fail-closed wrapper around release provenance containment-path
  resolution for the artifact input, output, and verify paths. Dangling or
  otherwise unresolvable symlinks now produce stable diagnostics and stop
  before hashing or writing instead of leaking an uncaught filesystem stack.
- Extended the existing deterministic path-safety regression with dangling
  output, verify, and input symlink cases. The unique iteration log is
  `docs/timeline/2026-09-02-slice155-provenance-dangling-path-resolution.md`.
- Verification: focused `ci_workflow_test.dart` passed (55 cases), full
  Flutter tests passed (`+393`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the safe containment resolver, dangling-link
  regressions, docs references, and this timeline entry; preserve regular
  artifact-root validation, destination containment, deterministic hashing,
  and Web contract checks.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Settings startup persistence isolation

- Hardened `SettingsService.load()` so an unavailable `app_settings` read
  returns the in-memory defaults, and malformed-settings repair writes are
  best-effort. A transient metadata failure therefore cannot abort app
  startup or turn a recoverable decode failure into a second failure.
- Added focused settings regressions for unavailable reads and a malformed
  payload whose repair write fails. The unique iteration log is
  `docs/timeline/2026-09-02-slice156-settings-startup-persistence-isolation.md`.
- Verification: focused settings tests passed (7 cases), full Flutter tests
  passed (`+393`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the settings read fallback, best-effort repair helper,
  focused regressions, docs references, and this timeline entry; preserve
  settings sanitization, explicit save semantics, and runtime wiring.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Settings page persistence recovery

- Hardened `SettingsPage` loading so settings and storage-path failures are
  rendered as a recoverable message while the form remains available with
  defaults or the available values. Save failures now stay in the page as a
  status message instead of escaping the button action.
- Added a focused `SettingsPage` widget suite covering unavailable storage
  paths and failed settings writes. The unique iteration log is
  `docs/timeline/2026-09-02-slice157-settings-page-persistence-recovery.md`.
- Verification: focused SettingsPage tests passed (2 cases), full Flutter
  tests passed (`+396`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the SettingsPage load/save error boundaries, focused
  widget suite, docs references, and this timeline entry; preserve settings
  service fallback, form fields, and runtime wiring.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Export history persistence isolation

- Hardened `FoodCatalogExportService` so export-history persistence is
  supplemental: once the export file is written, an `addExportHistory`
  failure no longer invalidates the returned artifact or reports the file as a
  failed export.
- Added a focused export-service regression with a repository that fails only
  history writes. The unique iteration log is
  `docs/timeline/2026-09-02-slice158-export-history-persistence-isolation.md`.
- Verification: focused export-service tests passed (9 cases), full Flutter
  tests passed (`+397`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the export-history write boundary, focused regression,
  docs references, and this timeline entry; preserve export file formats,
  deterministic paths, AI summary behavior, and recall persistence.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 AI suggestion persistence isolation

- Hardened `AiAssistServiceBase.runSuggestion` so model calls are isolated from
  supplemental suggestion-log writes. A successful model response remains
  usable when its log cannot be persisted, and model/limit fallbacks remain
  deterministic when fallback logging also fails.
- Added focused AI regressions for successful output and deterministic routing
  fallback with a failing suggestion persistor. The unique iteration log is
  `docs/timeline/2026-09-02-slice159-ai-suggestion-persistence-isolation.md`.
- Verification: focused settings/AI tests passed (9 cases), full Flutter tests
  passed (`+399`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the best-effort AI log helpers, focused regressions,
  docs references, and this timeline entry; preserve model budgeting, public
  `persist` semantics, deterministic caller fallbacks, and export/search
  routing behavior.
- Next slice: inspect `QueryExpansionService`'s analogous bounded persistence
  boundary without duplicating canonical content.

### 2026-09-02 Query expansion persistence isolation

- Hardened `QueryExpansionService.expand` so model/JSON parsing is isolated from
  supplemental suggestion-log writes. A valid expansion remains usable when
  its log fails, and request or budget fallbacks remain deterministic when
  fallback logging also fails.
- Added focused query-expansion regressions for successful output, request
  fallback, and budget fallback with a failing suggestion persistor. The unique
  iteration log is
  `docs/timeline/2026-09-02-slice160-query-expansion-persistence-isolation.md`.
- Verification: focused query-expansion/budget tests passed (9 cases), full
  Flutter tests passed (`+402`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the best-effort query-expansion log boundaries, focused
  regressions, docs references, and this timeline entry; preserve model
  budgeting, expansion parsing, public persistor semantics, and deterministic
  search fallback behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Import log persistence isolation

- Hardened `SyncFoodCatalogUseCase` so success and failure import logs are
  supplemental diagnostics. A successful import now returns its normalized
  foods even when the success log cannot be written; when ingestion fails, the
  original import error is preserved even if failure-log persistence also
  fails.
- Added focused importer regressions for success-log failure and original
  failure preservation with a failing log repository. The unique iteration log
  is `docs/timeline/2026-09-02-slice161-import-log-persistence-isolation.md`.
- Verification: focused source-importer tests passed (17 cases), full Flutter
  tests passed (`+404`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the best-effort import-log boundary, focused
  regressions, docs references, and this timeline entry; preserve ingestion,
  normalization, artifact persistence, original error semantics, and importer
  routing behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Fetch-job persistence isolation

- Hardened `ForegroundFetchRunner` and `BackgroundEnrichmentQueue` so
  fetch-job status writes are supplemental diagnostics. A storage failure while
  recording queued/running/success/failure/cancelled state no longer blocks
  source ingestion, converts a successful source into a false failure, or
  stops later enrichment sources.
- Added focused regressions for successful and failed foreground sources plus
  successful background enrichment with a failing job persistor. The unique
  iteration log is
  `docs/timeline/2026-09-02-slice162-fetch-job-persistence-isolation.md`.
- Verification: focused fetch-runner/queue/orchestrator tests passed (8 cases),
  full Flutter tests passed (`+407`), `flutter analyze` reported zero issues,
  and `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed
  with the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the best-effort fetch-job helpers, focused regressions,
  docs references, and this timeline entry; preserve importer execution,
  queue cancellation/state transitions, and fetch-job schema semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Operations retry persistence isolation

- Hardened the Operations manual Retry path so fetch-job running/success/failure
  writes are supplemental diagnostics. A status-storage outage no longer
  prevents the requested source retry, turns a successful retry into a false
  failure, or changes the source error message.
- Added a focused Operations widget regression with a failing fetch-job
  persistor; it verifies the retry still reaches the source and attempts the
  expected failure→running→success status sequence. The unique iteration log
  is `docs/timeline/2026-09-02-slice163-operations-retry-persistence-isolation.md`.
- Verification: focused retry regression passed, the full Operations widget
  suite passed (118 cases), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the Operations retry helper, focused regression, docs
  references, and this timeline entry; preserve source retry semantics,
  activity tracing, refresh behavior, and fetch-job schema semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Dataset-artifact persistence isolation

- Hardened `SyncFoodCatalogUseCase` so dataset-artifact inventory metadata is
  supplemental to an already committed normalized import. A successful import
  now returns its normalized foods and success log even when the artifact
  metadata write fails; ingestion and normalization errors retain their
  existing semantics.
- Added a focused importer regression with a failing artifact repository. The
  regression proves the normalized food remains searchable and the import
  outcome remains successful when the artifact write is unavailable. The
  unique iteration log is
  `docs/timeline/2026-09-02-slice164-dataset-artifact-persistence-isolation.md`.
- Verification: focused `it_crea`/source-importer tests passed (18 cases),
  full Flutter tests passed (`+409`), `flutter analyze` reported zero issues,
  and `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed
  with the canonical dependency file; the run included lockfile, 14
  importer, compare/accessibility, Web build, and provenance generate/verify
  checks.
- Rollback: remove only the best-effort artifact metadata boundary, focused
  regression, docs references, and this timeline entry; preserve normalized
  ingestion, success/failure import-log boundaries, artifact schema, and
  importer routing.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Recent fetch-history read isolation

- Hardened `SearchOrchestrator` so recent failed fetch-job history is treated as
  routing metadata rather than a prerequisite for user work. If that history
  read is unavailable, search and background enrichment continue with an empty
  failure set; local results, source execution, and queue outcomes retain their
  existing semantics.
- Added focused search and enrichment regressions with a repository that fails
  recent fetch-job reads. The unique iteration log is
  `docs/timeline/2026-09-02-slice165-recent-fetch-history-read-isolation.md`.
- Verification: focused SearchOrchestrator tests passed (9 cases), full
  Flutter tests passed (`+411`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the best-effort recent-history helper, focused
  regressions, docs references, and this timeline entry; preserve source
  routing rules, budget limits, local-search states, and enrichment queue
  semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Post-fetch reconciliation read isolation

- Hardened `SearchOrchestrator` so the post-fetch local-search reconciliation
  read is supplemental to the foreground runner result. A transient read
  failure now falls back to the runner's normalized imported foods, preserving
  canonical de-duplication on the normal read path and keeping a successful
  source from becoming a false failure.
- Added a focused regression with a repository that fails only the
  post-fetch search read; it verifies the fetched food and archived state still
  reach the caller. The unique iteration log is
  `docs/timeline/2026-09-02-slice166-post-fetch-reconciliation-read-isolation.md`.
- Verification: focused SearchOrchestrator tests passed (9 cases), full
  Flutter tests passed (`+412`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the post-fetch reconciliation fallback, focused
  regression, docs references, and this timeline entry; preserve canonical
  result merging, source outcome semantics, routing, and queue behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Export summary provider isolation

- Hardened `FoodCatalogExportService` so the export file remains the primary
  artifact and AI summary generation remains supplemental. An injected or
  future summary-provider failure now falls back to a deterministic summary
  while the export history entry is still written.
- Added a focused export-service regression with a throwing summary provider;
  it verifies the JSON artifact exists, history is retained, and the fallback
  summary is stable. The unique iteration log is
  `docs/timeline/2026-09-02-slice167-export-summary-provider-isolation.md`.
- Verification: focused export-service tests passed (11 cases), full Flutter
  tests passed (`+413`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the summary-provider fallback, focused regression,
  docs references, and this timeline entry; preserve export formats,
  deterministic paths, history schema, and existing AI summary behavior when
  the provider succeeds.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Export directory resolution read isolation

- Hardened `SettingsService.effectiveExportDirectory` so storage-path metadata
  is supplemental to the export action. An unavailable or malformed exports
  path now falls back to the deterministic local `exports` directory, while a
  non-empty explicit user directory remains honored.
- Added a focused settings regression with a repository that fails its storage
  path read. The unique iteration log is
  `docs/timeline/2026-09-02-slice168-export-directory-resolution-read-isolation.md`.
- Verification: focused Settings/AI tests passed (10 cases), full Flutter
  tests passed (`+414`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the storage-path fallback, focused regression, docs
  references, and this timeline entry; preserve explicit export-directory
  precedence, settings sanitization, and export formats.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Storage budget metadata read isolation

- Hardened `StorageBudgetManager.snapshot` so storage paths and dataset
  artifact inventory are read through independent supplemental boundaries. A
  transient failure in either source now leaves the other filesystem metrics
  available and adds an explicit warning instead of aborting the budget card.
- Added focused regressions for unavailable storage paths and unavailable
  artifact inventory. The unique iteration log is
  `docs/timeline/2026-09-02-slice169-storage-budget-metadata-read-isolation.md`.
- Verification: focused StorageBudgetManager tests passed (4 cases), full
  Flutter tests passed (`+416`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the independent budget-read boundaries, focused
  regressions, docs references, and this timeline entry; preserve filesystem
  sizing, budget thresholds, and explicit unavailable-data warnings.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Settings numeric bounds

- Hardened `SettingsService` sanitization for persisted and explicitly saved
  numeric controls. Negative model-call limits fall back to the default while
  zero remains an intentional AI-disable switch; timeout, token, and storage
  budgets require positive values and otherwise fall back to defaults.
- Added a focused settings regression covering both malformed persisted values
  and unsafe explicit saves. The unique iteration log is
  `docs/timeline/2026-09-02-slice170-settings-numeric-bounds.md`.
- Verification: focused Settings/AI tests passed (12 cases), full Flutter
  tests passed (`+417`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the numeric sanitization helpers, focused regression,
  docs references, and this timeline entry; preserve source enablement
  sanitization, explicit zero-call disable semantics, and settings persistence.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Settings save canonical snapshot

- Changed `SettingsService.save` to return the exact sanitized `AppSettings`
  snapshot written to `app_meta`. `SettingsPage` now applies that returned
  snapshot to its in-memory state and controllers after a successful save, so
  unsafe form input cannot remain visible as a value different from storage.
- Added a settings-page regression for unsafe numeric input and a service
  assertion for the returned canonical snapshot. The unique iteration log is
  `docs/timeline/2026-09-02-slice171-settings-save-canonical-snapshot.md`.
- Verification: focused Settings/AI tests passed (12 cases), settings-page
  tests passed (3 cases), full Flutter tests passed (`+418`), `flutter analyze`
  reported zero issues, and `git diff --check` passed. Strict
  `CI=true ./tool/ci_checks.sh` also passed with the canonical dependency
  file; the run included lockfile, 14 importer, compare/accessibility, Web
  build, and provenance generate/verify checks.
- Rollback: restore the `Future<void>` save contract and the page's raw `next`
  state assignment, then remove only the focused regression, docs references,
  and this timeline entry; preserve numeric sanitization and persistence.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Storage measurement completeness

- Added the injectable `StorageBudgetFileSystem` adapter and changed
  `StorageBudgetManager` measurements to carry both bytes and completeness.
  Invalid database paths now keep the budget snapshot renderable with an
  explicit warning; partial artifact/export/cache scans retain measured bytes
  while reporting incomplete measurements instead of presenting a false zero.
- Added focused regressions for a database measurement failure and a mixed
  valid/invalid artifact inventory. The unique iteration log is
  `docs/timeline/2026-09-02-slice172-storage-measurement-completeness.md`.
- Verification: focused StorageBudgetManager tests passed (6 cases), full
  Flutter tests passed (`+420`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` also passed
  with the canonical dependency file; the run included lockfile, 14 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the filesystem adapter, completeness result/warnings,
  focused regressions, docs references, and this timeline entry; preserve
  repository-read isolation, budget thresholds, and existing empty-path
  semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Home search failure recovery

- Hardened HomePage submitted-search handling with a request-generation guard,
  explicit failure state, and a retry action. Search-stream, advanced-search,
  cancellation, or supplemental read errors now stop loading, preserve the
  last visible results, and present a stable recovery card; stale requests can
  no longer overwrite a newer search or a cleared query.
- Added a widget regression that flips a repository search from success to a
  transient failure, verifies the retry card and settled loading state, then
  restores the repository and verifies the retry clears the error. The unique
  iteration log is
  `docs/timeline/2026-09-02-slice173-home-search-failure-recovery.md`.
- Verification: focused HomePage widget tests passed (30 cases), full Flutter
  tests passed (`+421`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` also passed
  with the canonical dependency file; the run included lockfile, 17 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the HomePage search-generation/error-card changes, the
  focused widget regression, docs references, and this timeline entry;
  preserve initial-results recovery, search orchestration, and enrichment
  cancellation semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Fetch budget input bounds

- Hardened `FetchBudgetPlanner` construction so negative importer budgets and
  non-positive per-importer limits cannot reach `Iterable.take` or an
  `ImportRequest`; invalid values fall back to safe defaults while
  `maxImporters: 0` remains an explicit no-fetch switch. Skipped plans now
  report the planner's sanitized limit instead of a hard-coded value.
- Hardened `SourceRoutingService.route` to clamp a directly supplied negative
  route budget to an empty route, keeping the routing boundary safe even when
  called outside the planner. Added focused planner and routing regressions.
  The unique iteration log is
  `docs/timeline/2026-09-02-slice174-fetch-budget-input-bounds.md`.
- Verification: focused planner/routing tests passed (11 cases), full Flutter
  tests passed (`+425`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` also passed
  with the canonical dependency file; the run included lockfile, 17 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the planner/routing sanitization and focused
  regressions, docs references, and this timeline entry; preserve existing
  source ordering, explicit zero-importer disable behavior, and import request
  semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Source route identity deduplication

- Hardened both capability-aware and legacy source routing to de-duplicate
  repeated importer IDs in default orders and source hints while preserving
  first-seen priority, recent-failure deprioritization, and the configured
  route budget. This prevents malformed configuration from executing the same
  source more than once in a search or enrichment plan.
- Added focused regressions for duplicate prioritized importers and duplicate
  source hints. The unique iteration log is
  `docs/timeline/2026-09-02-slice175-source-route-identity-deduplication.md`.
- Verification: focused planner/routing tests passed (13 cases), full Flutter
  tests passed (`+427`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` also passed
  with the canonical dependency file; the run included lockfile, 17 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the route de-duplication and focused regressions, docs
  references, and this timeline entry; preserve budget sanitization, route
  ordering, and recent-failure behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Model budget runtime bounds

- Hardened `ModelBudgetController` construction for release-safe runtime
  values: negative call limits fall back to the default, non-positive timeout,
  token, and failure-cooldown values fall back to safe defaults, and
  `maxCallsPerMinute: 0` remains an intentional model-disable switch.
- Added a focused regression covering invalid runtime values and the preserved
  zero-call behavior. The unique iteration log is
  `docs/timeline/2026-09-02-slice176-model-budget-runtime-bounds.md`.
- Verification: focused model-budget tests passed (4 cases), full Flutter
  tests passed (`+428`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` also passed
  with the canonical dependency file; the run included lockfile, 17 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the controller constructor sanitization and focused
  regression, docs references, and this timeline entry; preserve model budget
  evaluation, cooldown, and zero-call disable semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Non-finite nutrient normalization

- Hardened `FoodRecordNormalizer` so non-finite raw nutrient amounts and
  non-finite converted amounts are dropped before they reach canonical
  `Nutrient` models, SQLite writes, or JSON exports; valid nutrients in the
  same record remain available.
- Added a focused normalization regression covering `NaN`, conversion overflow
  to infinity, and a valid neighboring nutrient. The unique iteration log is
  `docs/timeline/2026-09-02-slice177-non-finite-nutrient-normalization.md`.
- Verification: focused normalization-toolkit tests passed (6 cases), full
  Flutter tests passed (`+429`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` also passed
  with the canonical dependency file; the run included lockfile, 17 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the finite-amount guards, focused regression, docs
  references, and this timeline entry; preserve canonical nutrient aliases,
  unit conversion, and valid-record normalization semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Import request limit boundary

- Hardened the `ImportRequest` value object so negative limits are normalized
  to `0` during construction, including `const` and `copyWith` requests. This
  prevents malformed callers from reaching importer `.take()` calls or
  count-based early exits with a negative value while preserving `0` as an
  explicit empty-request contract.
- Added a focused official-dataset request regression covering direct and
  copied negative limits. The unique iteration log is
  `docs/timeline/2026-09-02-slice178-import-request-limit-boundary.md`.
- Verification: focused official-dataset tests passed (6 cases), full Flutter
  tests passed (`+430`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` also passed
  with the canonical dependency file; the run included lockfile, 17 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the constructor normalization, focused regression,
  docs references, and this timeline entry; preserve valid limits, explicit
  zero-limit behavior, and dataset preparation semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Repository read limit normalization

- Added one shared repository-read limit normalizer and applied it to both
  `MemoryFoodRepository` and `SqliteFoodRepository`. Negative limits now yield
  empty pages before in-memory slicing, advanced-search early exits, or SQLite
  `LIMIT` parameters; zero remains an explicit empty-page request.
- Added Memory and SQLite regressions covering advanced search, country
  summaries, merge-review reads, and fetch-job history. The unique iteration
  log is
  `docs/timeline/2026-09-02-slice179-repository-read-limit-normalization.md`.
- Verification: focused repository tests passed (10 cases), full Flutter
  tests passed (`+432`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` also passed
  with the canonical dependency file; the run included lockfile, 17 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the shared read-limit helper, repository call-site
  guards, focused regressions, docs references, and this timeline entry;
  preserve valid paging, sorting, and SQLite query semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Export food-id limit boundary

- Hardened `FoodCatalogExportService.exportFoodIds` so negative caller limits
  normalize to `0` before identifier selection. Malformed export requests now
  produce a deterministic empty artifact instead of reaching `Iterable.take`
  with an invalid count; positive limits and existing deduplication remain
  unchanged.
- Added a focused export regression covering a negative limit, empty JSON
  payload, zero record count, and retained export-history behavior. The unique
  iteration log is
  `docs/timeline/2026-09-02-slice180-export-food-id-limit-boundary.md`.
- Verification: focused export-service tests passed (11 cases), full Flutter
  tests passed (`+433`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` also passed
  with the canonical dependency file; the run included lockfile, 17 importer,
  compare/accessibility, Web build, and provenance generate/verify checks.
- Rollback: remove only the export limit guard, focused regression, docs
  references, and this timeline entry; preserve identifier trimming,
  deduplication, artifact formats, and history semantics.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Export scope filename containment

- Hardened `FoodCatalogExportService` filename construction so the public
  `scopeType` is reduced to a safe slug before it is joined with the export
  directory. Path separators and traversal fragments can no longer escape the
  configured directory, while the original scope value remains unchanged in
  export payload and history labels.
- Added a focused export regression using a traversal-shaped scope type and
  asserting that the artifact parent remains the configured directory. The
  unique iteration log is
  `docs/timeline/2026-09-02-slice181-export-scope-filename-containment.md`.
- Verification: focused export-service tests passed (12 cases), full Flutter
  tests passed (`+434`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed,
  including lockfile, 17 importer, compare/accessibility, Web build, and
  provenance generate/verify checks.
- Rollback: remove only the filename slug guard, focused regression, docs
  references, and this timeline entry; preserve scope payload/history values,
  valid filenames, and export-directory selection.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Official ZIP extraction containment

- Hardened `DatasetPackagePreparer` ZIP extraction with segment-aware path
  containment. An archive entry that normalizes under a sibling prefix such as
  `extracted-evil` is now skipped instead of being written outside the
  configured extraction directory; valid nested files remain unchanged.
- Added a focused malicious-archive regression asserting the escaped file is
  absent while a safe nested file is extracted. The unique iteration log is
  `docs/timeline/2026-09-02-slice182-official-zip-extraction-containment.md`.
- Verification: focused official-dataset tests passed (7 cases), full Flutter
  tests passed (`+435`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed,
  including lockfile, 17 importer, compare/accessibility, Web build, and
  provenance generate/verify checks.
- Rollback: remove only the segment-aware containment guard, focused archive
  regression, docs references, and this timeline entry; preserve valid ZIP
  extraction and sentinel behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Official dataset download filename containment

- Hardened `HttpDatasetTransport.download` so absolute or traversal-shaped
  `suggestedFileName` values are rejected before any HTTP request or file write.
  The shared segment-aware path guard now covers both download and ZIP
  extraction targets; valid manifest filenames retain their existing paths.
- Added a focused transport regression asserting an escaping filename fails
  before network use and cannot create a sibling file. The unique iteration log
  is `docs/timeline/2026-09-02-slice183-official-download-filename-containment.md`.
- Verification: focused official-dataset tests passed (8 cases), full Flutter
  tests passed (`+436`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed,
  including lockfile, 17 importer, compare/accessibility, Web build, and
  provenance generate/verify checks.
- Rollback: remove only the download filename guard, shared-helper wiring,
  focused transport regression, docs references, and this timeline entry;
  preserve valid download and extraction behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Official dataset importer-id containment

- Hardened the official dataset path boundary so `importerId` must be a single
  non-empty path component. Absolute paths, parent-directory values, and both
  platform separator forms now fail before root resolution; valid manifest IDs
  retain their existing directory layout.
- Added transport and ZIP-preparer regressions proving unsafe IDs do not invoke
  their root resolvers. The unique iteration log is
  `docs/timeline/2026-09-02-slice184-official-importer-id-containment.md`.
- Verification: focused official-dataset tests passed (10 cases), full Flutter
  tests passed (`+438`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed,
  including lockfile, 17 importer, compare/accessibility, Web build, and
  provenance generate/verify checks.
- Rollback: remove only the importer-id validation, focused regressions, docs
  references, and this timeline entry; preserve valid directory resolution,
  downloads, and extraction.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Home refresh generation ownership

- Added a search-generation snapshot to HomePage's supplemental result refreshes.
  Initial/import/enrichment refreshes now check ownership before loading and
  after each repository/log/count await, so a stale query cannot overwrite a
  newer search or update its compare selection.
- Added a widget regression with a deliberately blocked salmon enrichment
  refresh, then submitted oats and released salmon; oats remains visible. The
  unique iteration log is
  `docs/timeline/2026-09-02-slice185-home-refresh-generation-ownership.md`.
- Verification: focused widget regression passed, full Flutter tests passed
  (`+439`), `flutter analyze` reported zero issues, and `git diff --check`
  passed. Strict `CI=true ./tool/ci_checks.sh` passed, including lockfile,
  17 importer, compare/accessibility, Web build, and provenance
  generate/verify checks.
- Rollback: remove only the refresh-generation parameter/checks, focused race
  regression, docs references, and this timeline entry; preserve search,
  import, enrichment, and supplemental-read behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 App metadata write-tail cleanup

- Updated `AppMetaWriteQueue` to remove a key's settled tail only when that
  exact tail is still current, retaining serialization for newer writes while
  preventing completed or failed keys from accumulating indefinitely.
- Added success/failure queue regressions that assert completed keys are
  released without disturbing an active key. The unique iteration log is
  `docs/timeline/2026-09-02-slice186-app-meta-write-tail-cleanup.md`.
- Verification: focused queue tests passed (4 cases), full Flutter tests passed
  (`+441`), `flutter analyze` reported zero issues, and `git diff --check`
  passed. Strict `CI=true ./tool/ci_checks.sh` passed, including lockfile,
  17 importer, compare/accessibility, Web build, and provenance
  generate/verify checks.
- Rollback: remove only settled-tail cleanup, the debug test count accessor,
  focused queue regressions, docs references, and this timeline entry; preserve
  per-key ordering and error propagation.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-02 Search expansion cache bound

- Bounded `SearchOrchestrator` query-expansion reuse to a validated default of
  32 entries. Cache hits now refresh recency, and the least-recently-used
  expansion is evicted when the cap is exceeded; enrichment re-expands an
  evicted query while retaining recent queries.
- Added a focused three-query eviction/re-expansion regression and kept the
  cache-size constructor contract explicit. The unique iteration log is
  `docs/timeline/2026-09-02-slice187-search-expansion-cache-bound.md`.
- Verification: focused orchestrator tests passed (11 cases), full Flutter
  tests passed (`+442`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed,
  including lockfile, 17 importer, compare/accessibility, Web build, and
  provenance generate/verify checks.
- Rollback: remove only the cache cap/recency helpers, focused eviction
  regression, docs references, and this timeline entry; preserve expansion
  semantics, enrichment routing, and existing failure isolation.
- Next slice: paused at the user's request after the final push; resume only
  on an explicit continuation instruction.

### 2026-09-01 Favorite template entry isolation

- Hardened HomePage `favorite_templates_v1` loading with a per-entry parser.
  Wrongly typed required/optional fields and malformed supplied timestamps now
  skip only that template instead of aborting the whole list; missing legacy
  timestamps retain the existing compatibility fallback.
- Added a widget regression with a malformed template before a valid template.
  The unique iteration log is
  `docs/timeline/2026-09-01-slice131-favorite-template-entry-isolation.md`.
- Verification: focused widget tests passed (9 cases), full Flutter tests
  passed (`+371`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed under
  a temporary environment-only sqlite system hook; the temporary pubspec
  block was removed and canonical dependency content is unchanged. The
  strict run included lockfile, importer, compare/accessibility, Web build,
  and provenance generate/verify checks.
- Rollback: remove only the favorite-template entry parser and focused
  regression, docs references, and this timeline entry; preserve metadata
  keys, valid-template behavior, UTF-8 budgets, and the write queue.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-01 Favorite persistence entry isolation

- Hardened HomePage `favorite_foods_v1` loading with a per-entry
  `_FavoriteFoodRef.fromJson` parser. Wrongly typed or empty entries are now
  skipped without aborting the whole list, and duplicate `foodId` entries are
  deterministically ignored after the first valid snapshot.
- Added a widget regression covering malformed, duplicate, and valid persisted
  favorites. The unique iteration log is
  `docs/timeline/2026-09-01-slice130-favorite-entry-isolation.md`.
- Verification: focused widget tests passed (8 cases), full Flutter tests
  passed (`+370`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed under
  a temporary environment-only sqlite system hook; the temporary pubspec
  block was removed and canonical dependency content is unchanged. The
  strict run included lockfile, importer, compare/accessibility, Web build,
  and provenance generate/verify checks.
- Rollback: remove only the favorite entry parser/deduplication and focused
  regression, docs references, and this timeline entry; preserve favorite
  metadata keys, UTF-8 budgets, write queue, and UI behavior for valid data.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-01 Saved-view monotonic timestamps

- Hardened `MergeReviewSavedView` so `updatedAt` cannot precede `createdAt`.
  `MergeReviewSavedViewStore` now retains an existing view's later
  `updatedAt` when the injected/system clock moves backwards, while still
  applying the newer name and filter snapshot.
- Added model and store regressions for inverse timestamp rejection and clock
  rollback ordering. The unique iteration log is
  `docs/timeline/2026-09-01-slice129-saved-view-monotonic-time.md`.
- Verification: focused saved-view model/store tests passed (21 cases), full
  Flutter tests passed (`+369`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed under
  a temporary environment-only sqlite system hook; the temporary pubspec
  block was removed and canonical dependency content is unchanged. The
  strict run included lockfile, importer, compare/accessibility, Web build,
  and provenance generate/verify checks.
- Rollback: remove only the timestamp invariant, monotonic update selection,
  focused regressions, docs references, and this timeline entry; preserve
  saved-view schema guards, UTF-8 budgets, serialized writes, and filtering.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-01 Provenance manifest strict schema

- Hardened `_verifyManifest` in `tool/build_release_provenance.dart` to require
  the exact generated root fields and exact `path`/`bytes`/`sha256` fields for
  every file entry. Extra or untracked fields now fail closed during release
  evidence verification.
- Added a focused regression for unknown root and file-entry fields. The
  unique iteration log is
  `docs/timeline/2026-09-01-slice128-provenance-schema.md`.
- Verification: focused CI workflow tests passed (54 cases), full Flutter
  tests passed (`+367`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed under
  a temporary environment-only sqlite system hook because the default local
  precompiled hook was stalled; the temporary pubspec block was removed and
  canonical dependency content is unchanged. The strict run included lockfile,
  importer, compare/accessibility, Web build, and provenance generate/verify
  checks.
- Rollback: remove only the exact root/entry schema guards, focused unknown-
  field regression, docs references, and this timeline entry; preserve
  artifact hashing, source-revision checks, Web contracts, and output schema.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-01 Saved-filter strict root schema

- Hardened `MergeReviewFilter.tryFromJson` to reject unknown JSON fields while
  continuing to allow the optional `severity` and `type` fields. Invalid or
  future-shaped filters therefore fail closed to `All` instead of silently
  discarding fields and changing the intended filter semantics.
- Added the unknown-field case to the existing strict parser regression. The
  unique iteration log is
  `docs/timeline/2026-09-01-slice125-filter-root-schema.md`.
- Verification: focused filter plus saved-view codec tests passed (10 cases),
  full Flutter tests passed (`+363`), `flutter analyze` reported zero issues,
  and `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed
  with the lockfile gate, 14 importer tests, compare/accessibility gates, Web
  release build, provenance generation, and provenance verification.
- Rollback: remove only the filter key-set guard and focused invalid-field
  case, docs references, and this timeline entry; preserve schema-version,
  enum validation, fail-open decoding, and saved-view behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-01 Saved review view UTF-8 byte budget

- Updated `MergeReviewSavedViewStore` to measure the persisted
  `merge_review_saved_views_v1` payload in UTF-8 bytes for both load rejection
  and save fitting. The configured cap now reflects actual serialized storage
  for multilingual view names and filter payloads.
- Added a focused regression covering multibyte load and save overflow while
  preserving no-write-on-rejection behavior. The unique iteration log is
  `docs/timeline/2026-09-01-slice121-saved-view-utf8.md`.
- Verification: focused saved-view store tests passed (`+11`), full Flutter
  tests passed (`+359`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, compare gates, Web release build,
  provenance generation, and provenance verification.
- Rollback: restore character-length accounting, remove the focused regression
  and documentation lines, and remove this timeline entry; preserve the schema,
  name normalization, serialized queue, and item limit.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-01 Persistence store runtime bounds

- Replaced debug-only constructor `assert` checks in `ActivityTraceStore` and
  `MergeReviewSavedViewStore` with runtime `ArgumentError` validation for
  positive item limits and the minimum UTF-8 payload budget. Invalid limits now
  fail consistently in release builds before any repository access.
- Added focused constructor regressions for zero/negative item limits and below-
  minimum byte budgets, while retaining the existing multibyte payload tests.
  The unique iteration log is
  `docs/timeline/2026-09-01-slice122-runtime-bounds.md`.
- Verification: combined focused store tests passed (`+27`), full Flutter tests
  passed (`+361`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, compare gates, Web release build,
  provenance generation, and provenance verification.
- Rollback: restore the constructor assertions and remove only the focused
  runtime-bound regressions, documentation lines, and this timeline entry;
  preserve UTF-8 payload accounting, serialized queues, fail-open reads, and
  item-limit behavior for valid configurations.
- Next slice: inspect one bounded persistence schema or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Saved-view strict root schema

- Hardened `MergeReviewSavedViewCodec.decode` to require the exact persisted
  root key set (`schemaVersion` and `views`). Unknown root fields now fail open
  instead of being silently accepted, keeping future schema additions explicit
  and preventing unvalidated data from entering the store canonicalizer.
- Added a focused regression with a valid view plus an unknown root field. The
  unique iteration log is
  `docs/timeline/2026-09-01-slice123-saved-view-root-schema.md`.
- Verification: focused saved-view codec/store tests passed (18 cases), full
  Flutter tests passed (`+362`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, compare and accessibility gates, Web
  release build, provenance generation, and provenance verification.
- Rollback: remove only the exact-root-key check, focused regression, docs
  references, and this timeline entry; preserve schema-version validation,
  invalid-entry filtering, UTF-8 budgets, and serialized store behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-01 HomePage app_meta UTF-8 byte budget

- Added the small canonical `AppMetaPayloadBudget` helper and routed all
  HomePage `app_meta` read limits and write/compaction decisions through its
  UTF-8 byte count. Recent replay timestamps/statuses, recent recalls, favorite
  filters/templates/foods, and prompt-config fallback now enforce the same
  storage-size semantics for multilingual and emoji payloads.
- Added a focused helper regression covering ASCII versus multibyte payloads;
  the existing HomePage widget suite also remains green. The unique iteration
  log is `docs/timeline/2026-09-01-slice124-home-app-meta-utf8.md`.
- Verification: focused helper plus HomePage widget tests passed (7 cases),
  full Flutter tests passed (`+363`), `flutter analyze` reported zero issues,
  and `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed
  with the lockfile gate, 14 importer tests, compare/accessibility gates, Web
  release build, provenance generation, and provenance verification.
- Rollback: remove the helper and restore the prior character-length checks in
  HomePage, then remove the focused regression, docs references, and timeline;
  preserve all existing metadata keys, trimming/compaction behavior, and
  interaction flows.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.

### 2026-09-01 HomePage app_meta per-key write queue

- Added the small canonical `AppMetaWriteQueue` and routed every HomePage
  `app_meta` write through a per-key serialized queue. A slow repository write
  can no longer complete after a newer write for the same key and overwrite its
  payload; writes for independent keys remain concurrent.
- A failed write is isolated so it does not poison later writes for that key.
  The focused queue regression covers invocation order, independent-key
  progress, and recovery after failure. The unique iteration log is
  `docs/timeline/2026-09-01-slice126-home-app-meta-write-queue.md`.
- Verification: focused queue plus HomePage widget tests passed (8 cases), full
  Flutter tests passed (`+365`), `flutter analyze` reported zero issues, and
  `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed with
  the lockfile gate, 14 importer tests, compare/accessibility gates, Web
  release build, provenance generation, and provenance verification.
- Rollback: remove the queue field/helper and focused queue regression, restore
  the prior direct `setAppMeta` calls, and remove only the related docs and
  timeline; preserve metadata keys, UTF-8 byte budgets, compaction, and user
  interaction behavior.
- Next slice: inspect one bounded persistence schema or release-evidence
  contract without duplicating canonical content.

### 2026-09-01 Saved-view item strict schema

- Hardened `MergeReviewSavedView.tryFromJson` to require the exact persisted
  item key set (`id`, `name`, `filter`, `createdAt`, and `updatedAt`). Unknown
  item fields now fail closed, complementing the existing exact codec root
  schema and preventing unvalidated future fields from entering the store.
- Added a focused regression for direct item parsing and codec filtering of a
  valid item carrying an unknown field. The unique iteration log is
  `docs/timeline/2026-09-01-slice127-saved-view-item-schema.md`.
- Verification: focused saved-view codec plus store tests passed (19 cases),
  full Flutter tests passed (`+366`), `flutter analyze` reported zero issues,
  and `git diff --check` passed. Strict `CI=true ./tool/ci_checks.sh` passed
  with the lockfile gate, 14 importer tests, compare/accessibility gates, Web
  release build, provenance generation, and provenance verification.
- Rollback: remove only the item key-set guard, focused unknown-field
  regression, docs references, and this timeline entry; preserve root schema,
  filter validation, invalid-entry filtering, UTF-8 budgets, and store queue
  behavior.
- Next slice: inspect one bounded persistence or release-evidence contract
  without duplicating canonical content.
