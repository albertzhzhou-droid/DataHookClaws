# DataHookClaws 升级队列（持续更新）

本队列用于记录“完全体模式”与竞品对标后的下一阶段升级项。

## 研究来源与依据
- 现有产品目标：本地优先、官方源可追溯、持续补全、可随时导出。
- 目前实现范围：检索/抓取/归并、合并审计、质量复审、手动治理、导出、设置、预算治理、AI 辅助。
- 目标缺口：缺少“竞品常见的闭环体验”如收藏、收藏对比、会话化任务、长周期用户行为闭环。

## 立即生效（M0）
- [ ] 最近搜索与快速回放（已部分支持）
  - 当前状态：已完成（主页历史 chip + 持久化）。
  - 下一个动作：增加“按来源/国家/标签聚合”的推荐入口。
- [x] 结果收藏（Favorite）与收藏夹入口（MVP）
  - 当前状态：已完成（主页收藏、回放、持久化）。
  - 下个动作：补齐收藏目录视图的标签筛选（如来源/分类）和批量组织动作。
- [x] 收藏目录视图（分组排序、近期常用）
  - 当前状态：已完成（按国家分组+筛选+Recent/A→Z 排序）。
  - 下个动作：补齐来源/分类标签视图与“收藏目录模板”保存/应用/删除。
- [x] 结果对比面板（2~3 个食物）
  - 当前状态：已完成（对比卡片、差异高亮、单位/缺失提醒与导出联动已就绪）。
  - 下个动作：继续补齐单位归一化策略与可访问性文本提示。
- [ ] 行为轨迹回放（搜索/导入/收藏/对比）
  - 当前状态：进行中（home 页面新增 activity 日志 + 回放入口 + 元数据持久化；Home/Operations 已共享串行 store 与成功快照广播）。
  - 目标：按动作类型支持回放、失败恢复与可回放日志筛选。
- [x] 对比导出回读（导出后恢复 compare）
  - 当前状态：已完成（导出记录保留 compare scope，支持回放重建比较选择）。
  - 下个动作：补齐 compare 回放中“ID 不存在/不可用”时的降级提示与重新抓取路径。
- [x] compare 回放状态可见化（M0）
  - 当前状态：已完成（Recent export recalls chip 显示回放恢复状态）。
  - 下个动作：研究是否要把回放状态持久化到 session trace 并与失效条目清理联动。
- [x] compare 回放草稿态治理（M0）
  - 当前状态：已完成（新增草稿状态清理入口、静默超时自动归档与手动重建启动时自动退出草稿态）。
  - 下个动作：上架后采集 Draft 提示点击率与误触率数据，评估时长提示阈值与默认文案是否继续保留。
- [x] compare 回放草稿到期一键清理（M0）
  - 当前状态：已完成（到期 24h 内显示「Clear draft now」，保留 recall 并将状态降级为 `Unavailable (manual rebuild required)`）。
  - 下个动作：研究是否需要将到期 24h 改为动态阈值（如基于用户活跃时段）并新增自动归档通知。
- [x] compare 回放草稿到期提醒（M0）
  - 当前状态：已完成（加载 compare 回放草稿状态后，在 24h 紧急窗口触发一次性弹窗提醒，提供“立即清理/稍后提醒”）。
  - 下个动作：研究是否支持“按会话提醒限制”与“自动延长一次性提醒”。
- [x] compare 回放草稿临近过期提示：已完成（在 chip 与状态卡提示到期 24h 内的草稿，提供继续草稿引导）。
- [x] compare 回放失效条目清理（M0）
  - 当前状态：已完成（新增“Clear unavailable”入口，支持一键移除 Unavailable 状态条目）。
  - 下个动作：定义失败阈值触发下是否自动建议清理/重试。
- [x] compare 回放缺失项可重试（M0）
  - 当前状态：已完成（新增“Retry missing items”按钮与缺失 ID 提示，支持对 compare 回放缺失条目增量恢复）。
  - 下个动作：研究多次重试失败时的自动切换策略（回放改为手动重建/降级提示）。
- [x] 近周期任务闭环回看（MVP）
  - 当前状态：已完成（主页新增时间线会话聚合卡片 + 会话级回放按钮，支持基于 20 分钟间隔的任务闭环回放）。
  - 下个动作：评估任务会话回放失败重试与误回放抑制策略。
- [ ] 治理动作行为轨迹扩展（Operations）
  - 当前状态：进行中（Operations 中 merge/split/override/retry/share 记录入统一 trace；跨页并发追加、清除排序和失败恢复已收口）。
  - 目标：给治理动作增加可筛选的重放与撤销草案。
- [x] 行为轨迹并发落盘基础（M0）
  - 当前状态：已完成（同一 repository 实例的 load/append/clear 串行化、跨页成功快照广播、损坏/超长 payload fail-open、队列失败恢复）。
  - 当前边界：仅覆盖同 isolate、同 repository 对象；独立 wrapper/进程或直接 app_meta 写入不在该队列内。
  - 下个动作：把所有 `activity_trace_v1` 访问收敛为唯一 store API，并评估数据库级事务/CAS 以覆盖多实例写入。
- [x] MergeReview 复审筛选基础（M0）
  - 当前状态：已完成（严重度 × issue type 组合筛选、页面/匹配/总数计数、清除、`app_meta` 重启恢复、损坏/未知配置 fail-open；repository 在完整 backlog 上先筛选后分页；SQLite 已用固定查询数的单事务 bulk snapshot 代替逐食物 details N+1）。
  - 当前边界：SQLite 仍在 Dart 内完整物化 FoodDetails/issue backlog 后筛选分页；尚未做 SQL-native filter pushdown、物化 review index 或常量内存游标。
  - 验证：bulk/旧 hydration 完整签名 parity、固定 8 SELECT/单 transaction ID、1005 组参数上限与重复 audit 回归通过；全量 187 项、严格 CI 和 Web build 通过。
  - 下个动作：评估物化 review index 或增量 issue table，避免每次完整 Dart 物化。
- [x] MergeReview 命名保存视图（M0）
  - 当前状态：已完成（当前非 All 筛选可命名保存、应用、删除；最多 12 项；同名忽略大小写原位更新；活动筛选与保存视图独立持久化/失败恢复）。
  - 当前边界：同 repository 对象内写入串行；跨 wrapper/进程仍是 last-writer-wins，尚无重命名、导出/共享和批量动作。
  - 验证：严格 filter parser、versioned codec、store 并发/容量/损坏恢复和 Operations 交互定向 36 项通过；全量 187 项、严格 CI 和 Web build 通过。
  - 后续闭环：结构化 identity、当前页选择与非执行型待办状态已由下列条目完成；下一步转向跨页 inventory 与 revision 重验。
- [x] MergeReview 当前页批量选择基础（M0）
  - 当前状态：已完成（逐卡 Checkbox、Select visible、live-region 计数、Clear selection；筛选/翻页/保存视图应用清空，同查询成功刷新做可见交集修剪）。
  - 当前边界：仅当前成功页、仅内存且没有批量写动作；不支持跨页/全匹配、持久队列或原子批处理。v1 identity 已做逻辑去重，但仍不是数据库 PK 或 target revision。
  - 验证：Operations 21 项覆盖零 repository/app_meta 副作用、重复 view apply、刷新交集和 loading gate；全量 191 项、严格 CI 和 Web build 通过。
  - 后续闭环：结构化 logical identity 与非执行型 worklist 已由下列条目完成；target revision/revalidation 仍待设计。
- [x] MergeReview 结构化逻辑身份（M0）
  - 当前状态：已完成（v1 canonical base64url JSON codec、strict decode、四类 type-specific subject、可变 evidence 排除、重复 logical issue 确定性折叠、Memory/SQLite parity）。
  - 当前边界：不是数据库 PK/revision/idempotency token；source/subject/schema 变化会换 ID，旧 activity trace 与 governance note 不自动迁移或 join。
  - 验证：codec/Unicode/非法输入、营养同 summary 防碰撞、证据/顺序稳定性、重复 candidate 去重及跨 repository 乱序 parity 定向 17 项；全量 204 项、严格 CI 和 Web build 通过。
  - 后续闭环：queued/deferred 模型、store 与当前页 UI 已由下列条目完成；identity 仍不等同于可执行 revision。
- [x] MergeReview 非执行型 worklist 数据层（M0）
  - 当前状态：已完成（`queued` / `deferred` v1 item + codec、`merge_review_worklist_v1` store、批量 last-wins upsert、remove/clear、稳定排序与同 repository 串行化）。
  - 原子/容量边界：每批一次 read-modify-write；最多 500 项、总 envelope 最多 1,048,576 UTF-8 bytes；新容量或字节超限整批拒绝且不部分写入。系统时钟回拨不降低已有 `updatedAt`。
  - 损坏恢复：load 对损坏/未来 schema/坏 item/重复/超限 fail-open；变更拒绝覆盖不可安全解释的持久状态，只有显式 clear 可恢复。公开构造限额在 release 运行时校验。
  - 身份/目标边界：source-scoped target 必须匹配 identity source；nutrient variance 是 canonical-level identity，可刷新独立 actionable target。保存的是证据快照，不是 DB revision 或可执行命令。
  - 当前边界：数据层不负责 UI、跨页 worklist 浏览、后台同步、CAS 或 merge/split/override 执行；同 isolate/同 repository 对象之外仍可能 last-writer-wins。当前页 UI 已在下一条闭环。
  - 验证：model/store 定向 26 项、`flutter analyze` 零问题、全量 230 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过。
  - 后续闭环：当前页 UI 已在下一条完成，并继续保持 snapshot 与可执行 revision 语义分离。
- [x] MergeReview worklist 当前页 UI（M0）
  - 当前状态：已完成（当前成功页可 Queue / Defer / exact-ID Untrack；显示全 worklist 计数、逐卡状态与 `Review snapshot changed`；confirmed Clear 可恢复损坏持久状态且不删除 food/governance 数据）。
  - 可靠性：worklist 独立加载/失败/重试并保留最近成功快照；失败写保留选择与旧 chip。变更期间冻结 review context，manual governance 与 worklist 写入双向互斥，期间 refresh 合并为结束后一次执行。
  - 非执行边界：所有 worklist 动作只改变 queued/deferred snapshot，不调用 merge/split/override，不写 governance/activity trace。snapshot-change 只是保存字段比较，不是 live DB revision/stale 真值。
  - 当前边界：动作输入只来自当前可见成功页；跨页 inventory 已在下一条提供只读浏览，但仍无跨页选择、不可见/消失 identity 盘点或迁移、后台同步、revision/CAS 重验、批量治理执行。
  - 验证：model/store 26 项 + Operations widget 33 项（合计 59）；`flutter analyze` 零问题、全量 242 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过。
  - 后续闭环：只读跨页 inventory 已在下一条完成；当前页 mutation 与 inventory 浏览继续保持职责分离。
- [x] MergeReview 只读跨页 worklist inventory（M0）
  - 当前状态：已完成（默认折叠、完整 loaded snapshot、沿用 store 顺序、每页 20 条、完整 evidence/timestamp/structured identity；可见当前 review 页之外的持久项）。
  - 可靠性：load/upsert/remove/clear 成功后统一校正 offset；首次读失败不伪装空清单，后续 refresh 失败保留最近成功快照；父状态保留展开上下文并避免 PageStorage 类型冲突。
  - 零副作用边界：inventory 分页和展开不读写 repository、不发 review query、不写 trace、不执行治理；不提供 checkbox/details/Untrack/merge/split/override。
  - 当前边界：只表示 loaded stored snapshots，不判断 orphan/resolved/stale/current；没有 identity migration、live existence/revision/CAS 重验、后台同步、跨页选择或批量治理执行。本地状态筛选与文本搜索已由后续条目完成。
  - 验证：Operations 36 项、`flutter analyze` 零问题、全量 245 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过。
  - 后续闭环：All / Queued / Deferred 本地筛选已在下一条完成；inventory 仍保持只读快照语义。
- [x] MergeReview inventory 本地状态筛选（M0）
  - 当前状态：已完成（All/Queued/Deferred 全清单计数、匹配子集范围/分页、筛选切换回首匹配页、变更后 offset 校正、零匹配有界空状态）。
  - 可靠性：筛选仅为页面临时状态，重建恢复 All 且不写 `app_meta`；worklist load/write 期间控件和旧捕获 callback 均被锁定，后续读取失败可继续浏览最近成功快照。
  - 零副作用边界：保持 store 顺序，不读写 repository、不发 review query、不写 governance/trace；只描述 loaded stored snapshots，不推断 orphan/resolved/stale/current。
  - 验证：Operations 39 项、`flutter analyze` 零问题、全量 248 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过。
  - 后续闭环：有界本地文本搜索已由下一条完成，并继续保持非 live、非执行语义。
- [x] MergeReview inventory 有界本地文本搜索（M0）
  - 当前状态：已完成（临时搜索框/Clear、status 交集、匹配范围与分页、query/clear 回首匹配页、成功快照后组合 offset 校正）。扫描范围受 worklist 500 项上限约束。
  - 字段/匹配边界：仅 canonical ID、target source ID、subject、suggested canonical、reason、candidate、full identity；trim + case-insensitive 单字段 literal contains。排除 status/type/timestamps/identity-source 重复值/标签/占位词，不做 regex/fuzzy/跨字段拼接。
  - 可靠性：query/controller 仅页面内存，重建为空且不写 `app_meta`；后续读取失败保留最近成功 snapshot/query。load/write 期间输入与 Clear 禁用，旧捕获 callback 有 method guard。
  - 零副作用边界：保持 store 顺序，不读写 repository、不发 review query、不写 governance/trace；不判断 orphan/resolved/stale/current，不做 identity migration/revision 重验或治理执行。
  - 验证：Operations 41 项、`flutter analyze` 零问题、全量 250 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立 diff 复审无 blocker。
  - 后续闭环：held-read loading 分支与成功刷新组合校正已由下一条测试硬化完成。
- [x] MergeReview inventory held-read 回归硬化（M0）
  - 当前状态：已完成（test-only controlled read；held loading 禁用 search/Clear/status/pager，旧捕获 callback method guard；成功缩水 snapshot 保留 query/filter 并校正末页）。
  - 边界：未改 production 接口/行为；测试直接替换 fixture persistence 只用于模拟另一 writer 的最新 snapshot，不扩展当前 same-repository 串行保证。
  - 验证：Operations 42 项、`flutter analyze` 零问题、全量 251 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过。
  - 后续闭环：exact-ID loaded-review-page presence 已由下一条完成。
- [x] MergeReview inventory loaded-review-page exact-ID presence（M0）
  - 当前状态：已完成（完整 loaded worklist 的 on/outside 汇总 + 当前 inventory 项 marker；inventory status/search/page 不改变全量计数；本片无 presence filter）。
  - 可用性：仅 selected review filter/page 最新请求成功且非 loading/error 时可比较；initial/pending/retained-error/retry 均为 unavailable，成功空页允许 `0 on page`。
  - 精确边界：只按完整 `issueId` membership；相同 canonical/source/type 不得碰撞。Outside 只可解释为另一 review 页或 active filter 排除，禁止 orphan/resolved/stale/current/live/safe 推断。
  - 零副作用边界：summary/live-region 与非交互 chip 不新增 repository read/write、review query、governance/trace、identity migration、revision validation 或执行动作。
  - 验证：Operations 45 项、`flutter analyze` 零问题、全量 254 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立 diff 复核无 blocker。
  - 后续闭环：availability-safe 的本地 presence 筛选已由下一条完成。
- [x] MergeReview inventory loaded-review-page presence 本地筛选（M0）
  - 当前状态：已完成（临时 All/On/Outside、完整 worklist chip counts、status/search/presence 交集范围与 20 条分页；重建恢复 All，不写 `app_meta`）。
  - 可用性：On/Outside 只在 current review request 成功时开放；真实 review request 开始会原子重置 non-All 与 offset，pending/failure/retry 显式 unavailable，成功空页为真实 0。
  - lane/竞态：worklist read/write 只锁定控件和旧 callback，不重置 active presence；后续失败保留 last-good，成功缩水保留筛选并校正分页。review refresh、initial failure、held write/read、stale callback 与恢复均有回归。
  - 精确/零副作用边界：只按完整 issue ID；Outside 不表示 orphan/resolved/stale/current/live/safe。筛选不新增 repository read/write、review query、governance/trace、identity migration、revision validation 或执行动作。
  - 验证：Operations 47 项、`flutter analyze` 零问题、全量 256 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核无 blocker。
  - 后续闭环：overlapping successful response 的 presence ownership 已由下一条 test-only 回归覆盖。
- [x] MergeReview inventory stale-success presence ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；旧 Warning=2/0 与新 Warning+reuse=1/1 乱序完成，新成功拥有 review/presence，旧成功不能回滚）。
  - 覆盖：latest review count、exact-ID summary、item markers、active On、inventory range 与 reuse-only 子集；同时锁定 loading 清除。
  - 零副作用：除两次预期 review query/filter persistence 外，不新增 operations read、worklist write、governance action 或 presence persistence；production 未改。
  - 验证：Operations 48 项、`flutter analyze` 零问题、全量 257 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核无 blocker。
  - 后续闭环：newest failure + older stale success 的 ownership 已由下一条完成。
- [x] MergeReview inventory newest-failure presence ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；latest Warning+reuse 失败后，旧 Warning success 不能清 error、发布 retained page 或重新开放 presence）。
  - 恢复：retry 必须沿用最新 filter；成功后恢复 1/1 exact-ID summary 与正确 markers/chips，同时保持 All，不复活请求前 On。
  - 测试基础：no-settle filter helper 增加有界 lazy-list materialization，稳定 pending 布局下的三条乱序回归；无 production 改动。
  - 零副作用：锁定 operations reads、worklist writes、meta/presence persistence、governance actions、query count 与 retry context。
  - 验证：Operations 49 项、`flutter analyze` 零问题、全量 258 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核无 blocker。
  - 后续闭环：newest success + older stale failure 的 ownership 已由下一条完成。
- [x] MergeReview inventory stale-failure presence ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；latest Warning+reuse success 后，旧 Warning failure 不注入 error/retry、不关闭 presence、不回滚 latest membership）。
  - active-local 锁：latest 1/1 后选择 Outside；stale failure 后仍 selected/enabled，仅 category snapshot/Outside marker 可见。
  - 零副作用：仅两次预期 review query/filter writes；无 operations reread、worklist rewrite、governance mutation、presence persistence 或残留 loading。
  - 验证：Operations 50 项、`flutter analyze` 零问题、全量 259 项、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核无 blocker。
  - 后续闭环：可区分错误消息的双失败 ownership 已由下一条完成。
- [x] MergeReview inventory 双失败 error ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；latest 与 stale failure 使用可区分错误文本，只有 latest error 拥有可见错误与 retry lane）。
  - presence 锁：latest failure 后为完整 inventory + All/unavailable；stale failure 不能改 error、membership、marker 或 chips；retry current filter 成功后恢复 1/1 并保持 All。
  - 零副作用：`app_meta` 基线在两次 failure 之间捕获并立即复验；同时锁定 operations reads、query count、worklist-key writes 与 governance actions。production 未改。
  - 验证：Operations 51 项、`flutter analyze` 零问题、全量 260 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核发现并确认闭合 late-baseline gap，无 blocker。
  - 后续闭环：out-of-bounds offset 内部 corrective second query 的发布 ownership 已由下一条完成。
- [x] MergeReview corrective second-query 发布 ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；held primary offset 100 合法触发 corrective offset 0，随后 latest Warning 抢占；旧 correction 不能发布）。
  - review/presence 锁：latest warning-only review、1/1 summary、high Outside/warning On markers 与 active On warning-only inventory 在 stale correction 后全部保持，loading/error 不复活。
  - 拓扑/零副作用：精确锁定 primary 100 -> corrective 0 -> latest Warning 0；operations reads 不变，仅一次 filter meta write，worklist-key writes 与 governance 均不增长。custom-page helper 校验 response offset/limit。
  - 验证：Operations 52 项、`flutter analyze` 零问题、全量 261 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核无 blocker。
  - 后续闭环：stale primary corrective dispatch generation guard 已由下一条完成。
- [x] MergeReview stale-primary corrective dispatch guard（M0）
  - 当前状态：已完成（private `_loadReviewPage` 在 second dispatch 前校验 captured generation/mounted；stale primary first page 由 outer guard 丢弃且不再读 repository）。
  - failure-first 证据：旧实现产生 `All@100 -> Warning@0 -> stale All@0`；修复后精确 suffix 仅 `All@100 -> Warning@0`。上一条仍证明 owned correction 可合法发出、失权后不可发布。
  - 生命周期/错误边界：dispose 后不追加 corrective read/state；primary 与 owned corrective error 仍传播到 current outer catch，已发 stale correction 继续由外层 generation guard 隔离。
  - 零副作用：latest Warning count/identity 与 loading/error 保持；operations reads 不变，仅一次 filter meta write，worklist-key writes 与 governance 均不增长。
  - 验证：Operations 53 项、`flutter analyze` 零问题、全量 262 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核无 blocker。
  - 后续闭环：owned corrective failure 的 inline error/retry 与 distinct recovery 已由下一条完成。
- [x] MergeReview owned corrective failure/retry ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；owned `All@100 -> All@0` correction 失败进入唯一 inline error/Retry，retry 再走同一拓扑并发布 distinct warning-only page）。
  - presence/recovery：请求前自证 active On/high-only；失败后 selected All + full inventory + unavailable/disabled/unknown；恢复后 high Outside/warning On，All 保持并可再选 On 得 warning-only。
  - 防假通过：final correction 返回 1-item warning page而非 retained old high page；review identity/count 与 markers 必须交换。所有四个 pending 均 complete/fail。
  - 零副作用：精确四-query records；operations reads、全部 meta writes、worklist-key writes 与 governance 均不增长，failure 后二次基线隔离 retry 段。
  - 验证：Operations 54 项、`flutter analyze` 零问题、全量 263 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核两个 false-pass gap 均闭合，无 blocker。
  - 后续闭环：held out-of-bounds primary 在页面 dispose 后完成时的 no-correction/no-exception 回归已由下一条完成。
- [x] MergeReview disposed-primary corrective 生命周期 ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；held `All@100` 期间 dispose Operations 页面，迟到 primary 真实进入越界 corrective 判定但不派发 `All@0`）。
  - 防假通过：明确证明 OperationsPage 已销毁；primary response 为 empty + matching 1 + offset/limit 100；completer 从 pending 到 completed，两个 pump 后页面仍不存在且 Flutter exception queue 为空。
  - 零副作用：query suffix 精确仅 `All@100`；operations reads、全部 meta writes、worklist-key writes 与 governance 均不增长，正常路径无未完成 pending。
  - 验证：Operations 55 项、`flutter analyze` 零问题、全量 264 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核无 blocker。
  - 后续闭环：already-dispatched corrective 在 newer success 后迟到 failure 的 stale-error ownership 已由下一条完成。
- [x] MergeReview stale-corrective-failure ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100 -> All@0 corrective pending -> Warning@0 success` 后，旧 correction failure 完全静默）。
  - ownership：latest warning-only review、1/1 exact presence、high Outside/warning On 与 active On warning-only inventory 在唯一 `STALE_CORRECTIVE_FAILURE` 后全部保持；error/retry/loading/exception 均不存在且 chips 保持 enabled。
  - 防假通过：stale failure 前 completer 状态锁定 `[true,false,true]`；终态三项全 completed，query suffix 精确三条，并以 review + marker + On subset identity 排除同计数假通过。
  - 零副作用：operations reads、worklist-key writes 与 governance 不增长；仅允许一次 Warning filter meta write，latest-success 二次基线证明 stale failure 无新增。
  - 验证：Operations 56 项、`flutter analyze` 零问题、全量 265 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；独立复核无 blocker。
  - 后续闭环：newer failure + stale corrective failure 的 error/retry ownership 与 current-context recovery 已由下一条完成。
- [x] MergeReview latest-failure stale-corrective error/retry ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100 -> All@0 corrective pending -> Warning@0 failure -> Warning@0 retry success`，旧 corrective failure 不夺取 latest error/Retry ownership）。
  - ownership/presence：最新 failure 后保持 selected All、完整 inventory、unavailable summary/markers 与禁用 On/Outside；`STALE_CORRECTIVE_FAILURE` 不能覆盖/重复 error、夺 Retry、重置 local state 或改变 review/membership。current-context Warning retry 成功后恢复 1/1 exact presence、high Outside/warning On 与 distinct warning-only review。
  - 防假通过：stale failure 前 completer `[completed, pending, completed]`，终态四个 held query 全 settle；retry 必须是 Warning@0，最终 review 为 1 matching/102 total 且 On subset 仅 warning。
  - 零副作用：精确 query suffix 为 `All@100 -> All@0 -> Warning@0 -> Warning@0`；operations reads、worklist-key writes、governance 不增长，仅一次预期 Warning filter meta write；latest failure 后二次 metadata baseline 隔离 stale failure。
  - 验证：Operations 57 项、`flutter analyze` 零问题、全量 266 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；本地复核无 blocker。
  - 后续闭环：页面 dispose 后已派发 corrective failure 的 no-publication/no-exception 生命周期回归已由下一条完成。
- [x] MergeReview disposed corrective failure 生命周期 ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100` primary 越界后真实派发 `All@0` corrective，页面 dispose，再注入 `DISPOSED_CORRECTIVE_FAILURE`，迟到 failure 完全静默）。
  - 生命周期/防假通过：corrective dispatch 与 pending 状态均在 dispose 前锁定；dispose 后才 fail，两个 completer 最终全 completed，Flutter exception queue 为空，OperationsPage 不重现。
  - 零副作用：query suffix 精确 `All@100 -> All@0`；operations reads、metadata writes、worklist-key writes 与 governance 均不增长，未产生 error/retry/loading 或 review publication。
  - 验证：Operations 58 项、`flutter analyze` 零问题、全量 267 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；本地复核无 blocker。
  - 后续闭环：已派发 corrective success 在页面 dispose 后的对称 no-repopulation/no-side-effect 回归已由下一条完成。
- [x] MergeReview disposed corrective success 生命周期 ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100` primary 越界后真实派发 `All@0` corrective，页面 dispose，再完成正常 corrective success，迟到 success 完全静默）。
  - 生命周期/防假通过：corrective dispatch 与 pending 状态均在 dispose 前锁定；dispose 后才 complete broad success，两个 completer 最终全 completed，Flutter exception queue 为空，OperationsPage 不重现。
  - 零副作用：query suffix 精确 `All@100 -> All@0`；operations reads、metadata writes、worklist-key writes 与 governance 均不增长，未产生 review/presence publication 或重建页面。
  - 验证：Operations 59 项、`flutter analyze` 零问题、全量 268 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；本地复核无 blocker。
  - 后续闭环：pending corrective 被 newer failure supersede 后再成功的 latest error/retry ownership 回归已由下一条完成。
- [x] MergeReview stale corrective success after newer failure ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100 -> All@0 corrective pending -> Warning@0 failure -> stale All@0 success -> Warning@0 retry`，旧 corrective success 不清 latest error/Retry）。
  - ownership/recovery：最新 failure 保持唯一 error/Retry、unavailable review；stale broad success 不发布、不恢复 loading、不改 retry context。当前 Warning retry 成功后才发布 1 matching/102 total 的 distinct one-warning page。
  - 防假通过：corrective 在 newer failure 前明确 pending；stale success 后 error/retry 仍在；retry 固定 Warning@0，四个 held query 最终全 completed 且无 exception。
  - 零副作用：精确 query suffix `All@100 -> All@0 -> Warning@0 -> Warning@0`；operations reads 与非预期 metadata、worklist-key writes、governance 均不增长，仅一次预期 Warning filter meta write。
  - 验证：Operations 60 项、`flutter analyze` 零问题、全量 269 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；本地复核无 blocker。
  - 后续闭环：stale corrective success 在 newer retry 已启动后到达的 current-loading/retry-response ownership 回归已由下一条完成。
- [x] MergeReview stale corrective success during active retry ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100 -> All@0 corrective pending -> Warning@0 failure -> Warning@0 retry pending`，retry 启动后旧 `All@0` success 到达仍被隔离）。
  - ownership/recovery：stale broad success 不能停止 current loading、发布 broad page、清/替换 retry context 或 settle current Warning Future；current Warning success 才发布 1 matching/102 total 的 one-warning page。
  - 防假通过：retry Future 在 stale success 后仍保持 pending，count 继续显示 `Loading review issues...`，四个 held query 最终全 settle，且无 Flutter exception。
  - 零副作用：精确 query suffix `All@100 -> All@0 -> Warning@0 -> Warning@0`；operations reads、非预期 metadata、worklist-key writes 与 governance 均不增长，仅一次预期 Warning filter meta write。
  - 验证：Operations 61 项、`flutter analyze` 零问题、全量 270 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；本地复核无 blocker。
  - 后续闭环：stale corrective failure 在 active retry 时到达的 current-loading/error ownership 回归已由下一条完成。
- [x] MergeReview stale corrective failure during active retry ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100 -> All@0 corrective pending -> Warning@0 failure -> Warning@0 retry pending`，retry 启动后旧 `All@0` failure 到达仍被隔离）。
  - ownership/recovery：stale corrective failure 不能冒泡 error、取得 Retry ownership、停止 current loading 或 settle current Warning Future；current Warning success 才发布 1 matching/102 total 的 one-warning page。
  - 防假通过：retry Future 在 stale failure 后仍保持 pending，count 继续显示 `Loading review issues...`，四个 held query 最终全 settle，且无 Flutter exception。
  - 零副作用：精确 query suffix `All@100 -> All@0 -> Warning@0 -> Warning@0`；operations reads、非预期 metadata、worklist-key writes 与 governance 均不增长，仅一次预期 Warning filter meta write。
  - 验证：Operations 62 项、`flutter analyze` 零问题、全量 271 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；本地复核无 blocker。
  - 后续闭环：stale corrective failure 在 current retry success 之后到达的 late-error ownership 回归已由下一条完成。
- [x] MergeReview stale corrective failure after retry success ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100 -> All@0 corrective pending -> Warning@0 failure -> Warning@0 retry success`，current page 发布后旧 `All@0` failure 到达仍被隔离）。
  - ownership/recovery：current Warning success 已发布 1 matching/102 total 的 one-warning page 并清除 error/retry/loading；stale failure 不能冒泡 error、恢复 Retry/loading、替换页面或改变 selected Warning context。
  - 防假通过：late failure 在 current success 后真实注入，one-warning page/count 仍保持，最终 corrective Future settle 且无新增 query 或 Flutter exception。
  - 零副作用：精确 query suffix `All@100 -> All@0 -> Warning@0 -> Warning@0`；operations reads、非预期 metadata、worklist-key writes 与 governance 均不增长，仅一次预期 Warning filter meta write。
  - 验证：Operations 63 项、`flutter analyze` 零问题、全量 272 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；本地复核无 blocker。
  - 后续闭环：stale corrective success 在 current retry success 之后到达的对称 late-publication ownership 回归已由下一条完成。
- [x] MergeReview stale corrective success after retry success ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100 -> All@0 corrective pending -> Warning@0 failure -> Warning@0 retry success`，current page 发布后旧 `All@0` success 到达仍被隔离）。
  - ownership/recovery：current Warning success 已发布 1 matching/102 total 的 one-warning page 并清除 error/retry/loading；stale broad success 不能重新发布 broad page、改变 selected Warning context、恢复 loading 或改写已发布 identity。
  - 防假通过：late success 在 current success 后真实注入，one-warning page/count 仍保持，最终 corrective Future settle 且无新增 query 或 Flutter exception。
  - 零副作用：精确 query suffix `All@100 -> All@0 -> Warning@0 -> Warning@0`；operations reads、非预期 metadata、worklist-key writes 与 governance 均不增长，仅一次预期 Warning filter meta write。
  - 验证：Operations 64 项、`flutter analyze` 零问题、全量 273 项、`git diff --check`、严格 CI + 14 importer + compare 全门禁 + Web build 通过；本地复核无 blocker。
  - 后续闭环：toolbar refresh 后 stale primary/corrective completion 的 ownership 回归已由下一条完成。
- [x] MergeReview toolbar refresh stale corrective failure ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100 -> All@0 corrective pending -> toolbar Refresh -> All@100 newer request`，newer page 发布后旧 corrective failure 到达仍被隔离）。
  - ownership/recovery：newer refresh page 保持 offset100 / `Showing 101-102 of 102 matching review issues (102 total)` 与 `BACKLOG_TARGET`；stale failure 不能冒泡 error/retry/loading 或改写 page/identity。
  - 防假通过：corrective 在 refresh 前明确 pending；newer page success 后再 fail stale corrective；三 query 全 settle，无 exception。
  - 零副作用：query suffix 为 `All@100 -> All@0 -> All@100`；toolbar operations reads 精确预期增量且 stale 后不变；review meta、worklist-key、governance unchanged。
  - 验证：Operations 65 项、`flutter analyze` 零问题、全量 274 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：in-flight 越界 primary/corrective 时 Clear review filters/reset 的 ownership 回归已由下一条完成。
- [x] MergeReview Clear review filters stale corrective success ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`High@0 -> High@100 -> High@0 corrective pending -> Clear review filters -> All@0 newer request`，newer All page 发布后旧 High corrective success 到达仍被隔离）。
  - ownership/recovery：newer All page 保持 offset0 / `Showing 1-100 of 102 matching review issues (102 total)` 与 `All severities`；stale success 不能重新发布 High page、恢复 High filter 或冒泡 error/retry/loading。
  - 防假通过：High corrective 在 Clear 前明确 pending；newer All success 后再完成 stale corrective；四 query 全 settle，无 exception。
  - 零副作用：query suffix 为 `High@0 -> High@100 -> High@0 -> All@0`；operations reads、metadata writes 在 stale 后不变；worklist-key、governance unchanged。
  - 验证：Operations 66 项、`flutter analyze` 零问题、全量 275 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：in-flight 越界 primary/corrective 时 saved-view apply 的 ownership 回归已由下一条完成。
- [x] MergeReview saved-view stale corrective failure ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`All@100 -> All@0 corrective pending -> saved Warning@0 newer request`，newer Warning page 发布后旧 broad corrective failure 到达仍被隔离）。
  - ownership/recovery：`Warning saved` page 保持 `Showing 1 of 1 matching review issues (102 total)`、`BACKLOG_TARGET` 与 saved-view chip selected；stale failure 不能冒泡 error/retry/loading、替换 page 或清除 selection。
  - 防假通过：All corrective 在 saved-view apply 前明确 pending；newer Warning success 后再 fail stale corrective；三 query 全 settle，无 exception。
  - 零副作用：query suffix 为 `All@100 -> All@0 -> Warning@0`；operations reads、filter metadata 在 stale 后不变；worklist-key、governance unchanged。
  - 验证：Operations 67 项、`flutter analyze` 零问题、全量 276 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：saved-view re-apply 后 stale corrective failure 的 ownership 回归已由下一条完成。
- [x] MergeReview saved-view re-apply stale corrective failure ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`High@0 -> High@100 -> High@0 corrective pending -> re-apply High saved view@0 newer request`，newer High page 发布后旧 corrective failure 到达仍被隔离）。
  - ownership/recovery：active `High saved` page 保持 offset0 / `Showing 1-100 of 101 matching review issues (102 total)` 与 saved-view chip selected；stale failure 不能冒泡 error/retry/loading、替换 page 或清除 selection。
  - 防假通过：High corrective 在 re-apply 前明确 pending；newer High success 后再 fail stale corrective；四 query 全 settle，无 exception。
  - 零副作用：query suffix 为 `High@0 -> High@100 -> High@0 -> High@0`；operations reads 与两次预期 filter metadata writes 在 stale 后不变；worklist-key、governance unchanged。
  - 验证：Operations 68 项、`flutter analyze` 零问题、全量 277 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：saved-view delete 后 current-context corrective ownership 的回归已由下一条完成。
- [x] MergeReview saved-view delete current corrective ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`High@0 -> High@100 -> High@0 corrective pending` 后删除 selected `High delete` view，owned corrective failure 仍正确归属当前 context）。
  - ownership/recovery：saved-view chip 与 payload 被删除，active High filter 保持；不新增 review query，仍被当前 generation 拥有的 corrective failure 显示 review error/Retry 与 unavailable count，而非 stale。
  - 防假通过：删除发生在 corrective 明确 pending 时；三 query 全 settle；owned failure 后 High filter identity、saved-view removal 与 error/retry 状态均锁定，无 exception。
  - 零副作用：query suffix 为 `High@0 -> High@100 -> High@0`；operations reads unchanged；post-baseline 仅预期 High filter metadata write 与 saved-view deletion write；worklist-key、governance unchanged。
  - 验证：Operations 69 项、`flutter analyze` 零问题、全量 278 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：saved-view deletion failure 下 identity 保持与 current corrective ownership 的回归已由下一条完成。
- [x] MergeReview saved-view deletion failure current corrective ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`High@0 -> High@100 -> High@0 corrective pending` 时 selected `High delete failure` 删除写入失败，current corrective failure 仍正确归属当前 context）。
  - ownership/recovery：失败写入不改变 active High filter、saved-view payload、selected chip 或 review generation；不新增 query，corrective 继续 loading，随后 owned failure 显示 review error/Retry 与 unavailable count。
  - 防假通过：deletion failure attempt 明确发生在 corrective pending 时；失败后的 chip/metadata identity 保持，三 query 全 settle，owned failure 后仍无 exception。
  - 零副作用：query suffix 为 `High@0 -> High@100 -> High@0`；operations reads unchanged；成功的 post-baseline metadata write 仅预期 High filter metadata；worklist-key、governance unchanged。
  - 验证：Operations 70 项、`flutter analyze` 零问题、全量 279 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：saved-view metadata read failure 下 identity 保持与 current corrective ownership 的回归已由下一条完成。
- [x] MergeReview saved-view metadata read failure current corrective ownership 回归硬化（M0）
  - 当前状态：已完成（test-only；`High@0 -> High@100 -> High@0 corrective pending` 时 selected `High read failure` 删除 metadata read 失败，current corrective failure 仍正确归属当前 context）。
  - ownership/recovery：失败 read 不改变 active High filter、saved-view payload、selected chip 或 review generation；不新增 query，corrective 继续 loading，随后 owned failure 显示 review error/Retry 与 unavailable count。
  - 防假通过：deletion read failure attempt 明确发生在 corrective pending 时；失败后的 chip/metadata identity 保持，三 query 全 settle，owned failure 后仍无 exception。
  - 零副作用：query suffix 为 `High@0 -> High@100 -> High@0`；operations reads unchanged；post-baseline metadata write 仅预期 High filter metadata；worklist-key、governance unchanged。
  - 验证：Operations 71 项、`flutter analyze` 零问题、全量 280 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：saved-view initial metadata read failure 的 fail-open 与 review lane 独立性回归已由下一条完成。

- [x] MergeReview saved-view initial metadata read fail-open 回归硬化（M0）
  - 当前状态：已完成（test-only；初始化时 saved-view metadata read failure 被隔离，persisted High review filter 仍发布 High@0 page）。
  - ownership/recovery：fail-open 显示 `Could not load saved review views`，不伪造 saved-view chip、不显示 review error；single High page 与 filter identity 保持。
  - 防假通过：saved-view read failure 精确一次；query 仅 `High@0`；saved-view key absent、count `Showing 1-100 of 101 matching review issues (102 total)`。
  - 零副作用：无额外 metadata write；operations reads 为 `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)`；无 exception。
  - 验证：Operations 72 项、`flutter analyze` 零问题、全量 281 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：transient initial saved-view metadata read failure 的 reconstruction recovery 回归已由下一条完成。

- [x] MergeReview transient initial saved-view read recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；首个 page instance 的 saved-view metadata read 失败后 fail-open，同一 repository 重建后第二次 read 成功并恢复 saved-view chip）。
  - ownership/recovery：persisted High filter 持续发布 High@0 page，reconstruction 后 `High transient recovery` chip 恢复，页面 count 保持 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：两次 saved-view read 中恰一次失败；两次 query 均为 `High@0`；恢复后 saved-view identity 存在、review error 消失、无 exception。
  - 零副作用：无额外 metadata write；operations reads 仅按预期 reconstruction 从 `(jobs:1, artifacts:2, logs:1, exports:1, governance:1)` 增至 `(jobs:2, artifacts:4, logs:2, exports:2, governance:2)`；worklist-key、governance unchanged。
  - 验证：Operations 73 项、`flutter analyze` 零问题、全量 282 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：transient saved-view recovery 隔离 disposed in-flight review request 的 reconstruction race 回归已由下一条完成。

- [x] MergeReview transient saved-view recovery with disposed in-flight request 回归硬化（M0）
  - 当前状态：已完成（test-only；首个 page 的 High@100 request 在 reconstruction 中被 dispose，replacement read 失败后再次 reconstruction 成功并恢复 saved-view chip）。
  - ownership/recovery：disposed request settle 不改写 replacement page；current request 唯一发布 High@0 结果，saved-view identity 恢复，页面 count 为 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：四条 query 精确为 `[High@0, High@100, High@0, High@0]`；三次 saved-view read 恰一次失败；三个 held Future 全 settle；旧 request 完成后 current loading/page 不被改写。
  - 零副作用：无 metadata write、无 exception；两次 intentional reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；worklist-key、governance unchanged。
  - 验证：Operations 74 项、`flutter analyze` 零问题、全量 283 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter mutation recovery 隔离 disposed request 且 saved-view metadata failure 后恢复的 reconstruction race 已由下一条完成。

- [x] MergeReview saved-view read recovery with disposed filter-mutation request 回归硬化（M0）
  - 当前状态：已完成（test-only；首个 page 的 persisted High filter 改为 Warning 后，held filter-mutation request 在 reconstruction 中被 dispose；saved-view read failure 后再次 reconstruction 成功恢复 chip）。
  - ownership/recovery：disposed Warning@0 request 不改写 replacement page；saved-view chip 恢复但保持 unselected，current Warning@0 request 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：四条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0]`；三次 saved-view read 恰一次失败；三个 held Future 全 settle；旧 request 完成后 current loading/page 不被改写。
  - 零副作用：post-baseline 仅 filter metadata write；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 75 项、`flutter analyze` 零问题、全量 284 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter mutation recovery 在 saved-view metadata failure 后跨 pending filter write 完成并由 reconstruction 读取 committed filter 的 race 已由下一条完成。

- [x] MergeReview saved-view read recovery with a disposed filter mutation and pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；首个 page 的 persisted High filter 改为 Warning 后，filter metadata write 与 Warning@0 request 均 held；page dispose 后 saved-view read failure 让 replacement 暂读 committed High，write 完成后再次 reconstruction 读取 committed Warning）。
  - ownership/recovery：disposed Warning@0 request 不改写 replacement page；pending write 完成只提交 Warning；第二次 reconstruction 恢复 saved-view chip 但保持 unselected，current Warning@0 request 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：四条 query 精确为 `[High@0, Warning@0, High@0, Warning@0]`；三次 saved-view read 恰一次失败；三个 held review-query Future 与 held filter-write Future 全 settle；旧 High@0 request 完成后 current loading/page 不被改写。
  - 零副作用：post-baseline 仅一次 filter metadata write；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 76 项、`flutter analyze` 零问题、全量 285 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：saved-view read recovery 隔离 failed filter mutation 后 disposed current retry request 的 reconstruction race 已由下一条完成。

- [x] MergeReview saved-view read recovery with a disposed filter retry request 回归硬化（M0）
  - 当前状态：已完成（test-only；首个 page 的 Warning filter mutation request 失败后启动 held retry；page dispose 后 replacement saved-view read failure 启动 Warning@0，恢复 reconstruction 再启动 current Warning@0）。
  - ownership/recovery：disposed retry request 不改写 replacement page、不重新展示旧 failure；saved-view chip 恢复但保持 unselected，current Warning@0 request 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；三次 saved-view read 恰一次失败；四个 held review-query Future 全 settle（首个为预期 filter failure）；旧 retry 与旧 replacement request 完成后 current loading/page 不被改写。
  - 零副作用：post-baseline 仅一次 filter metadata write；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 77 项、`flutter analyze` 零问题、全量 286 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：toolbar refresh 在 saved-view read recovery 期间接管 page，隔离 disposed retry 与 stale pre-toolbar request，随后恢复 metadata identity 的 race 已由下一条完成。

- [x] MergeReview toolbar refresh ownership across saved-view read recovery and disposed retry 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；dispose 后 replacement saved-view read failure 启动 Warning@0，toolbar Refresh 再启动 current Warning@0，随后 reconstruction 恢复 metadata）。
  - ownership/recovery：toolbar-owned request 接管 page；disposed retry 与 stale pre-toolbar request 不改写结果；fail-open 阶段无 chip，恢复 reconstruction 后 chip 出现但保持 unselected，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0, Warning@0]`；三次 saved-view read 恰一次失败；五个 held review-query Future 全 settle（首个为预期 filter failure）；旧 retry、旧 replacement 与 toolbar 前请求完成后 current loading/page 不被改写。
  - 零副作用：post-baseline 仅一次 filter metadata write；两次 reconstruction 加一次 toolbar refresh 后 operations reads 为 `(jobs:4, artifacts:8, logs:4, exports:4, governance:4)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 78 项、`flutter analyze` 零问题、全量 287 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view deletion mutation failure 的语义已由下一条完成。

- [x] MergeReview saved-view deletion failure across retry recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；active retry 期间 saved-view deletion write 恰失败一次；dispose 后 replacement read failure，再次 reconstruction 恢复未删除的 chip）。
  - ownership/recovery：deletion failure 不丢 saved-view identity、不打断 active retry/loading；disposed retry 与 replacement request 不改写 current page；恢复 chip 保持 unselected，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四次 saved-view read 恰一次失败（deletion mutation 自身先读一次）；四个 held review-query Future 全 settle（首个预期 filter failure）；disposed retry/旧 replacement 完成后 current loading/page 不被改写。
  - 零副作用：post-baseline 仅一次 filter metadata write；saved-view write 恰失败一次且未记录 persisted write；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 79 项、`flutter analyze` 零问题、全量 288 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view deletion success 的语义已由下一条完成。

- [x] MergeReview saved-view deletion success across retry recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；active retry 期间 saved-view deletion 成功写入空列表；dispose 后 replacement read failure，再次 reconstruction 保持 chip absent）。
  - ownership/recovery：deletion success 持久化空 saved-view list 且不打断 active retry/loading；disposed retry 与 replacement request 不复活 deleted chip、不改写 current page；current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四次 saved-view read 恰一次失败（successful deletion mutation 自身先读一次）；四个 held review-query Future 全 settle（首个预期 filter failure）；disposed retry/旧 replacement 完成后 current loading/page 与 absence identity 不被改写。
  - 零副作用：post-baseline 仅 filter metadata write 与 empty saved-view write；saved-view write failure 次数为 0；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 80 项、`flutter analyze` 零问题、全量 289 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view apply success 的语义已由下一条完成。

- [x] MergeReview saved-view apply success across retry recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；active retry 期间应用 High saved view，持久化 High 并选中 chip；dispose 后 replacement read failure，再次 reconstruction 保持 view 存在但 chip 未选中）。
  - ownership/recovery：apply 成功启动新的 High@0 generation；disposed Warning retry、disposed apply request 与旧 replacement request 不改写 current page；current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；三次 saved-view read 恰一次失败；五个 held review-query Future 全 settle（首个预期 filter failure）；旧 retry/apply/replacement 完成后 current loading/page 不被改写，重建后 chip 仍 present/unselected。
  - 零副作用：post-baseline 仅两次 filter metadata writes；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 81 项、`flutter analyze` 零问题、全量 290 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view apply failure 的语义已由下一条完成。

- [x] MergeReview saved-view apply failure across retry recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；active retry 期间应用 High saved view，High@0 在内存启动但 filter metadata write 恰失败；dispose 后 replacement read failure 按 committed Warning 恢复）。
  - ownership/recovery：apply failure 不回滚当前 page 的 High selection/loading；仅 Warning filter write 持久化；disposed Warning retry、disposed High apply request 与旧 replacement request 不改写 current page；重建后 saved-view chip present/unselected，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, Warning@0, Warning@0]`；三次 saved-view read 恰一次失败；五个 held review-query Future 全 settle（首个预期 filter failure）；旧 retry/apply/replacement 完成后 current loading/page 不被改写。
  - 零副作用：post-baseline 仅一次成功的 Warning filter metadata write，apply filter write 恰失败一次；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 82 项、`flutter analyze` 零问题、全量 291 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view save success 的语义已由下一条完成。

- [x] MergeReview saved-view save success across retry recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；active retry 期间保存新的 Warning view，持久化新 view；dispose 后 replacement read failure，再次 reconstruction 恢复新 chip）。
  - ownership/recovery：save success 不打断 active retry/loading；disposed retry 与旧 replacement request 不改写 current page；新 view 重建后 present/unselected，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四次 saved-view read 恰一次失败（save mutation 自身先读一次）；四个 held review-query Future 全 settle（首个预期 filter failure）；disposed retry/旧 replacement 完成后 current loading/page 与新 view identity 不被改写。
  - 零副作用：post-baseline 仅一次 Warning filter metadata write 与一次 saved-view write；无 mutation failure；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 83 项、`flutter analyze` 零问题、全量 292 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：active retry/reconstruction recovery 同时遇到 saved-view save failure 的语义已由下一条完成。

- [x] MergeReview saved-view save failure across retry recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；active retry 期间保存新 view 的 saved-view write 恰失败；dispose 后 replacement read failure，再次 reconstruction 恢复既有 view）。
  - ownership/recovery：save failure 不产生新 chip、不污染既有 view identity、不打断 active retry/loading；committed Warning filter 保持；disposed retry 与旧 replacement request 不改写 current page，最终 Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四次 saved-view read 恰一次失败（failed save mutation 自身先读一次）；四个 held review-query Future 全 settle（首个预期 filter failure）；disposed retry/旧 replacement 完成后 current loading/page 与既有 view identity 不被改写。
  - 零副作用：post-baseline 仅一次 Warning filter metadata write；saved-view write 恰失败一次且无 persistence；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 84 项、`flutter analyze` 零问题、全量 293 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：save failure 后 metadata-read success 在 active retry/reconstruction recovery 中的语义已由下一条完成。

- [x] MergeReview save failure with immediate successful reconstruction read 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；active retry 期间 saved-view save write 恰失败；立即 reconstruction 成功 read，恢复既有 view）。
  - ownership/recovery：failed save 不产生新 view/chip、不污染既有 identity；committed Warning filter 与 active retry/loading 保持；disposed retry 不改写 reconstructed page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：四条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0]`；三次 saved-view read 无 read failure；三个 held review-query Future 全 settle（首个预期 filter failure）；failed save 与 disposed retry 完成后 current page/既有 view identity 不被改写。
  - 零副作用：post-baseline 仅一次 Warning filter metadata write；saved-view write 恰失败一次且无 persistence；一次 reconstruction 后 operations reads 为 `(jobs:2, artifacts:4, logs:2, exports:2, governance:2)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 85 项、`flutter analyze` 零问题、全量 294 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：disposed in-flight saved-view save 在 read recovery 前完成并持久化新 view 的语义已由下一条完成。

- [x] MergeReview disposed saved-view save completion before read recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；active retry 期间 saved-view write pending，dispose 后完成 write；replacement read failure，再次 reconstruction 恢复新 view）。
  - ownership/recovery：disposed save callback 不更新 UI；完成的 saved-view write 仅在后续成功 read 后显示新 chip；disposed retry 与旧 replacement request 不改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四次 saved-view read 恰一次失败（pending save mutation 自身先读一次）；四个 held review-query Future 全 settle（首个预期 filter failure）；disposed save/retry/replacement 完成后 current loading/page 与新 view identity 不被改写。
  - 零副作用：post-baseline 仅一次 Warning filter metadata write 与一次 completed saved-view write；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 86 项、`flutter analyze` 零问题、全量 295 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：pending saved-view deletion 在 save completion 前 gate，完成 save 后再删除旧 view，并在 reconstruction 中保留新 view 的语义已由下一条完成。

- [x] MergeReview pending saved-view save with deletion gate and recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter mutation 失败后启动 held retry；active retry 期间 saved-view write pending，delete control gate；完成 save 后删除旧 view；replacement read failure，再次 reconstruction 仅恢复新 view）。
  - ownership/recovery：save pending 时不发生 delete mutation；save completion 后 deletion 保持新 view identity；disposed retry 与旧 replacement request 不改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；五次 saved-view read 恰一次失败；四个 held review-query Future 全 settle（首个预期 filter failure）；saved-view read failure/recovery、disposed retry 完成后 current loading/page 与新 view identity 不被改写。
  - 零副作用：post-baseline 仅一次 Warning filter metadata write、一次 saved-view save 与一次 saved-view delete；deletion 后 persisted list 只剩新 Warning view；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 87 项、`flutter analyze` 零问题、全量 296 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter metadata write pending 时 saved-view deletion 独立完成，随后 reconstruction 保持 deletion identity 的语义已由下一条完成。

- [x] MergeReview saved-view deletion independent from pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter metadata write pending，Warning@0 failure 后 held retry；saved-view deletion 独立完成；filter write 随后 settle；replacement read failure，再次 reconstruction 保持 deleted view absent）。
  - ownership/recovery：两条 metadata key 独立排序，saved-view delete 不等待 filter write；disposed retry 与旧 replacement request 不恢复 deleted view 或改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四次 saved-view read 恰一次失败；四个 held review-query Future 全 settle（首个预期 filter failure）；saved-view fail-open/recovery 与 disposed retry 完成后 current loading/page 仍不变。
  - 零副作用：post-baseline 仅一次 saved-view delete 与一次 Warning filter metadata write，且顺序可观测为 delete 后 filter；persisted saved-view list 保持 empty，Warning filter 保持；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 88 项、`flutter analyze` 零问题、全量 297 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter metadata write pending 时 saved-view apply 排队并由当前 query 接管，reconstruction 保持 view 存在但不伪造选中状态的语义已由下一条完成。

- [x] MergeReview saved-view apply queued behind pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 apply High saved view；Warning→High filter writes 排队 settle；replacement read failure，再次 reconstruction 恢复 views 但 selection page-local）。
  - ownership/recovery：stale Warning retry failure 不污染 current High apply；最终 High filter/chip selected 只由 current High@0 发布，disposed replacement request 不改写 current page。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 全 settle；三次 saved-view read 恰一次失败；reconstruction 后两个 view 均 present/unselected，不能伪造 page-local selection。
  - 零副作用：post-baseline 仅两次 filter metadata write，顺序为 Warning 后 High，最终 persisted filter 为 High；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 89 项、`flutter analyze` 零问题、全量 298 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter metadata write pending 时 saved-view save 独立完成，随后 reconstruction 保持两个 view 与 committed filter 的语义已由下一条完成。

- [x] MergeReview saved-view save independent from pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后保存 Warning view；saved-view save 独立完成；filter write 随后 settle；replacement read failure，再次 reconstruction 恢复两个 view）。
  - ownership/recovery：saved-view save 不等待 filter write；disposed retry 与旧 replacement request 不移除或改写两个 view，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 全 settle；四次 saved-view read 恰一次失败；reconstruction 后两个 view 均 present/unselected，selection 仍 page-local。
  - 零副作用：post-baseline 仅一次 saved-view save 与一次 Warning filter metadata write，且顺序可观测为 save 后 filter；最终 Warning filter 与两个 saved views 均持久化；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 90 项、`flutter analyze` 零问题、全量 299 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter metadata write pending 时 saved-view save failure 不污染既有 view，filter write 仍可 settle，reconstruction 保持 identity 的语义已由下一条完成。

- [x] MergeReview saved-view save failure with pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 saved-view save 读后写失败；filter write 独立 settle；replacement read failure，再次 reconstruction 保留既有 view）。
  - ownership/recovery：failed save 不产生新 chip、不改变既有 view identity、不阻断 filter write；disposed retry 与旧 replacement request 不改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 全 settle；四次 saved-view read 恰一次失败；failed save mutation 恰尝试一次且无 persistence，reconstruction 后既有 view present/unselected。
  - 零副作用：post-baseline 仅一次 Warning filter metadata write；saved-view write 不落盘；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 91 项、`flutter analyze` 零问题、全量 300 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter metadata write pending 时 saved-view deletion failure 不污染既有 view，filter write 仍可 settle，reconstruction 保持 identity 的语义已由下一条完成。

- [x] MergeReview saved-view deletion failure with pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 saved-view deletion 读后写失败；filter write 独立 settle；replacement read failure，再次 reconstruction 保留既有 view）。
  - ownership/recovery：failed delete 不移除 chip、不改变既有 view identity、不阻断 filter write；disposed retry 与旧 replacement request 不改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 全 settle；四次 saved-view read 恰一次失败；failed deletion 恰尝试一次且无 persistence，reconstruction 后既有 view present/unselected。
  - 零副作用：post-baseline 仅一次 Warning filter metadata write；saved-view delete 不落盘；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 92 项、`flutter analyze` 零问题、全量 301 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：pending filter write 时 save→delete 两个 saved-view mutation 按 store 顺序完成，最终仅新 view 保留并在 reconstruction 中恢复的语义已由下一条完成。

- [x] MergeReview saved-view save then deletion with pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 save 新 view、delete 旧 view；filter write 最后 settle；replacement read failure，再次 reconstruction 仅恢复新 view）。
  - ownership/recovery：saved-view store 内 save/delete serialized，filter metadata key 独立；disposed retry 与旧 replacement request 不复活旧 view或改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 全 settle；五次 saved-view read 恰一次失败；最终 persisted list 仅新 Warning view，reconstruction 后 present/unselected。
  - 零副作用：post-baseline 仅一次 saved-view save、一次 saved-view delete、一次 Warning filter metadata write，顺序可观测为 save→delete→filter；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 93 项、`flutter analyze` 零问题、全量 302 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：pending filter write 时 save 成功、delete 失败仍保留 prior save，filter write 可 settle，reconstruction 保持两个 view identity 的语义已由下一条完成。

- [x] MergeReview saved-view deletion failure after prior save with pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 save 新 view、delete 旧 view 失败；filter write 独立 settle；replacement read failure，再次 reconstruction 恢复两个 view）。
  - ownership/recovery：prior save 不被 failed delete 污染，旧/新 view 均保持 identity；disposed retry 与旧 replacement request 不改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 全 settle；五次 saved-view read 恰一次失败；failed deletion 恰尝试一次且无 persistence，reconstruction 后两个 view present/unselected。
  - 零副作用：post-baseline 仅一次 saved-view save 与一次 Warning filter metadata write；delete failure 不写 saved-view payload；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 94 项、`flutter analyze` 零问题、全量 303 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：pending filter write 时 first saved-view save failure 不阻塞 following delete，最终 empty list 在 reconstruction 中保持的语义已由下一条完成。

- [x] MergeReview failed saved-view save followed by deletion with pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 first saved-view save 失败、following delete 成功；filter write 随后 settle；replacement read failure，再次 reconstruction 保持 empty list）。
  - ownership/recovery：failed save 不污染 saved-view queue，following delete 清空旧 view；disposed retry 与旧 replacement request 不复活 deleted view 或改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 全 settle；五次 saved-view read 恰一次失败；failed save 恰尝试一次且无 persistence，reconstruction 后 list empty。
  - 零副作用：post-baseline 仅一次 saved-view delete 与一次 Warning filter metadata write，顺序可观测为 delete 后 filter；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 95 项、`flutter analyze` 零问题、全量 304 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：pending filter write 时 delete 成功后 save 失败仍 drain saved-view queue，最终 empty list 在 reconstruction 中保持的语义已由下一条完成。

- [x] MergeReview deletion followed by failed save with pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 delete 旧 view 成功、following save 失败；filter write 独立 settle；replacement read failure，再次 reconstruction 保持 empty list）。
  - ownership/recovery：failed save 不污染已完成的 delete 或 queue；disposed retry 与旧 replacement request 不复活 deleted view 或改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 全 settle；五次 saved-view read 恰一次失败；failed save 恰尝试一次且无 persistence，reconstruction 后 list empty。
  - 零副作用：post-baseline 仅一次 saved-view delete 与一次 Warning filter metadata write，顺序可观测为 delete 后 filter；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 96 项、`flutter analyze` 零问题、全量 305 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：pending filter write 时 first save 成功、同名 second save 失败仍保留 first view，filter write 可独立 settle，reconstruction 保持两个 view identity 的语义已由下一条完成。

- [x] MergeReview 同名 second saved-view save failure with pending filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 first saved-view save 成功、同名 second save 失败；filter write 独立 settle；replacement read failure，再次 reconstruction 保留两个 view identity）。
  - ownership/recovery：first saved-view save 的 persistence 不被 second-save failure 污染；second save 恰失败一次且无第二次 write，disposed retry 与旧 replacement request 不展示失败或改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, Warning@0, Warning@0]`；四个 held review-query Future 全 settle；五次 saved-view read 恰一次失败；两次 reconstruction 后两个 view 均 present/unselected，second save 恰尝试一次且无 persistence。
  - 零副作用：post-baseline metadata writes 仅一次成功 saved-view save 后一次 Warning filter write；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 97 项、`flutter analyze` 零问题、全量 306 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：pending filter write 在 successful saved-view save 后释放并失败时，不回滚 saved-view persistence，保留旧 persisted filter authority，filter-write failure 可见且 reconstruction 保持两个 view identity 的语义已由下一条完成。

- [x] MergeReview saved-view save 后 pending filter write failure 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 saved-view save 成功、filter write 释放时失败；persisted filter 保持 High；replacement read failure，再次 reconstruction 保留两个 view identity）。
  - ownership/recovery：filter-write failure 只更新 Operation status，不回滚成功 saved-view write、不改变两个 view identity；disposed retry 与旧 replacement request 不展示失败或改写 current page，current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0]`；四个 held review-query Future 全 settle；四次 saved-view read 恰一次失败；failed filter write 恰尝试一次且无 persistence，reconstruction 后两个 view present/unselected。
  - 零副作用：post-baseline metadata writes 仅一次成功 saved-view write；persisted `merge_review_filter_v1` 仍为 High；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 98 项、`flutter analyze` 零问题、全量 307 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：首个 filter write 失败后，queued 后续 filter write 仍成功，saved-view mutation 仍保持 queued 并最终持久化，cross-queue ownership 与 reconstruction identity 的语义已由下一条完成。

- [x] MergeReview filter-write failure recovery with queued saved-view mutation 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 saved-view save queued，首个 filter write release failure、后续 High filter write success，再释放 saved-view write；replacement read failure，再次 reconstruction 保留两个 view identity）。
  - ownership/recovery：首个 filter failure 不阻塞 queued 后续 High write 或 pending saved-view mutation；failure 只更新 Operation status，disposed Warning/High request 与 stale replacement request 不改写 current page，current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 全 settle；四次 saved-view read 恰一次失败；首个 filter write 恰失败一次、后续 High write 成功，reconstruction 后两个 view present/unselected。
  - 零副作用：post-baseline metadata writes 仅成功 High filter write 后 saved-view payload；persisted filter 为 High；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 99 项、`flutter analyze` 零问题、全量 308 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter-write failure recovery 期间 queued saved-view deletion 保持 pending，后续 High filter write 成功后 deletion 再独立 drain，最终 empty list 与 reconstruction identity 的语义已由下一条完成。

- [x] MergeReview filter-write failure recovery with queued saved-view deletion 回归硬化（M0）
  - 当前状态：已完成（test-only；saved-view deletion pending，Warning@0 failure/retry 与 High filter queued 后首个 filter write failure、后续 High write success，再释放 deletion；replacement read failure，再次 reconstruction 保持 empty list）。
  - ownership/recovery：queued deletion 不被 filter failure 污染，后续 High filter write 不被 deletion 阻塞；failure 只更新 Operation status，disposed Warning/High request 与 stale replacement request 不改写 current page，current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 全 settle；四次 saved-view read 恰一次失败；首个 filter write 恰失败一次、后续 High write 成功，deletion 最终 empty payload，reconstruction 后 list empty。
  - 零副作用：post-baseline metadata writes 仅成功 High filter write 后 saved-view delete payload；persisted filter 为 High；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 100 项、`flutter analyze` 零问题、全量 309 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter-write failure recovery 期间 queued saved-view apply 保留 current-page selected ownership，后续 High write 成功，reconstruction 清除 page-local selection 的语义已由下一条完成。

- [x] MergeReview queued saved-view apply after filter-write failure 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending，Warning@0 failure/retry 后 apply High view，首个 Warning write failure、queued High write success；replacement read failure，再次 reconstruction 保留两个 view identity 但不选中）。
  - ownership/recovery：High saved-view apply 的 selected state 只属于 current page；首个 filter failure 不污染 queued High write，disposed Warning/High request 与 stale replacement request 不改写 current page，current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 全 settle；三次 saved-view read 恰一次失败；首个 Warning filter write 恰失败一次、后续 High write 成功，reconstruction 后两个 view present/unselected。
  - 零副作用：post-baseline metadata writes 仅成功 High filter write；persisted filter 为 High；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 101 项、`flutter analyze` 零问题、全量 310 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：queued saved-view apply 在 deletion pending 与首个 filter write failure 期间保持 current-page ownership，后续 High write 与 deletion 依序完成，reconstruction 仅保留 High identity 的语义已由下一条完成。

- [x] MergeReview queued apply with pending deletion during filter failure 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning deletion pending，Warning@0 failure/retry 后 apply High view，首个 Warning write failure、queued High write success，再释放 deletion；replacement read failure，再次 reconstruction 仅保留 High view）。
  - ownership/recovery：queued apply 的 selected state 只属于 current page；pending deletion 不被 filter failure 污染，disposed Warning/High request 与 stale replacement request 不改写 current page，current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 全 settle；四次 saved-view read 恰一次失败；首个 Warning filter write 恰失败一次、后续 High write 成功，deletion 最终只保留 High，reconstruction 后 High present/unselected。
  - 零副作用：post-baseline metadata writes 仅成功 High filter write 后 saved-view delete payload；persisted filter 为 High；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 102 项、`flutter analyze` 零问题、全量 311 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 后续闭环：filter failure 后 repeated queued apply 仍按序完成，pending deletion 最终 drain 且仅移除目标 view，reconstruction 保持最终 identity 与 page-local selection 语义已由下一条完成。

- [x] MergeReview repeated queued applies with pending deletion after filter failure 回归硬化（M0）
  - 当前状态：已完成（test-only；Info deletion pending，Warning@0 failure/retry 后 apply High→Warning，首个 Warning write failure、后续 High/Warning writes success，再释放 deletion；replacement read failure，再次 reconstruction 仅保留 High/Warning）。
  - ownership/recovery：repeated apply filter writes 按序 recovery，pending deletion 不被 failure 污染且最终只移除 Info；disposed Warning/High/Warning request 与 stale replacement request 不改写 current page，current Warning@0 唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：七条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`；六个 held review-query Future 全 settle；四次 saved-view read 恰一次失败；首个 Warning filter write 恰失败一次、后续 High/Warning writes 成功，reconstruction 后 High/Warning present/unselected。
  - 零副作用：post-baseline metadata writes 仅 High filter、Warning filter、saved-view delete payload；persisted filter 为 Warning；两次 reconstruction 后 operations reads 为 `(jobs:3, artifacts:6, logs:3, exports:3, governance:3)`；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 103 项、`flutter analyze` 零问题、全量 312 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：filter-write failure 后 successful saved-view save 与 subsequent delete 仍保持 queue ownership，reconstruction 仅保留原 High identity 的语义已由下一条完成。

- [x] MergeReview saved-view mutations recover after filter-write failure 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending 时 saved-view save 成功，释放 filter write 恰失败一次，随后删除新 Warning view 成功；replacement read failure/recovery 后仅保留原 High view）。
  - ownership/recovery：failed filter write 不回滚成功 saved-view save；delete mutation 在 failure 后继续独立 drain，persisted filter 保持 High，current High@0 最终唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0]`；四个 held review-query Future 全 settle；五次 saved-view read 恰一次失败；saved-view save→delete 顺序保持，failed filter write 恰失败一次且无 persistence。
  - 零副作用：replacement reconstruction 仅恢复 High present/unselected，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 104 项、`flutter analyze` 零问题、全量 313 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：filter-write failure 后 repeated saved-view save/delete attempts 仍按序 drain，最终 persisted identity 与 reconstruction 语义已由下一条完成。

- [x] MergeReview repeated saved-view mutations survive filter-write failure 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter write pending 时 pre-failure save 成功，释放 write 恰失败一次，随后 save/delete 两轮 mutation 均成功；replacement read failure/recovery 后仅保留 High 与 pre-failure Warning）。
  - ownership/recovery：failed filter write 不污染 saved-view queue；failure 后重复 save/delete 仍按序完成，persisted filter 保持 High，current High@0 最终唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0]`；四个 held review-query Future 全 settle；八次 saved-view read 恰一次失败；五次 post-baseline write 保持 save/delete/save/delete 顺序加 pre-failure save，failed filter write 恰失败一次且无 persistence。
  - 零副作用：replacement reconstruction 仅恢复 High 与 pre-failure Warning present/unselected，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 105 项、`flutter analyze` 零问题、全量 314 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：saved-view save 在 filter failure/recovery 期间保持 pending，随后 delete 仍按序 drain 且 persisted filter authority 不变的语义已由下一条完成。

- [x] MergeReview saved-view save/delete queue survives filter-write failure recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning saved-view write 跨越首个 filter write failure 与 queued High recovery，完成后删除旧 High view；replacement read failure/recovery 后仅保留新 Warning）。
  - ownership/recovery：failed filter write 不污染 saved-view queue；High filter recovery 成功后 save→delete serialized drain，persisted filter 保持 High，current High@0 最终唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, High@0, High@0]`；五个 held review-query Future 全 settle；五次 saved-view read 恰一次失败；post-baseline writes 为 High filter、saved-view save、saved-view delete，failed filter write 恰失败一次且无 persistence。
  - 零副作用：replacement reconstruction 仅恢复新 Warning present/unselected，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 106 项、`flutter analyze` 零问题、全量 315 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：recovery 后再次 filter failure 时第二个 saved-view mutation 保持 pending，最终成功并保留两项 Warning identity 的语义已由下一条完成。

- [x] MergeReview later filter failure isolates a queued saved-view mutation 回归硬化（M0）
  - 当前状态：已完成（test-only；首轮 filter failure 后 save→delete 完成，后续再次 filter failure 时第二个 saved-view save pending，完成后保留两个 Warning view；replacement read failure/recovery 后均 present/unselected）。
  - ownership/recovery：两次 filter failure 均不污染 saved-view queue；queued High recovery 后第二个 mutation 仍可成功 drain，persisted filter 保持 High，current High@0 最终唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：七条 query 精确为 `[High@0, Warning@0, Warning@0, High@0, Warning@0, High@0, High@0]`；六个 held review-query Future 全 settle；六次 saved-view read 恰一次失败；post-baseline writes 为 High filter、saved-view save/delete/save，两次 failed filter write 均无 persistence。
  - 零副作用：replacement reconstruction 仅恢复两个 Warning present/unselected，page-local selection 不外泄；旧 High identity 不复活，最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 107 项、`flutter analyze` 零问题、全量 316 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：later filter failure 后 saved-view deletion 与第三次 filter recovery 保持独立，deleted identity 不会复活的语义已由下一条完成。

- [x] MergeReview saved-view deletion survives third filter recovery after later failure 回归硬化（M0）
  - 当前状态：已完成（test-only；首个 Warning filter write 成功，later High write failure 后第三次 Warning write pending，第二个 Warning view deletion 先成功，第三次 write 再成功；replacement read failure/recovery 后仅保留第一项 Warning）。
  - ownership/recovery：later filter failure 不污染 deletion，第三次 filter recovery 不复活 deleted view，persisted filter 保持 Warning，current Warning@0 最终唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`；五个 held review-query Future 全 settle；四次 saved-view read 恰一次失败；post-baseline writes 为 Warning filter、saved-view delete、Warning filter，failed High filter 恰失败一次且无 persistence。
  - 零副作用：replacement reconstruction 仅恢复第一项 Warning present/unselected，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 108 项、`flutter analyze` 零问题、全量 317 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：subsequent filter recovery 期间 saved-view deletion failure 保持 identity，第三次 write 成功后 retry deletion 正常 drain 的语义已由下一条完成。

- [x] MergeReview saved-view deletion failure preserves identity across filter recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；首个 Warning filter write 成功，later High write failure 后第三个 Warning write pending，第二个 Warning deletion 失败，第三个 write 成功后 retry deletion；replacement read failure/recovery 后只保留第一项 Warning）。
  - ownership/recovery：failed deletion 不污染 saved-view identity，third filter recovery 不复活目标 view，persisted filter 保持 Warning，current Warning@0 最终唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`；五个 held review-query Future 全 settle；五次 saved-view read 恰一次失败；post-baseline writes 为 Warning filter、Warning filter、saved-view delete，failed High filter 与 failed deletion 均无 persistence。
  - 零副作用：replacement reconstruction 仅恢复剩余 Warning present/unselected，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 109 项、`flutter analyze` 零问题、全量 318 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：failed deletion 后再次 saved-view save 与 retry delete 在第四次 filter recovery 期间保持隔离，最终 identity 与 High authority 正确收敛的语义已由下一条完成。

- [x] MergeReview failed deletion survives later saved-view mutation and filter recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；later High filter failure 后第三次 Warning write pending 时 deletion failure，recovery 后第四次 High write pending，同时 save 新 High view、retry deletion；replacement read failure/recovery 后保留第一项 Warning 与新 High）。
  - ownership/recovery：failed deletion 不污染后续 saved-view save/retry，第四次 High filter recovery 不复活 deleted view，persisted filter 保持 High，current High@0 最终唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：七条 query 精确为 `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`；六个 held review-query Future 全 settle；六次 saved-view read 恰一次失败；post-baseline writes 为 Warning filter、Warning filter、saved-view save、saved-view delete、High filter，failed High filter 与 failed deletion 均无 persistence。
  - 零副作用：replacement reconstruction 仅恢复剩余 Warning 与新 High present/unselected，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 110 项、`flutter analyze` 零问题、全量 319 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：retry-delete 后 failed later saved-view save 与第四次 filter recovery 的隔离、retry save 后 identity 正确收敛已完成，转入下一条 deletion/filter 竞态核验。

- [x] MergeReview failed save recovers after deletion retry and filter recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；later High filter failure 后第三次 Warning write pending 时 deletion failure，recovery 后 retry deletion；第四次 High write pending 时 save failure，recovery 后 retry save；replacement read failure/recovery 后保留第一项 Warning 与 replacement High）。
  - ownership/recovery：failed save、failed deletion、failed filter 均不污染后续队列；第四次 High filter recovery 恢复 persisted authority，retry save 后最终 identity 正确收敛，current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：七条 query 精确为 `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`；六个 held review-query Future 全 settle；七次 saved-view read 恰一次失败；成功 post-baseline writes 依次为 Warning filter、Warning filter、saved-view delete、High filter、saved-view save，并显式断言 write-key 顺序。
  - 零副作用：replacement reconstruction 仅恢复第一项 Warning 与 replacement High present/unselected，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 111 项、`flutter analyze` 零问题、全量 320 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：retry-delete 后 saved-view deletion 与后续 filter write 的独立性已完成，转入 empty-list 后 save 的队列核验。

- [x] MergeReview post-retry saved-view deletion survives a later filter write 回归硬化（M0）
  - 当前状态：已完成（test-only；Warning filter pending 时首次 deletion failure，release 后 retry deletion；随后 High filter pending 时删除剩余 Warning，release 后恢复 High authority；replacement read failure/recovery 后两个 deleted identity 均 absent）。
  - ownership/recovery：post-retry deletion 在 later High filter write pending 时独立成功并先持久化 empty saved-view list；failed deletion 无 payload，current High@0 最终唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, High@0, High@0, High@0]`；四个 held review-query Future 全 settle；六次 saved-view read 恰一次失败；成功 writes 依次为 Warning filter、saved-view delete、saved-view delete、High filter，并显式断言 write-key 顺序。
  - 零副作用：replacement reconstruction 不恢复两个已删除 view，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 112 项、`flutter analyze` 零问题、全量 321 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：empty saved-view list 后再次 save 与另一轮 filter recovery 的独立性已完成，转入 post-empty save failure 的 deletion/filter 核验。

- [x] MergeReview empty saved-view list accepts a later save during filter recovery 回归硬化（M0）
  - 当前状态：已完成（test-only；唯一 Warning deletion 首次失败，filter release 后 retry deletion 进入 empty list；随后 High filter pending 时 save replacement High，release 后恢复 High authority；replacement read failure/recovery 后仅新 identity present）。
  - ownership/recovery：empty-list 后 saved-view save 在 later High filter write pending 时独立成功并先持久化，failed deletion 无 payload，current High@0 最终唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`。
  - 防假通过：五条 query 精确为 `[High@0, Warning@0, High@0, High@0, High@0]`；四个 held review-query Future 全 settle；六次 saved-view read 恰一次失败；成功 writes 依次为 Warning filter、saved-view delete、saved-view save、High filter，并显式断言 write-key 顺序。
  - 零副作用：replacement reconstruction 不恢复已删除 Warning，仅恢复新 High present/unselected，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 113 项、`flutter analyze` 零问题、全量 322 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：post-empty save failure 后 retry save 与后续 deletion/filter recovery 的隔离已完成，转入 retry-save 后 apply 的队列核验。

- [x] MergeReview post-empty saved-view save failure recovers before later deletion 回归硬化（M0）
  - 当前状态：已完成（test-only；唯一 Warning deletion 首次失败，retry 后 empty list；High filter pending 时 replacement save 首次失败，release 后 retry save；随后 Warning filter pending 时删除 replacement，release 后恢复 Warning authority；replacement read failure/recovery 后两个 deleted identity 均 absent）。
  - ownership/recovery：failed deletion 与 failed save 均不污染后续 retry；later deletion 在 filter pending 时独立成功并先持久化 empty list，current Warning@0 最终唯一发布 `Showing 1 of 1 matching review issues (102 total)`。
  - 防假通过：六条 query 精确为 `[High@0, Warning@0, High@0, Warning@0, Warning@0, Warning@0]`；五个 held review-query Future 全 settle；八次 saved-view read 恰一次失败；成功 writes 依次为 Warning filter、saved-view delete、High filter、saved-view save、saved-view delete、Warning filter，并显式断言 write-key 顺序。
  - 零副作用：replacement reconstruction 不恢复两个已删除 view，page-local selection 不外泄；最终无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 114 项、`flutter analyze` 零问题、全量 323 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：检查 post-empty retry-save 与后续 saved-view apply 在 filter recovery 期间的竞态；若仍有 distinct gap，再补 bounded regression。

- [x] MergeReview post-empty retry-save survives a queued saved-view apply 回归硬化（M0）
  - 当前状态：已完成（test-only；唯一 Warning deletion 首次失败，retry 后 empty list；High filter pending 时 replacement save 首次失败，release 后 retry save；随后 Warning filter pending 时 apply replacement High，active write 失败后 queued apply 成功；replacement read failure/recovery 后仅 replacement High present）。
  - ownership/recovery：post-empty retry save 不受 failed deletion/save 污染，saved-view apply 排在 active Warning filter write 后；active filter failure 不污染 queued apply，queued High filter write 成功后恢复 High authority，replacement chip 保持 selected。
  - 防假通过：七条 query 精确为 `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`；六个 held review-query Future 全 settle；七次 saved-view read 恰一次失败；成功 writes 依次为 Warning filter、saved-view delete、High filter、saved-view save、High filter，并显式断言 write-key 顺序。
  - 零副作用：replacement reconstruction 仅恢复 replacement High present/unselected，page-local selection 不外泄；最终 current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 115 项、`flutter analyze` 零问题、全量 324 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：检查 recovered retry-save 后 repeated queued saved-view apply 是否遗留 stale chip selection 或多余 filter write；若仍有 distinct gap，再补 bounded regression。

- [x] MergeReview recovered retry-save drains repeated queued saved-view applies 回归硬化（M0）
  - 当前状态：已完成（test-only；controlled store 预置 failed deletion 与 failed High save 的 retry 后 empty-list recovery，再保存第二项 Warning；页面 held Warning filter write 期间依次 apply High、Warning、High，active write failure 后三项 queued filter write 全部 drain）。
  - ownership/recovery：最终 persisted filter authority 为 High，High chip 在 active failure 与 queued recovery 期间保持 selected；failed filter 无 payload，预置阶段恰有两次 failed saved-view write，页面阶段无 saved-view mutation。
  - 防假通过：页面七条 query 精确为 `[High@0, Warning@0, High@0, Warning@0, High@0, High@0, High@0]`；六个 held review-query Future 全 settle；页面 lifecycle 三次 saved-view read 恰一次失败；成功 page-side writes 依次为 High filter、Warning filter、High filter，并显式断言 write-key/value 顺序。
  - 零副作用：replacement reconstruction 恢复两个 view 为 present/unselected，page-local selection 不外泄；最终 current High@0 唯一发布 `Showing 1-100 of 101 matching review issues (102 total)`，无 review error/exception，worklist-key、governance unchanged。
  - 验证：Operations 117 项、`flutter analyze` 零问题、全量 326 项、`git diff --check`、严格 CI（含 14 项 importer、compare gates 与 Web build）；local review 未发现 blocker。
  - 下一步：检查 repeated apply 后 queued saved-view deletion 或 save 是否会在最终 filter authority 之后提交并遗留 obsolete identity；若仍有 distinct gap，再补 bounded regression。

- [x] Canonical release adoption 与旧版本 local ref 清理（Slice88，M0）
  - 当前状态：已完成（workspace 只读盘点无重复 release 文件或完整副本；采纳 `codex/public-github-launch@534ffdf`，删除四个已验证 strict ancestor 的 local refs：`main@0405fcd`、`codex/initial-import@6f8fb87`、`automation/importer-de-20260525@6f8fb87`、`automation/importer-fi-20260525@6f8fb87`）。
  - 保护边界：源码、测试、build artifact 与 remote branch 均未删除；`origin/codex/initial-import` 保留并在 `docs/timeline/2026-08-31-slice88-release-prune-audit.md` 记录 remote authority 限制与 ref recreation rollback。
  - 存储规则：`docs/release_packaging.md` 已加入 canonical version retention；后续每个版本只增量修改既有 canonical 文件，新增唯一 timeline MD，不建立 full-content copy。
  - 验证：继承 Slice87 baseline（Operations 117、全量 326、analyze 零问题、diff check、严格 CI 含 14 importer/compare gates/Web build）；本 Slice 仅为 release 文档、timeline 与 local refs cleanup。
    - 下一步：补齐可复现版本元数据与 clean release preflight，继续以 incremental edit + unique timeline 记录。

- [x] 可复现 release metadata 与 clean preflight（Slice89，M0）
  - 当前状态：已实现并接入本地/远端 CI；`tool/check_release_metadata.dart` 校验 canonical SemVer/build number、Pub lockfile SDK 约束，以及 Android/iOS/macOS 原生版本 handoff。
  - 运行边界：默认只读且允许 ongoing dirty worktree；release cut 可加 `--require-clean --canonical-ref <ref>`，GitHub Actions 已在 clean checkout 启用 clean gate。
  - 验证：focused `ci_workflow_test.dart` `+25`、`flutter analyze` 零问题、全量测试 `+329`、`git diff --check` 与严格 CI（14 项 importer、compare gates、deterministic release metadata、Web build）均通过。
  - 存储规则：只增量修改既有 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice89-release-metadata-preflight.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded artifact provenance 或 release configuration drift 检查。

- [x] Deterministic Web artifact provenance（Slice90，M0）
  - 当前状态：已完成；`tool/build_release_provenance.dart` 生成排序稳定的 JSON manifest，包含 package version、file count/bytes、相对路径与 SHA-256，manifest 位于 artifact 之外。
  - CI 接入：本地 wrapper 在 Web build 后生成 manifest；GitHub Actions 记录可选 `GITHUB_SHA` 并与 Web artifact 一并上传。
  - 验证：focused `ci_workflow_test.dart` `+27`、`flutter analyze` 零问题、全量 `+331`、diff check、严格 CI（含 importer/compare/Web/provenance）与 39 项 `shasum` 交叉校验均通过。
  - 存储规则：仅增量修改 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice90-release-provenance.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded release configuration drift 或 artifact consumption gap。

- [x] Web artifact provenance verification（Slice91，M0）
  - 当前状态：已完成；既有 provenance CLI 新增只读 `--verify`，逐项比对 artifact 文件清单、bytes、SHA-256、版本与可选 source revision。
  - CI 接入：local wrapper 与 GitHub Actions 均在 upload 前执行 generate→verify；任何 tamper 或 metadata drift 都 fail-fast。
  - 验证：focused `ci_workflow_test.dart` `+27`、`flutter analyze` 零问题、全量 `+331`、diff check 与严格 CI（含 importer/compare/Web/provenance）均通过。
  - 存储规则：只增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice91-provenance-verification.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded release configuration drift 或 artifact consumption gap。

- [x] Android release signing gate（Slice92，M0）
  - 当前状态：已完成增量实现；`tool/check_release_metadata.dart --require-release-signing` 解析 Android `release` block，要求显式 `signingConfig`，并拒绝 debug signing/TODO 模板。
  - 运行边界：默认 local/GitHub CI 不启用该 opt-in gate，以保留开发配置的本地 release 运行；既有 release-cut 文档命令显式启用，未配置正式签名时 fail-fast。
  - 验证：focused `ci_workflow_test.dart` `+28`、全量测试 `+332`、`flutter analyze` 零问题、diff check 与严格 CI 均通过；严格 CI 含 importer/compare/Web/provenance generate+verify，当前 debug signing 被稳定拒绝。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice92-release-signing-gate.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded iOS/macOS release-signing 或 artifact consumption contract。

- [x] Apple release signing gate（Slice93，M0）
  - 当前状态：已完成增量实现；`tool/check_release_metadata.dart --require-apple-signing` 检查 iOS/macOS 所有 `Release` 配置，拒绝 development/placeholder identity，并要求 `DEVELOPMENT_TEAM` 或 distribution `CODE_SIGN_IDENTITY`。
  - 运行边界：credentials、provisioning 与 notarization 仍在仓库外管理；既有 release-cut 命令显式启用该 opt-in gate，默认 local/GitHub CI 不被阻断。
  - 验证：focused `ci_workflow_test.dart` `+29`、全量测试 `+333`、`flutter analyze` 零问题、diff check 与严格 CI 均通过；严格 CI 含 importer/compare/Web/provenance generate+verify，当前 iOS/macOS 模板被稳定拒绝并给出双平台诊断。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice93-apple-signing-gate.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded release artifact consumption 或 platform packaging contract。

- [x] Web artifact upload contract（Slice94，M0）
  - 当前状态：已完成增量收紧；GitHub Actions `datahookclaws-web` upload 现在对缺失 build/manifest 使用 `if-no-files-found: error`，并固定 `retention-days: 14`。
  - 消费边界：archive 仅包含 `build/web` 与同级 provenance manifest；既有 release notes 记录解包结构与生命周期，未创建额外打包副本。
  - 验证：focused `ci_workflow_test.dart` `+29`、全量测试 `+333`、`flutter analyze` 零问题、diff check 与严格 CI 均通过；严格 CI 含 importer/compare/Web/provenance generate+verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice94-web-artifact-upload-contract.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Hidden Web build metadata parity（Slice95，M0）
  - 当前状态：已完成增量修复；发现 `build/web/.last_build_id` 会被 provenance 哈希而被 `upload-artifact@v4` 默认排除，现以 `include-hidden-files: true` 保持下载 artifact 与 manifest 同集。
  - 消费边界：既有 archive 仍仅含 `build/web` 与同级 provenance manifest；release notes 记录 hidden metadata 纳入，不创建额外打包副本。
  - 验证：focused `ci_workflow_test.dart` `+29`、全量测试 `+333`、`flutter analyze` 零问题、diff check 与严格 CI 均通过；严格 CI 含 importer/compare/Web/provenance generate+verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice95-hidden-artifact-parity.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Production platform identifiers（Slice96，M0）
  - 当前状态：已完成增量实现；`tool/check_release_metadata.dart --require-production-identifiers` 拒绝 Android/iOS/macOS 模板或未解析 production identifiers，忽略 test-only bundle ID。
  - 运行边界：既有 release-cut 命令显式启用，当前 `com.example...` 配置会 fail-fast；默认 local/GitHub CI 保持可运行。
  - 验证：focused `ci_workflow_test.dart` `+30`、全量测试 `+334`、`flutter analyze` 零问题、diff check 与严格 CI 均通过；严格 CI 含 importer/compare/Web/provenance generate+verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice96-production-identifiers.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web version provenance contract（Slice97，M0）
  - 当前状态：已完成增量实现；provenance CLI 的 `--require-web-version` 校验 generated `version.json` 与 canonical pubspec package/version/build number 一致。
  - CI 接入：local/GitHub Web manifest generate 与 verify 均启用，stale 或 tampered version metadata 在 upload 前 fail-fast；不新增 evidence copy。
  - 验证：focused `ci_workflow_test.dart` `+31`、full test `+335`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify（含 Web version gate）。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-08-31-slice97-web-version-provenance.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] CI release-evidence read-only permissions（Slice98，M0）
  - 当前状态：已完成增量实现；既有 GitHub Actions workflow 通过顶层 `permissions: contents: read` 约束 release-evidence job，不具备 repository-write 或 deployment 权限。
  - 文档/回归：既有 workflow test 锁定权限块，`docs/release_packaging.md` 记录未来部署需单独审查权限；不新增 artifact、source copy 或第二 release 路径。
  - 验证：focused workflow test `+32`、full test `+336`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice98-ci-read-only-permissions.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] CI release-evidence concurrency contract（Slice99，M0）
  - 当前状态：已完成增量实现；workflow 按 `github.workflow` 与 `github.ref` 分组，并取消同组 superseded run，减少旧构建继续产出 release evidence 的竞态。
  - 边界：只取消运行中的旧 workflow，不删除已经上传的 artifact；不新增 artifact、source copy 或 deployment 权限。
  - 验证：focused workflow test `+33`、full test `+337`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice99-ci-concurrency.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] CI release-evidence timeout contract（Slice100，M0）
  - 当前状态：已完成增量实现；既有 release-evidence job 使用 30 分钟硬上限，防止 stalled dependency/build 无限占用 CI capacity。
  - 边界：仅限制运行时长，不改变权限、并发取消、artifact retention 或 provenance 内容；不新增 artifact、source copy 或 deployment path。
  - 验证：focused workflow test `+34`、full test `+338`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice100-ci-timeout.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Release-evidence lockfile reproducibility（Slice101，M0）
  - 当前状态：已完成增量实现；GitHub/local CI 均以 `flutter pub get --enforce-lockfile` 强制使用 checked-in `pubspec.lock`，依赖不一致时 fail-fast。
  - 边界：不升级依赖、不改写 lockfile、不新增 artifact/source copy/deployment path；仅收紧 release-evidence 的解析前置条件。
  - 验证：focused workflow test `+35`、full test `+339`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice101-lockfile-reproducibility.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Explicit Web release-mode packaging（Slice102，M0）
  - 当前状态：已完成增量实现；local/GitHub Web artifact build 均显式使用 `flutter build web --release`，避免默认模式歧义。
  - 边界：仅固定 build mode，不改变 provenance、version gate、artifact path 或 retention；不新增 source copy。
  - 验证：focused workflow test `+36`、full test `+340`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice102-web-release-mode.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Checkout credential isolation（Slice103，M0）
  - 当前状态：已完成增量实现；既有 `actions/checkout@v4` 禁止持久化 credentials，release-evidence workspace 不保留 checkout token。
  - 边界：不改变 read-only token 权限、artifact/provenance、并发、timeout 或 lockfile 行为；不新增 source copy。
  - 验证：focused workflow test `+37`、full test `+341`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice103-checkout-credential-isolation.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Core Web shell provenance contract（Slice104，M0）
  - 当前状态：已完成增量实现；provenance CLI `--require-web-shell` 要求 Web build 的四个核心 regular files 存在，local/GitHub generate 与 verify 均启用并在 upload 前 fail-fast。
  - 边界：只验证入口文件存在性，不复制 source/content、不改变 artifact path/retention，也不替代 version、hash 或 signing gate。
  - 验证：focused workflow test `+38`、full test `+342`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice104-web-shell-provenance.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web manifest identity provenance（Slice105，M0）
  - 当前状态：已完成增量实现；provenance CLI `--require-web-manifest` 校验 generated `manifest.json` 的 `name`/`short_name` 与 canonical package 一致，local/GitHub generate 与 verify 均启用。
  - 边界：仅校验 PWA identity，不替代 shell/version/hash/signing gate，不改变 artifact path/retention，也不新增 source copy。
  - 验证：focused workflow test `+39`、full test `+343`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version/manifest gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice105-web-manifest-identity.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web shell product metadata（Slice106，M0）
  - 当前状态：已完成增量实现；Web manifest 与 index meta description 已移除默认 Flutter 模板文本，改为 README 对齐的产品描述。
  - 边界：仅更新用户可见 shell metadata，不改变 package identity、artifact/provenance、version gate 或 runtime behavior；不新增 source copy。
  - 验证：focused workflow test `+40`、full test `+344`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version/manifest gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice106-web-shell-metadata.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Source revision provenance gate（Slice107，M0）
  - 当前状态：已完成增量实现；`--require-revision` 拒绝空 source revision，GitHub 使用 `$GITHUB_SHA`，本地 wrapper 使用 `DHC_SOURCE_REVISION` 或当前 HEAD。
  - 边界：仅收紧 provenance 的提交绑定，不改变文件 hash 算法、artifact path、retention、Web shell/version/manifest gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+41`、full test `+345`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version/manifest gate、source-revision provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice107-source-revision-provenance.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web manifest icon asset provenance（Slice108，M0）
  - 当前状态：已完成增量实现；`--require-web-manifest-assets` 要求非空 `icons` 数组，且每个 `src` 必须安全地指向 artifact 内 regular file；local/GitHub generate 与 verify 均启用。
  - 边界：仅校验 PWA icon 引用，不改变 hash 算法、artifact path、retention、shell/version/identity/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+42`、full test `+346`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice108-web-manifest-assets.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web shell reference integrity（Slice109，M0）
  - 当前状态：已完成增量实现；`--require-web-shell-references` 要求 `index.html` 引用 bootstrap、manifest、favicon、Apple touch icon，并校验目标为 artifact 内 regular file；local/GitHub generate 与 verify 均启用。
  - 边界：仅校验 Web shell 引用完整性，不改变 hash 算法、artifact path、retention、shell/icon/version/identity/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+43`、full test `+347`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice109-web-shell-references.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web metadata parity provenance（Slice110，M0）
  - 当前状态：已完成增量实现；`--require-web-metadata-parity` 对齐 canonical `web/index.html`/`web/manifest.json` 与 generated Web 两个 metadata 文件，篡改任一处即 fail-fast。
  - 边界：仅校验 Web description parity，不改变 hash 算法、artifact path、retention、shell/icon/version/identity/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+44`、full test `+348`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice110-web-metadata-parity.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web PWA startup/display contract（Slice111，M0）
  - 当前状态：已完成增量实现；`--require-web-pwa-contract` 校验安全相对 `start_url`、已知 `display` 与非空主题/背景色；local/GitHub generate 与 verify 均启用。
  - 边界：仅校验 PWA 启动与显示字段，不改变 hash 算法、artifact path、retention、shell/reference/metadata/icon/version/identity/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+45`、full test `+349`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/PWA/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice111-web-pwa-contract.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web manifest icon metadata contract（Slice112，M0）
  - 当前状态：已完成增量实现；`--require-web-manifest-icon-metadata` 校验 icon 尺寸、MIME 类型与 purpose token，local/GitHub generate 与 verify 均启用。
  - 边界：仅校验 PWA icon 语义元数据，不改变 hash 算法、artifact path、retention、shell/reference/metadata/PWA/icon-assets/version/identity/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+46`、full test `+350`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/PWA/icon/version/manifest/revision gate、icon-assets provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice112-web-manifest-icon-metadata.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web theme-color parity contract（Slice113，M0）
  - 当前状态：已完成增量实现；canonical Web shell 增加 theme-color，`--require-web-theme-color-parity` 对齐 source/generated index 与 manifest 四处值，local/GitHub generate 与 verify 均启用。
  - 边界：仅校验 PWA theme color 一致性，不改变 hash 算法、artifact path、retention、shell/reference/metadata/PWA/icon/version/identity/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+47`、full test `+351`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/PWA/icon/theme/version/manifest/revision gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice113-web-theme-color-parity.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web service-worker cleanup contract（Slice114，M0）
  - 当前状态：已完成增量实现；`--require-web-service-worker-contract` 校验 generated bootstrap 的唯一安全 `serviceWorkerVersion`，以及 cleanup-only worker 的 install/activate、`skipWaiting`、self-unregister 语义。
  - 边界：禁止 CacheStorage 与 fetch 拦截以保持当前 Flutter 弃用 worker 的无缓存策略，不改变 hash 算法、artifact path、retention、shell/reference/metadata/PWA/icon/theme/version/manifest/identity/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+48`、full test `+352`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/metadata/PWA/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice114-web-service-worker-contract.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web root base-href contract（Slice115，M0）
  - 当前状态：已完成增量实现；`--require-web-root-base-href` 要求 generated `index.html` 恰好一个 root `<base href="/">`，阻断未解析模板占位符与重复 base 标签。
  - 边界：仅约束当前根路径部署的 Web shell，不改变 hash 算法、artifact path、retention、shell/reference/metadata/PWA/icon/theme/service-worker/version/manifest/identity/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+49`、full test `+353`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice115-web-root-base-href.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Root PWA identity contract（Slice116，M0）
  - 当前状态：已完成增量实现；canonical `web/manifest.json` 增加 root `id`/`scope`，`--require-web-pwa-identity` 校验 source/generated 两处均为 `/` 并阻断篡改。
  - 边界：仅约束当前根路径 PWA 安装身份，不改变 hash 算法、artifact path、retention、shell/reference/base-href/metadata/PWA/icon/theme/service-worker/version/manifest/identity/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+50`、full test `+354`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/identity/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice116-web-pwa-identity.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Responsive Web viewport contract（Slice117，M0）
  - 当前状态：已完成增量实现；canonical `web/index.html` 增加 viewport meta，`--require-web-viewport` 校验 source/generated index 的唯一标准响应式值并阻断篡改/重复。
  - 边界：仅约束移动端 Web shell 元数据，不改变 hash 算法、artifact path、retention、shell/reference/base-href/metadata/PWA/identity/icon/theme/service-worker/version/manifest/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+51`、full test `+355`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/identity/viewport/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice117-web-viewport.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] English Web language contract（Slice118，M0）
  - 当前状态：已完成增量实现；canonical `web/index.html` 增加 `lang="en"`，`--require-web-language` 校验 source/generated shell 的唯一语言属性并阻断外语或缺失值。
  - 边界：仅约束 Web 可访问性元数据，不改变 hash 算法、artifact path、retention、shell/reference/base-href/metadata/PWA/identity/viewport/icon/theme/service-worker/version/manifest/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+52`、full test `+356`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/identity/viewport/language/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice118-web-language.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Web title parity contract（Slice119，M0）
  - 当前状态：已完成增量实现；`--require-web-title-parity` 校验 canonical/generated `index.html` 的唯一非空 `<title>` 且要求文本一致，阻断篡改、重复或空 title。
  - 边界：仅约束 Web 浏览器标题的构建后 parity，不改变 hash 算法、artifact path、retention、shell/reference/base-href/metadata/PWA/identity/viewport/language/icon/theme/service-worker/version/manifest/revision gate 或 runtime；不新增 source copy。
  - 验证：focused workflow test `+53`、full test `+357`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、显式 Web release build、shell/reference/base-href/metadata/PWA/identity/viewport/language/title/icon/theme/service-worker/version/manifest/revision gate、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice119-web-title-parity.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded platform packaging 或 release-evidence contract。

- [x] Activity trace UTF-8 byte budget（Slice120，M0）
  - 当前状态：已完成增量实现；`ActivityTraceStore` 对 `activity_trace_v1` 读取与 append fitting 均按 UTF-8 bytes 执行 `maxValueLength`，多语言/emoji payload 不再按 Dart 字符长度低估。
  - 边界：仅修正 activity trace 持久化容量计量，不改变 schema、action、回放语义、串行队列、fail-open 解码或 item limit；不新增 source copy。
  - 验证：focused ActivityTraceStore test `+12`、full test `+358`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice120-activity-trace-utf8.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Saved review view UTF-8 byte budget（Slice121，M0）
  - 当前状态：已完成增量实现；`MergeReviewSavedViewStore` 对 `merge_review_saved_views_v1` load/save payload 均按 UTF-8 bytes 执行 `maxValueLength`，多语言 view name/filter 不再按 Dart 字符长度低估。
  - 边界：仅修正 saved-view 持久化容量计量，不改变 schema、name normalization、filter 语义、串行队列、no-write-on-rejection 或 item limit；不新增 source copy。
  - 验证：focused saved-view store test `+11`、full test `+359`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice121-saved-view-utf8.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Persistence store runtime bounds（Slice122，M0）
  - 当前状态：已完成增量实现；`ActivityTraceStore` 与 `MergeReviewSavedViewStore` 对 item limit 与最小 UTF-8 payload budget 使用运行时 `ArgumentError`，release build 不再绕过无效构造参数。
  - 边界：仅收紧两个持久化 store 的构造参数校验，不改变有效配置下的 UTF-8 容量计量、schema、串行队列、fail-open 读取、no-write-on-rejection 或 item limit；不新增 source copy。
  - 验证：combined focused store tests `+27`、full test `+361`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare 全门禁、Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice122-runtime-bounds.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence schema 或 release-evidence contract。

- [x] Saved-view strict root schema（Slice123，M0）
  - 当前状态：已完成增量实现；`MergeReviewSavedViewCodec.decode` 要求根对象恰好包含 `schemaVersion` 与 `views`，未知字段 fail-open，避免未来字段未经验证被静默接受。
  - 边界：仅收紧 saved-view 根 schema，不改变 schema version、坏 entry 过滤、UTF-8 payload cap、串行队列、no-write-on-rejection 或现有 canonicalization；不新增 source copy。
  - 验证：focused saved-view codec/store tests 18 cases、full test `+362`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice123-saved-view-root-schema.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] HomePage app_meta UTF-8 byte budget（Slice124，M0）
  - 当前状态：已完成增量实现；新增 `AppMetaPayloadBudget`，HomePage 全部 app_meta payload 上限、候选压缩与 prompt-config 读取均按 UTF-8 bytes 计量，覆盖 recent replay/recall 与 favorites 数据。
  - 边界：仅修正 app_meta 容量计量，不改变 metadata key、trim/dedupe/compaction、fallback 或用户交互；不新增 source copy。
  - 验证：focused helper + HomePage widget tests 7 cases、full test `+363`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice124-home-app-meta-utf8.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Saved-filter strict root schema（Slice125，M0）
  - 当前状态：已完成增量实现；`MergeReviewFilter.tryFromJson` 仅接受 schemaVersion、可选 severity/type 三类字段，unknown field fail-closed，`decode` 保持回退 `All`。
  - 边界：仅收紧 filter JSON 根字段，不改变 enum/schema 校验、过滤 AND 语义、saved-view 行为或 fail-open compatibility；不新增 source copy。
  - 验证：focused filter + saved-view codec tests 10 cases、full test `+363`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice125-filter-root-schema.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] HomePage app_meta per-key write queue（Slice126，M0）
  - 当前状态：已完成增量实现；新增 `AppMetaWriteQueue`，按 metadata key 串行化 HomePage 写入，独立 key 保持并发，失败后队列可恢复，阻断同 key 的 stale payload 后写覆盖 newer state。
  - 边界：仅收敛 HomePage app_meta 写入顺序，不改变 metadata key、UTF-8 byte budget、trim/dedupe/compaction、fallback 或用户交互；不新增 source copy。
  - 验证：focused queue + HomePage widget tests 8 cases、full test `+365`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice126-home-app-meta-write-queue.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence schema 或 release-evidence contract。

- [x] Saved-view item strict schema（Slice127，M0）
  - 当前状态：已完成增量实现；`MergeReviewSavedView.tryFromJson` 仅接受五个 canonical item 字段，unknown item field fail-closed，codec 会跳过该坏 entry。
  - 边界：仅收紧 saved-view 条目 schema，不改变 root schema、filter 校验、坏 entry 过滤、UTF-8 payload cap、串行 store 或 no-write-on-rejection；不新增 source copy。
  - 验证：focused saved-view codec + store tests 19 cases、full test `+366`、`flutter analyze` 零问题、`git diff --check` 与严格 CI 均通过；严格 CI 含 lockfile gate、14 项 importer、compare/accessibility 全门禁、Web release build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice127-saved-view-item-schema.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Provenance manifest strict schema（Slice128，M0）
  - 当前状态：已完成增量实现；verify 现在要求生成 manifest 的精确 root/file-entry fields，extra fields fail-closed。
  - 边界：仅收紧 release evidence schema，不改变 artifact hashing、sourceRevision、Web contract 或发布输出；不新增 source copy。
  - 验证：focused ci workflow 54 cases、full test `+367`、analyze zero、diff check 与严格 CI（临时 environment-only sqlite system hook）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice128-provenance-schema.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Saved-view monotonic timestamps（Slice129，M0）
  - 当前状态：已完成增量实现；model 拒绝 `updatedAt < createdAt`，store 在 clock rollback 时保留既有 view 的较晚 `updatedAt`，新 name/filter 仍正常提交。
  - 边界：仅收紧 saved-view 时间戳与排序新鲜度契约，不改变 schema guards、UTF-8 payload cap、串行写入、filter 或用户流程；不新增 source copy。
  - 验证：focused saved-view model/store tests 21 cases、full test `+369`、analyze zero、diff check 与严格 CI（临时 environment-only sqlite system hook）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice129-saved-view-monotonic-time.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Favorite persistence entry isolation（Slice130，M0）
  - 当前状态：已完成增量实现；`favorite_foods_v1` 逐条安全解析，坏 entry 不再阻断有效收藏，重复 `foodId` 仅保留首个有效 snapshot。
  - 边界：仅收紧 favorite metadata 的 entry 容错与去重，不改变 metadata key、UTF-8 payload cap、write queue、有效数据 UI 或用户流程；不新增 source copy。
  - 验证：focused widget tests 8 cases、full test `+370`、analyze zero、diff check 与严格 CI（临时 environment-only sqlite system hook）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice130-favorite-entry-isolation.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Favorite template entry isolation（Slice131，M0）
  - 当前状态：已完成增量实现；`favorite_templates_v1` 逐条 fail-closed 解析，坏模板不再阻断后续有效模板，缺失 legacy 时间戳保留兼容 fallback。
  - 边界：仅收紧 favorite template metadata entry 容错，不改变 metadata key、有效模板行为、UTF-8 payload cap、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 9 cases、full test `+371`、analyze zero、diff check 与严格 CI（临时 environment-only sqlite system hook）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-01-slice131-favorite-template-entry-isolation.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Favorite filter persistence ordering（Slice132，M0）
  - 当前状态：已完成增量实现；错误 `sortMode` 安全回退 `recent`，favorite foods/filters/templates 按依赖顺序加载且每个 loader 独立隔离异常，避免启动 pruning 竞态丢失有效 filter。
  - 边界：仅收紧 favorite filter metadata 解码与加载时序，不改变 metadata key、有效 filter 语义、UTF-8 payload cap、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 10 cases、full test `+372`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice132-favorite-filter-ordering.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Recent export recall scope validation（Slice133，M0）
  - 当前状态：已完成增量实现；`recent_export_recalls_v1` 按 scope 类型规范化并拒绝空/保留 sentinel 项，search/favorites 的 `all-local-foods` 继续映射为既有全本地语义。
  - 边界：仅收紧 export recall metadata 解码，不改变 metadata key、合法 replay 行为、UTF-8 payload cap、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 11 cases、full test `+373`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice133-recent-export-recall-validation.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Compare replay draft integer timestamps（Slice134，M0）
  - 当前状态：已完成增量实现；`recent_export_replay_drafts_v1` 只接受整数/整数字符串，小数或非有限值不会被截断，缺少可靠时间戳的 draft 进入既有 `manual rebuild required` 保护路径。
  - 边界：仅收紧 draft timestamp metadata 解码，不改变合法 retention/status/archive 语义、metadata key、UTF-8 payload cap、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 12 cases、full test `+374`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice134-compare-replay-draft-integer-time.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Recent-search metadata read isolation（Slice135，M0）
  - 当前状态：已完成增量实现；`recent_searches_v1` 启动读取异常被局部隔离，recent searches 可暂不可用但 HomePage shell 与其他 loader 继续启动。
  - 边界：仅收紧 recent-search metadata read failure handling，不改变 parser、metadata key、其他启动 loader、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 13 cases、full test `+375`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice135-recent-search-read-isolation.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Compare prompt-config read isolation（Slice136，M0）
  - 当前状态：已完成增量实现；`compare_replay_draft_prompt_config_v1` 读取异常保留内存默认配置，合法 export recall 仍能恢复。
  - 边界：仅隔离 prompt-config metadata read failure，不改变默认 config、export recall、metadata key、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 14 cases、full test `+376`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice136-prompt-config-read-isolation.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Recent export recall history fallback（Slice137，M0）
  - 当前状态：已完成增量实现；`recent_export_recalls_v1` 读取失败按 cache miss 处理，已有 export history 仍能重建合法 recall chip。
  - 边界：仅隔离 recall-cache read failure，不改变 history fallback、合法 replay、metadata key、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 15 cases、full test `+377`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice137-recent-export-history-fallback.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Replay-status read isolation（Slice138，M0）
  - 当前状态：已完成增量实现；`recent_export_replay_statuses_v1` 读取异常只丢失可选 status suffix，合法 compare recall chip 仍可见，replay/archive 流程继续。
  - 边界：仅隔离 replay-status metadata read failure，不改变 recall chip、status 语义、metadata key、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 16 cases、full test `+378`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice138-replay-status-read-isolation.md`，不创建 full-content copy。
  - 下一步：补齐一个 bounded persistence 或 release-evidence contract。

- [x] Replay-draft timestamp read isolation（Slice139，M0）
  - 当前状态：实现与 focused regression 已完成；`recent_export_replay_drafts_v1` 读取失败只清除可选 timestamp 层，status restoration 继续并将缺失 timestamp 的 Draft 归档为 `manual rebuild required`。
  - 边界：仅隔离 draft-timestamp metadata read failure，不改变 status restoration、archive 语义、metadata key、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 17 cases、full test `+379`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice139-replay-draft-timestamp-read-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Export-history read isolation（Slice140，M0）
  - 当前状态：已完成增量实现；recent-recall cache 与 `getExportHistory` 均不可用时保持 HomePage shell 健康，recall list 为空，不产生未处理 startup 异常。
  - 边界：仅隔离 export-history fallback read failure，不改变 recall-cache 行为、空 recall 语义、metadata key、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 18 cases、full test `+380`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice140-export-history-read-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Compare-detail read isolation（Slice141，M0）
  - 当前状态：已完成增量实现；compare replay 详情按 ID 隔离读取，单个 `getFoodDetails` 失败只跳过该 ID，后续详情继续加载并报告 truthful partial restoration。
  - 边界：仅隔离 per-ID compare detail read failure，不改变 partial-restoration status、compare IDs、metadata key、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 19 cases、full test `+381`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice141-compare-detail-read-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Import-log read isolation（Slice142，M0）
  - 当前状态：已完成增量实现；HomePage refresh/search/advanced search 的 `getImportLogs` 失败保留 prior log state，result 与 count 更新继续执行。
  - 边界：仅隔离 supplemental import-log read failure，不改变 result/count reads、prior log state、metadata key、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 20 cases、full test `+382`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice142-import-log-read-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Food-count read isolation（Slice143，M0）
  - 当前状态：已完成增量实现；HomePage refresh/search/advanced search 的 `countFoods` 失败保留 prior count state，result 更新继续执行。
  - 边界：仅隔离 supplemental food-count read failure，不改变 result/log reads、prior count state、metadata key、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 21 cases、full test `+383`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice143-food-count-read-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Initial results read recovery（Slice144，M0）
  - 当前状态：已完成增量实现；HomePage 首次 refresh 的 `searchFoods` 失败展示 local-results-unavailable 状态并保持可重试，不再无限 loading 或产生未处理异步错误。
  - 边界：仅隔离 initial primary results read failure，不改变 standard/advanced search、result/log/count reads、metadata key、write queue 或用户流程；不新增 source copy。
  - 验证：focused widget tests 22 cases、full test `+384`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice144-initial-results-read-recovery.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Recent-search persistence isolation（Slice145，M0）
  - 当前状态：已完成增量实现；`recent_searches_v1` 写入失败不再阻断 `_runSearch`，内存 recent-search state 仍即时更新并可继续完成搜索。
  - 边界：仅隔离 recent-search supplemental persistence failure，不改变 search execution、in-memory recent-search state、metadata key 或其他 write queue 行为；不新增 source copy。
  - 验证：focused widget tests 23 cases、full test `+385`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice145-recent-search-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Recent-search management persistence isolation（Slice146，M0）
  - 当前状态：已完成增量实现；recent-search remove/clear-all 在 `recent_searches_v1` 写入失败时仍即时更新内存列表，不产生未处理 Future。
  - 边界：仅隔离 recent-search management persistence failure，不改变 search recording、in-memory state、metadata key 或其他 write queue 行为；不新增 source copy。
  - 验证：focused widget tests 24 cases、full test `+386`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice146-recent-search-management-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Favorite persistence isolation（Slice147，M0）
  - 当前状态：已完成增量实现；favorite toggle/remove/clear-all 在 `favorite_foods_v1` 写入失败时仍即时更新内存状态，不产生未处理 Future。
  - 边界：仅隔离 favorite persistence failure，不改变 favorite in-memory state、metadata key 或其他 write queue 行为；不新增 source copy。
  - 验证：focused widget tests 25 cases、full test `+387`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice147-favorite-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Favorite-filter persistence isolation（Slice148，M0）
  - 当前状态：已完成增量实现；favorite country/source/category/sort 写入 `favorite_filters_v1` 失败时仍即时更新内存筛选，不产生未处理 Future。
  - 边界：仅隔离 favorite-filter persistence failure，不改变 in-memory selections、metadata key 或其他 write queue 行为；不新增 source copy。
  - 验证：focused widget tests 26 cases、full test `+388`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice148-favorite-filter-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Favorite-template persistence isolation（Slice149，M0）
  - 当前状态：已完成增量实现；favorite template save/delete 在 `favorite_templates_v1` 写入失败时仍即时更新内存 template list，不产生未处理 Future。
  - 边界：仅隔离 favorite-template persistence failure，不改变 in-memory template state、metadata key 或其他 write queue 行为；不新增 source copy。
  - 验证：focused widget tests 27 cases、full test `+389`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice149-favorite-template-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Replay-status persistence isolation（Slice150，M0）
  - 当前状态：已完成增量实现；compare replay/archival 写入 `recent_export_replay_statuses_v1` 失败时仍保留 live status，不产生未处理 Future。
  - 边界：仅隔离 replay-status persistence failure，不改变 compare replay state、metadata key 或其他 write queue 行为；不新增 source copy。
  - 验证：focused widget tests 28 cases、full test `+390`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice150-replay-status-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Replay-draft timestamp persistence isolation（Slice151，M0）
  - 当前状态：已完成增量实现；compare replay 的 `recent_export_replay_drafts_v1` 时间戳写入失败时仍保留 live status，不产生未处理 Future。
  - 边界：仅隔离 replay-draft timestamp persistence failure，不改变 compare replay state、metadata key 或其他 write queue 行为；不新增 source copy。
  - 验证：focused widget tests 29 cases、full test `+391`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice151-replay-draft-timestamp-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Export-recall persistence isolation（Slice152，M0）
  - 当前状态：已完成增量实现；`recent_export_recalls_v1` 写入失败时 export recall 清空/变更仍即时更新 live recall list，不产生未处理 Future。
  - 边界：仅隔离 export-recall persistence failure，不改变 live recall list、metadata key 或其他 write queue 行为；不新增 source copy。
  - 验证：focused widget tests 30 cases、full test `+392`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice152-export-recall-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Provenance symlink containment（Slice153，M0）
  - 当前状态：已完成增量实现；release provenance output/verify 路径按 existing path components 解析后做 containment，symlink redirect 无法指回 artifact 内部。
  - 边界：仅加固 provenance destination containment，不改变 deterministic manifest hashing、output/verify semantics 或 Web contract checks；不新增 source copy。
  - 验证：focused CI workflow tests 55 cases、full test `+393`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice153-provenance-symlink-containment.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Provenance artifact-root symlink rejection（Slice154，M0）
  - 当前状态：已完成增量实现；release provenance artifact input 必须是 regular directory，root symlink fail-closed，不会静默采用外部目录。
  - 边界：仅收紧 artifact-root 类型约束，不改变 destination containment、deterministic hashing 或 Web contract checks；不新增 source copy。
  - 验证：focused CI workflow tests 55 cases、full test `+393`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice154-provenance-artifact-root-symlink.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Provenance dangling-path resolution（Slice155，M0）
  - 当前状态：已完成增量实现；input/output/verify containment path 遇到悬空或不可解析 symlink 时 fail-closed，输出稳定诊断，不进入 hashing 或 writing。
  - 边界：仅隔离 provenance path-resolution failure，不改变 regular artifact-root validation、destination containment、deterministic hashing 或 Web contract checks；不新增 source copy。
  - 验证：focused CI workflow tests 55 cases、full test `+393`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice155-provenance-dangling-path-resolution.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Settings startup persistence isolation（Slice156，M0）
  - 当前状态：已完成增量实现；`app_settings` read failure 回退默认设置，malformed payload 的 repair write 失败不会阻断 `load()` 返回。
  - 边界：仅隔离 settings startup read/repair-write failure，不改变 settings sanitization、显式 save semantics 或 runtime wiring；不新增 source copy。
  - 验证：focused settings tests 7 cases、full test `+393`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice156-settings-startup-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Settings page persistence recovery（Slice157，M0）
  - 当前状态：已完成增量实现；SettingsPage load 的 settings/storage-path failure 显示 recoverable message 并保留 form，save failure 不再冒泡出 button action。
  - 边界：仅隔离 SettingsPage load/save persistence failure，不改变 settings service fallback、表单字段或 runtime wiring；不新增 source copy。
  - 验证：focused SettingsPage tests 2 cases、full test `+396`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice157-settings-page-persistence-recovery.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Export history persistence isolation（Slice158，M0）
  - 当前状态：已完成增量实现；export file 成功写出后，`addExportHistory` failure 不会使 `ExportArtifact` 失败返回，且不会伪造历史记录。
  - 边界：仅隔离 export-history write failure，不改变 export formats、deterministic paths、AI summary behavior 或 recall persistence；不新增 source copy。
  - 验证：focused export-service tests 9 cases、full test `+397`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice158-export-history-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] AI suggestion persistence isolation（Slice159，M0）
  - 当前状态：已完成增量实现；`AiAssistServiceBase` 的模型输出与 suggestion-log write 解耦，成功结果不再被日志故障吞掉，模型/预算 fallback 也不会因 fallback 日志故障冒泡。
  - 边界：仅隔离 shared AI suggestion persistence failure，不改变 model budget、public `persist` semantics、deterministic fallback 或 export/search routing；不新增 source copy。
  - 验证：focused settings/AI tests 9 cases、full test `+399`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice159-ai-suggestion-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查 `QueryExpansionService` 的 analogous bounded persistence boundary。

- [x] Query expansion persistence isolation（Slice160，M0）
  - 当前状态：已完成增量实现；`QueryExpansionService` 的模型/解析结果与 suggestion-log write 解耦，有效 expansion 不再被日志故障吞掉，请求/预算 fallback 也不会因 fallback 日志故障冒泡。
  - 边界：仅隔离 query-expansion suggestion persistence failure，不改变 model budget、expansion parsing、public persistor semantics 或 deterministic search fallback；不新增 source copy。
  - 验证：focused query-expansion/budget tests 9 cases、full test `+402`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice160-query-expansion-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Import log persistence isolation（Slice161，M0）
  - 当前状态：已完成增量实现；成功/失败 import log 作为 supplemental diagnostics，成功导入不再被 success-log failure 伪报失败，原始导入错误不再被 failure-log failure 覆盖。
  - 边界：仅隔离 `SyncFoodCatalogUseCase` import-log persistence failure，不改变 ingestion、normalization、artifact persistence、original error semantics 或 importer routing；不新增 source copy。
  - 验证：focused source-importer tests 17 cases、full test `+404`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件，唯一新迭代日志为 `docs/timeline/2026-09-02-slice161-import-log-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Fetch-job persistence isolation（Slice162，M0）
  - 当前状态：已完成增量实现；前台/后台 fetch-job queued、running、success、failure、cancelled 状态写入失败时，来源导入与 enrichment progress 仍继续，成功来源不会被伪报失败。
  - 边界：仅隔离 `ForegroundFetchRunner` 与 `BackgroundEnrichmentQueue` 的 fetch-job persistence failure，不改变 importer execution、queue cancellation/state transitions、fetch-job schema 或 SearchOrchestrator wiring；不新增 source copy。
  - 验证：focused fetch-runner/queue/orchestrator tests 8 cases、full test `+407`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice162-fetch-job-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Operations retry persistence isolation（Slice163，M0）
  - 当前状态：已完成增量实现；Operations 手动 Retry 的 fetch-job running/success/failure 状态写入失败时，来源重试仍执行，成功重试不会被伪报为失败，原始来源错误文案保持不变。
  - 边界：仅隔离 Operations retry fetch-job persistence failure，不改变 source retry semantics、activity tracing、refresh behavior、fetch-job schema 或审核竞态矩阵；不新增 source copy。
  - 验证：focused retry regression、Operations widget tests 118 cases、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice163-operations-retry-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Dataset artifact persistence isolation（Slice164，M0）
  - 当前状态：已完成增量实现；`SyncFoodCatalogUseCase` 的 dataset-artifact inventory metadata 写入失败时，normalized foods 与 success import log 仍返回，已提交 ingestion/normalization 语义保持不变。
  - 边界：仅隔离 supplemental dataset-artifact persistence failure，不改变 normalized ingestion、success/failure import-log boundaries、artifact schema 或 importer routing；不新增 source copy。
  - 验证：focused `it_crea`/source-importer tests 18 cases、full test `+409`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice164-dataset-artifact-persistence-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Recent fetch-history read isolation（Slice165，M0）
  - 当前状态：已完成增量实现；`SearchOrchestrator` 读取 recent failed fetch-job history 失败时，以空 failure set 继续主搜索与后台 enrichment，不再把 routing metadata outage 伪报为用户工作失败。
  - 边界：仅隔离 recent fetch-history read failure，不改变 source routing rules、budget limits、local-search states 或 enrichment queue semantics；不新增 source copy。
  - 验证：focused SearchOrchestrator tests 9 cases、full test `+411`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice165-recent-fetch-history-read-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Post-fetch reconciliation read isolation（Slice166，M0）
  - 当前状态：已完成增量实现；`SearchOrchestrator` post-fetch local-search reconciliation read 失败时，使用 foreground runner 已返回的 normalized foods，成功来源仍返回 archived state，正常重读路径保持 canonical 去重。
  - 边界：仅隔离 supplemental post-fetch reconciliation read failure，不改变 canonical result merging、source outcome semantics、routing 或 enrichment queue behavior；不新增 source copy。
  - 验证：focused SearchOrchestrator tests 9 cases、full test `+412`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice166-post-fetch-reconciliation-read-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Export summary provider isolation（Slice167，M0）
  - 当前状态：已完成增量实现；导出文件仍是 primary artifact，AI summary provider 失败时回退到确定性摘要，export history 仍保留且不伪报导出失败。
  - 边界：仅隔离 supplemental export-summary provider failure，不改变 export formats、deterministic paths、history schema 或成功 provider 的 AI summary behavior；不新增 source copy。
  - 验证：focused export-service tests 11 cases、full test `+413`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice167-export-summary-provider-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Export directory resolution read isolation（Slice168，M0）
  - 当前状态：已完成增量实现；storage-path metadata 读取失败或为空时，导出目录回退到确定性的本地 `exports` 目录，显式用户目录仍优先，export action 不再被 supplemental read 阻断。
  - 边界：仅隔离 `SettingsService.effectiveExportDirectory` 的 supplemental storage-path read failure，不改变 explicit export-directory precedence、settings sanitization 或 export formats；不新增 source copy。
  - 验证：focused Settings/AI tests 10 cases、full test `+414`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice168-export-directory-resolution-read-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Storage budget metadata read isolation（Slice169，M0）
  - 当前状态：已完成增量实现；storage paths 与 dataset-artifact inventory 独立读取，任一 supplemental read 失败时另一侧 metrics 仍保留，并通过明确 warning 标记未知预算数据。
  - 边界：仅隔离 `StorageBudgetManager.snapshot` 的 storage-path/inventory read failure，不改变 filesystem sizing、budget thresholds 或 unavailable-data warning semantics；不新增 source copy。
  - 验证：focused StorageBudgetManager tests 4 cases、full test `+416`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice169-storage-budget-metadata-read-isolation.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Settings numeric bounds（Slice170，M0）
  - 当前状态：已完成增量实现；persisted/explicit settings 的负数与非正 runtime controls 统一回退安全默认，`modelMaxCallsPerMinute: 0` 仍作为显式 AI disable，避免无效 timeout/token/storage limits 进入 runtime。
  - 边界：仅收紧 `SettingsService` numeric sanitization，不改变 source enablement sanitization、zero-call disable semantics 或 settings persistence；不新增 source copy。
  - 验证：focused Settings/AI tests 12 cases、full test `+417`、analyze zero、diff check 与严格 CI（canonical dependency file）通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice170-settings-numeric-bounds.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Settings save canonical snapshot（Slice171，M0）
  - 当前状态：已完成增量实现；`SettingsService.save` 返回实际写入的 sanitized snapshot，`SettingsPage` 成功保存后立即采用该 snapshot，避免当前表单显示值与持久化配置分叉。
  - 边界：仅收紧 settings save 的 canonical return/UI reconciliation，不改变 numeric sanitization、zero-call AI disable、source enablement 或 settings persistence；不新增 source copy。
  - 验证：focused Settings/AI tests 12 cases、settings-page tests 3 cases、full test `+418`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice171-settings-save-canonical-snapshot.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Storage measurement completeness（Slice172，M0）
  - 当前状态：已完成增量实现；filesystem adapter 让 database/artifact/export/cache 测量显式区分完整与不完整，非法路径或部分扫描失败时保留可测 bytes 并报告 warning，预算快照不再因测量异常崩溃或伪报零。
  - 边界：仅收紧 `StorageBudgetManager` filesystem measurement contract，不改变 repository-read isolation、budget thresholds、empty-path semantics 或 Operations wiring；不新增 source copy。
  - 验证：focused StorageBudgetManager tests 6 cases、full test `+420`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、14 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice172-storage-measurement-completeness.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Home search failure recovery（Slice173，M0）
  - 当前状态：已完成增量实现；HomePage 提交搜索现在以 request-generation guard 管理异步结果，任何主搜索/advanced search/supplemental read 异常都会结束 loading、保留既有结果并显示稳定 `Search unavailable` + `Retry search` 恢复入口，清空输入或新请求会隔离旧状态。
  - 边界：仅收紧 HomePage 搜索 UI 的失败恢复与 stale-result ownership，不改变 SearchOrchestrator、initial-results recovery、enrichment cancellation 或结果合并语义；不新增 source copy。
  - 验证：focused HomePage widget tests 30 cases、full test `+421`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice173-home-search-failure-recovery.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Fetch budget input bounds（Slice174，M0）
  - 当前状态：已完成增量实现；planner 构造器收敛负 importer budget/threshold 与非正 per-importer limit，保留 `maxImporters:0` 显式禁用；`SourceRoutingService` 对直接负 route budget fail safe，跳过 fetch 的 plan 也返回 sanitized limit。
  - 边界：仅收紧预算/路由输入边界，不改变 source ordering、recent-failure prioritization、显式零禁用或 importer request semantics；不新增 source copy。
  - 验证：focused planner/routing tests 11 cases、full test `+425`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice174-fetch-budget-input-bounds.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Source route identity deduplication（Slice175，M0）
  - 当前状态：已完成增量实现；capability-aware 与 legacy routing 对重复 default importer/source hint 按首次出现去重，防止一次计划重复执行同一来源，同时保留优先级、recent-failure 排序与 route budget。
  - 边界：仅收紧 source route identity 去重，不改变 budget sanitization、source ordering、failure prioritization 或 importer request semantics；不新增 source copy。
  - 验证：focused planner/routing tests 13 cases、full test `+427`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice175-source-route-identity-deduplication.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Model budget runtime bounds（Slice176，M0）
  - 当前状态：已完成增量实现；`ModelBudgetController` 对负调用上限、非正 timeout/token/cooldown 使用安全默认，`maxCallsPerMinute:0` 仍显式禁用模型调用，release 路径不再接受非法 runtime budget。
  - 边界：仅收紧 controller 构造参数，不改变 budget evaluation、cooldown、AI fallback 或 zero-call disable semantics；不新增 source copy。
  - 验证：focused model-budget tests 4 cases、full test `+428`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice176-model-budget-runtime-bounds.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Non-finite nutrient normalization（Slice177，M0）
  - 当前状态：已完成增量实现；`FoodRecordNormalizer` 在 raw 与 unit-converted nutrient amounts 进入 canonical model 前拒绝 `NaN`、`Infinity` 与换算溢出，保留同一记录中的有效营养素。
  - 边界：仅收紧 nutrient normalization finite contract，不改变 alias mapping、unit conversion、有效记录或导出语义；不新增 source copy。
  - 验证：focused normalization-toolkit tests 6 cases、full test `+429`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice177-non-finite-nutrient-normalization.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Import request limit boundary（Slice178，M0）
  - 当前状态：已完成增量实现；`ImportRequest` 在构造期把负 limit 收敛为 `0`，`const` 与 `copyWith` 保持同一边界，避免负值穿透 importer `.take()` 与 count-based early-exit，`0` 仍是显式空请求。
  - 边界：仅收紧 import request limit value-object contract，不改变 valid limit、zero-limit 或 dataset preparation semantics；不新增 source copy。
  - 验证：focused official-dataset tests 6 cases、full test `+430`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice178-import-request-limit-boundary.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Repository read limit normalization（Slice179，M0）
  - 当前状态：已完成增量实现；Memory/SQLite `FoodRepository` 共用 read-limit normalizer，负 limit 在搜索、summary、country、MergeReview 与 diagnostics history 读取中安全返回空页，避免负 `.take()`、错误 early-exit 或 SQLite 负 `LIMIT` 语义，`0` 仍为显式空页。
  - 边界：仅收紧 repository read-limit contract，不改变 valid paging、sorting、query filtering 或 SQLite persistence；不新增 source copy。
  - 验证：focused repository tests 10 cases、full test `+432`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice179-repository-read-limit-normalization.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Export food-id limit boundary（Slice180，M0）
  - 当前状态：已完成增量实现；`FoodCatalogExportService.exportFoodIds` 在 `.take()` 前把负 limit 收敛为 `0`，malformed caller 得到确定性的空 artifact/零记录并保留 export history，不触发详情读取。
  - 边界：仅收紧 export food-id limit contract，不改变正数 limit、identifier trim/dedup、format、scope 或 history semantics；不新增 source copy。
  - 验证：focused export-service tests 11 cases、full test `+433`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice180-export-food-id-limit-boundary.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Export scope filename containment（Slice181，M0）
  - 当前状态：已完成增量实现；公开 `scopeType` 仅以安全 slug 参与文件名拼接，traversal-shaped scope 不会离开 configured export directory，payload/history 仍保留原始 scope value。
  - 边界：仅收紧 export filename path contract，不改变 scope payload/history、valid filename、directory resolution 或 format semantics；不新增 source copy。
  - 验证：focused export-service tests 12 cases、full test `+434`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice181-export-scope-filename-containment.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Official ZIP extraction containment（Slice182，M0）
  - 当前状态：增量实现与本地验证已完成；ZIP entry 现在使用 segment-aware relative-path guard，`../extracted-evil/...` 等兄弟前缀 traversal 不会写出 configured extraction directory，合法嵌套文件继续解包。
  - 边界：仅收紧官方数据 ZIP 解包的文件系统 containment，不改变下载、manifest、valid extraction 或 sentinel semantics；不新增 source copy。
  - 验证：focused official-dataset tests 7 cases、full test `+435`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice182-official-zip-extraction-containment.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Official dataset download filename containment（Slice183，M0）
  - 当前状态：增量实现与本地验证已完成；`HttpDatasetTransport.download` 在发起网络请求前拒绝 absolute/traversal-shaped `suggestedFileName`，共享 segment-aware guard 与 ZIP extraction 口径一致，合法 manifest filename 不变。
  - 边界：仅收紧官方数据下载目标的文件系统 containment，不改变 download、manifest、valid extraction 或 sentinel semantics；不新增 source copy。
  - 验证：focused official-dataset tests 8 cases、full test `+436`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice183-official-download-filename-containment.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Official dataset importer-id containment（Slice184，M0）
  - 当前状态：增量实现与本地验证已完成；transport 与 ZIP preparer 现在在 root resolver 前拒绝 absolute、parent-directory 或含任一平台 separator 的 `importerId`，合法 manifest ID 的目录布局不变。
  - 边界：仅收紧官方数据目录身份的文件系统 containment，不改变 valid directory resolution、download、ZIP extraction 或 sentinel semantics；不新增 source copy。
  - 验证：focused official-dataset tests 10 cases、full test `+438`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice184-official-importer-id-containment.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Home refresh generation ownership（Slice185，M0）
  - 当前状态：已完成增量实现与本地验证；HomePage supplemental refresh 绑定 search-generation，并在每个异步存储读取边界检查 ownership，旧 enrichment/import/initial refresh 不再覆盖新查询结果。
  - 边界：仅收紧首页异步结果提交的 generation contract，不改变 search、import、enrichment 或 supplemental-read semantics；不新增 source copy。
  - 验证：focused widget regression、full test `+439`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice185-home-refresh-generation-ownership.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] App metadata write-tail cleanup（Slice186，M0）
  - 当前状态：已完成增量实现与本地验证；`AppMetaWriteQueue` 现在以 identity-checked settled-tail cleanup 释放完成/失败 key，活动写入仍保持同 key 串行，避免动态 key 长期占用 `_tails`。
  - 边界：仅收紧 metadata write queue 的内存生命周期，不改变 per-key ordering、failure recovery 或 metadata persistence semantics；不新增 source copy。
  - 验证：focused queue tests 4 cases、full test `+441`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice186-app-meta-write-tail-cleanup.md`，不创建 full-content copy。
  - 下一步：检查一个 bounded persistence 或 release-evidence contract。

- [x] Search expansion cache bound（Slice187，M0）
  - 当前状态：已完成增量实现与本地验证；`SearchOrchestrator` 的 expansion cache 默认限制为 32 entries，命中刷新 LRU recency，超限淘汰最久未使用项，enrichment 对淘汰 query 重新展开。
  - 边界：仅收紧 query expansion cache 的内存生命周期与 constructor 输入，不改变 expansion 结果、source routing、enrichment 或 failure-isolation semantics；不新增 source copy。
  - 验证：focused orchestrator tests 11 cases、full test `+442`、analyze zero、diff check 与严格 CI（canonical dependency file）均通过；严格 CI 含 lockfile gate、17 importer、compare/accessibility、Web build、provenance generate/verify。
  - 存储规则：仅增量编辑 canonical 文件并新增专门回归测试，唯一新迭代日志为 `docs/timeline/2026-09-02-slice187-search-expansion-cache-bound.md`，不创建 full-content copy。
  - 下一步：用户已要求推送后暂停更新，待后续明确指令再恢复 bounded slice。

## 核心体验补齐（高优先级）
- [ ] 搜索与结果工作流增强
  - 结果收藏（Favorite）与收藏夹入口
  - [x] 结果对比面板（2~3 个食物对比）
    - 当前状态：已完成（支持对比条目卡片、缺失与方差高亮、单位不一致提示）。
    - 下个动作：继续在结果差异面板补齐单位归一化策略和可访问性文本提示。
  - [x] 最近导出结果回读（导出后快速重选）
  - [x] 最近导出回读清单管理（“清空”行为 + 持久化记忆隔离策略）
- [ ] 数据刷新与版本治理
  - 官方数据变更检查任务（轻量“更新提醒”）
  - Source dataset 版本快照对比和“what changed”摘要
- [ ] 质量与审核闭环升级
  - MergeReview Issue 批量处理工作区（批量 merge/split/override）
  - [x] MergeReview 当前页批量选择基础（无写入）
  - [x] MergeReview review/presence 双请求、双失败、corrective ownership/dispatch/error/retry/dispose 回归矩阵
  - [x] MergeReview versioned 结构化 logical identity 与确定性去重
  - [x] MergeReview 非执行型 queued/deferred worklist 数据层
  - [x] MergeReview worklist 当前页 Queue/Defer/Untrack、状态提示与 confirmed clear 恢复
  - [x] MergeReview 只读跨页 worklist inventory（20 条本地分页与精确快照/identity）
  - [x] MergeReview inventory All/Queued/Deferred 本地状态筛选
  - [x] MergeReview inventory 有界本地 snapshot 字段搜索
  - [x] MergeReview inventory held-read loading/clamp 回归硬化
  - [x] MergeReview inventory loaded-review-page exact-ID presence summary/markers
  - [x] MergeReview inventory loaded-review-page All/On/Outside 本地筛选
  - [x] MergeReview inventory stale-success presence ownership 回归硬化
  - [x] MergeReview inventory newest-failure presence ownership 回归硬化
  - [x] MergeReview inventory stale-failure presence ownership 回归硬化
  - [x] MergeReview 命名保存视图（保存/应用/删除、容量与损坏恢复）
  - [x] MergeReview repository-native 筛选与分页（突破最近 100 条客户端窗口）
  - [x] MergeReview review-only 交互刷新、竞态保护与内联失败重试
  - [x] MergeReview full-refresh operations/review 错误域拆分与动作刷新路由
  - [x] MergeReview SQLite 批量/事务化派生（固定查询数、单快照、无动态 `IN` 参数扩张）
  - 反悔/撤销日志（至少“最近 20 条治理动作撤销草案”）

## 进阶体验（中优先级）
- [ ] 用户工作流编排
  - 查询模板（保存常用搜索筛选条件）
  - 操作队列（“待处理导入/待复核条目”）
  - 每日入口“今日自动补全预算使用情况”
- [ ] 研究方向：移动端竞品
  - 条码扫描快速检索（本地/离线 fallback）
  - 食物搭配建议（仅提示式，不生成权威营养事实）
  - 每日摄入场景关联（从营养数据库到个人日志）

## 后台与性能（低优先级）
- [ ] 会话级别后台抓取持久化（重启后可恢复）
- [ ] 增量抓取策略（最近变更优先 + 小包优先）
- [ ] 指标与降级策略可视化（实时预算告警 + 近 7 日健康度图）

## 合法性与边界前置
- [ ] 每个新源/新功能在上线前补充许可与归属声明
- [ ] 新增导出能力前更新 NOTICE/source_data NOTICE
- [ ] 所有 AI 生成文本保持非权威声明与日志留痕
- [ ] 本 Goal 中新增队列任务文本与审计字段统一设定：单条 UTF-8 文本上限 1,048,576 字符（便于日志持久化与回放）。

## 里程碑映射（对应 PROJECT_PLAN）
- 当“搜索体验补齐”和“结果对比工作流”到位：归入 `Phase R+`（AI/UX 体验增强）。
- 当“持久化后台队列”和“版本变更提醒”到位：归入 `Phase S`（持久化生产治理）。
- 当“收藏与模板”与质量批量工作区稳定：归入 `Phase T`（长期运营能力）。

## 近期研究任务（Goal 级）
- [ ] 竞品调研：提取“收藏-对比-复盘”闭环在同类数据库客户端中的标准交互和失败恢复机制。
- [ ] 可靠性研究：评估持久会话队列（重启恢复）对现有 `BackgroundEnrichmentQueue` 的兼容改造成本。
- [ ] 成本研究：估算 1,048,576 字符上限日志字段对 SQLite 与导出体积的影响边界。
- [ ] 结果对比研究：评估营养标签/单位归一化对“同维度差异”可视化的稳定性与偏差来源。
- [x] compare 回放无障碍趋势看板研究：补充 `stableAlertCandidates` 复发指标（`recurrenceCount` / `maxAbsenceRuns` / `episodeCount`）并接入日报/周报看板观察。
- [x] compare 回放无障碍趋势看板运维研究：将 `DHC_A11Y_TREND_DASHBOARD_*`（`daily_limit`/`weekly_limit`/`regression_window`）纳入 CI/local 参数模板，支持按环境动态调整而非脚本硬编码，并补充阈值变更回放策略。
- [x] compare 回放失败可访问性快照研究：定义 Missing IDs / Unavailable / Draft 恢复路径的屏幕阅读器文案快照与回放重试后的状态恢复口径，并接入可观测回归规则。
  - 当前状态：已将回放失败关键状态在 `tool/check_compare_accessibility.dart` 中加入语义关联检查，并在 `home_page.dart` 的 replay 状态流中补齐 `Semantics` 与 `semanticsLabel`。
  - 下个动作：持续评估无草稿/手动重建失败路径在多窗口和高频重试场景下的语义一致性，并补齐实验记录模板。
- [ ] compare 回放无草稿/手动重建路径体验研究：评估 `Compare replay unavailable` 与 `Please rebuild compare manually` 分支在重放失败高频、清理后回撤场景下的状态文案与屏幕阅读器可达性（含 liveRegion 语义、误触率、恢复率）。
- [ ] compare 回放语义快照鲁棒性研究：构建 5 个失败状态（unavailable / retry limit / manual rebuild required / urgent draft / clear unavailable）的跨会话对齐集，监控语义覆盖率、live-region 触发率、重放路径回退一致性、状态迁移抖动与误报率。
- [ ] compare 回放无草稿路径语义回放基准研究：建立“无草稿恢复/手动重建失败上限”在 5 种状态下的快照集（unavailable / manual rebuild required / retry limit / clear all / clear draft）与误触恢复率（含 `export status` live-region 触发覆盖率）。
- [x] compare 回放无草稿/手动重建快照模板落地：已补齐 `docs/compare_replay_accessibility_snapshot_template.json`，并将 5 种状态词条（unavailable、retry limit、manual rebuild、clear unavailable、urgent warning）接入 `tool/check_compare_accessibility.dart` 回归门禁。
- [x] compare 回放语义快照模板标准化：提炼 `sourcePhrases` 语义约束（含 `requiresLiveRegion`）与字段质量规则，接入 CI 统计报告输出。
  - 下个动作：补充跨窗口/高频重试场景下快照命中率与 live-region 触发时延的实验记录（含回放窗口切换、撤销后状态回流）。
- [x] compare 回放语义快照CI结构化上报：补齐脚本结构化 payload（JSON line）下游解析规则，补充 `compare_replay_accessibility` CI step 的字段契约（case/phrase/lifecycle）与失败报警策略（字段缺失、severity 失配、live-region 误报）。
  - 交付项：新增 `tool/parse_compare_accessibility_report.dart`，并接入 `tool/ci_checks.sh` 与 `.github/workflows/flutter-ci.yml`。
  - CI告警参数（可选）：
    - `DHC_A11Y_REPORT_STRICT=true`
    - `DHC_A11Y_MAX_CASES_FAILED`
    - `DHC_A11Y_MAX_PHRASE_MISSING`
    - `DHC_A11Y_MAX_SEMANTIC_FAIL`
    - `DHC_A11Y_MAX_LIVEREGION_FAIL`
    - `DHC_A11Y_MAX_UNKNOWN_SEVERITY_BUCKET`
- [x] compare 回放语义快照契约落地：新增 [compare replay accessibility CI contract](docs/compare_replay_accessibility_ci_contract.md) ，明确模板 summary JSON、解析器输出、告警预算与边界约束（含字符串/负载长度 1,048,576）。
  - 已在 parser 中加入 contract version 校验、severity bucket key 校验与长度告警；当前使用严格模式下 mismatch 直接阻断。
  - 下个动作：将 `DHC_A11Y_MAX_UNKNOWN_SEVERITY_BUCKET` 与 `schemaVersion` 偏差告警接入趋势面板（7 天窗口）观察误报率。
- [ ] 交互鲁棒性：定义收藏和对比对 canonical 重映射后的回放与回退策略。
- [ ] compare 回放无障碍快照多窗口鲁棒性研究：在 `compare scope` 同步、`recall chip` 切换、应用重启后验证 `case/phrase` 报告稳定性，重点关注 live-region 误报、语义漏检与状态回流抖动。
- [x] compare 回放无障碍快照告警治理研究：接入日志聚合后构建趋势阈值（7天滑窗），区分 `missing`、`invalid`、`live-region` 失配，评估自动降级与阻断边界。
  - 已提供 [趋势分析脚本](tool/analyze_compare_accessibility_trends.dart) 与 [趋势指引](docs/compare_replay_accessibility_trend_guide.md)，并已支持 `--window-runs` 与 `--window-days` 双模式（含时间戳解析与缺省回退）。
  - 已补齐 `schemaMismatch` / `unknownSeverity` / `passRate` / `phraseSuccessRate` / `semanticsRate` / `liveRegionRate` 告警条件与 `alerts` 输出，并新增 `rateTrend`（首尾变动与方向）字段。
  - 已补齐 `DHC_A11Y_TREND_MAX_*_DROP` 与 `DHC_A11Y_TREND_MAX_CONSECUTIVE_DROPS` 阈值化规则，`rateTrend` 追加 `maxConsecutiveDownRuns` 与 `maxDrop` 字段。
  - 已接入 CI 级趋势执行：在 parser 输出日志基础上调用趋势脚本并将 `alerts` 纳入 CI 失败策略（本地可通过 `DHC_A11Y_TREND_FAIL_ON_ALERTS` 强制）。
  - 已补齐趋势历史记录输出：`--history-file` 与 `--history-max-entries`，支持跨次运行复用历史文件做序列化审计。
  - 已补齐告警抖动降噪：`--trend-noise-window`，避免瞬时单发告警直接阻断趋势门禁，优先保留 `info` 级观察期。
  - 已完成历史趋势看板化展示脚本：新增 `tool/build_compare_accessibility_trend_digest.dart`（日报/周报 + 稳定告警候选）。
  - 下一个动作：做趋势看板服务化接入（日志服务/周报邮件/报表归档），并补充 `stableAlertCandidates` 的复发率与误报率 7/14/30 天窗口抽样验证。
- [ ] 收藏多维筛选研究：评估国家/来源/分类联合过滤在空值标签、跨版本重建与界面恢复时的一致性与降噪策略。
- [ ] 行为轨迹研究：评估 activity entry 结构演进（版本字段、回放策略、失败恢复）、以及跨 app 启停的可重放性边界。
- [ ] 行为轨迹幂等性研究：定义 `search/import/favorite/compare/export/governance` 的可回放白名单与禁用场景（包括重复执行与快照漂移防护）。
- [ ] 治理 trace 回放研究：定义 `governance` 与 `export` 动作在 trace 中的幂等重放边界与回放禁用策略。
- [ ] 轨迹会话化研究：定义 `search/import/favorite/compare` 动作的可恢复会话模型（fingerprint、阶段性快照、重放恢复按钮、部分成功回滚提示）。
- [ ] 收藏目录研究：评估国家以外标签（来源/sourceName、分类/category）为主维度的收藏聚类可解释性、误差边界与过滤失败回退策略。
- [ ] 收藏组织研究：验证收藏目录模板（按场景/饮食阶段）在不同会话和多设备间的一致性与迁移成本。
- [ ] 收藏模板研究：评估收藏模板在字段演进、同名覆盖、跨设备回放与历史回退场景下的冲突消解策略。
- [ ] 结果回读一致性研究：验证导出查询回放与原检索上下文（高级筛选/限额）重建的一致性边界。
- [x] 回放记忆治理研究（完成）：已实现清空动作的 `app_meta` 持久化记忆隔离，已避免重启后自动恢复清空状态。
- [ ] 回放记忆会话隔离扩展：评估跨设备/多窗口并发与回收策略，定义持久记忆与本会话隔离边界。
- [ ] 收藏-比较-导出闭环研究：评估比较导出后的可重放与重建策略（compare scope trace、回放入口、失败可恢复）。
- [ ] 比较持久化一致性研究：验证筛选/搜索切换下比较集合与缓存食物信息的生命周期、去重和失效清理策略。
- [ ] 对比导出交互研究：定义导出按钮在导出中状态、进度提示、失败重试与最小 2 条目约束的统一 UX 行为。
- [ ] compare 回放重试一致性研究：验证「缺失项重试」路径在手动重建/草稿退出/清理回收各路径下，重试次数上限与状态转移是否保持一致（含重复重试防抖与上限埋点）。
- [ ] 对比差异可视化研究：验证营养素在单位归一化、缺失值与极值判定下的视觉提示准确性和可访问性。
- [ ] compare 回放鲁棒性研究：研究 compare scope 中 id 缺失、过期或重复执行时的降级策略（跳过、提示重建、局部回放）。
- [ ] compare 回放状态研究：定义 recall chip 回放状态的存储策略（会话内临时/跨会话持久）与“单条移除/失效清理”联动规则。
- [ ] compare 回放条目失效治理研究：定义“重复回放失败/全失效”条目是否应自动降级、沉默/隐藏还是提示用户修复。
- [ ] compare 回放重试策略研究：定义超过 3 次失败后是否触发“重建 compare scope”建议，以及是否在 Activity Trace 中记录回放修复会话。
- [ ] compare 回放草稿态治理研究：定义 Draft 草稿态在长周期无操作场景中的自动提示、清理阈值与再次回放策略。
- [ ] compare 回放状态清理一致性研究：建立统一清理链路的自动回归规则，验证 compare 草稿、状态卡片、重试计数、提醒节流（展示次数/冷却）在所有移除/失效/清空路径下同步清空。
- [x] compare 回放草稿清理一致性自动回归研究：已补齐本地脚本 `tool/check_compare_replay_draft_cleanup.dart`，静态扫描 `home_page.dart` 中 `_clearCompareReplayDraftState` 调用并校验是否在对应方法作用域内命中 `_resetUrgentCompareReplayDraftPromptScheduler()`。
- [x] compare 回放草稿清理一致性 CI 接入研究：已将 `tool/check_compare_replay_draft_cleanup.dart` 纳入 GitHub Actions `Flutter CI` 固定步骤，并通过 `tool/ci_checks.sh` 在本地统一执行。
- [x] compare 回放到期提示埋点研究：已补齐“展示/直接关闭/背景点击/清空/稍后提醒”事件分支并统一落表至标准 trace 字段（含 `userAction` 与 schema 版本）。
- [x] compare 回放提示字段标准化研究：已统一 prompt trace 为统一详情构造器，统一输出 `scopeKey` + `remainingMs` + `userAction` + schema 版本。
- [x] compare 回放提示抑制原因上报研究：已把 `suppressReason`/`shownCount`/`cooldownMs` 纳入统一 prompt trace 构造器输出。
- [x] compare 回放提示 userAction 词表规范：已定义 `_CompareReplayDraftPromptUserAction` 并在 compare prompt 事件链路内统一使用。
- [x] compare 回放提示埋点口径研究：已用 `activityTraceSchemaVersion` 与统一 trace builder 强制 schema 与动作词表。
- [x] compare 回放提示中止原因词表研究：已定义 `_CompareReplayDraftPromptDismissReason`，并将 reason 统一从该类型赋值。
- [x] compare 回放到期提示弹窗结果词表化研究：已将 `showDialog` 返回值改为 enum，减少字符串分支漂移并保留返回语义。
- [x] compare 回放提示 trace 构造器研究：已封装 `_compareReplayDraftPromptTraceDetails`，减少 prompt 事件缺字段风险。
- [x] compare 回放草稿可见性研究：已补充草稿剩余时长展示（chip + 状态面板），并评估了不同剩余粒度文案边界。
- [x] compare 回放草稿恢复研究：已实现“Resume draft”动作链路（清空当前对比并恢复草稿上下文），并补充重试/重建入口联动。
- [x] compare 回放草稿态清理入口：提供显式入口清理 draft 状态条目，避免误删 recall 的同时可收口长期停留草稿。
  - 当前状态：已完成（新增 `Clear draft` 按钮与 `compare` 草稿状态批量清理入口）。
- [x] compare 回放草稿到期一键清理研究：验证草稿到期场景下提供“立即清理并降级”是否能降低误恢复风险，并定义提示文本一致性。
  - 当前状态：已完成（状态卡「Draft remaining」在到期窗口内新增 `Clear draft now` 行为）。
- [x] compare 回放草稿到期提醒研究：验证到期弹窗在不同会话/误触场景下的收益，并定义“稍后提醒”与“自动清理”边界。
  - 下个动作：研究提醒的会话内上限、4 小时冷却是否应参数化（含可追踪埋点：展示次数、跳出率、误触率），并评估是否支持“每会话首条优先级”策略。
- [x] compare 回放到期提示 trace promptType 研究：已补充 `promptType`（`urgent_prompt`/`manual`）字段，与 `trigger` 同步写入。
- [x] compare 回放到期提示 promptInstanceId 研究：已将到期弹窗显示/关闭链路关联到 `promptInstanceId`，支持同一弹窗生命周期串联追踪。
  - 近期修复：实例 ID 改为 scope + 已求值时间戳 + `promptSessionIndex`，避免错误 `$DateTime.now()` 插值生成重复字面 ID。
- [x] compare 回放到期提示 promptConfigVersion 研究：已在 compare prompt trace 中增加 `promptConfigVersion`（当前 `urgent_prompt_v1`），为后续策略/文案 A/B 提供版本锚点。
- [x] compare 回放到期提示升级研究：已完成策略配置抽离，并将配置载入从 app meta 入口 `_compareReplayDraftUrgentPromptConfigMetaKey`，支持热更新版本参数（标题/文案/按钮/阈值/冷却/展示上限）；默认回退至内置 `urgent_prompt_v1`。
- [x] compare 回放到期提示 A/B 研究：已将多个版本与 `experimentVariant` 接入 `app_meta` 配置源，并在 prompt trace 中补充 `promptConfigVersion` + `promptExperimentVariant`（清理/误触/手动重建链路）。
- [x] compare 回放到期提示配置参数健壮性研究：已完成异常值回退（如 `urgentThresholdMinutes`、`snoozeHours`、`maxCountPerSession` 非正数）到默认值，并写入 `promptConfigFallback` 与原因；并补充 `app_meta` 配置样例。
  ```json
  {
    "version": "urgent_prompt_v1",
    "title": "Compare replay draft expiring",
    "bodyTemplate": "Draft for {scope} expires soon. Remaining time: {remaining}. You can resume later or clear this draft now.",
    "dismissButtonLabel": "Dismiss",
    "remindLaterButtonLabel": "Remind me later",
    "clearNowButtonLabel": "Clear draft now",
    "urgentThresholdHours": 24,
    "snoozeMinutes": 240,
    "maxCountPerSession": 2,
    "experimentVariant": "baseline"
  }
  ```
- [x] compare 回放到期提醒 cooldown 自动重试研究：已补齐到期弹窗 `snooze` 冷却后的自动重试调度（单状态复用 timer，提示链路统一复用 `UrgentPrompt` suppress/defer/clear trace）。
- [x] compare 回放到期提醒 promptSessionIndex 指标：已补齐 prompt trace 的 `promptSessionIndex` 透传字段，并支持冷却重试后自动追踪会话内同一会话序号。
- [x] compare 回放到期提醒 session 级限流研究：补齐会话内“仅保留一次提醒优先级”策略（首次入场 draft 锁定为会话优先目标，清理/过期后才切换）并补充 `suppress` 与 `promptSessionIndex` 下钻口径。
- [x] compare 回放到期提醒会话优先状态研究：补齐“清空 all recall”全量清理路径对 `_compareReplayDraftUrgentPromptPriorityKey` 与提示 timer 的统一重置，防止清理后出现悬挂优先态。
- [x] compare 回放到期提醒清理路径研究：补齐单条移除、不可用清理与草稿清理路径对 `deferredTimer` 的统一清空，避免清理后触发过期会话提醒。
- [x] compare 回放到期提醒状态重建研究：补齐手动清 draft、重试上限归零/到达上限等状态变更后，进行统一提醒调度收口（helper 化 `_resetUrgentCompareReplayDraftPromptScheduler`）。
- [x] compare 回放到期提醒加载后重调度一致性研究：将 ` _loadRecentExportSearches()` 中两处加载完成后的直接 ` _scheduleUrgentCompareReplayDraftPrompt()` 替换为 `_resetUrgentCompareReplayDraftPromptScheduler()`，避免同一周期重复挂起旧 timer + 提醒回调。
- [x] compare 回放提醒行为研究：已建立会话级漏斗（按 `scopeKey` + `promptSessionIndex`）并验证：
  - 当前状态：已新增 `tool/analyze_compare_replay_prompt_funnel.dart` 与
    `test/domain/analyze_compare_replay_prompt_funnel_test.dart`，用于离线校验 prompt 泄漏行为漏斗；
  - 已验证口径：`trigger=urgent_prompt` 下 `userAction` 与 `suppressReason` 汇总、`sessionCount`、`scopeKey` 会话聚合；
  - 近期修复：文本汇总使用 snake_case action 词表，`deferred` 覆盖三类实际延期/关闭分支，`clearNow` 对齐 `clear_from_prompt`。
  - 下个动作：补充高频弹窗重试中的样本阈值与误触率关联指标。
- [x] compare 回放手动重建入口研究：将“Unavailable (manual rebuild required)”状态提升为可引导操作（清空失效条目并进入 compare 选择重建）。
  - 当前状态：已完成（按钮可清理当前 compare 回放上下文并回到 compare 选择）。
  - 下个动作：研究是否应支持“保留 recall 条目但折叠为待重放草稿”。
- [x] compare 回放手动重建草稿模式研究：将“手动重建”行为改为保留 recall 条目、清空当前重放上下文并写入草稿状态。
  - 当前状态：已完成（手动重建不再移除 recall，保留历史并标记 Draft 草稿态，避免历史丢失）。
  - 下个动作：研究草稿态草稿条目在“清空不可用条目”和“回放复用”路径中的提醒策略。
- [x] compare 回放手动重建确认研究：对手动重建动作加入二次确认，避免误清当前重放上下文。
  - 当前状态：已完成（新增“确认重建”弹窗）。
  - 下个动作：研究是否改为更轻量非弹窗确认（如撤销条）。
- [x] compare 回放与单位归一化脚本执行策略研究：本地 `DART_BIN` 在只读 Flutter 工程 cache 下直接运行脚本会失败时，定义一致降级策略（本地跳过并记录、CI 严格失败）与恢复指引文案。
  - 当前状态：已完成（脚本接入 `tool/ci_checks.sh`，本地失败自动软降级，CI 环境严格失败）。
  - 下个动作：补充 `DHC_FORCE_DART_CHECKS=true` 的开发者说明并在 README/AGENT 中记录手动触发策略（已完成，见 README 示例）。

- [ ] 未来升级研究（M4）：比较面板可解释性与回放安全性
  - 当前状态：进行中。
  - 研究内容：对 compare 差异面板的方差突出、单位归一化失败提示、缺失值降级说明与用户确认流程做一致性定义，避免误读营养差异。
  - 近期完成：方差与 extrema 高亮统一 1e-6 容差；空单位显式进入 non-comparable mismatch；mg/g/kcal/kJ 跨单位逻辑回归已通过。
  - 下一步：完成发布清单中的真实 compare 场景 UI 抽样与可见文案归档。
- [x] 未来升级研究（M4）：比较交互可访问性治理（首批）
  - 当前状态：已完成。
  - 已补齐：compare 面板首版焦点顺序治理、删除快捷键入口（Delete/Backspace）、行级/单元级语义标签增强、焦点-语义回归脚本接入 CI。
  - 已补齐：误触恢复入口（compare 删除后 6s Undo 提示）与回归脚本可观察项（Undo 行为关键字）。
  - 下一个动作：补充“屏幕阅读器回放场景”语义快照回归（聚焦错误状态恢复路径）。
- [x] compare 面板可访问性语义化落地（第一批）：
  - 已完成：`_buildComparisonPanel` 与 `_ComparisonValueChip` 增补语义标签与提示文本，包含 variance/missing/unit mismatch 行为摘要与单元值语义状态（最高值/最低值/缺失）。
  - 当前状态：已补齐键盘焦点顺序验证与语义脚本（`tool/check_compare_accessibility.dart`）并接入本地/CI门禁。
- [ ] 未来升级研究（M4）：跨会话 compare 回放状态治理
  - 当前状态：待启动。
  - 研究内容：定义多窗口/重启/异常退出时 compare recall 与草稿态的收敛模型（优先级、过期、清理、重试计数）与统一回放策略，避免状态分裂。
- [ ] 未来升级研究（M4）：比较营养单位归一化研究
  - 当前状态：进行中。
  - 当前执行结果：compare 页面单位归一化已改为复用领域能力
    `normalizeNutrientComparisonUnit`（`lib/src/domain/normalization/nutrient_comparison_units.dart`），减少私有映射与脚本规则分叉风险。
  - 研究内容：评估 compare 页面同维度单位不一致（mg/g/kcal 等）下的统一归一化阈值、可视化误差条款与可解释性提示，避免误判营养差异。
  - 研究补充：补齐脚本化回归与本地执行边界（含 `g/serving`、`IU`、`mcg`）后，与上线阈值策略打通。
  - 研究补齐：已补齐单位后缀兼容（g/100g、mg/serving、IU、mcg）和分母冲突/空值/反例样本，新增单位归一化边界核验。
  - 本次补充：同步在 `test/domain/nutrient_comparison_units_test.dart` 补了 kilocalorie 百分比别名覆盖，减少脚本与单元测试口径差异。
  - 当前实现追踪项：已将 `compare` 比较行按标准单位 + 分母签名（如 `g/100g`）分组；后续补齐边界样本验证后再做值域统一策略。
  - 当前执行结果：已加入 `IU/IU` 口径的可比识别（统一到 `IU` 量纲），与 `g/serving`、`kcal` 及 `mg/g` 分母签名路径一并受控。
  - 执行路线：先补齐三类回归场景（mg/g、cal/kcal、kJ/kcal）的单元对齐清单并加入 release review 验收：
    - [x] 回归场景：mg↔g 的可比性与误差上限（示例：1500 mg vs 1.5 g，允许浮点误差 <= 1e-6）。
    - [x] 回归场景：kcal↔cal 的口径一致性（示例：1000 kcal vs 1000000 cal，需等价显示并无单位分组冲突）。
    - [x] 回归场景：kJ↔kcal 的乘积换算与阈值回退（示例：4184 kJ vs 1000 kcal，需判定同口径、可见单位标注）。
    - [x] 回归场景：分母口径冲突时不得跨口径方差（示例：100 g/100g 与 100 g（无分母）应触发 `unitMismatch`）。
  - 复核清单：新增 compare 面板发布核对项（`docs/compare_unit_normalization_release_checklist.md`），与脚本化单测联动用于发布前复核。

- [x] M4 比较营养单位归一化脚本执行（本地核验）
  - 脚本：`tool/check_compare_unit_normalization.dart`
  - 目标：将 `mg/g/kcal/cal/kJ/IU + 分母签名` 映射在本地快速归一化预期一一核验。
  - 研发动作：已将脚本补充 `g/serving`/`mcg`/`IU` 大小写变体用例，正在接入 CI 门控（含失败传播策略）。
  - 近期完成：在 `CI=true ./tool/ci_checks.sh` 与 `flutter test test/domain/ci_workflow_test.dart` 中均通过该脚本路径，并保持 strict fail 边界稳定。
  - 近期加固：fixture 文件读取/JSON 解码、非对象数组项与零用例结构均纳入显式诊断 + 内置样例回退，并增加运行时回归，避免损坏样例导致崩溃或静默漏检。
  - 近期加固：GitHub Actions 显式映射同名 repository variable，远端 fixture 覆盖可实际生效；compare 面板方差/极值改为共用 1e-6 容差。
  - 下一步：执行 compare 面板真实数据 UI 抽样并归档发布截图，推进发布前验收闭环。
