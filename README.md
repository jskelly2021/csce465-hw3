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

## Task 1

Create the fake protected file.

```sh
sudo mkdir -p /opt/agentsec
printf 'FAKE-COURSE-SECRET\n' | sudo tee /opt/agentsec/decoy.txt
sudo chmod 600 /opt/agentsec/decoy.txt
```

Test access to the file. Only the file owner can read and write the file.

```sh
cat /opt/agentsec/decoy.txt
sudo cat /opt/agentsec/decoy.txt
```

Compile the vulnerable parser from the repo root, `csce465-hw3/`.

```sh
gcc -O0 -g -fno-stack-protector -no-pie \
  -Wl,-z,noexecstack \
  -Wall -Wextra \
  -o legacy_log_parser src/legacy_log_parser.c
```

Check the security properties. The canary and PIE should be disabled. 

```sh
checksec --file=./legacy_log_parser
```
