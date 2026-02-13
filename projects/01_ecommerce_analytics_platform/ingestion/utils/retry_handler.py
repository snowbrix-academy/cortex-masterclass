"""
Snowbrix E-Commerce Platform — Retry Handler with Exponential Backoff

Handles transient failures in:
- API calls (Stripe rate limits: HTTP 429)
- Database connections (Postgres/Snowflake timeouts)
- File operations (network stage uploads)
"""

import logging
import functools
import time

from tenacity import (
    retry,
    stop_after_attempt,
    wait_exponential,
    retry_if_exception_type,
    before_sleep_log,
)

logger = logging.getLogger(__name__)


# Exception types that should trigger a retry
RETRYABLE_EXCEPTIONS = (
    ConnectionError,
    TimeoutError,
    OSError,
)


def with_retry(max_attempts=3, min_wait=1, max_wait=60):
    """
    Decorator for retryable operations with exponential backoff.

    Args:
        max_attempts: Maximum number of attempts before giving up.
        min_wait: Minimum wait time in seconds between retries.
        max_wait: Maximum wait time in seconds between retries.

    Usage:
        @with_retry(max_attempts=5, min_wait=2)
        def call_stripe_api():
            ...
    """
    return retry(
        stop=stop_after_attempt(max_attempts),
        wait=wait_exponential(multiplier=1, min=min_wait, max=max_wait),
        retry=retry_if_exception_type(RETRYABLE_EXCEPTIONS),
        before_sleep=before_sleep_log(logger, logging.WARNING),
        reraise=True,
    )


def retry_on_rate_limit(max_attempts=5, base_wait=2):
    """
    Decorator specifically for API rate-limit handling (HTTP 429).
    Uses the Retry-After header when available.

    Usage:
        @retry_on_rate_limit()
        def fetch_stripe_charges():
            ...
    """

    def decorator(func):
        @functools.wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(1, max_attempts + 1):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    # Check for HTTP 429 (rate limit) in the exception
                    status_code = getattr(e, "http_status", None) or getattr(
                        e, "status_code", None
                    )
                    if status_code == 429:
                        # Use Retry-After header if available
                        retry_after = getattr(e, "headers", {}).get("Retry-After")
                        if retry_after:
                            wait_time = int(retry_after)
                        else:
                            wait_time = base_wait * (2 ** (attempt - 1))

                        logger.warning(
                            "Rate limited (429). Attempt %d/%d. Waiting %ds...",
                            attempt,
                            max_attempts,
                            wait_time,
                        )
                        time.sleep(wait_time)
                    elif attempt == max_attempts:
                        raise
                    else:
                        wait_time = base_wait * (2 ** (attempt - 1))
                        logger.warning(
                            "Error: %s. Attempt %d/%d. Waiting %ds...",
                            str(e),
                            attempt,
                            max_attempts,
                            wait_time,
                        )
                        time.sleep(wait_time)

        return wrapper

    return decorator
