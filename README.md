# video-analyze

**A Claude Code plugin that lets Claude watch your screen recordings.**

Drop a `.mov`, `.mp4`, or any video URL into a Claude Code prompt and Claude will automatically:

- Extract keyframes from the video
- Transcribe the audio with Whisper
- See and hear the content as if you'd described it yourself

No copy-pasting frame-by-frame, no manual setup per video.

---

## 🚀 Install (copy + paste)

Open Claude Code and run these two commands:

```
/plugin marketplace add EcomGraduates/video-analyze
```

```
/plugin install video-analyze@ecomgraduates
```

Then restart Claude Code (or run `/reload-plugins`).

**That's the whole install.** The very first time you share a video, the plugin handles everything else automatically (one-time dependency install, ~488 MB Whisper model download).

---

## 🎬 How to use it

Just mention a video file or URL in a normal prompt:

```
hey there's a bug in this /Users/me/Desktop/Screen Recording 2026-04-17 at 1.26.27 PM.mov  please fix it
```

or

```
can you check out https://example.com/demo.mp4
```

Claude will see the frames, hear the audio, and respond to what you actually asked. No special syntax, no flags, no attachments UI.

---

## 📋 Requirements

- **macOS** (Apple Silicon or Intel)
- **Python 3** (already on every Mac — nothing to install)
- **[Homebrew](https://brew.sh)** — used to install `ffmpeg` + `whisper-cpp`

### Don't have Homebrew yet?

If you've never installed developer tools before, the plugin will detect this and tell Claude to paste this one line for you. You can also install it yourself first:

Open **Terminal** (⌘ + Space, type "Terminal", hit enter) and paste:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

It'll ask for your Mac password once — same one you use to log in. Wait a few minutes for it to finish, then you're ready to install the plugin (two commands above).

---

## 🔄 Updating

```
/plugin update video-analyze@ecomgraduates
```

## ❌ Uninstalling

```
/plugin uninstall video-analyze@ecomgraduates
```

Clean removal — no leftover files in your settings.

---

## 🧠 What actually happens under the hood

When you submit a prompt containing a video path or URL, a `UserPromptSubmit` hook fires:

1. **Detects** the video reference — handles quoted paths, backslash-escapes, tilde paths, plain paths with spaces, HTTP/HTTPS URLs, and macOS Screen Recording filenames (which contain a sneaky `U+202F` narrow no-break space before "AM"/"PM").
2. **Extracts keyframes** with `ffmpeg` at 1 frame every 2 seconds by default.
3. **Transcribes audio** with `whisper-cpp` if speech is present.
4. **Injects frame paths + transcript** into Claude's context so Claude can `Read` each frame image and respond naturally.

Temp files are stored in `/tmp/video-analyze-*` and cleaned up automatically when your Claude session ends.

### Supported video formats

`mp4`, `mov`, `avi`, `mkv`, `webm`, `m4v`, `flv`, `wmv`, `mpg`, `mpeg`, `ts`, `mts`, `3gp`

---

## 📁 Repo layout

```
.claude-plugin/
  plugin.json          # hook registrations
  marketplace.json     # single-plugin marketplace manifest
hooks/
  video-detect.sh      # UserPromptSubmit hook (Python)
  video-cleanup.sh     # SessionEnd cleanup
bin/
  video-analyze        # ffmpeg + whisper-cpp runner
```

---

## License

MIT
