# Build Roadmap

The plan for taking this project from an empty folder to something a hiring
manager will take seriously. Twelve phases. Each one ends with working software
and a specific thing you can say in an interview.

Work through them in order. Do not skip Phase 3 (the deliberately naive
baseline) — without it you have nothing to measure the real system against, and
the measurement *is* the portfolio piece.

---

## Phase 0 — Foundations

**Build:** repo structure, virtual environment, dependency management,
configuration via environment variables, `.gitignore`, Git repository.

**Learn:**
- What a virtual environment is and why every project gets its own
- `pyproject.toml` as the modern replacement for `requirements.txt`
- Why secrets live in `.env` and `.env` never enters Git
- The difference between `.env` (real, private) and `.env.example` (template, committed)
- Git basics: `init`, `add`, `commit`, `branch`, `push`

**Recruiter signal:** every backend role assumes this. Getting it wrong is a
silent rejection — a committed API key in your GitHub history is a real
disqualifier, and people do check.

---

## Phase 1 — Database and data

**Build:** the Postgres schema (`db/schema.sql`), the read-only role
(`db/readonly_role.sql`), and a seed script that generates realistic data.

**Learn:**
- `CREATE TABLE`, primary keys, foreign keys, `CHECK` constraints
- `JOIN`, `GROUP BY`, `HAVING`, aggregate functions, window functions
- Why indexes exist and when they help
- Database roles and the principle of least privilege
- Soft deletes, denormalisation, and why real schemas are messy

**Recruiter signal:** "Can you write SQL?" is asked in almost every data-adjacent
interview. You cannot build a text-to-SQL system without being better at SQL
than the model you are supervising.

---

## Phase 2 — LLM client layer

**Build:** a provider-agnostic client wrapping Groq, Gemini and OpenAI, with
automatic fallback, retries with backoff, timeouts, and token/cost accounting.

**Learn:**
- What an LLM API call actually is (an HTTP POST with a JSON body)
- System vs user messages, temperature, max tokens
- Structured output: making the model return validated JSON, not prose
- Pydantic models as the contract between your code and the model
- Retry strategy, exponential backoff, and why you need timeouts

**Recruiter signal:** this is the single most transferable skill for GenAI
roles. Anyone can call one API. Building a swappable abstraction with fallback
is what "production" means here.

---

## Phase 3 — The naive baseline

**Build:** the simplest possible text-to-SQL: dump the whole schema in a prompt,
ask for SQL, run it. Roughly forty lines. This is "tutorial AI".

**Learn:**
- Prompt construction and why schema context matters
- How and why this approach fails: wrong joins, hallucinated columns,
  silently wrong answers to ambiguous questions
- Why "it worked when I tried it" is not evidence

**Recruiter signal:** deliberately building the weak version, then measuring it,
is senior behaviour. It shows you think in baselines and deltas, not vibes.

---

## Phase 4 — Safety layer

**Build:** SQL parsing with `sqlglot`, statement-type allowlist, table and
column allowlist, mandatory `LIMIT` injection, query timeout, read-only
execution path.

**Learn:**
- Parsing SQL into an AST instead of matching strings with regex
- Prompt injection: what it is and why prompt-level defences are not enough
- Defence in depth, and which layer is the one that actually holds
- Fail-closed design

**Recruiter signal:** the most common follow-up question on this project is
"what stops it running `DROP TABLE`?" Having a real answer, with a test that
proves it, ends that line of questioning immediately.

---

## Phase 5 — The clarification engine

**Build:** ambiguity detection, structured clarification questions with concrete
options, conversation state across turns, resolution into an unambiguous intent,
and a bounded number of clarification rounds.

**Learn:**
- Classifying intent with structured output rather than free text
- Designing a multi-turn conversation with explicit state
- Calibration: when to ask versus when to proceed (asking too often is also a failure)
- Why a confidence score from a model is not a probability

**Recruiter signal:** this is the project's thesis. Most candidates build a RAG
or text-to-SQL demo that answers confidently and wrongly. Knowing *when the
system should refuse to answer yet* is the difference being tested for.

---

## Phase 6 — Retrieval accuracy

**Build:** schema linking (retrieve only relevant tables), dynamic few-shot
example selection, a business glossary / semantic layer, value hints for
categorical columns, and a bounded self-correction loop on execution errors.

**Learn:**
- Why you cannot just paste a 400-table schema into a prompt
- BM25 and lexical retrieval; embeddings and semantic retrieval; when each wins
- Few-shot prompting, and why retrieved examples beat fixed examples
- Defining business metrics once, in code, instead of hoping the model guesses

**Recruiter signal:** "how did you improve accuracy?" is the question. Each
technique here is a measurable increment you can quote with a number.

---

## Phase 7 — Evaluation harness

**Build:** a golden dataset of questions with reference SQL, execution-match
scoring, an ambiguous-question subset, and an A/B benchmark of the system with
and without the clarification engine.

**Learn:**
- Execution accuracy vs exact-match accuracy, and why the latter is misleading
- Building a labelled dataset by hand (yes, by hand — this is the work)
- Regression testing for non-deterministic systems
- Reporting results honestly, including where the system loses

**Recruiter signal:** this is the artifact that gets you hired. Almost nobody
evaluates their portfolio project. A results table with a real delta puts you in
a different category of candidate.

---

## Phase 8 — API and interface

**Build:** FastAPI service with session handling for the clarification dialogue,
plus a Streamlit UI that shows the question, any clarification, the generated
SQL, and the result.

**Learn:**
- REST design for a multi-turn interaction (this is not a simple request/response)
- Pydantic request/response models and automatic API documentation
- Server-side session state, and why the SQL must be visible to the user

**Recruiter signal:** turns a script into a product. Showing the generated SQL
is itself a trust-and-transparency design decision worth explaining.

---

## Phase 9 — Observability and cost

**Build:** structured logging, per-request trace IDs, latency and token
accounting, a cache for schema context and repeated questions, model routing by
question complexity.

**Learn:**
- Structured logs vs print statements
- Measuring p50/p95 latency instead of "it feels fast"
- Where LLM cost actually goes, and how caching changes the bill
- Routing cheap questions to cheap models

**Recruiter signal:** cost and latency awareness reads as production experience.
Most candidates have never thought about either.

---

## Phase 10 — Packaging and deployment

**Build:** Dockerfile, docker-compose for local Postgres, GitHub Actions running
lint and tests on every push, deployment to a free tier.

**Learn:**
- Containers, images, and why "works on my machine" stops being a sentence
- CI: automated checks as a gate, not a suggestion
- Managing configuration and secrets across environments

**Recruiter signal:** a green CI badge on the README is a small thing that
signals a large thing.

---

## Phase 11 — Documentation

**Build:** README with architecture diagram and results, architecture decision
records, a security document, and a demo recording.

**Learn:**
- Writing for a reader who has thirty seconds
- Architecture Decision Records: capturing *why*, not just *what*
- Diagramming a system so someone else can hold it in their head

**Recruiter signal:** a reviewer spends under a minute on your repo. The README
is the product. Most strong projects are lost to weak READMEs.

---

## Phase 12 — Interview preparation

**Build:** a written set of answers covering system design, trade-offs,
failures and fixes, plus the adversarial follow-ups an interviewer will use to
find the edge of your understanding.

**Learn:** how to narrate your own engineering decisions under pressure.

**Recruiter signal:** the project only pays off if you can defend it.

---

## Skills this project puts on your CV

| Area | Specifics |
|---|---|
| Language | Python 3.11+, type hints, async |
| Data | PostgreSQL, schema design, query optimisation, indexing |
| GenAI | LLM APIs, prompt engineering, structured output, multi-provider fallback |
| Validation | Pydantic, `sqlglot` AST parsing, allowlisting |
| Retrieval | Schema linking, BM25, embeddings, dynamic few-shot |
| Evaluation | Golden datasets, execution accuracy, A/B benchmarking |
| Backend | FastAPI, REST, session state |
| Security | Least privilege, prompt injection defence, defence in depth |
| Ops | Docker, GitHub Actions, structured logging, cost tracking |
