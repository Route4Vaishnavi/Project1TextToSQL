# Text-to-SQL with a Clarification Engine

Ask a database questions in plain English. When the question is ambiguous, the
system **asks you what you meant instead of guessing**.

> *"Show me last month's best customer"* — best by what? Revenue? Order count?
> Repeat visits? Each gives a different answer. A tutorial text-to-SQL system
> picks one silently and reports a confident, unverifiable number. This one
> asks first.

---

## The problem

Text-to-SQL demos are easy to build and dangerous to deploy. The failure mode
is not the obvious one — it is not that the system errors out. It is that the
system returns a plausible number that is quietly wrong, and a human pastes it
into a business review.

Roughly a third of real analytical questions are under-specified. "Revenue" may
be gross or net of refunds. "Last month" may be the previous calendar month or
a trailing thirty days. "New customers" may mean accounts created or first-time
buyers. The model cannot know which you meant — but it will answer anyway.

## The approach

```
                   ┌──────────────────────┐
  Question ───────►│  Schema retrieval    │  pick relevant tables only
                   └──────────┬───────────┘
                              ▼
                   ┌──────────────────────┐
                   │ Ambiguity detection  │
                   └──────────┬───────────┘
                     ambiguous│      │clear
                    ┌─────────┘      │
                    ▼                │
         ┌────────────────────┐      │
         │ Ask the user       │      │
         │ with real options  │      │
         └─────────┬──────────┘      │
                   │ answer          │
                   └────────►┌───────▼──────────┐
                             │ SQL generation   │
                             └───────┬──────────┘
                                     ▼
                             ┌──────────────────┐
                             │ Safety validation│  AST parse, allowlist, LIMIT
                             └───────┬──────────┘
                                     ▼
                             ┌──────────────────┐
                             │ Read-only execute│  separate DB role, timeout
                             └───────┬──────────┘
                                     ▼
                              Answer + the SQL
```

## Status

Under construction. See [docs/00-roadmap.md](docs/00-roadmap.md) for the twelve
build phases and what each one teaches.

- [x] Phase 0 — Foundations: repo, venv, typed config, tests
- [x] Phase 1 — Schema and read-only role *(seed data in progress)*
- [ ] Phase 2 — Multi-provider LLM client
- [ ] Phase 3 — Naive baseline
- [ ] Phase 4 — Safety layer
- [ ] Phase 5 — Clarification engine
- [ ] Phase 6 — Retrieval accuracy
- [ ] Phase 7 — Evaluation harness
- [ ] Phase 8 — API and UI
- [ ] Phase 9 — Observability and cost
- [ ] Phase 10 — Docker, CI, deploy
- [ ] Phase 11 — Documentation
- [ ] Phase 12 — Interview preparation

## Results

*Populated in Phase 7. The headline metric is execution accuracy on an
ambiguous-question subset, measured with the clarification engine disabled and
enabled. Both numbers get published here, including the cases where the system
loses.*

## Stack

| Layer | Choice | Why |
|---|---|---|
| Language | Python 3.11+ | Type hints throughout, checked with mypy |
| Database | PostgreSQL | Real analytical SQL; window functions, CTEs |
| Validation | Pydantic v2 | Structured LLM output with a schema contract |
| SQL safety | sqlglot | Parse to an AST — never regex over SQL |
| Models | Groq, Gemini, OpenAI | Free tiers, with automatic fallback |
| API | FastAPI | Async, typed, self-documenting |
| UI | Streamlit | Fastest path to a demo that shows the SQL |

Total running cost: **zero**. Every service used has a free tier sufficient for
this workload.

## Security

A language model can be talked into emitting `DROP TABLE customers`. Prompt
instructions are a probabilistic defence, so this project does not rely on
them. Layers, outermost first:

1. A Postgres role with `SELECT` and nothing else — see [db/readonly_role.sql](db/readonly_role.sql)
2. A `statement_timeout` on that role
3. AST-level validation rejecting anything that is not a single `SELECT`
4. Table and column allowlisting against the live schema
5. A `LIMIT` injected into every query
6. Prompt instructions — the weakest layer, listed last deliberately

Layer 1 is the one that holds when everything above it fails.

## Quick start

```bash
# 1. Clone and enter
git clone <your-repo-url>
cd text2sql-clarify

# 2. Create an isolated environment
python -m venv .venv
.venv\Scripts\activate          # Windows
source .venv/bin/activate       # macOS / Linux

# 3. Install
pip install -e ".[dev]"

# 4. Configure
copy .env.example .env          # then fill in your values
pytest                          # should pass
```

You need a Postgres database (a free Neon or Supabase instance works) and at
least one LLM API key. Groq's free tier is the fastest to obtain.

## Repository layout

```
db/            schema, read-only role, seed data, business glossary
docs/          roadmap, architecture decisions, security notes, interview prep
evals/         golden dataset and benchmark results
src/text2sql/  application code
  llm/         provider clients and fallback logic
  core/        schema linking, clarification, generation, validation, execution
  api/         FastAPI service
tests/         unit and integration tests
```

## Licence

MIT
