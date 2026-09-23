"""Tests for configuration loading.

Note what is being tested: not that pydantic works (that is their job), but
that OUR rules hold - validation rejects bad values, and provider selection
only returns providers that actually have a key.
"""

import pytest

from text2sql.config import Settings


def test_log_level_is_normalised_to_upper() -> None:
    settings = Settings(log_level="debug")
    assert settings.log_level == "DEBUG"


def test_invalid_log_level_is_rejected() -> None:
    with pytest.raises(ValueError, match="log_level must be one of"):
        Settings(log_level="chatty")


def test_configured_providers_only_returns_providers_with_keys() -> None:
    settings = Settings(
        groq_api_key="gsk_fake",
        gemini_api_key="",
        openai_api_key="sk_fake",
        llm_provider_order="gemini,openai,groq",
    )
    # gemini has no key so it is skipped; order of the rest is preserved
    assert settings.configured_providers() == ["openai", "groq"]


def test_row_limit_bounds_are_enforced() -> None:
    with pytest.raises(ValueError):
        Settings(max_result_rows=0)
    with pytest.raises(ValueError):
        Settings(max_result_rows=999_999)
