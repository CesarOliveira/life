# Roadmap — Atividade, Hábitos, Metas e Saúde

Plano da evolução do tracking pessoal do Life. Desenhado em 2026-06-29.

## Conceitos centrais (3 coisas distintas)

| Conceito | O que é | Vira contribuição no heatmap? |
|---|---|---|
| **Hábito** (manual ou automático) | recorrência (diário / dias da semana / Nx por semana) | ✅ cada dia feito = 1 `HabitCheck` |
| **Meta** (alvo) | aspiração pontual: "chegar a 80kg" | ❌ barra de progresso (não recorrente) |
| **Medição** (saúde/exames) | sinal bruto: sono, passos, glicemia, colesterol… | ❌ por si só; pode alimentar hábito-automático |

**Decisão sobre "metas são hábitos?":** depende do tipo.
- **Meta de limiar diário** ("tela ≤ 3h", "sono ≥ 7h") = **hábito automático** (regra avalia a métrica do dia e cria/remove o `HabitCheck`; sem toque manual).
- **Meta de alvo** ("80kg") = **entidade `Goal` separada** (progresso início→atual→alvo lendo o histórico de peso).

## Substrato técnico
Tudo que é recorrente desagua em **`HabitCheck`** (já existe; índice único `[habit_id, date]`), que o heatmap (`ContributionGraph`), o streak e a aderência (`HabitStats`) já consomem. **Não** criar tabela `contributions` nova.

## Modelo de dados planejado
- `habit_checks` *(existe)* — substrato de contribuição.
- `habits` *(existe)* — +`frequency` (dias-da-semana / diário / Nx-semana), +`weekly_target`, +`auto`, +regra inline (`metric_key`, `comparator` lte/gte, `threshold_value`).
- `measurements` *(nova, genérica)* — `account_id, key, value, unit, measured_on, ref_low?, ref_high?, source`; único `[account, key, measured_on]`. Cobre sono, passos **e exames** (glicemia, colesterol, com faixa de referência).
- `goals` *(nova)* — `account_id, name, metric_key, start_value, target_value, deadline?, achieved_on?`.
- `app_usages` *(existe)* — tela continua aqui; hábito "tela<3h" lê a soma do dia.
- `weight_entries` *(existe)* — a meta 80kg lê daqui.

## Fases

- [x] **Fase 1 — Página de Atividade** (`/activity`): heatmap com filtros 3/6/12 meses (padrão 3) + select por ano. `ContributionGraph` generalizado p/ `from:/to:`. Dias sem atividade em cinza (sem vermelho); futuros vazios. *(Concluída 2026-06-29.)*
- [x] **Fase 2 — Cadência semanal + força do hábito**: `habits.frequency` (`weekly_days`/`weekly_count`) + `weekly_target` ("Academia 3x/sem"); `HabitStats` com força (adesão 28d → **Forte ≥80% / Médio 50–79% / Fraco <50%**, badge) e streak semanal; página do hábito (`/habits/:id`) com heatmap próprio + timeline 28d (feito/perdido/não agendado). *(Concluída 2026-06-29.)*
- [x] **Fase 3a — Saúde (dados + manual + API)**: tabela genérica `measurements` (sinais e exames, com faixa de referência); `POST /api/metrics` (token/fuso reutilizados, idempotente) p/ sono/passos; página `/measurements` (Saúde) com abas Sinais/Exames, entrada manual, tendência (SVG) e badge fora-da-faixa. *(Concluída 2026-06-29.)*
- [x] **Fase 3b — Import de PDF de exame**: upload do PDF na aba Exames → `ExamPdfExtractor` (API Anthropic, leitura de PDF) extrai os resultados → cria `measurements` (source "pdf", idempotente). Requer `ANTHROPIC_API_KEY` no ambiente (modelo via `LIFE_EXTRACTION_MODEL`, padrão `claude-sonnet-4-6`); sem a chave a UI mostra aviso e o endpoint recusa. PDF processado em memória (não persistido). *(Concluída 2026-06-29.)*
- [x] **Fase 4 — Hábitos automáticos de limiar**: `habits.auto` + `metric_key`/`comparator`/`threshold_value`; `HabitRuleEvaluator` cria/remove `HabitCheck` por regra (≤/≥), disparado na ingestão (tela via `AppUsage`, sono/passos via `measurements`) e em backfill de 90d ao criar/editar. Métricas: tela (total/dia), sono, passos, FC repouso. Toggle manual bloqueado em hábitos `auto`; entram no heatmap/streak sem mexer no `ContributionGraph`. *(Concluída 2026-06-29.)*
- [x] **Fase 5 — Metas de alvo (`Goal`)**: entidade `goals` (metric_key, start/target, deadline) + página `/goals` (nav "Metas") com cartão de progresso (`GoalProgress`: % start→atual→alvo em qualquer direção, atingida + data, faltando). Lê peso (`weight_entries`) ou qualquer métrica do catálogo (`measurements`). Início auto-preenchido do dado atual. *(Concluída 2026-06-29.)*
- [x] **Fase 6 — Análise cruzada**: página `/insights` (nav "Análises") com `CrossAnalysis` — para a métrica escolhida (sono/passos/tela/FC), correlação de Pearson com a aderência diária aos hábitos manuais + comparação acima x abaixo da mediana (chave comum `(account, date)`), em janela de 90d. Frase em linguagem simples + ressalva "correlação ≠ causa". *(Concluída 2026-06-29.)*

---

**Status: Fases 1–6 concluídas e em produção (2026-06-29).** Pendência operacional: definir `ANTHROPIC_API_KEY` (e opcionalmente `LIFE_EXTRACTION_MODEL`) no Railway para ligar o import de PDF de exames (Fase 3b).

## Decisões tomadas
- Dia perdido no grid geral = **cinza** (ausente), nada de vermelho. O "perdido" explícito fica só no timeline por hábito.
- `weekly_count`: cada check = 1 contribuição (sem cap no heatmap); o cap fica só na métrica de força.
- Hábito-auto sem dado do dia = **"sem dados"** (não pune o streak); reavalia quando o dado atrasado chega na janela.
- Tela: derivar total diário de `AppUsage` (não duplicar em `measurements`).
- Idioma da interface: movido do cabeçalho para **Configurações da conta**.
