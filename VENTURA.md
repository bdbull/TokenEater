# Running TokenEater on macOS 13 Ventura

## What was changed

The app required macOS 14+. These changes backport it to macOS 13:

### `project.yml`
Deployment target lowered from `14.0` to `13.0`.

### `Shared/Components/View+OnChange.swift` (new file)
The 2-parameter `onChange(of:) { old, new in }` API is macOS 14+. Two backward-compatible
`ViewModifier`-based wrappers replace all usages:
- `onChangeCompat(of:perform:)` — new value only
- `onChangeCompat(of:perform:)` — old + new values (tracks previous via `@State` on macOS 13)

### Swift 5.9 concurrency fixes
Xcode 15.2 / Swift 5.9 is stricter than Xcode 16.4 / Swift 6.x about capturing `self` across
concurrent boundaries. Three files were patched:

- `Shared/Stores/UpdateStore.swift` — move `guard let self` before `Task { @MainActor in }`
- `TokenEaterApp/OverlayWindowController.swift` — same pattern
- `TokenEaterApp/StatusBarController.swift` — `MainActor.assumeIsolated` (macOS 14+) wrapped in
  `#available(macOS 14, *)`, macOS 13 path uses `Task { @MainActor in }`

---

## Prerequisites

### Xcode 15.2
The highest Xcode version compatible with macOS 13. Install via `xcodes`:

```bash
brew install xcodes
xcodes signin
xcodes install "15.2" --directory /Applications
```

### xcodegen
Homebrew can't install xcodegen on macOS 13 (its formula requires Xcode 15.3+).
Use the pre-built binary from GitHub instead:

```bash
gh release download --repo yonaskolb/XcodeGen 2.45.2 -p "xcodegen.zip" -D /tmp
unzip -o /tmp/xcodegen.zip -d /tmp/xcodegen_install
```

> The binary lives in `/tmp` and won't survive a reboot. Re-run the above if needed.

### Apple Developer certificate
A free Apple ID is sufficient — no $99/year program needed.

1. Open Xcode → **Settings → Accounts** → add your Apple ID
2. Click **Manage Certificates → +** → **Apple Development**
3. Find your Team ID:
   ```bash
   security find-certificate -a -p | openssl x509 -noout -subject 2>/dev/null | grep "Apple Development"
   # Look for OU=XXXXXXXXXX — that 10-char string is your Team ID
   ```

---

## Rebuild & reinstall

```bash
# 1. Re-download xcodegen if needed (after reboot)
gh release download --repo yonaskolb/XcodeGen 2.45.2 -p "xcodegen.zip" -D /tmp && \
unzip -o /tmp/xcodegen.zip -d /tmp/xcodegen_install

# 2. Generate Xcode project
DEVELOPER_DIR=/Applications/Xcode-15.2.0.app/Contents/Developer \
/tmp/xcodegen_install/xcodegen/bin/xcodegen generate

# 3. Build — look up your Team ID if you forgot it:
#    security find-certificate -a -p | openssl x509 -noout -subject 2>/dev/null | grep "Apple Development"
#    It's the OU= value (e.g. OU=855MGS2733)
DEVELOPER_DIR=/Applications/Xcode-15.2.0.app/Contents/Developer \
xcodebuild -project TokenEater.xcodeproj -scheme TokenEaterApp \
  -configuration Release -derivedDataPath build \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM=TEAM_ID \
  build 2>&1 | tail -3

# 4. Nuke caches (required — macOS caches widget aggressively)
killall TokenEater 2>/dev/null; killall NotificationCenter 2>/dev/null; killall chronod 2>/dev/null
rm -rf ~/Library/Application\ Support/com.tokeneater.shared
pluginkit -r -i com.tokeneater.app.widget 2>/dev/null

# 5. Install and launch
rm -rf /Applications/TokenEater.app && \
cp -R build/Build/Products/Release/TokenEater.app /Applications/ && \
xattr -cr /Applications/TokenEater.app && \
/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister -f -R /Applications/TokenEater.app && \
sleep 2 && open /Applications/TokenEater.app
```
