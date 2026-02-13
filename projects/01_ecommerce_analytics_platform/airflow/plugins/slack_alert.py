"""
Snowbrix E-Commerce Platform -- Slack Notification Helper for Airflow

Sends formatted Slack messages via incoming webhook for:
- Task success (green)
- Task failure (red)
- SLA breaches (orange)

Usage in DAGs:
    from plugins.slack_alert import send_slack_alert, slack_failure_alert

    # As on_failure_callback:
    default_args = {
        "on_failure_callback": slack_failure_alert,
    }

    # As a task:
    PythonOperator(
        task_id="notify_success",
        python_callable=send_slack_alert,
        op_kwargs={"status": "success"},
    )
"""

import json
import logging
import os
from datetime import datetime, timezone
from typing import Any, Dict, Optional

import requests

logger = logging.getLogger(__name__)

# ──────────────────────────────────────────────
# CONSTANTS
# ──────────────────────────────────────────────

# Slack attachment colors (hex)
COLOR_SUCCESS = "#36a64f"   # Green
COLOR_FAILURE = "#ff0000"   # Red
COLOR_SLA_BREACH = "#ff9900"  # Orange

# Status display labels
STATUS_LABELS = {
    "success": "SUCCESS",
    "failure": "FAILURE",
    "sla_breach": "SLA BREACH",
}

# Status emoji (Slack shortcodes)
STATUS_ICONS = {
    "success": ":white_check_mark:",
    "failure": ":x:",
    "sla_breach": ":warning:",
}

# Color mapping
STATUS_COLORS = {
    "success": COLOR_SUCCESS,
    "failure": COLOR_FAILURE,
    "sla_breach": COLOR_SLA_BREACH,
}

# Base URL for Airflow UI (used to build log links).
# In production, set AIRFLOW_BASE_URL env var to your domain.
AIRFLOW_BASE_URL = os.getenv("AIRFLOW_BASE_URL", "http://localhost:8080")


# ──────────────────────────────────────────────
# CORE FUNCTION
# ──────────────────────────────────────────────

def send_slack_alert(context: Optional[Dict[str, Any]] = None, status: str = "success", **kwargs) -> None:
    """
    Send a formatted Slack notification about a DAG task.

    This function works both as a PythonOperator callable (with context
    passed via op_kwargs or provide_context) and as an Airflow callback
    (where context is the first argument).

    Args:
        context: Airflow context dictionary containing task_instance,
                 dag_run, execution_date, etc. When called as a
                 PythonOperator with provide_context=True, this is
                 automatically populated.
        status:  One of "success", "failure", "sla_breach".
        **kwargs: Additional keyword arguments (ignored, for compatibility
                  with Airflow's callback signature).

    Returns:
        None. Logs the result of the Slack API call.

    Raises:
        Does NOT raise exceptions. Slack notification failures are logged
        but never crash the DAG. A failed alert should not cause a
        pipeline failure.
    """
    # ── Resolve webhook URL ──
    webhook_url = os.getenv("SLACK_WEBHOOK_URL")

    if not webhook_url:
        logger.warning(
            "SLACK_WEBHOOK_URL not set. Skipping Slack notification. "
            "Set this environment variable in your .env file to enable alerts."
        )
        return

    # ── Extract task details from Airflow context ──
    try:
        # When called as a callback, context is the first positional arg.
        # When called as a PythonOperator, context may be in kwargs.
        if context is None:
            context = kwargs

        task_instance = context.get("task_instance") or context.get("ti")
        dag_run = context.get("dag_run")
        exception = context.get("exception")

        # Extract identifiers with safe defaults
        dag_id = getattr(task_instance, "dag_id", "unknown_dag") if task_instance else "unknown_dag"
        task_id = getattr(task_instance, "task_id", "unknown_task") if task_instance else "unknown_task"
        execution_date = context.get("execution_date") or context.get("logical_date")
        run_id = getattr(dag_run, "run_id", "N/A") if dag_run else "N/A"

        # Calculate duration
        duration_str = _calculate_duration(task_instance)

        # Build log link
        log_url = _build_log_url(dag_id, task_id, execution_date, task_instance)

        # Format execution date for display
        exec_date_str = _format_execution_date(execution_date)

    except Exception as extract_err:
        # If we cannot parse context, send a degraded alert rather than nothing
        logger.error("Failed to extract context for Slack alert: %s", extract_err)
        dag_id = "unknown_dag"
        task_id = "unknown_task"
        exec_date_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
        duration_str = "N/A"
        log_url = AIRFLOW_BASE_URL
        exception = None
        run_id = "N/A"

    # ── Build Slack message payload ──
    label = STATUS_LABELS.get(status, status.upper())
    icon = STATUS_ICONS.get(status, ":question:")
    color = STATUS_COLORS.get(status, "#808080")

    # Header text
    header = f"{icon} *[{label}]* `{dag_id}`"

    # Fields for the attachment
    fields = [
        {"title": "Task", "value": f"`{task_id}`", "short": True},
        {"title": "Execution Date", "value": exec_date_str, "short": True},
        {"title": "Duration", "value": duration_str, "short": True},
        {"title": "Run ID", "value": run_id, "short": True},
    ]

    # Add exception details for failures
    if status == "failure" and exception:
        # Truncate long exception messages to avoid Slack's 3000-char limit
        exception_text = str(exception)[:500]
        fields.append({
            "title": "Exception",
            "value": f"```{exception_text}```",
            "short": False,
        })

    # Add log link
    fields.append({
        "title": "Log",
        "value": f"<{log_url}|View Task Log>",
        "short": False,
    })

    # Compose the Slack payload using attachments for color-coding
    payload = {
        "text": header,
        "attachments": [
            {
                "color": color,
                "fields": fields,
                "footer": "Snowbrix E-Commerce Pipeline",
                "footer_icon": "https://platform.slack-edge.com/img/default_application_icon.png",
                "ts": int(datetime.now(timezone.utc).timestamp()),
            }
        ],
    }

    # ── Send to Slack ──
    try:
        response = requests.post(
            webhook_url,
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"},
            timeout=10,
        )

        if response.status_code == 200 and response.text == "ok":
            logger.info(
                "Slack alert sent successfully: [%s] %s / %s",
                label, dag_id, task_id,
            )
        else:
            logger.error(
                "Slack webhook returned unexpected response: status=%d, body=%s",
                response.status_code, response.text[:200],
            )

    except requests.exceptions.Timeout:
        logger.error("Slack webhook timed out after 10 seconds. Alert not sent.")
    except requests.exceptions.ConnectionError:
        logger.error("Could not connect to Slack webhook URL. Alert not sent.")
    except Exception as send_err:
        logger.error("Unexpected error sending Slack alert: %s", send_err)


# ──────────────────────────────────────────────
# CONVENIENCE CALLBACKS
# ──────────────────────────────────────────────

def slack_failure_alert(context: Dict[str, Any]) -> None:
    """
    Airflow on_failure_callback that sends a red Slack alert.

    Usage:
        default_args = {
            "on_failure_callback": slack_failure_alert,
        }
    """
    send_slack_alert(context=context, status="failure")


def slack_success_alert(context: Dict[str, Any]) -> None:
    """
    Airflow on_success_callback that sends a green Slack alert.

    Usage:
        default_args = {
            "on_success_callback": slack_success_alert,
        }
    """
    send_slack_alert(context=context, status="success")


def slack_sla_alert(dag, task_list, blocking_task_list, slas, blocking_tis) -> None:
    """
    Airflow sla_miss_callback that sends an orange Slack alert.

    Note: The sla_miss_callback has a different signature than
    on_failure_callback. It receives the DAG object and lists of
    tasks/SLAs that were breached.

    Args:
        dag:                The DAG object.
        task_list:          List of tasks that missed their SLA.
        blocking_task_list: List of tasks blocking SLA-missed tasks.
        slas:               List of SLA objects.
        blocking_tis:       List of blocking task instances.
    """
    webhook_url = os.getenv("SLACK_WEBHOOK_URL")

    if not webhook_url:
        logger.warning("SLACK_WEBHOOK_URL not set. Skipping SLA breach alert.")
        return

    dag_id = dag.dag_id if dag else "unknown_dag"

    # Format the list of tasks that breached SLA
    breached_tasks = ", ".join(
        [str(t) for t in task_list]
    ) if task_list else "N/A"

    blocking_tasks = ", ".join(
        [str(t) for t in blocking_task_list]
    ) if blocking_task_list else "None"

    header = f":warning: *[SLA BREACH]* `{dag_id}`"

    payload = {
        "text": header,
        "attachments": [
            {
                "color": COLOR_SLA_BREACH,
                "fields": [
                    {
                        "title": "Breached Tasks",
                        "value": f"`{breached_tasks}`",
                        "short": False,
                    },
                    {
                        "title": "Blocking Tasks",
                        "value": f"`{blocking_tasks}`",
                        "short": False,
                    },
                    {
                        "title": "Action Required",
                        "value": (
                            "The pipeline is taking longer than expected. "
                            "Check Airflow UI for task durations and Snowflake "
                            "query history for slow queries."
                        ),
                        "short": False,
                    },
                ],
                "footer": "Snowbrix E-Commerce Pipeline",
                "ts": int(datetime.now(timezone.utc).timestamp()),
            }
        ],
    }

    try:
        response = requests.post(
            webhook_url,
            data=json.dumps(payload),
            headers={"Content-Type": "application/json"},
            timeout=10,
        )
        if response.status_code == 200:
            logger.info("SLA breach alert sent for DAG: %s", dag_id)
        else:
            logger.error(
                "SLA breach alert failed: status=%d, body=%s",
                response.status_code, response.text[:200],
            )
    except Exception as err:
        logger.error("Failed to send SLA breach alert: %s", err)


# ──────────────────────────────────────────────
# HELPER FUNCTIONS
# ──────────────────────────────────────────────

def _calculate_duration(task_instance) -> str:
    """
    Calculate human-readable task duration from the task instance.

    Args:
        task_instance: Airflow TaskInstance object.

    Returns:
        Duration string like "12m 34s" or "N/A" if unavailable.
    """
    if not task_instance:
        return "N/A"

    try:
        # task_instance.duration is available after the task finishes
        duration_seconds = getattr(task_instance, "duration", None)

        if duration_seconds is not None:
            minutes, seconds = divmod(int(duration_seconds), 60)
            hours, minutes = divmod(minutes, 60)

            if hours > 0:
                return f"{hours}h {minutes}m {seconds}s"
            elif minutes > 0:
                return f"{minutes}m {seconds}s"
            else:
                return f"{seconds}s"

        # Fallback: calculate from start_date to now
        start_date = getattr(task_instance, "start_date", None)
        if start_date:
            now = datetime.now(timezone.utc)
            # Ensure start_date is timezone-aware
            if start_date.tzinfo is None:
                start_date = start_date.replace(tzinfo=timezone.utc)
            delta = now - start_date
            total_seconds = int(delta.total_seconds())
            minutes, seconds = divmod(total_seconds, 60)
            return f"{minutes}m {seconds}s"

    except Exception as err:
        logger.debug("Could not calculate duration: %s", err)

    return "N/A"


def _build_log_url(dag_id: str, task_id: str, execution_date, task_instance) -> str:
    """
    Build a direct URL to the task log in the Airflow UI.

    Args:
        dag_id:         DAG identifier.
        task_id:        Task identifier.
        execution_date: Execution date (datetime or string).
        task_instance:  Airflow TaskInstance (for try_number).

    Returns:
        URL string pointing to the Airflow task log page.
    """
    try:
        # Format execution date for URL
        if hasattr(execution_date, "isoformat"):
            exec_date_param = execution_date.isoformat()
        else:
            exec_date_param = str(execution_date)

        try_number = getattr(task_instance, "try_number", 1)

        return (
            f"{AIRFLOW_BASE_URL}/dags/{dag_id}/grid?"
            f"task_id={task_id}&"
            f"execution_date={exec_date_param}&"
            f"try_number={try_number}"
        )

    except Exception:
        return f"{AIRFLOW_BASE_URL}/dags/{dag_id}/grid"


def _format_execution_date(execution_date) -> str:
    """
    Format the execution date for human-readable display.

    Args:
        execution_date: datetime object, string, or None.

    Returns:
        Formatted date string like "2024-01-15 06:00:00 UTC".
    """
    if execution_date is None:
        return "N/A"

    try:
        if hasattr(execution_date, "strftime"):
            return execution_date.strftime("%Y-%m-%d %H:%M:%S UTC")
        return str(execution_date)
    except Exception:
        return str(execution_date)
