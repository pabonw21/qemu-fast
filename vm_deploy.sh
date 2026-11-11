#!/bin/bash

# vm config
VM_NAME="$1"
shift

[[ -z "$VM_NAME" ]] && { echo "### Please type a new valid or existing VM name to run!" >&2; exit 1; }

DISK_SIZE="100G"
RAM="6G"
CPU="4"
OVMF_CODE="/usr/share/OVMF/OVMF_CODE_4M.secboot.fd"
OVMF_VARS_TEMPLATE="/usr/share/OVMF/OVMF_VARS_4M.fd"

cdrom=""
cdrom_count=0
usb=""

for arg in "$@"; do
    case "$arg" in
        usb)
            usb="-device usb-host,vendorid=0x090c,productid=0x1000"
	    ;;
        *.iso)
            if [ "$cdrom_count" -lt 2 ]; then
                cdrom_count=$((cdrom_count + 1))
                cdrom="$cdrom -drive file=../$arg,media=cdrom,id=cdrom${cdrom_count},index=$((cdrom_count - 1))"
            fi
            ;;
	*)
	    echo "### Please try a valid option!"
	    exit 0
    esac
done

# create VM and TPM dirs
mkdir -p $VM_NAME/tpm
cd "$VM_NAME" || exit 1

# create disk
[ -f "$VM_NAME.qcow2" ] || (qemu-img create -f qcow2 "$VM_NAME.qcow2" "$DISK_SIZE")

# run tpm emulator
[ -S "swtpm.sock" ] || (swtpm socket --tpmstate dir=tpm --ctrl type=unixio,path=tpm/swtpm.sock --tpm2 -d && sleep 1)

# copy UEFI vars for persistance
[ -f "OVMF_VARS.fd" ] || (cp $OVMF_VARS_TEMPLATE ./OVMF_VARS.fd)

# running VM
qemu-system-x86_64 -enable-kvm -machine q35,smm=on -cpu host \
    -global driver=cfi.pflash01,property=secure,value=on \
    -smp "$CPU" -m "$RAM" \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="OVMF_VARS.fd" \
    -chardev socket,id=chrtpm,path="tpm/swtpm.sock" \
    -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-crb,tpmdev=tpm0 \
    -drive file="$VM_NAME.qcow2",format=qcow2,if=virtio \
    -nic user,model=virtio-net-pci \
    -device qemu-xhci,id=xhci \
    -device usb-tablet \
    -vga virtio \
    $cdrom \
    $usb \
    -boot menu=on
