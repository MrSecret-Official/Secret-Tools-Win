# Secret-Tools

Personal Windows recovery & repair toolkit.
**Made by: mrsecret_official**

## PERSONAL USE ONLY
This tool is for **PERSONAL USE ONLY** on your own devices.

---

## 1. Quick Installation

This repository is public, so anyone can install it — no GitHub account or
token required. Just execute **`Setup-Tools.bat`**:

```cmd
Setup-Tools.bat
```

Before it downloads or changes anything, it shows a plain-language notice of
exactly what it does (the only network activity is downloading from this
repo — no telemetry, no data collection), where it installs to, and asks you
to confirm. Answering "N" installs nothing — and if Secret-Tools was already
installed, removes it completely (files, PATH entries, shortcut) instead.
This notice is shown every time the installer runs, not just the first time.

This single script:
- Fetches all required files from this public repository.
- Installs the project into `%USERPROFILE%\Tools`.
- Adds `%USERPROFILE%\Tools` to your system `PATH`.
- Creates a Desktop shortcut (`Secret-Tools.lnk`).
- Checks for updates automatically every time it runs.

Share `Setup-Tools.bat` (or the repository link) with friends and they can
install it the same way, on their own machine.

---

## 2. Usage from Any Terminal

Once installed, open any terminal and type:

```cmd
secret-tools
```

Windows will show its normal **UAC elevation prompt** once per launch (this
tool changes system settings, so it needs Administrator rights — there's no
way around that prompt, and there shouldn't be). After that, all menu
actions run without repeated prompts for the rest of that session.

There is no login screen. Anyone with access to your Windows account already
has access to everything this tool can do — a password screen on top of that
wouldn't add real protection. If your concern is device theft, the actual
protection is your Windows account password plus full-disk encryption
(BitLocker).

---

## 3. Updating

Re-running `Setup-Tools.bat` (or just relaunching `secret-tools`, which
checks in the background) detects and deploys new commits to this repo
automatically. No credentials involved at any point.

---

## Security notes

- This repo is public and contains no secrets, tokens, or passwords — keep
  it that way. Never commit credentials into any file here.
- `[12] Emergency Access Accounts` can enable the built-in Administrator
  account or create a new local admin user, but **only from an already
  logged-in Windows session** — **only use it on a device you own or are
  explicitly authorized to administer.** If you're sharing this tool with
  friends, make sure they understand that boundary too. There is
  deliberately no offline/WinRE login-screen bypass: if you're fully locked
  out (no account you can log into at all), use Microsoft's own recovery
  paths — an online password reset via https://account.live.com/password/reset
  for Microsoft accounts, or a password reset disk for local accounts. That
  offline-bypass capability was tried and removed: it's the most
  fingerprinted "login bypass" technique that exists, so antivirus software
  flags it regardless of how carefully it's implemented — the capability
  itself is indistinguishable from what a backdoor does.
- Anyone can read this source (that's the point), so review any change
  before you run it — especially anything touching elevation, the boot
  process, or account management.
