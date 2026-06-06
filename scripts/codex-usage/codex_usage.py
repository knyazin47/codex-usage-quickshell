#!/usr/bin/env python3
"""Collect Codex Desktop token usage from local session JSONL logs.

The script is intentionally dependency-free so the Quickshell module can be
published or copied without a Python environment setup step.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import pathlib
import selectors
import shutil
import subprocess
import sys
import time
from collections import defaultdict
from dataclasses import dataclass
from typing import Any


HOME = pathlib.Path.home()
DEFAULT_SESSION_DIRS = (
    HOME / ".codex" / "sessions",
)
ARCHIVED_SESSION_DIR = HOME / ".codex" / "archived_sessions"
DEFAULT_DAYS_BACK = 8
MAX_DAYS_BACK = 30
INCLUDE_WORKSPACE = os.environ.get("CODEX_USAGE_INCLUDE_WORKSPACE") == "1"
INCLUDE_ARCHIVED = os.environ.get("CODEX_USAGE_INCLUDE_ARCHIVED") == "1"
LIVE_LIMITS_ENABLED = os.environ.get("CODEX_USAGE_LIVE_LIMITS", "1") != "0"
LIVE_LIMITS_TIMEOUT_SECONDS = 3.0
LIVE_LIMITS_CACHE_SECONDS_DEFAULT = 5
LIVE_LIMITS_STALE_SECONDS_DEFAULT = 600
XDG_CACHE_HOME = pathlib.Path(os.environ.get("XDG_CACHE_HOME") or HOME / ".cache")
LIVE_LIMITS_CACHE_PATH = XDG_CACHE_HOME / "codex-usage-quickshell" / "rate_limits.json"


@dataclass
class UsageEvent:
    timestamp: dt.datetime
    tokens: int
    input_tokens: int
    cached_input_tokens: int
    output_tokens: int
    reasoning_output_tokens: int
    model_context_window: int
    cwd: str
    rate_limits: dict[str, Any]


@dataclass
class RateLimitResult:
    snapshots: list[dict[str, Any]]
    source: str
    synced_at: dt.datetime | None
    error: str = ""


def parse_timestamp(value: str | None) -> dt.datetime | None:
    if not value:
        return None
    try:
        if value.endswith("Z"):
            value = value[:-1] + "+00:00"
        parsed = dt.datetime.fromisoformat(value)
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=dt.timezone.utc)
        return parsed.astimezone()
    except ValueError:
        return None


def short_workspace(cwd: str) -> str:
    if not cwd:
        return "unknown"
    home = str(HOME)
    if cwd == home:
        return "~"
    if cwd == "/home":
        return "/home"
    if cwd.startswith(home + "/"):
        rel = cwd[len(home) + 1 :]
        parts = [part for part in rel.split("/") if part]
        if not parts:
            return "~"
        if parts[0] in {"Documents", "Downloads", "src", "Проекты"} and len(parts) > 1:
            return parts[-1]
        return parts[0] if len(parts) == 1 else parts[-1]
    return pathlib.Path(cwd).name or cwd


def format_tokens(tokens: int) -> str:
    if tokens >= 1_000_000:
        return f"{tokens / 1_000_000:.1f}M"
    if tokens >= 10_000:
        return f"{round(tokens / 1000):.0f}K"
    if tokens >= 1_000:
        return f"{tokens / 1000:.1f}K"
    return str(tokens)


def safe_int(value: Any, default: int = 0) -> int:
    try:
        return int(value or default)
    except (TypeError, ValueError):
        return default


def safe_float(value: Any, default: float = 0.0) -> float:
    try:
        return float(value or default)
    except (TypeError, ValueError):
        return default


def env_int(name: str, default: int, minimum: int, maximum: int) -> int:
    value = safe_int(os.environ.get(name), default)
    return max(minimum, min(maximum, value))


def live_cache_seconds() -> int:
    return env_int("CODEX_USAGE_LIVE_CACHE_SECONDS", LIVE_LIMITS_CACHE_SECONDS_DEFAULT, 5, 3600)


def live_stale_seconds() -> int:
    return env_int("CODEX_USAGE_LIVE_STALE_SECONDS", LIVE_LIMITS_STALE_SECONDS_DEFAULT, 0, 86400)


def add_rate_limit_error(result: RateLimitResult, error: str) -> RateLimitResult:
    result.error = error
    return result


def codex_search_path() -> list[pathlib.Path]:
    return [
        HOME / ".local" / "bin" / "codex",
        HOME / ".cargo" / "bin" / "codex",
        HOME / ".bun" / "bin" / "codex",
        HOME / ".npm-global" / "bin" / "codex",
        pathlib.Path("/usr/local/bin/codex"),
        pathlib.Path("/usr/bin/codex"),
    ]


def find_codex_binary() -> str | None:
    configured = os.environ.get("CODEX_USAGE_CODEX_PATH")
    if configured:
        path = pathlib.Path(configured).expanduser()
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)

    found = shutil.which("codex")
    if found:
        return found

    # Quickshell can be launched by the desktop session with a minimal PATH.
    # Check the usual user install locations explicitly so live limits still
    # work after reboot even when an interactive shell would find `codex`.
    for path in codex_search_path():
        if path.is_file() and os.access(path, os.X_OK):
            return str(path)
    return None


def codex_subprocess_env() -> dict[str, str]:
    env = os.environ.copy()
    extra_paths = [str(path.parent) for path in codex_search_path()]
    env["PATH"] = os.pathsep.join(extra_paths + [env.get("PATH", "")])
    return env


def read_live_limits_cache(now: dt.datetime, max_age_seconds: int) -> RateLimitResult:
    # Fresh cache keeps fast UI refreshes cheap. Stale cache is used only as a
    # softer fallback when the live endpoint is unavailable for a short while.
    try:
        cache = json.loads(LIVE_LIMITS_CACHE_PATH.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return RateLimitResult([], "local", None)

    synced_at = parse_timestamp(cache.get("syncedAt"))
    snapshots = cache.get("rateLimits") or []
    if synced_at is None or not isinstance(snapshots, list):
        return RateLimitResult([], "local", None)
    snapshots = [snapshot for snapshot in snapshots if isinstance(snapshot, dict)]
    if not snapshots:
        return RateLimitResult([], "local", synced_at)

    age_seconds = max(0, int((now - synced_at).total_seconds()))
    if age_seconds <= max_age_seconds:
        source = "cache" if age_seconds <= live_cache_seconds() else "stale"
        return RateLimitResult(
            snapshots,
            source,
            synced_at,
        )
    return RateLimitResult([], "local", synced_at)


def write_live_limits_cache(snapshots: list[dict[str, Any]], synced_at: dt.datetime) -> None:
    try:
        # Cache writes are best-effort: a read-only cache directory should not
        # make the Quickshell widget fail or hide local usage data.
        LIVE_LIMITS_CACHE_PATH.parent.mkdir(parents=True, exist_ok=True)
        LIVE_LIMITS_CACHE_PATH.write_text(
            json.dumps(
                {
                    "syncedAt": synced_at.isoformat(timespec="seconds"),
                    "rateLimits": snapshots,
                },
                ensure_ascii=False,
                separators=(",", ":"),
            ),
            encoding="utf-8",
        )
    except OSError:
        return


def normalize_live_window(window: dict[str, Any] | None) -> dict[str, Any]:
    window = window or {}
    return {
        "used_percent": safe_float(window.get("usedPercent")),
        "window_minutes": safe_int(window.get("windowDurationMins")),
        "resets_at": safe_int(window.get("resetsAt")) or None,
    }


def normalize_live_snapshot(snapshot: dict[str, Any]) -> dict[str, Any]:
    credits = snapshot.get("credits") or {}
    return {
        "limit_id": snapshot.get("limitId") or "codex",
        "limit_name": snapshot.get("limitName"),
        "primary": normalize_live_window(snapshot.get("primary")),
        "secondary": normalize_live_window(snapshot.get("secondary")),
        "credits": {
            "has_credits": bool(credits.get("hasCredits")),
            "unlimited": bool(credits.get("unlimited")),
            "balance": credits.get("balance"),
        },
        "plan_type": snapshot.get("planType") or "",
        "rate_limit_reached_type": snapshot.get("rateLimitReachedType"),
    }


def fetch_live_rate_limits(
    timeout_seconds: float = LIVE_LIMITS_TIMEOUT_SECONDS,
    force_refresh: bool = False,
) -> RateLimitResult:
    """Read the same live account rate-limit snapshot that Codex Desktop uses."""
    now = dt.datetime.now().astimezone()
    if not LIVE_LIMITS_ENABLED:
        return RateLimitResult([], "local", None)

    # The panel may refresh every five seconds; the account snapshot does not
    # need to start a Codex app-server process every time.
    if not force_refresh:
        cached = read_live_limits_cache(now, live_cache_seconds())
        if cached.snapshots:
            return cached

    codex = find_codex_binary()
    if not codex:
        return add_rate_limit_error(
            read_live_limits_cache(now, live_stale_seconds()),
            "codex binary not found",
        )

    proc: subprocess.Popen[str] | None = None
    selector: selectors.BaseSelector | None = None
    try:
        proc = subprocess.Popen(
            [codex, "app-server", "--stdio"],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
            text=True,
            env=codex_subprocess_env(),
        )
        if proc.stdin is None or proc.stdout is None:
            return read_live_limits_cache(now, live_stale_seconds())

        requests = (
            {
                "id": 1,
                "method": "initialize",
                "params": {
                    "clientInfo": {"name": "codex-usage-quickshell", "version": "1"},
                    "capabilities": {},
                },
            },
            {"id": 2, "method": "account/rateLimits/read"},
        )
        for request in requests:
            proc.stdin.write(json.dumps(request, separators=(",", ":")) + "\n")
        proc.stdin.flush()

        selector = selectors.DefaultSelector()
        selector.register(proc.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + timeout_seconds

        while time.monotonic() < deadline:
            ready = selector.select(max(0.0, deadline - time.monotonic()))
            if not ready:
                break
            line = proc.stdout.readline()
            if not line:
                break
            try:
                message = json.loads(line)
            except json.JSONDecodeError:
                continue
            if message.get("id") != 2:
                continue
            result = message.get("result") or {}
            by_id = result.get("rateLimitsByLimitId") or {}
            # Newer Codex builds expose a multi-limit map. Older builds expose
            # one historical snapshot, so support both shapes.
            snapshots = list(by_id.values()) if by_id else [result.get("rateLimits")]
            normalized = [normalize_live_snapshot(snapshot) for snapshot in snapshots if isinstance(snapshot, dict)]
            if not normalized:
                return add_rate_limit_error(
                    read_live_limits_cache(now, live_stale_seconds()),
                    "codex app-server returned empty live limits",
                )
            synced_at = dt.datetime.now().astimezone()
            write_live_limits_cache(normalized, synced_at)
            return RateLimitResult(normalized, "live", synced_at)
    except (OSError, subprocess.SubprocessError) as exc:
        return add_rate_limit_error(read_live_limits_cache(now, live_stale_seconds()), str(exc))
    finally:
        if selector is not None:
            selector.close()
        if proc is not None and proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=0.5)
            except subprocess.TimeoutExpired:
                proc.kill()
    return add_rate_limit_error(
        read_live_limits_cache(now, live_stale_seconds()),
        "codex app-server returned no live limits",
    )


def format_reset(epoch: int | None, now: dt.datetime) -> str:
    if not epoch:
        return "--"
    reset_at = dt.datetime.fromtimestamp(epoch, tz=dt.timezone.utc).astimezone()
    seconds = max(0, int((reset_at - now).total_seconds()))
    if seconds <= 0:
        return "now"
    minutes = seconds // 60
    if minutes < 90:
        return f"{max(1, minutes)}m"
    hours = minutes // 60
    if hours < 48:
        return f"{hours}h"
    return f"{hours // 24}d"


def iter_recent_session_files(days_back: int) -> list[pathlib.Path]:
    cutoff = dt.datetime.now().timestamp() - days_back * 86400
    files: list[tuple[float, pathlib.Path]] = []
    session_dirs = list(DEFAULT_SESSION_DIRS)
    if INCLUDE_ARCHIVED:
        session_dirs.append(ARCHIVED_SESSION_DIR)

    for session_dir in session_dirs:
        if not session_dir.exists():
            continue
        for path in session_dir.rglob("*.jsonl"):
            try:
                modified = path.stat().st_mtime
                if modified >= cutoff:
                    files.append((modified, path))
            except OSError:
                continue
    return [path for _, path in sorted(files, key=lambda item: item[0])]


def usage_from_payload(payload: dict[str, Any]) -> tuple[int, int, int, int, int, int]:
    info = payload.get("info") or {}
    last = info.get("last_token_usage") or {}
    total = safe_int(last.get("total_tokens"))
    input_tokens = safe_int(last.get("input_tokens"))
    cached_input_tokens = safe_int(last.get("cached_input_tokens"))
    output_tokens = safe_int(last.get("output_tokens"))
    reasoning_output_tokens = safe_int(last.get("reasoning_output_tokens"))
    model_context_window = safe_int(info.get("model_context_window"))
    if total <= 0:
        output = payload.get("output") or ""
        if "last_token_usage" not in output:
            return 0, 0, 0, 0, 0, 0
        return 0, 0, 0, 0, 0, 0
    return total, input_tokens, cached_input_tokens, output_tokens, reasoning_output_tokens, model_context_window


def read_events(days_back: int) -> list[UsageEvent]:
    events: list[UsageEvent] = []
    for path in iter_recent_session_files(days_back):
        cwd = ""
        try:
            lines = path.open("r", encoding="utf-8", errors="replace")
        except OSError:
            continue

        with lines:
            for line in lines:
                if not line or ("token_count" not in line and "session_meta" not in line and "turn_context" not in line):
                    continue
                try:
                    obj = json.loads(line)
                except json.JSONDecodeError:
                    continue

                payload = obj.get("payload") or {}
                event_type = obj.get("type")
                if event_type == "session_meta":
                    if not INCLUDE_WORKSPACE:
                        continue
                    cwd = payload.get("cwd") or cwd
                    continue
                if event_type == "turn_context":
                    if not INCLUDE_WORKSPACE:
                        continue
                    cwd = payload.get("cwd") or cwd
                    continue

                if event_type != "event_msg" or payload.get("type") != "token_count":
                    continue

                timestamp = parse_timestamp(obj.get("timestamp"))
                if timestamp is None:
                    continue
                (
                    tokens,
                    input_tokens,
                    cached_input_tokens,
                    output_tokens,
                    reasoning_output_tokens,
                    model_context_window,
                ) = usage_from_payload(payload)
                if tokens <= 0:
                    continue

                rate_limits = payload.get("rate_limits") or {}
                events.append(
                    UsageEvent(
                        timestamp=timestamp,
                        tokens=tokens,
                        input_tokens=input_tokens,
                        cached_input_tokens=cached_input_tokens,
                        output_tokens=output_tokens,
                        reasoning_output_tokens=reasoning_output_tokens,
                        model_context_window=model_context_window,
                        cwd=cwd,
                        rate_limits=rate_limits,
                    )
                )
    return sorted(events, key=lambda event: event.timestamp)


def limit_window_label(window_minutes: int | None) -> str:
    if not window_minutes:
        return "limit"
    if window_minutes < 60:
        return f"{window_minutes}m"
    if window_minutes < 1440:
        hours = window_minutes // 60
        return f"{hours}h"
    if window_minutes == 10080:
        return "weekly"
    days = window_minutes // 1440
    return f"{days}d"


def limit_title(rate_limits: dict[str, Any]) -> str:
    limit_name = rate_limits.get("limit_name")
    limit_id = rate_limits.get("limit_id") or "codex"
    if limit_name:
        return str(limit_name)
    if limit_id == "codex":
        return "Codex"
    return str(limit_id).replace("_", " ")


def build_limit_rows(rate_limits: dict[str, Any], now: dt.datetime) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for key in ("primary", "secondary"):
        limit = rate_limits.get(key) or {}
        used = safe_float(limit.get("used_percent"))
        resets_at = safe_int(limit.get("resets_at")) or None
        if resets_at is not None and resets_at <= int(now.timestamp()):
            used = 0.0
        remaining = max(0.0, min(100.0, 100.0 - used))
        window_minutes = safe_int(limit.get("window_minutes"))
        rows.append(
            {
                "kind": key,
                "label": limit_window_label(window_minutes),
                "usedPercent": int(round(used)),
                "remainingPercent": int(round(remaining)),
                "remaining": round(remaining / 100, 4),
                "reset": format_reset(resets_at, now),
                "windowMinutes": window_minutes or 0,
            }
        )
    return rows


def build_limits(
    events: list[UsageEvent],
    now: dt.datetime,
    live_rate_limits: list[dict[str, Any]] | None = None,
) -> list[dict[str, Any]]:
    latest_by_id: dict[str, dict[str, Any]] = {}
    if live_rate_limits:
        for rate_limits in live_rate_limits:
            limit_id = str(rate_limits.get("limit_id") or "codex")
            latest_by_id[limit_id] = rate_limits
    else:
        for event in events:
            rate_limits = event.rate_limits or {}
            limit_id = str(rate_limits.get("limit_id") or "codex")
            latest_by_id[limit_id] = rate_limits

    def sort_key(item: tuple[str, dict[str, Any]]) -> tuple[int, str]:
        limit_id, rate_limits = item
        if limit_id == "codex":
            return (0, limit_id)
        if rate_limits.get("limit_name"):
            return (1, str(rate_limits["limit_name"]))
        return (2, limit_id)

    limits: list[dict[str, Any]] = []
    for limit_id, rate_limits in sorted(latest_by_id.items(), key=sort_key):
        rows = build_limit_rows(rate_limits, now)
        credits = rate_limits.get("credits") or {}
        limits.append(
            {
                "id": limit_id,
                "title": limit_title(rate_limits),
                "planType": rate_limits.get("plan_type") or "",
                "credits": {
                    "hasCredits": bool(credits.get("has_credits")),
                    "unlimited": bool(credits.get("unlimited")),
                    "balance": credits.get("balance"),
                },
                "rows": rows,
            }
        )
    return limits


def sparkline(values: list[int], length: int = 24) -> list[float]:
    if len(values) < length:
        values = ([0] * (length - len(values))) + values
    else:
        values = values[-length:]
    max_value = max(values) if values else 0
    if max_value <= 0:
        return [0.08, 0.16, 0.24, 0.18, 0.32, 0.22, 0.12, 0.2, 0.08, 0.14, 0.1, 0.18]
    return [round(max(0.06, value / max_value), 3) for value in values]


def activity_details(values: list[int], length: int = 18) -> list[dict[str, Any]]:
    now = dt.datetime.now().astimezone()
    start_hour = now.hour - length + 1
    selected: list[tuple[int, int]] = []
    for index in range(length):
        hour = (start_hour + index) % 24
        selected.append((hour, values[hour]))

    max_value = max((value for _, value in selected), default=0)
    details: list[dict[str, Any]] = []
    for hour, tokens in selected:
        intensity = 0.06 if max_value <= 0 else round(max(0.06, tokens / max_value), 3)
        details.append(
            {
                "hour": f"{hour:02d}:00",
                "tokens": tokens,
                "tokensText": format_tokens(tokens),
                "intensity": intensity,
            }
        )
    return details


def build_summary(days_back: int = 8, force_live_limits: bool = False) -> dict[str, Any]:
    now = dt.datetime.now().astimezone()
    today = now.date()
    week_start = today - dt.timedelta(days=6)
    events = read_events(days_back)

    today_events = [event for event in events if event.timestamp.date() == today]
    week_events = [event for event in events if event.timestamp.date() >= week_start]
    latest = events[-1] if events else None
    live_rate_limits = fetch_live_rate_limits(force_refresh=force_live_limits)
    limits = build_limits(events, now, live_rate_limits.snapshots)
    main_limit = limits[0] if limits else {"rows": []}
    main_rows = main_limit.get("rows") or []
    primary_row = main_rows[0] if len(main_rows) > 0 else {}
    secondary_row = main_rows[1] if len(main_rows) > 1 else {}

    hourly = [0] * 24
    workspaces: dict[str, int] = defaultdict(int)
    for event in today_events:
        if INCLUDE_WORKSPACE:
            workspaces[short_workspace(event.cwd)] += event.tokens
        hourly[event.timestamp.hour] += event.tokens

    top_workspace = "none"
    if INCLUDE_WORKSPACE and workspaces:
        top_workspace = max(workspaces.items(), key=lambda item: item[1])[0]

    today_tokens = sum(event.tokens for event in today_events)
    week_tokens = sum(event.tokens for event in week_events)
    last_turn = today_events[-1].tokens if today_events else (latest.tokens if latest else 0)
    input_today = sum(event.input_tokens for event in today_events)
    cached_today = sum(event.cached_input_tokens for event in today_events)
    output_today = sum(event.output_tokens for event in today_events)
    reasoning_today = sum(event.reasoning_output_tokens for event in today_events)
    primary_used = float(primary_row.get("usedPercent") or 0)
    secondary_used = float(secondary_row.get("usedPercent") or 0)
    primary_remaining = float(primary_row.get("remainingPercent") or 100)
    secondary_remaining = float(secondary_row.get("remainingPercent") or 100)

    if primary_used >= 90 or secondary_used >= 90:
        status = "Critical"
    elif primary_used >= 65 or secondary_used >= 65:
        status = "Watch"
    else:
        status = "Safe"

    return {
        "ok": True,
        "updatedAt": now.isoformat(timespec="minutes"),
        "status": status,
        "primaryUsed": round(primary_used / 100, 4),
        "secondaryUsed": round(secondary_used / 100, 4),
        "primaryPercent": int(round(primary_used)),
        "secondaryPercent": int(round(secondary_used)),
        "primaryRemaining": round(primary_remaining / 100, 4),
        "secondaryRemaining": round(secondary_remaining / 100, 4),
        "primaryRemainingPercent": int(round(primary_remaining)),
        "secondaryRemainingPercent": int(round(secondary_remaining)),
        "reset": str(primary_row.get("reset") or "--"),
        "todayTokens": today_tokens,
        "todayTokensText": format_tokens(today_tokens),
        "weekTokens": week_tokens,
        "weekTokensText": format_tokens(week_tokens),
        "lastTurnTokens": last_turn,
        "lastTurnTokensText": format_tokens(last_turn),
        "inputTokensText": format_tokens(input_today),
        "cachedInputTokensText": format_tokens(cached_today),
        "outputTokensText": format_tokens(output_today),
        "reasoningOutputTokensText": format_tokens(reasoning_today),
        "modelContextWindowText": format_tokens(latest.model_context_window if latest else 0),
        "topWorkspace": top_workspace,
        "eventCount": len(today_events),
        "activity": sparkline(hourly, 18),
        "activityDetails": activity_details(hourly, 18),
        "limitsSource": live_rate_limits.source,
        "limitsSyncedAt": live_rate_limits.synced_at.isoformat(timespec="minutes") if live_rate_limits.synced_at else "",
        "limitsError": live_rate_limits.error,
        "limits": limits,
    }


def main() -> int:
    try:
        days_back = env_int("CODEX_USAGE_DAYS", DEFAULT_DAYS_BACK, 1, MAX_DAYS_BACK)
        force_live_limits = "--force-live" in sys.argv[1:] or os.environ.get("CODEX_USAGE_FORCE_LIVE_LIMITS") == "1"
        print(json.dumps(build_summary(days_back, force_live_limits), ensure_ascii=False, separators=(",", ":")))
        return 0
    except Exception as exc:  # Keep Quickshell alive even if one scan fails.
        print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False))
        return 1


if __name__ == "__main__":
    sys.exit(main())
