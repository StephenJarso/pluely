# 🖥️ Windows VM for Stealth Mode on Linux

> **Problem:** Pluely's stealth mode (invisible to screen shares) works on Windows (`WDA_EXCLUDEFROMCAPTURE`) and macOS (`NSWindowSharingNone`), but **Linux has no OS-level API** to exclude a window from screen capture. The `contentProtected: true` Tauri setting is essentially a no-op on X11/Wayland.
>
> **Solution:** Run a Windows 10 VM locally via QEMU with KVM hardware acceleration. Install Pluely inside the Windows VM where stealth mode works natively. When you share your entire Linux screen, the QEMU window shows only the Windows desktop — Pluely's overlay inside is invisible to the screen share viewer.

---

## Quick Start

```bash
# Open a new terminal (or reload your shell)
source ~/.zshrc

# First time — boot from Windows installer ISO
windows install

# After Windows is installed — normal boot
windows
```

That's it. Type **`windows`** in any terminal to launch the VM.

---

## Why This Works

Pluely's stealth implementation is in [`src-tauri/src/window.rs`](src-tauri/src/window.rs):

```rust
// Windows: Exclude window from ALL screen capture APIs
#[cfg(target_os = "windows")]
fn set_window_excluded_from_capture(window: &WebviewWindow) {
    use windows::Win32::UI::WindowsAndMessaging::{
        SetWindowDisplayAffinity, WDA_EXCLUDEFROMCAPTURE
    };
    let _ = unsafe { SetWindowDisplayAffinity(hwnd, WDA_EXCLUDEFROMCAPTURE) };
}
```

| Platform | Stealth API | Works? |
|----------|-------------|--------|
| **Windows** | `SetWindowDisplayAffinity(WDA_EXCLUDEFROMCAPTURE)` | ✅ Yes |
| **macOS** | `NSWindowSharingNone` via `contentProtected: true` | ✅ Yes |
| **Linux** | None — `contentProtected` is a no-op | ❌ No |

### 3. Interview Workflow

1. On Linux host: start your interview screen share (share entire screen)
2. Type `windows` in terminal → VM opens showing Windows desktop with Chrome
3. Pluely runs inside Windows with full stealth mode (`WDA_EXCLUDEFROMCAPTURE`)
4. Interviewer sees: your Windows desktop + Chrome. **Never sees Pluely.**

---

## Free Local AI (No Keys Needed)

To run Pluely completely free without paying for API keys, you can use **Ollama** to run models locally.

### Option A: Run Ollama on Linux Host (Recommended - Faster & Saves VM RAM)

Running Ollama on your Linux host allows it to directly access your GPU for extremely fast responses.

1. **Install Ollama on Linux Host:**
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   ```
2. **Configure Ollama to accept external connections (needed for VM):**
   - By default, Ollama only listens to `localhost`. We need it to listen to all interfaces so the VM can reach it.
   - Edit the systemd service or run it manually with `OLLAMA_HOST=0.0.0.0`:
     ```bash
     OLLAMA_HOST=0.0.0.0 ollama serve
     ```
3. **Download a model (e.g., Llama 3 or Qwen 2.5):**
   ```bash
   ollama run llama3
   # or for a lightweight coding model:
   ollama run qwen2.5:7b
   ```
4. **Inside Pluely (VM):**
   - Go to **Settings** → **AI Provider**.
   - Disable **Use Pluely API** (this enables custom providers).
   - Select **Ollama Host** (`ollama-host`) as the provider.
   - Set the model name to `llama3` or `qwen2.5:7b`.
   - Set the API Key field to any placeholder (e.g. `free`) since Ollama doesn't require keys.

### Option B: Run Ollama inside Windows VM

If you prefer to keep everything inside the VM, you can install Ollama directly in Windows:

1. Download and run the Windows installer from **[ollama.com/download/windows](https://ollama.com/download/windows)**.
2. Open Command Prompt inside Windows and run:
   ```cmd
   ollama run llama3
   ```
3. **Inside Pluely (VM):**
   - Go to **Settings** → **AI Provider**.
   - Disable **Use Pluely API**.
   - Select **Ollama** (`ollama`) as the provider (points to `localhost:11434`).
   - Set model to `llama3`.

---

## Installation Details

### What Was Installed

Everything is installed in **userspace** under `~/.local/`. **No sudo was used.**

#### QEMU, PRoot, & Dependencies (extracted via `apt download` + `dpkg -x`)

| Package / Bin | Version | Purpose |
|---------------|---------|---------|
| `proot` | 5.4.0 (GitLab static) | Userspace bind-mount engine to solve module path limit |
| `qemu-system-x86` | 8.2.2 | Main x86_64 VM emulator |
| `qemu-system-gui` | 8.2.2 | GTK/SDL UI display plugins |
| `qemu-system-modules-opengl` | 8.2.2 | OpenGL display interface plugin |
| `qemu-system-common` | 8.2.2 | Shared QEMU components |
| `qemu-system-data` | 8.2.2 | BIOS/firmware data |
| `qemu-utils` | 8.2.2 | `qemu-img` disk management |
| `seabios` | 1.16.3 | PC BIOS firmware |
| `ipxe-qemu` | 1.21.1 | Network boot ROMs |
| `libaio1t64` | 0.3.113 | Async I/O library |
| `libfdt1` | 1.7.0 | Flattened Device Tree lib |
| `libpmem1` | 1.13.1 | Persistent memory lib |
| `librdmacm1t64` | 50.0 | RDMA connection manager |
| `liburing2` | 2.5 | io_uring library |
| `libndctl6` | 77 | NVM device control |
| `libdaxctl1` | 77 | DAX device control |
| `aria2` | 1.37.0 | Multi-connection downloader |
| `libaria2-0` | 1.37.0 | aria2 shared library |
| `libssh2-1t64` | 1.11.0 | SSH2 library |

#### OS & Driver ISOs

| Item | Details |
|------|---------|
| **Windows 10 ISO** | Windows 10 Enterprise Evaluation (22H2) (~5.2 GB)<br>Source: Microsoft Official CDN |
| **VirtIO Drivers ISO** | Fedora stable `virtio-win.iso` (~754 MB)<br>Source: Fedora Project (contains network & hardware drivers) |

#### Virtual Disk

| Item | Value |
|------|-------|
| **Format** | QCOW2 (thin-provisioned, copy-on-write) |
| **Max size** | 60 GB |
| **Actual size** | Grows as Windows uses space |
| **Location** | `~/.local/vm/windows10.qcow2` |

---

### Directory Structure

```
~/.local/
├── bin/
│   └── proot                      # PRoot static binary
├── qemu-local/                    # Extracted QEMU + dependencies
│   └── usr/
│       ├── bin/
│       │   ├── qemu-system-x86_64 # Main emulator binary
│       │   ├── qemu-img           # Disk management tool
│       │   └── aria2c             # Download accelerator
│       ├── lib/x86_64-linux-gnu/  # Shared libraries & UI plugins (.so)
│       └── share/
│           ├── qemu/              # QEMU firmware/data
│           └── seabios/           # BIOS firmware
├── vm/
│   ├── windows.sh                 # Launch script (aliased as 'windows')
│   ├── windows10.iso              # Windows installer ISO (~5.2 GB)
│   ├── virtio-win.iso             # VirtIO drivers ISO (~754 MB)
│   └── windows10.qcow2            # Virtual disk (grows up to 60 GB)
└── vm-setup/                      # Downloaded .deb packages (safe to delete)
```

---

## VM Configuration

| Setting | Value |
|---------|-------|
| **RAM** | 6 GB (host has 16 GB) |
| **CPU Cores** | 4 (host has 8) |
| **KVM Acceleration** | ✅ Enabled via `/dev/kvm` ACL |
| **Networking** | User-mode NAT (internet works out of the box) |
| **Display** | SDL Window / GTK window |
| **Mouse** | USB Tablet (no grab needed) |
| **Disk** | IDE Interface (out-of-box install) |
| **RDP** | Port forwarded: `localhost:13389 → VM:3389` |

---

## How to Use

### 1. First Boot & Windows Installation

```bash
windows install
```

1. The VM boots from the Windows ISO.
2. When the installer wizard opens:
   - Click **"I don't have a product key"**.
   - Select **Windows 10 Enterprise**.
   - Choose **"Custom: Install Windows only"**.
   - Select the 60GB drive (Drive 0) and click **Next** (visible immediately because we fallback to IDE interface).
   - Wait for the setup to complete (~15 mins).
3. On the configuration wizard (OOBE):
   - When asked to connect to a network, click **"I don't have internet"** in the bottom left.
   - On the next screen, click **"Continue with limited setup"**.
   - Create a local username and password.

---

### 2. Install Network Drivers (Get Internet Connection)

Once you reach the Windows desktop, the internet is not active yet. Follow these steps to load the drivers:

1. Open **File Explorer** (shortcut `Win + E`).
2. Click on **"This PC"** in the left sidebar.
3. Locate the CD-ROM drive called **`virtio-win`** and double-click to open it.
4. Locate and run the driver installer: **`virtio-win-gt-x64.msi`** (double-click).
5. Follow the setup wizard and accept all driver installations.
6. The moment it completes, the network adapter will activate and you will be connected to the internet!
7. **Now install:**
   - Chrome (via Edge browser).
   - Pluely for Windows (from [pluely.com/download/windows](https://pluely.com/download/windows)).

---

### 3. Normal Usage (Stealth Interview Workflow)

To launch the VM for future sessions:

```bash
windows
```

1. On your Linux host, share your entire screen on Zoom, Google Meet, Teams, or Pluely screen capture.
2. Launch the VM.
3. Once the VM opens, press **`Ctrl + Alt + F`** to toggle **Fullscreen Mode**. This hides the Ubuntu desktop, docks, top bar, and VM window frames.
4. Open **Display settings** inside Windows and set resolution to match your screen (e.g., **`1920x1080`**) to remove any blurriness.
5. Run Pluely inside the VM. The interview tool/viewer will see your Windows screen and Chrome browser, but the Pluely interface will remain **completely invisible** to them!

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| **`Ctrl + Alt + F`** | Toggle Fullscreen (hides Ubuntu dock/UI completely) |
| **`Ctrl + Alt + G`** | Release mouse grab from VM window |
| **`Ctrl + Alt + 1`** | Switch to main VGA display view |
| **`Ctrl + Alt + 2`** | Switch to QEMU monitor console |

---

## Tuning (Optional)

Edit `~/.local/vm/windows.sh` to adjust resource allocations:

```bash
RAM="8G"     # More RAM for heavy Chrome tabs
CPUS="6"     # More CPU cores for smoother rendering
```

---

## How to Remove Everything

To completely uninstall the VM and reclaim disk space:

```bash
# 1. Remove all VM files, QEMU, and downloaded packages
rm -rf ~/.local/vm ~/.local/qemu-local ~/.local/vm-setup

# 2. Remove the 'windows' command alias from your shells
sed -i '/alias windows=/d' ~/.zshrc ~/.bashrc

# 3. Reload your shell
source ~/.zshrc
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `KVM acceleration: DISABLED` | `/dev/kvm` not accessible. VM runs but ~10x slower. Ask sysadmin to add you to `kvm` group |
| Double free / memory crashes | GTK backend crashed. The script automatically falls back to `-display sdl` which is stable |
| No internet in VM | Run the `virtio-win-gt-x64.msi` installer from the mounted `virtio-win` CD-ROM drive inside Windows |
| Windows screen is blurry | Change the display resolution inside Windows Settings to match your monitor resolution (e.g. `1920x1080`) |
| Evaluation expired (90 days) | Run `slmgr /rearm` in command prompt (extends 3 times), or reinstall |
