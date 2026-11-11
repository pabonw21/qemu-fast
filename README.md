# VM Deploy Script (`vm_deploy.sh`)

A Bash script designed to automate the creation and deployment of hardware-accelerated QEMU/KVM virtual machines with UEFI Secure Boot (OVMF) and TPM 2.0 emulation (`swtpm`).

---

## Prerequisites & Dependencies

To execute `vm_deploy.sh` successfully, the host system must satisfy the following software and hardware requirements:

### 1. Hardware Requirements & Permissions
* **Hardware Virtualization Support**: Intel VT-x or AMD-V enabled in BIOS/UEFI.
* **KVM Kernel Modules**: `kvm` and `kvm_intel` or `kvm_amd`.
* **KVM User Permissions**: The user executing the script must have read/write access to `/dev/kvm`. Add your user to the `kvm` group:
  ```bash
  sudo usermod -aG kvm $USER
  ```
  *(Log out and log back in for changes to take effect).*

### 2. Software Packages
* **`qemu-system-x86_64`**: Main QEMU emulator for the x86_64 architecture.
* **`qemu-img`**: Utility used to generate the `.qcow2` virtual disk image.
* **`swtpm`**: Software TPM emulator supporting TPM 2.0 over Unix domain sockets.
* **UEFI Firmware (`OVMF` / `edk2`)**: Provides the UEFI Secure Boot code and variable store templates.

---

## Package Installation by Distribution

### Ubuntu / Debian
```bash
sudo apt update
sudo apt install qemu-system-x86 qemu-utils swtpm swtpm-tools ovmf
```

### Arch Linux / Manjaro
```bash
sudo pacman -S qemu-desktop qemu-img swtpm edk2-ovmf
```

### Fedora / RHEL
```bash
sudo dnf install qemu-system-x86 qemu-img swtpm swtpm-tools edk2-ovmf
```

---

## Configuring UEFI Firmware Paths

The script uses two variables at the top of `vm_deploy.sh` to locate the UEFI firmware:

* **`OVMF_CODE`**: Read-only UEFI executable firmware code.
* **`OVMF_VARS_TEMPLATE`**: Clean NVRAM template used to initialize each VM's persistent NVRAM variable store (`OVMF_VARS.fd`).

Because file locations and naming conventions differ across Linux distributions, **you must verify and manually adjust these variables in `vm_deploy.sh` according to the host distro being used**:

```bash
# vm config
VM_NAME="$1"
shift

DISK_SIZE="100G"
RAM="6G"
CPU="4"
OVMF_CODE="/path/to/OVMF_CODE..."
OVMF_VARS_TEMPLATE="/path/to/OVMF_VARS..."
```

### Common Paths by Distribution

#### Ubuntu / Debian (Default in current script)
```bash
OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"
OVMF_VARS_TEMPLATE="/usr/share/OVMF/OVMF_VARS_4M.fd"
```
*(On older releases or standard non-4M builds, these may be located at `/usr/share/OVMF/OVMF_CODE.secboot.fd` and `/usr/share/OVMF/OVMF_VARS.fd`, or `/usr/share/OVMF/OVMF_CODE_4M.ms.fd`).*

#### Arch Linux / Manjaro
```bash
OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd"
OVMF_VARS_TEMPLATE="/usr/share/edk2/x64/OVMF_VARS.4m.fd"
```

#### Fedora / RHEL
```bash
OVMF_CODE="/usr/share/edk2/ovmf/OVMF_CODE.secboot.fd"
OVMF_VARS_TEMPLATE="/usr/share/edk2/ovmf/OVMF_VARS.secboot.fd"
```

---

## Why Is `OVMF_VARS_TEMPLATE` Copied for Each VM?

UEFI firmware is split into two components:
1. **`OVMF_CODE` (Read-only)**: Executable instructions shared safely across any number of VMs.
2. **`OVMF_VARS` (Read/Write NVRAM)**: Simulates the non-volatile storage chip where the OS installer registers boot entries (e.g., Windows Boot Manager, GRUB), Secure Boot keys, and firmware settings.

Because the system template in `/usr/share/...` is owned by `root` and cannot be modified by standard users, and to prevent multiple VMs from overwriting each other's boot entries and cryptographic keys, the script creates an isolated per-VM copy (`./OVMF_VARS.fd`) on initial launch:

```bash
[ -f "OVMF_VARS.fd" ] || (cp $OVMF_VARS_TEMPLATE ./OVMF_VARS.fd)
```

This guarantees persistence across reboots without corrupting host files or other virtual machines.

---

## Usage

```bash
./vm_deploy.sh <VM_NAME> [OPTIONS...]
```

### Arguments and Options

* `<VM_NAME>`: Unique identifier and directory name for the virtual machine (automatically created by the script if it does not exist).
* `*.iso`: Up to two `.iso` images passed as arguments (e.g., installer ISO and `virtio-win.iso`).
* `usb`: Enables USB host passthrough for a specific vendor/product ID (defined in the script).

### Example

Deploy a new Windows virtual machine with installer and VirtIO drivers:

```bash
./vm_deploy.sh win11 windows11.iso virtio-win.iso
```

---

## VM Specifications

* **CPU**: 4 vCPUs (`-smp 4`, host pass-through)
* **RAM**: 6 GB
* **Disk**: 100 GB (`qcow2`, VirtIO interface)
* **Firmware**: UEFI with Secure Boot enabled (`q35`, `smm=on`)
* **Security**: Virtual TPM 2.0 (CRB interface via `swtpm`)
* **Graphics**: VirtIO VGA
* **Network**: User-mode networking with VirtIO network adapter (`virtio-net-pci`)
