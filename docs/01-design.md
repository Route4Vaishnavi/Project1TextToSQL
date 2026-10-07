# Design Document: Text-to-SQL with Clarification Engine

## 1. Problem
Business users get answers from data in two ways today, and both have problems:

- **Analysts write SQL by hand.** The answers are correct, but slow, because every question waits in an analyst's queue.
- **Basic AI tools (like ChatGPT) generate SQL directly.** They are fast, but they answer ambiguous questions confidently and wrongly.

For example, "Show me last month's best customer" has no single meaning. "Best" could mean highest revenue, most orders, or most repeat visits, and each gives a different person. A basic system silently picks one.

A wrong number given confidently is dangerous for an organisation's decisions. It is worse than no number at all. This project adds a **clarification engine**: when a question is ambiguous, and only then, the system asks the user what they meant before generating SQL. For example: "By 'best', do you mean (a) highest revenue, (b) most orders, or (c) most repeat visits?" It also adds **safety checks** so the generated SQL can never change or delete data.

## 2. Users
Managers, finance and sales teams. They can't write SQL themselves, because it is a technical language different from the work they do. They want answers that are **fast** and that they can **trust**.

## 3. Solution overview
```
Question
  → Find relevant tables
  → Check for ambiguity ──(ambiguous)──→ Ask the user, with options → User picks one
  → Generate SQL
  → Validate SQL (safety check)
  → User approves the SQL (optional)
  → Run on the database (read-only)
  → Answer explained in plain English
```
**What makes it different:** it asks only when a question is unclear, it always shows the SQL it ran, and it can never modify data.

## 4. Components
- **Frontend (Streamlit):** the screen where users type questions, answer clarifications, see the SQL and see results.
- **Backend (FastAPI):** coordinates every step in order and remembers the conversation, so follow-up questions work.
- **LLM layer (Groq, Gemini):** sends requests to the AI. If one provider fails or hits its limit, it automatically switches to the other.
- **Retrieval:** finds only the tables relevant to the question, so the AI gets less to read and makes fewer mistakes.
- **Clarification engine:** decides whether a question is clear or ambiguous. If it is ambiguous, it creates a question with concrete options.
- **SQL generator:** turns the clarified question into a SQL query, using the relevant tables and example queries.
- **SQL validator (safety guard):** allows only `SELECT` queries, blocks `UPDATE`/`DELETE`/`DROP`/`TRUNCATE`, allows only approved tables and adds a row `LIMIT`.
- **Human approval:** shows the SQL and its plain-English meaning, and the user approves it before it runs.
- **Database (PostgreSQL on Neon):** stores the company data. The app connects as a **read-only user**, so even a bad query cannot change data.
- **Explainer:** explains the SQL and the result in plain English.
- **Observability:** logs every request with its timing, AI usage and accuracy statistics, which feed the evaluation dashboard.
- **Security:** login, user roles, rate limits and protection of personal data.

## 5. Data flow and privacy
- **Sent to the AI:** the user's question and the table structure (table and column names only).
- **Never sent to the AI:** full query results or customer personal data. At most, a small summary is sent so the result can be explained.
- **Data source:** only synthetic (fake) data generated for this project. No real company data is ever used.
- **API keys:** stored in the `.env` file locally and in the hosting platform's "Secrets" settings online. They are never in the code and never on GitHub.

## 6. Key decisions
1. **PostgreSQL.** We chose it because it is free, an industry standard and strong for analytics (window functions, CTEs). The alternative was MySQL, but its analytics features are weaker.
2. **FastAPI.** We chose it because it is fast, modern and creates API documentation automatically. The alternative was Django, but it is heavy and built for full websites rather than APIs.
3. **Groq and Gemini.** We chose them because both have free tiers, and two providers give a fallback when one is down. The alternative was OpenAI, but it costs money (it is supported but switched off).
4. **Streamlit.** We chose it because it is pure Python, so a working screen takes hours, not weeks. The alternative was React, but it needs JavaScript and pulls focus away from the AI skills.
5. **A read-only database user.** We chose it because the database itself refuses to change data, even if every other check fails. The alternative was trusting the validator alone, but then a single bug could cause data loss.

## 7. Out of scope (for now)
- Multiple databases (only PostgreSQL)
- Voice input
- A React frontend
- Fine-tuning our own AI model
- Charts and graphs for query results
