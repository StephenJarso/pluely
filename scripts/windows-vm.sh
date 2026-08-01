#!/bin/bash
# ============================================================
# Windows 10 VM Launcher (No Sudo Required)
# Uses locally-extracted QEMU 8.2.2 with proot and KVM
# ============================================================

set -e

# --- Configuration ---
VM_DIR="$HOME/.local/vm"
QEMU_DIR="$HOME/.local/qemu-local"
DISK_IMAGE="$VM_DIR/windows10.qcow2"
ISO_IMAGE="$VM_DIR/windows10.iso"

# Path to our custom binaries
PROOT_BIN="$HOME/.local/bin/proot"
QEMU_BIN="$QEMU_DIR/usr/bin/qemu-system-x86_64"
QEMU_IMG="$QEMU_DIR/usr/bin/qemu-img"

# VM Resources (tune these if needed)
RAM="6G"           # 6GB RAM (machine has 16GB)
CPUS="4"           # 4 CPU cores (machine has 8)
DISK_SIZE="60G"    # Max virtual disk size (thin-provisioned)

# Set library path for locally-extracted dependencies
export LD_LIBRARY_PATH="$QEMU_DIR/usr/lib/x86_64-linux-gnu${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

# --- Checks ---
if [ ! -f "$PROOT_BIN" ] || [ ! -f "$QEMU_BIN" ]; then
    echo "❌ ERROR: QEMU or PRoot binaries not found."
    echo "   Something went wrong with the setup."
    exit 1
fi

# Create disk if it doesn't exist
if [ ! -f "$DISK_IMAGE" ]; then
    echo "📀 Creating virtual disk ($DISK_SIZE, thin-provisioned)..."
    "$QEMU_IMG" create -f qcow2 "$DISK_IMAGE" "$DISK_SIZE"
fi

# --- Detect boot mode ---
DISK_BYTES=$(stat -c%s "$DISK_IMAGE" 2>/dev/null || echo 0)
INSTALL_MODE=false

if [ "$1" = "install" ]; then
    INSTALL_MODE=true
elif [ "$DISK_BYTES" -lt 5000000 ]; then
    INSTALL_MODE=true
fi

BOOT_ARGS=""
if [ "$INSTALL_MODE" = true ]; then
    if [ ! -f "$ISO_IMAGE" ]; then
        echo "❌ ERROR: Windows ISO not found at $ISO_IMAGE"
        echo "   Download it first."
        exit 1
    fi
    echo "🔧 INSTALL MODE — Booting from ISO..."
    BOOT_ARGS="-cdrom $ISO_IMAGE -boot order=d"
else
    echo "🖥️  Booting Windows from disk..."
fi

# --- Check KVM availability ---
KVM_ARGS="-cpu qemu64"
if [ -w /dev/kvm ]; then
    KVM_ARGS="-enable-kvm -cpu host"
    echo "   ⚡ KVM hardware acceleration: ENABLED"
else
    echo "   🐢 KVM hardware acceleration: DISABLED (will be slower)"
fi

# BIOS/Firmware search paths
BIOS_ARGS="-L $QEMU_DIR/usr/share/qemu -L $QEMU_DIR/usr/share/seabios -L $QEMU_DIR/usr/share/ipxe-qemu -L $QEMU_DIR/usr/lib/ipxe/qemu"

echo "   💾 RAM: $RAM | CPUs: $CPUS"
echo "   📁 Disk: $DISK_IMAGE"
echo ""
echo "   🖱️  Press Ctrl+Alt+G to release mouse grab"
echo "   ⏻  Close the QEMU window to shut down the VM"
echo ""

# --- Launch QEMU inside PRoot to map modular directory ---
# Try GTK display with 3D/GL hardware acceleration first
exec "$PROOT_BIN" -b "$QEMU_DIR/usr/lib/x86_64-linux-gnu/qemu:/usr/lib/x86_64-linux-gnu/qemu" \
    "$QEMU_BIN" \
    $KVM_ARGS \
    $BIOS_ARGS \
    -m "$RAM" \
    -smp "$CPUS" \
    -drive file="$DISK_IMAGE",format=qcow2,if=ide \
    $BOOT_ARGS \
    -drive file="$VM_DIR/virtio-win.iso",media=cdrom,readonly=on \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::13389-:3389 \
    -usb -device usb-tablet \
    -device usb-host,vendorid=0x04f2,productid=0xb681 \
    -vga virtio \
    -display gtk,gl=on \
    -name "Windows 10" \
    2>/dev/null || \
# Fallback to standard GTK display without GL
exec "$PROOT_BIN" -b "$QEMU_DIR/usr/lib/x86_64-linux-gnu/qemu:/usr/lib/x86_64-linux-gnu/qemu" \
    "$QEMU_BIN" \
    $KVM_ARGS \
    $BIOS_ARGS \
    -audiodev pipewire,id=snd0 \
    -device ich9-intel-hda \
    -device hda-duplex,audiodev=snd0 \
    -m "$RAM" \
    -smp "$CPUS" \
    -drive file="$DISK_IMAGE",format=qcow2,if=ide \
    $BOOT_ARGS \
    -drive file="$VM_DIR/virtio-win.iso",media=cdrom,readonly=on \
    -device virtio-net-pci,netdev=net0 \
    -netdev user,id=net0,hostfwd=tcp::13389-:3389 \
    -usb -device usb-tablet \
    -device usb-host,vendorid=0x04f2,productid=0xb681 \
    -vga std \
    -display gtk \
    -name "Windows 10"
