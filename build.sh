#!/bin/bash

set -euo pipefail

linux_version="v7.0"
busybox_version="1_37_1"

root="$PWD"
configs_dir="$root/configs"

initramfs_dir="$root/initramfs"
rootfs_dir="$root/rootfs"

thirdparty_dir="$root/thirdparty"
build_dir="$root/build"

linux_dir="$thirdparty_dir/linux-$linux_version"
busybox_dir="$thirdparty_dir/busybox-$busybox_version"

build_initramfs_dir="$build_dir/initramfs"
build_rootfs_dir="$build_dir/rootfs"
build_iso_dir="$build_dir/iso"

pwdr_cpio="$build_dir/pwdr.cpio"
pwdr_img="$build_dir/pwdr.img"
pwdr_iso="$build_dir/pwdr.iso"

linux_repo="https://github.com/torvalds/linux"
busybox_repo="https://github.com/pwdrlinux/busybox"

mkdir -p "$thirdparty_dir" "$build_dir"

if [[ ! -v MAKEFLAGS ]]; then
    export MAKEFLAGS="-j$(nproc)"
fi

if [[ ! -v CFLAGS ]]; then
    export CFLAGS="-Oz"
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

_require_cmd git make cc cpio zstd grub-mkrescue mksquashfs

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

    cp "$configs_dir/linux.config" .config
    make olddefconfig

    make
)

_build_initramfs_busybox() (
    echo "initramfs: building busybox..."

    _clone_if_needed "$busybox_repo" "$busybox_version" "$busybox_dir"
    cd "$busybox_dir"

    make distclean

    cp "$configs_dir/initramfs/busybox.config" .config
    make oldconfig

    make
    make CONFIG_PREFIX="$build_initramfs_dir" install
)

_build_rootfs_busybox() (
    echo "rootfs: building busybox..."

    _clone_if_needed "$busybox_repo" "$busybox_version" "$busybox_dir"
    cd "$busybox_dir"

    make distclean

    cp "$configs_dir/rootfs/busybox.config" .config
    make oldconfig

    make
    make CONFIG_PREFIX="$build_rootfs_dir" install
)

_build_rootfs() (
    rm -rf "$build_rootfs_dir"
    mkdir -p "$build_rootfs_dir"

    _build_rootfs_busybox
    cd "$build_rootfs_dir"

    cp -a "$rootfs_dir"/. .
    mkdir -p home root
)

_build_initramfs_rootfs() (
    echo "initramfs: creating rootfs..."

    rm -rf "$build_initramfs_dir"
    mkdir -p "$build_initramfs_dir"

    _build_initramfs_busybox
    _build_rootfs

    mksquashfs "$build_rootfs_dir" "$build_initramfs_dir/rootfs.squashfs" \
        -comp zstd

    cd "$build_initramfs_dir"
    cp -a "$initramfs_dir"/. .

    chmod +x init
    mkdir -p dev proc sbin sys usr/bin usr/sbin
)

_build_img() {
    _build_initramfs_rootfs
    echo "creating img..."

    cd "$build_initramfs_dir"
    find . | cpio -ov -H newc > "$pwdr_cpio"

    zstd -6 -T0 -c "$pwdr_cpio" > "$pwdr_img"
}

_build_iso() {
    _build_img

    rm -rf "$build_iso_dir"
    mkdir -p "$build_iso_dir/boot/grub"

    cp "$configs_dir/grub.cfg" "$build_iso_dir/boot/grub"

    _build_linux
    cp "$linux_dir/arch/x86_64/boot/bzImage" "$pwdr_img" "$build_iso_dir/boot"

    echo "creating iso..."
    grub-mkrescue -o "$pwdr_iso" "$build_iso_dir"
}

_build_iso
