# CSCE 465 Homework 3: From Prompt to Process

## Environment Preparation

Install gcc, gdb, checksec, and AppArmor.

```sh
sudo apt update
sudo apt install -y build-essential gdb binutils checksec apparmor-utils
```

Confirm each was installed.

```sh
gcc --version
gdb --version
checksecd --version
aa-status --help
```
