# Security policy

## Supported versions

Security fixes go into the latest release. Please update before you report.

| Version | Supported |
|---|---|
| 1.0.x | Yes |

## Reporting a vulnerability

Please do not open a public issue for security problems.

Report it privately through GitHub: open the [Security tab](https://github.com/DigitalIQ/pocketwerk/security) of the repository and choose **Report a vulnerability**. This uses GitHub's private vulnerability reporting, so only the maintainers see your report.

Helpful details:

- the Pocketwerk version (Settings > About) and the macOS version,
- what an attacker can do and under which conditions,
- steps to reproduce, or a proof of concept,
- whether the issue is already public anywhere.

Replies and the work on a fix happen in that private report.

## What Pocketwerk accesses

Pocketwerk is a local app. It has no account, no server and no telemetry.

**Files it reads and writes**

- `~/Library/Application Support/Pocketwerk/`: the library (`library.json`), images you chose and cached link favicons.
- `~/Applications/Pocketwerk/`: one small launcher app per Dock icon, built from a template inside Pocketwerk and signed ad hoc.
- A folder you choose under Settings > Backup > Copy to Another Folder, if you turn that on. Pocketwerk writes a copy of the library there and never reads it back on its own.
- Backup files you export or import, and files you add to groups (only their paths are stored).

**The Dock**

Pocketwerk reads and writes the Dock preferences (`com.apple.dock`) when you add or remove one of its icons, add a spacer or apply a Dock profile, and then restarts the Dock with `killall Dock`.

**Network**

- Once a day, if enabled: a request to `https://api.github.com/repos/DigitalIQ/pocketwerk/releases/latest`. Nothing else is sent.
- For link items: `https://<host>/apple-touch-icon.png` and `https://<host>/favicon.ico` of the link's own site. Failed hosts are not asked again for a week.

**Permissions**

- No Accessibility permission. Global hotkeys use the system hotkey API.
- Optional Automation permission, only when you use **Add Current Browser Tab**. Pocketwerk then asks Safari, Chrome, Arc or Brave for the URL and title of the front tab.

**Other apps**

On your request (Hide All, Quit All, Force Quit All, ⌥-click, or a profile set to quit other apps), Pocketwerk hides, quits or force quits running apps.

## Signing

Releases are signed ad hoc and not notarized. Every release is built from the tagged source with `scripts/release.sh`. If you want to be sure what you run, build it yourself as described in the [README](README.md#build-from-source).
