#!/usr/bin/env python3
"""
video-detect — UserPromptSubmit hook (Claude Code plugin: video-analyze).

Scans the prompt for video references and injects analysis as additionalContext.
Handles:
  - Quoted paths          : "/foo bar.mov"   '/foo bar.mov'
  - Backslash-escaped     : /foo\\ bar.mov
  - Tilde paths           : ~/Downloads/clip.mp4
  - Plain paths w/ spaces : /Users/me/Screen Recording 2026-04-17 at 11.52.42 AM.mov
  - HTTP/HTTPS URLs       : https://example.com/video.mp4

Auto-installs dependencies (ffmpeg, whisper-cpp) via Homebrew and downloads the
whisper model on first run — only triggered when a video is actually detected.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
import tempfile
import urllib.request
from pathlib import Path
from shutil import which

VIDEO_EXTS = ("mp4", "mov", "avi", "mkv", "webm", "m4v", "flv", "wmv",
              "mpg", "mpeg", "ts", "mts", "3gp")
EXT_GROUP = "|".join(VIDEO_EXTS)
WHISPER_MODEL_URL = "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-small.bin"

PLUGIN_ROOT = os.environ.get("CLAUDE_PLUGIN_ROOT", os.path.dirname(os.path.dirname(os.path.realpath(__file__))))
VIDEO_ANALYZE = os.path.join(PLUGIN_ROOT, "bin", "video-analyze")


def log(msg: str) -> None:
    print(f"video-detect: {msg}", file=sys.stderr, flush=True)


def brew_prefix(pkg: str = "") -> str | None:
    try:
        r = subprocess.run(["brew", "--prefix", pkg] if pkg else ["brew", "--prefix"],
                           capture_output=True, text=True, timeout=10)
        if r.returncode == 0:
            return r.stdout.strip()
    except Exception:
        pass
    return None


def whisper_model_path() -> str:
    prefix = brew_prefix("whisper-cpp") or brew_prefix() or "/opt/homebrew"
    return os.path.join(prefix, "share", "whisper-cpp", "ggml-small.bin")


def ensure_deps() -> None:
    need = []
    if not which("ffmpeg"):
        need.append("ffmpeg")
    if not which("whisper-cli"):
        need.append("whisper-cpp")
    if need and which("brew"):
        log(f"installing missing deps: {' '.join(need)}")
        subprocess.run(["brew", "install", *need], stderr=sys.stderr, stdout=sys.stderr)
    model = whisper_model_path()
    if which("whisper-cli") and not os.path.isfile(model):
        try:
            os.makedirs(os.path.dirname(model), exist_ok=True)
            log("downloading whisper ggml-small.bin (~488MB, first run only)...")
            tmp = model + ".tmp"
            urllib.request.urlretrieve(WHISPER_MODEL_URL, tmp)
            os.rename(tmp, model)
        except Exception as e:
            log(f"whisper model download failed ({e}); transcription will be skipped")
            try:
                os.remove(model + ".tmp")
            except OSError:
                pass


def find_urls(prompt: str) -> list[str]:
    pattern = re.compile(rf'https?://[^\s<>"\']+?\.(?:{EXT_GROUP})(?:\?[^\s<>"\']*)?', re.IGNORECASE)
    seen, out = set(), []
    for m in pattern.finditer(prompt):
        url = m.group(0).rstrip(').,;:!?"\'')
        if url not in seen:
            seen.add(url)
            out.append(url)
    return out


def find_local_paths(prompt: str) -> list[str]:
    ext_re = re.compile(rf'\.(?:{EXT_GROUP})\b', re.IGNORECASE)
    seen: set[str] = set()
    out: list[str] = []

    for m in ext_re.finditer(prompt):
        end = m.end()
        prefix = prompt[:end]

        starts = []
        for i, ch in enumerate(prefix):
            if ch == "/":
                starts.append(i)
            elif ch == "~" and i + 1 < len(prefix) and prefix[i + 1] == "/":
                starts.append(i)

        for s in starts:
            raw = prefix[s:end]
            candidate = raw.replace("\\ ", " ")
            candidate = candidate.strip("\"'")
            if candidate.startswith("~"):
                candidate = os.path.expanduser(candidate)
            if os.path.isfile(candidate):
                resolved = os.path.realpath(candidate)
                if resolved not in seen:
                    seen.add(resolved)
                    out.append(candidate)
                break
    return out


def analyze_local(path: str) -> tuple[str | None, str | None]:
    basename = os.path.basename(path)
    env = os.environ.copy()
    env["WHISPER_MODEL"] = whisper_model_path()
    try:
        r = subprocess.run(
            [VIDEO_ANALYZE, path],
            capture_output=True, text=True, timeout=600, env=env,
        )
    except Exception as e:
        return None, f"{basename}: {e}"
    if r.returncode != 0:
        return None, f"{basename}: video-analyze exit {r.returncode}"
    summary_path = r.stdout.strip().splitlines()[-1] if r.stdout.strip() else ""
    if not summary_path or not os.path.isfile(summary_path):
        return None, f"{basename}: no summary produced"
    try:
        return Path(summary_path).read_text(), None
    except Exception as e:
        return None, f"{basename}: {e}"


def analyze_url(url: str) -> tuple[str | None, str | None]:
    basename = url.rsplit("/", 1)[-1].split("?", 1)[0] or "video"
    ext = "." + basename.rsplit(".", 1)[-1] if "." in basename else ".mp4"
    tmp = tempfile.NamedTemporaryFile(prefix="video-detect-url-", suffix=ext, delete=False)
    tmp.close()
    try:
        log(f"downloading {url} ...")
        urllib.request.urlretrieve(url, tmp.name)
    except Exception as e:
        os.unlink(tmp.name)
        return None, f"{basename}: download failed ({e})"
    try:
        summary, err = analyze_local(tmp.name)
        if summary:
            summary = summary.replace(tmp.name, url)
            return summary, None
        return None, err
    finally:
        try:
            os.unlink(tmp.name)
        except OSError:
            pass


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except Exception:
        print("{}")
        return

    prompt = data.get("prompt") or data.get("tool_input", {}).get("prompt") or ""
    if not prompt:
        print("{}")
        return

    urls = find_urls(prompt)
    paths = find_local_paths(prompt)

    if not urls and not paths:
        print("{}")
        return

    if not os.path.isfile(VIDEO_ANALYZE) or not os.access(VIDEO_ANALYZE, os.X_OK):
        log(f"bundled video-analyze not found or not executable at {VIDEO_ANALYZE}")
        print("{}")
        return

    ensure_deps()

    instruction = (
        "INSTRUCTIONS FOR CLAUDE: The user shared a video. Use the Read tool on the "
        "frames listed under '## Frames' to see the content, combined with the "
        "transcript. Then respond to the user NATURALLY — treat the video like a "
        "normal message from them. If they asked a question, answer it. If they "
        "asked you to do something, do it. Do NOT produce a mechanical frame-by-frame "
        "breakdown, bullet-list description, or meta-commentary about the video "
        "unless they explicitly asked for one. The frames are context for you, not "
        "content to recite back.\n\n"
        "FILENAME NOTE: Video paths (especially macOS Screen Recordings) often contain "
        "spaces AND may include U+202F (narrow no-break space) before AM/PM. Pass paths "
        "to Read/Bash EXACTLY as listed — do not retype them, do not substitute regular "
        "spaces for U+202F, and do not add backslash-escapes. When using Bash, always "
        "wrap the full path in double quotes."
    )

    context_blocks: list[str] = []
    errors: list[str] = []

    for path in paths:
        summary, err = analyze_local(path)
        if summary:
            context_blocks.append(
                f"\n--- Video Analysis: {os.path.basename(path)} ---\n"
                f"{instruction}\n\nSource: {path}\n{summary}\n---\n"
            )
        elif err:
            errors.append(err)

    for url in urls:
        summary, err = analyze_url(url)
        if summary:
            basename = url.rsplit("/", 1)[-1].split("?", 1)[0] or url
            context_blocks.append(
                f"\n--- Video Analysis: {basename} ---\n"
                f"{instruction}\n\nSource URL: {url}\n{summary}\n---\n"
            )
        elif err:
            errors.append(err)

    if not context_blocks:
        print("{}")
        return

    total = len(paths) + len(urls)
    msg = f"Auto-analyzed {total} video file(s) with video-analyze"
    if errors:
        msg += f" ({len(errors)} failed)"

    print(json.dumps({
        "suppressOutput": True,
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": "\n".join(context_blocks),
        },
        "systemMessage": msg,
    }))


if __name__ == "__main__":
    main()
