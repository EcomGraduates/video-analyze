# video-analyze

Claude Code plugin that auto-analyzes videos mentioned in your prompts. Share a screen recording or video URL — Claude extracts keyframes, transcribes audio with Whisper, and sees/hears the content as if you'd described it.

## What it does

When you submit a prompt containing a video path or URL, a `UserPromptSubmit` hook:

1. Detects the reference (quoted paths, backslash-escaped, tilde paths, plain paths with spaces, HTTP/HTTPS URLs, macOS Screen Recording filenames with U+202F narrow no-break space)
2. Extracts keyframes with `ffmpeg` (default: 1 frame every 2 seconds)
3. Transcribes audio with `whisper-cpp` (if speech is present)
4. Injects frame paths + transcript into Claude's context so Claude can `Read` each frame image and respond naturally

Temp files land in `/tmp/video-analyze-*` and are cleaned up on `SessionEnd`.

## Install

In Claude Code:

```
/plugin marketplace add EcomGraduates/video-analyze
/plugin install video-analyze@ecomgraduates
```

Restart Claude Code (or `/reload-plugins`). That's it. The first video you share auto-installs `ffmpeg` + `whisper-cpp` and downloads the Whisper model (~488 MB) — no further action needed.

### First-run setup on a fresh Mac

If you don't already have [Homebrew](https://brew.sh) installed, the plugin will tell you exactly what to paste — a single command:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Homebrew's installer needs your Mac password once (it has to create `/opt/homebrew`). After that, every remaining dependency installs automatically.

## Requirements

- macOS (Apple Silicon or Intel)
- Python 3 (ships with macOS)
- [Homebrew](https://brew.sh) — auto-installable; used to install `ffmpeg` + `whisper-cpp` on first video

## Usage

Just mention a video in a prompt:

```
check out this bug /Users/me/Desktop/Screen Recording 2026-04-17 at 1.26.27 PM.mov
```

or

```
can you analyze https://example.com/demo.mp4
```

Claude will see the frames and hear the audio, then respond to whatever you actually asked.

## Supported formats

mp4, mov, avi, mkv, webm, m4v, flv, wmv, mpg, mpeg, ts, mts, 3gp

## Files

- `hooks/video-detect.sh` — UserPromptSubmit hook (Python)
- `hooks/video-cleanup.sh` — SessionEnd hook (clears `/tmp` scratch)
- `bin/video-analyze` — ffmpeg + whisper-cpp runner

## License

MIT
