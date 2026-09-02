# compare 单位归一化发布复核清单（M4）

用途：在发布前对 compare 面板单位归一化与显示口径做最后闭环核对。

## 一、脚本化归一化验证

- [x] `tool/check_compare_unit_normalization.dart` 本地运行通过
  - mg ↔ g 可比性与比例误差（<= 1e-6）
  - kcal ↔ cal 可比性
  - kJ ↔ kcal 可比性
  - 分母签名规范化（`g/100g`、`g/serving`）
  - 空值/反例样本拒绝（空串、`mystery-unit`、未知单位）
  - 大小写与同源别名覆盖（`KILOCALORIES`、`percent`）
  - 样例由 `tool/fixtures/compare_unit_normalization_cases.json` 统一维护（脚本仅负责加载校验）。
  - 可通过 `DHC_COMPARE_UNIT_NORMALIZATION_FIXTURE` 覆盖样例路径（未设置时默认落到 `tool/fixtures/compare_unit_normalization_cases.json`）。
  - GitHub Actions 通过同名 repository variable 注入覆盖路径；workflow 未配置该变量时继续使用仓库默认 fixture。
  - 证据：fixture 不存在时会回退到脚本内置默认用例并给出 `Normalization fixture not found` 提示，仍保持脚本通行。
  - fixture 无法读取、JSON 损坏、数组含非对象条目或没有任何测试用例时，也会在 stderr 明确告警并回退到内置用例；无效条目不会被静默跳过。

## 二、可复用边界样本

- [x] 正向样本
  - `1500 mg` 与 `1.5 g` 同口径
  - `1000000 cal` 与 `1000 kcal` 同口径
  - `4184 kJ` 与 `1000 kcal` 同口径
  - `g/100g` 与 `g` 被识别为不同口径（不应跨口径比较）
  - `KILOCALORIES` 与 `kcal` 同口径（大小写别名）
  - `percent` 与 `%` 同口径

- [x] 反例/异常
  - `""`（空单位）不应归一化
  - `mystery-unit` 不应归一化
  - `μCi`（当前归类未知）不应归一化

## 三、UI/显示一致性对齐（发布前）

- [x] 自动逻辑回归确认方差判定与最高/最低高亮共用 1e-6 容差，近似等价换算值不触发极值语义
- [x] 自动逻辑回归确认空单位显示为 non-comparable mismatch，不进入“同口径一致”路径
- 仅在同口径且同分母签名下显示“同口径变动”
- 不同分母（如 `g` vs `g/100g`）不发生直接方差对齐
- `kcal` 与 `cal` 在 compare 面板可见单位口径统一为 `kcal`
- `IU` 与 `IU`（大小写变体）统一归一化为 `IU`

## 四、验收动作

- [ ] 在当前 App 版本中抽样一次包含 `g/100g`、`g`、`mg`、`kcal`、`kJ` 的 nutrition compare 场景
- [ ] 确认用户可见差异标签与内部归一化口径一致（无“错口径误差”文案）
- [ ] 将本复核清单和 `tool/ci_checks.sh` 输出截图归档到发布记录
