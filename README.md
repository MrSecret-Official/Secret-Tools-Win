# Secret-Tools

Personal Windows recovery & repair toolkit.
**Made by: mrsecret_official**

## PERSONAL USE ONLY
This tool is for **PERSONAL USE ONLY** on your own devices.

---

## 1. Quick Installation

Execute **`Setup-Tools.bat`**:

```cmd
Setup-Tools.bat
```

The first time you run it, it will ask for a **GitHub Personal Access Token**
with read access to this repository (input is hidden). The token is never
stored in any script — it's saved once, encrypted with Windows DPAPI, under
`%LOCALAPPDATA%\Secret-Tools\Credentials\`, and can only be decrypted by your
own Windows user account on this machine.

This single script:
- Fetches all required files from the repository using that token.
- Installs the project into `%USERPROFILE%\Tools`.
- Adds `%USERPROFILE%\Tools` to your system `PATH`.
- Creates a Desktop shortcut (`Secret-Tools.lnk`).
- Checks for updates automatically every time it runs.

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

## 3. Updating / clearing the stored token

- Re-running `Setup-Tools.bat` checks for and deploys updates automatically.
- If your GitHub token expires or you want to rotate it, clear it from the
  running tool via menu option **[9] Clear Stored GitHub Token**, or delete
  `%LOCALAPPDATA%\Secret-Tools\Credentials\repo.dat` manually. The next run
  of `Setup-Tools.bat` will ask for a new one.

---

## Security notes

- Never commit a GitHub token into any file in this repo. If one is ever
  exposed (pasted somewhere, checked into git, shown to a third party), treat
  it as compromised and revoke/regenerate it immediately from
  GitHub → Settings → Developer settings → Personal access tokens.
- `[7] Emergency Access Accounts` can enable the built-in Administrator
  account or create a new local admin user. It requires being physically at
  the console and confirming interactively — use it only when you actually
  need to recover access to this machine.
