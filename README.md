# Secret-Tools-Win

Personal management and recovery tool for Windows.

## PERSONAL USE ONLY
This tool is for **PERSONAL USE ONLY** on your own devices.

---

## One-Click Setup & Auto-Updater

To install or run the project, execute **`Setup-Tools.bat`**:

```cmd
Setup-Tools.bat
```

### Features
1. **Standalone Portability**: You only need to pass or run `Setup-Tools.bat`. It fetches the complete project automatically from the private repository.
2. **Installation Directory**: Installed directly into `%USERPROFILE%\Tools`.
3. **Automatic PATH Integration**: Automatically registers `%USERPROFILE%\Tools` and `%USERPROFILE%\Tools\Tools` into the User's Windows `PATH`.
4. **Auto-Updater**: Every time `Setup-Tools.bat` is executed (or via the Desktop shortcut), it queries the GitHub API for newer commits. If a new version exists, it updates all files automatically.
5. **Offline Support**: If offline, it immediately loads the local installation and cached credentials.

---

## User Accounts
Both user accounts have equal access to all administrative features:
- **Secret-user**: Authenticates against remote `Sec-User-Pass.txt`.
- **MrSecret**: Authenticates against remote `MrSecret-Access.txt`.