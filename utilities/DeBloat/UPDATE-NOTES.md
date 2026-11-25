# RemoveBloat-5.6.5.ps1: local changes

Modified copy of Andrew Taylor's `RemoveBloat.ps1` version 5.6.5 (upstream: `andrew-s-taylor/public`, folder `De-Bloat`, commit `ce39945`). Every change is marked `LOCAL CHANGE` in the script.

Upstream original SHA256: `4500fe5538471cc2df8d0fde5ad23bfef037561e095f27a3e341e744e69af039`

## Deployment

- ImmyBot runs it with `Invoke-Expression` from the raw GitHub URL, onboarding only.
- Log: `C:\ProgramData\Automation\Logs\Debloat.log`
- Report: `C:\ProgramData\Automation\Logs\DebloatReport.html`
- Working files: `C:\ProgramData\Automation\Debloat`
- Dependencies: `utilities/DeBloat/` in this repo (`start2.bin`, `HPConnOpt.iss`, `mcafeeclean.zip`, `mccleanup.zip`). `start2.bin` is not used (Start menu section skipped) but its URL is kept consistent.
- Immy test: passes when the log contains a line starting with `Completed`. A skipped run (in-use machine) writes `Skipped` instead, so Immy reports it as failed on purpose.

## Edits to upstream code

Apply these to a new upstream version with find and replace.

| # | Edit | Find | Replace with |
|---|---|---|---|
| 1 | Dependency URLs (4) | `https://github.com/andrew-s-taylor/public/raw/main/De-Bloat` and `https://raw.githubusercontent.com/andrew-s-taylor/public/main/De-Bloat` | `https://raw.githubusercontent.com/keenits/automation/main/utilities/DeBloat` |
| 2 | Log path | `C:\ProgramData\Debloat\Debloat.log` | `C:\ProgramData\Automation\Logs\Debloat.log` |
| 3 | Working folder (do after #2) | `C:\ProgramData\Debloat` | `C:\ProgramData\Automation\Debloat` |
| 4 | Signature block | Everything from `# SIG # Begin signature block` to end of file | Delete |
| 5 | Whitelist | End of `$WhitelistedApps` array | Add `Microsoft.ZuneMusic`, `MicrosoftCorporationII.QuickAssist`, `MicrosoftWindows.CrossDevice`, `Microsoft.PowerAutomateDesktop`, `Microsoft.PowerAutomateDesktopCopilotPlugin`, `Microsoft.RemoteDesktop` |

After the edits, a search for `andrew-s-taylor` should only find the header comment, and a search for `ProgramData\Debloat` should find nothing. If either finds more, the new version has new dependencies or paths to review.

## Blocks added (copy from the current script)

| # | Block | Where it goes |
|---|---|---|
| 6 | Header comment | Line 1, above the `<#` help block |
| 7 | Create `C:\ProgramData\Automation\Logs` | Line before `Start-Transcript` |
| 8 | In-use safeguard: skip if any real user profile is older than 8 days (Immy cutoff is 7) | Right after `Start-Transcript` |
| 9 | Before snapshot (`Get-DebloatSnapshot`) for the report | After the safeguard |
| 10 | Consumer features: `DisableWindowsConsumerFeatures` plus ContentDeliveryManager keys for the default user and loaded users, so removed apps don't return | After the AppX removal, before the `Remove Registry Keys` header |
| 11 | Extra AppX removal: partial-name match list (Win11Debloat safe defaults plus HP extras), skips whitelisted apps | After block 10 |
| 12 | Removal report | Before `#Set ProgressPreerence back` at the end |

## Sections skipped

Wrapped in `if ($false) { ... }`; the settings are handled by the separate Windows 11 settings script.

| Part | From | To (not included) |
|---|---|---|
| 1 | `Remove Registry Keys` header | `Remove OneDrive Photos App` header |
| 2 | First `Apply User Settings to Default User Profile` header | `Grab all Uninstall Strings` header |

The OneDrive Photos app removal between the two parts still runs. Before wrapping on a new version, check that nothing after part 2 depends on variables or functions defined inside the skipped parts (none do in 5.6.5).

## Decisions behind this version

- Keep: Media Player, Quick Assist, Phone Link, Power Automate Desktop, Remote Desktop, new Outlook, Clipchamp, Copilot, Widgets.
- Dell, HP, Lenovo, Samsung, Acer and Asus sections: upstream behavior. Dell Display Manager, Peripheral Manager and Pair are whitelisted upstream but still removed by its manual blocks; accepted.
- Dell Optimizer 6.x (MSI) is not removed by upstream; not pursued.
- McAfee removal kept; the zips are Andrew Taylor's repackaged McAfee tools, hosted in this repo.
- Not carried over from the old `RemoveBloat2.ps1`: nothing. Its wildcard bloat entries never matched; the extra AppX list replaces them.

## Long-term items (settings script)

- Capture our own `start2.bin` and deploy it from the Windows 11 settings script.
- Review the settings script against the skipped upstream settings.
