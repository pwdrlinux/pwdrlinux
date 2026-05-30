#!/bin/bash

set -euo pipefail

linux_version="v7.0"
busybox_version="1_37_1"

root="$PWD"
configs_dir="$root/configs"
initramfs_dir="$root/initramfs"

thirdparty_dir="$root/thirdparty"
build_dir="$root/build"

linux_dir="$thirdparty_dir/linux-$linux_version"
busybox_dir="$thirdparty_dir/busybox-$busybox_version"

rootfs_dir="$build_dir/rootfs"
iso_dir="$build_dir/iso"

pwdr_cpio="$build_dir/pwdr.cpio"
pwdr_img="$build_dir/pwdr.img"
pwdr_iso="$build_dir/pwdr.iso"

linux_repo="https://github.com/torvalds/linux"
busybox_repo="https://github.com/pwdrlinux/busybox"

mkdir -p "$thirdparty_dir" "$build_dir"

if [[ ! -v MAKEFLAGS ]]; then
    export MAKEFLAGS="-j$(nproc)"
fi

_error() {
    echo "error: $@" >&2
}

_fatal() {
    _error "$@"
    exit 1
}

_has_cmd() {
    command -v "$@" > /dev/null
}

_require_cmd() {
    for cmd in "$@"; do
        if ! _has_cmd "$cmd"; then
            _fatal "$cmd: not found"
        fi
    done
}

_require_cmd git make cc cpio gzip grub-mkrescue

_clone_if_needed() {
    local repo="$1"
    local tag="$2"
    local dir="$3"

    if [[ ! -d "$dir" ]]; then
        mkdir -p "$(dirname "$dir")"
        git clone --depth 1 "$repo" -b "$tag" "$dir"
    fi
}

_build_linux() (
    echo "building kernel..."

    _clone_if_needed "$linux_repo" "$linux_version" "$linux_dir"
    cd "$linux_dir"

    make defconfig
    make
)

_build_initramfs_busybox() (
    echo "initramfs: building busybox..."

    _clone_if_needed "$busybox_repo" "$busybox_version" "$busybox_dir"
    cd "$busybox_dir"

    cp "$configs_dir/initramfs/busybox.config" .config
    make oldconfig

    make CONFIG_PREFIX="$rootfs_dir" install
)

_build_initramfs_rootfs() (
    echo "initramfs: creating rootfs..."

    rm -rf "$rootfs_dir"
    mkdir -p "$rootfs_dir"

    cp -a "$initramfs_dir"/* "$rootfs_dir"

    _build_initramfs_busybox

    cd "$rootfs_dir"

    chmod +x init
    mkdir -p dev proc sbin sys usr/bin usr/sbin
)

_build_img() {
    _build_initramfs_rootfs
    echo "creating img..."

    cd "$rootfs_dir"
    find . | cpio -ov -H newc > "$pwdr_cpio"

    gzip -9c "$pwdr_cpio" > "$pwdr_img"
}

_build_iso() {
    _build_img

    rm -rf "$iso_dir"
    mkdir -p "$iso_dir/boot/grub"

    cp "$configs_dir/grub.cfg" "$iso_dir/boot/grub"

    _build_linux
    cp "$linux_dir/arch/x86_64/boot/bzImage" "$pwdr_img" "$iso_dir/boot"

    echo "creating iso..."
    grub-mkrescue -o "$pwdr_iso" "$iso_dir"
}

_build_iso
