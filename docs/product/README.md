# JoeyPet Product Documentation

`docs/product/` 是 JoeyPet 产品层的 Source of Truth。

| 文档 | 负责回答什么 |
|---|---|
| [PRD](prd.md) | 产品为什么存在、服务谁、提供什么体验 |
| [MVP Scope](mvp-scope.md) | V1 做什么、不做什么、怎样算完成 |
| [Feature Spec](feature-spec.md) | 每个产品功能如何表现、如何验收 |
| [Design.md](../../DESIGN.md) | UI/UX 与 IA 的可复核实现基线（Stitch 为输入，非无条件覆盖） |
| [Roadmap](roadmap.md) | 按什么产品 Milestone 完成 V1 |

技术实现以 `docs/architecture.md`、`docs/domain-model.md`、
`docs/pet-runtime.md`、`docs/system-sensors.md`、`docs/cleanup.md`、
`docs/app-lifecycle.md` 等技术文档为准；不可逆或重要技术决策以
`docs/decisions/` 中的 ADR 为准。

发生冲突时：

- 产品行为：以 PRD、MVP Scope、Feature Spec 为准。
- 用户界面：以 [Design.md](../../DESIGN.md) 为可复核基线；Apple HIG 决定平台行为与无障碍；ADR 记录窄范围例外；Stitch 仅在冻结稿/设计系统产物可取时作为输入（详见 [AGENTS.md](../../AGENTS.md) 与 [ADR 013](../decisions/013-ui-skill-and-design-authority.md)）。
- 技术实现：以 Architecture 与 ADR 为准。

产品文档不替代技术文档，也不因为已有代码就自动扩大 V1 范围。
