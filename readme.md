![Pwdr](assets/logo.svg)

A small live Linux distro.

## Features

- BusyBox utilities
- Bash
- Neofetch
- Runit-like service supervision
- GRUB bootloader

## Building

Make sure you have the dependencies installed:

- Git
- Make
- C compiler
- CPIO
- Zstd
- GRUB (`grub-mkrescue`)
- SquashFS tools (`mksquashfs`)

Clone the repository:

```sh
$ git clone https://github.com/pwdrlinux/pwdrlinux && cd pwdrlinux
```

Build the ISO:

```sh
$ ./build.sh
```

This will produce `build/pwdr.iso`.

## Running in QEMU

```sh
qemu-system-x86_64 -cdrom build/pwdr.iso
```
