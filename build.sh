#!/bin/bash

set -euo pipefail

linux_version="v7.0"
busybox_version="1_37_1"

root_dir="$PWD"
src_dir="$root_dir/src"

thirdparty_dir="$root_dir/thirdparty"
build_dir="$root_dir/build"

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

_build_busybox() (
    echo "building busybox..."

    _clone_if_needed "$busybox_repo" "$busybox_version" "$busybox_dir"
    cd "$busybox_dir"

    cp "$src_dir/busybox.config" .config
    make oldconfig

    make install
)

_create_rootfs() (
    echo "creating rootfs..."

    mkdir -p "$rootfs_dir"

    cp -a "$busybox_dir"/_install/* "$rootfs_dir"
    cp "$src_dir/init" "$rootfs_dir/init"

    cd "$rootfs_dir"

    chmod +x init
    mkdir -p dev proc sbin sys usr/bin usr/sbin
)

_create_img() {
    _create_rootfs
    echo "creating img..."

    cd "$rootfs_dir"
    find . | cpio -ov -H newc > "$pwdr_cpio"

    gzip -9c "$pwdr_cpio" > "$pwdr_img"
}

_create_iso() {
    _create_img
    echo "creating iso..."

    mkdir -p "$iso_dir/boot/grub"

    cp "$linux_dir/arch/x86_64/boot/bzImage" "$pwdr_img" "$iso_dir/boot"
    cp "$src_dir/grub.cfg" "$iso_dir/boot/grub"

    grub-mkrescue -o "$pwdr_iso" "$iso_dir"
}

_build_linux
_build_busybox

_create_iso
