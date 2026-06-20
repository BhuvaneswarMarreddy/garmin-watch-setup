# Garmin Venu 3 — Watch Face Development

This folder is your workspace for building **custom watch faces (and later, apps)**
for the **Garmin Venu 3 / Venu 3S** using Garmin's Connect IQ platform and the
Monkey C language.

```
garmin-watch-setup/
└── creator/                       ← your development workspace
    ├── watchface-starter/         ← custom WATCH FACE (digital + analog + settings)
    │   ├── manifest.xml           ← app id, type, target devices (venu3, venu3s)
    │   ├── monkey.jungle          ← build config
    │   ├── source/                ← Monkey C code (.mc)
    │   │   ├── VenuWatchFaceApp.mc
    │   │   └── VenuWatchFaceView.mc   ← edit this to change the design
    │   └── resources/
    │       ├── strings/strings.xml
    │       ├── settings/          ← user settings (themes, toggles, style)
    │       └── drawables/ (launcher_icon.png + drawables.xml)
    └── datafield-starter/         ← a DATA FIELD (heart rate, shows in activities)
        ├── manifest.xml
        ├── source/ (HeartRateFieldApp.mc, HeartRateFieldView.mc)
        └── resources/
```

The watch face shows **time, date, battery %, and steps** on a black background
(best for the AMOLED), and supports:
- **Digital or analog** style — switchable in settings
- **User settings** (Garmin Connect app): face style, accent color, and toggles
  for seconds / steps / battery
- **Always-on (low-power) mode** that strips the face down to protect the AMOLED

The data field shows your **current heart rate** during activities. Each project
has its own `README.md`. Change the watch face look by editing
`watchface-starter/source/VenuWatchFaceView.mc`.

---

## What you need (the toolchain)

| Tool | Why | Status on this Mac |
|------|-----|--------------------|
| **JDK (Java 17+)** | The Monkey C compiler runs on Java | ❌ not installed |
| **VS Code** | The IDE Garmin's tools plug into | ❌ not installed |
| **Connect IQ SDK Manager + SDK** | Compiler, simulator, device files | ⬜ install in Step 3 |
| **Monkey C VS Code extension** | New project / build / run / debug | ⬜ install in Step 4 |
| **A free Garmin account** | Required to download the SDK & publish | ⬜ |
| OpenSSL | Generate your developer key | ✅ installed |

---

## Setup steps

### Step 1 — Install Java (JDK)
```bash
brew install --cask temurin
java -version          # confirm it prints a version (17 or newer)
```

### Step 2 — Install VS Code
```bash
brew install --cask visual-studio-code
```
Then open VS Code once and enable the `code` command:
press <kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>P</kbd> → "Shell Command: Install 'code' command in PATH".

### Step 3 — Install the Connect IQ SDK Manager + SDK
1. Go to **https://developer.garmin.com/connect-iq/sdk/** and download the
   **SDK Manager for macOS**.
2. Open it, sign in with your Garmin account.
3. In the **SDK** tab: download the **latest SDK** (and tick "Always use latest").
4. In the **Devices** tab: download **Venu 3** and **Venu 3S** (this gives the
   simulator the screen sizes, fonts, and sensors of those watches).

### Step 4 — Install the VS Code extension
In VS Code: Extensions (<kbd>Cmd</kbd>+<kbd>Shift</kbd>+<kbd>X</kbd>) → search
**"Monkey C"** (publisher: **Garmin**) → Install.
After install it may ask where the SDK is — point it at the SDK the Manager
downloaded (usually `~/Library/Application Support/Garmin/ConnectIQ/Sdks/...`).

### Step 5 — Generate your developer key
Every Connect IQ app must be signed. Generate the key once and reuse it for all
your projects. Two ways:

**A) Via the extension (easiest):**
Command Palette → **"Monkey C: Generate a Developer Key"** → save it somewhere
safe (e.g. `~/garmin/developer_key`).

**B) Via OpenSSL (already installed here):**
```bash
mkdir -p ~/garmin
openssl genrsa -out ~/garmin/developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER \
  -in ~/garmin/developer_key.pem -out ~/garmin/developer_key -nocrypt
```
⚠️ **Back this key up.** If you publish to the Connect IQ Store, you must sign all
future updates with the *same* key. Keep it private (it's already in `.gitignore`).

### Step 6 — Open the project and run it
1. In VS Code: **File → Open Folder** → choose
   `garmin-watch-setup/creator/watchface-starter`
   (open `creator/datafield-starter` the same way to work on the data field —
   each project is built/run on its own).
2. Command Palette → **"Monkey C: Build for Device"** the first time it may ask
   you to select the developer key from Step 5.
3. Press **<kbd>F5</kbd>** (or Command Palette → **"Monkey C: Run"**).
4. Pick **Venu 3** when asked for a device. The **Connect IQ Simulator** opens
   and shows your watch face. 🎉

### Step 7 — Test on the real watch (optional)
1. Command Palette → **"Monkey C: Build for Device"** → select **Venu 3** →
   it produces a `.prg` file in `bin/`.
2. Connect the Venu 3 to the Mac by USB cable (it mounts as a drive).
3. Copy the `.prg` into the watch's **`GARMIN/Apps/`** folder.
4. Eject, then on the watch: long-press → **Watch Face** → pick your face.

### Step 8 — Publish (optional, later)
Create a developer account at **https://apps.garmin.com/**, then upload the
`.iq` package (Command Palette → **"Monkey C: Export Project"**). Review usually
takes a few days.

---

## Editing the design — quick start
Open `source/VenuWatchFaceView.mc`. In `onUpdate()` you'll find each element
(date, time, battery, steps) drawn with `dc.drawText(...)`. Try:
- Change colors: `Graphics.COLOR_WHITE` → `Graphics.COLOR_BLUE`, etc.
- Move elements: the `cy - (height * 0.22)` numbers are vertical positions.
- Change the time font: `Graphics.FONT_NUMBER_THAI_HOT` is the big one.

Save, press <kbd>F5</kbd>, and the simulator reloads.

## Helpful links
- Connect IQ SDK & download: https://developer.garmin.com/connect-iq/sdk/
- API docs: https://developer.garmin.com/connect-iq/api-docs/
- Programmer's guide: https://developer.garmin.com/connect-iq/connect-iq-basics/
- Core topics (watch faces, AMOLED/always-on): https://developer.garmin.com/connect-iq/core-topics/
