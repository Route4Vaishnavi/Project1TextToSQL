"""Application configuration.

WHY THIS FILE EXISTS
--------------------
Every setting that changes between your laptop and a deployed server lives
here, and nowhere else. Database URLs, API keys, limits. The rest of the code
imports ``settings`` and never reads an environment variable directly.

Three rules this file enforces, and the reason for each:

1. Secrets come from the environment, never from source code.
   A hard-coded API key ends up in Git history. Git history is forever, and
   scrapers watch public repositories for exactly this. Rotating a leaked key
   is the *good* outcome; the bad one is a bill.

2. Configuration is validated at startup, not at first use.
   ``pydantic-settings`` checks types and required fields the moment the
   process boots. A missing DATABASE_URL should crash the app immediately with
   a clear message, not three minutes later, mid-request, with a confusing
   AttributeError.

3. There is exactly one source of truth.
   Reading ``os.environ`` scattered across twenty files is how you end up with
   a setting that is read in two places with two different default values.
"""

from __future__ import annotations

from functools import lru_cache
from typing import Literal

from pydantic import Field, SecretStr, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

Provider = Literal["groq", "gemini", "openai"]


class Settings(BaseSettings):
    """Typed application settings, loaded from the environment and `.env`."""

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # -- Database ----------------------------------------------------------
    # Two URLs on purpose. The read-write one is used only by migrations and
    # the seed script. Everything the model can influence goes through the
    # read-only one. See db/readonly_role.sql for the reasoning.
    database_url: str = Field(
        default="",
        description="Read-write connection string. Migrations and seeding only.",
    )
    database_url_readonly: str = Field(
        default="",
        description="Read-only connection string used for all generated SQL.",
    )

    # -- LLM providers -----------------------------------------------------
    # SecretStr keeps the value out of logs and tracebacks. Printing a
    # SecretStr shows '**********' rather than the key itself. This is a small
    # thing that prevents a very embarrassing class of incident.
    groq_api_key: SecretStr = SecretStr("")
    gemini_api_key: SecretStr = SecretStr("")
    openai_api_key: SecretStr = SecretStr("")

    llm_provider_order: str = Field(
        default="groq,gemini,openai",
        description="Comma-separated preference order. First configured provider wins.",
    )

    # -- Application -------------------------------------------------------
    app_env: Literal["development", "production", "test"] = "development"
    log_level: str = "INFO"

    # Hard limits. These are enforced in code before any query reaches the
    # database - they are not suggestions made to the model in a prompt.
    max_result_rows: int = Field(default=500, ge=1, le=10_000)
    query_timeout_seconds: int = Field(default=10, ge=1, le=60)

    # How many times the system may ask the user for clarification before it
    # gives up and answers with its best guess (clearly labelled as a guess).
    # Without a cap, a badly calibrated detector can loop forever and the user
    # abandons the product.
    max_clarification_rounds: int = Field(default=2, ge=0, le=5)

    @field_validator("log_level")
    @classmethod
    def _validate_log_level(cls, v: str) -> str:
        allowed = {"DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL"}
        upper = v.upper()
        if upper not in allowed:
            raise ValueError(f"log_level must be one of {sorted(allowed)}, got {v!r}")
        return upper

    @property
    def provider_order(self) -> list[Provider]:
        """Provider preference as a clean list."""
        raw = [p.strip().lower() for p in self.llm_provider_order.split(",")]
        return [p for p in raw if p in {"groq", "gemini", "openai"}]  # type: ignore[misc]

    def configured_providers(self) -> list[Provider]:
        """Providers that actually have a key set, in preference order.

        Used by the LLM client to decide what to try. Returning an empty list
        here is a startup error, surfaced in main() rather than at request time.
        """
        keys: dict[str, SecretStr] = {
            "groq": self.groq_api_key,
            "gemini": self.gemini_api_key,
            "openai": self.openai_api_key,
        }
        return [p for p in self.provider_order if keys[p].get_secret_value()]


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    """Return the singleton settings object.

    ``lru_cache`` means the `.env` file is parsed once per process rather than
    on every call. It also gives tests a seam: call
    ``get_settings.cache_clear()`` to force a reload with patched environment
    variables.
    """
    return Settings()
