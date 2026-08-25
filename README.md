# Secret-Tools-Win

Personal management and recovery tool for Windows.

## PERSONAL USE ONLY
This tool is for **PERSONAL USE ONLY** on your own devices.

---

## 1. Quick Installation

Execute **`Setup-Tools.bat`**:

```cmd
Setup-Tools.bat
```

This single script:
- Fetches all required files automatically from the private repository.
- Installs the project into `%USERPROFILE%\Tools`.
- Adds `%USERPROFILE%\Tools` to your system `PATH`.
- Creates a Desktop shortcut (`Secret-Tools-Win.lnk`).
- Checks for future updates automatically every time it runs.

---

## 2. Usage from Any Terminal

Once installed, simply open any standard Windows Terminal, CMD, or PowerShell and type:

```cmd
secret-tools
```

This immediately prompts for credentials:
1. **Username**: (`Secret-user` or `MrSecret`)
2. **Password**: (Hidden password prompt authenticated securely via remote repository / offline cache)

---

## User Accounts
Both accounts have equal access to all administrative features:
- **Secret-user**: Authenticates against remote `Sec-User-Pass.txt`.
- **MrSecret**: Authenticates against remote `MrSecret-Access.txt`.