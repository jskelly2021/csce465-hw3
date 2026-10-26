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

### Setup and Compilation

Create the protected decoy file.

```sh
sudo mkdir -p /opt/agentsec
printf 'FAKE-COURSE-SECRET\n' | sudo tee /opt/agentsec/decoy.txt
sudo chmod 600 /opt/agentsec/decoy.txt
```

Verify the file permissions.

```sh
cat /opt/agentsec/decoy.txt
sudo cat /opt/agentsec/decoy.txt
```

Compile the vulnerable parser from the repo root, `(csce465-hw3/)`.

```sh
gcc -O0 -g -fno-stack-protector -no-pie \
  -Wl,-z,noexecstack \
  -Wall -Wextra \
  -o legacy_log_parser src/legacy_log_parser.c
```

Verify the compiled binary's security properties. Stack canaries and PIE should be disabled, while NX should be enabled.

```sh
checksec --file=./legacy_log_parser
```

### Generate the ret2win payload

Run the python script to generate the payload.

```sh
python3 src/make_payload.py
```

This creates `tests/ret2win_payload.bin`.

### Run the Expirement

Test normal execution. Run the parser with a benign log file. The parser should print the beginning of the log.

```sh
./legacy_log_parser tests/short.log
```

Test the buffer overflow exploit. Remove any existing marker file and run the parser with the payload.

```sh
rm -rf markers/ret2win.txt
./legacy_log_parser tests/ret2win_payload.bin
```

Verify the marker was created.

```sh
ls markers/
```

The payload should redirect execution to `win()`, creating `markers/ret2win.txt` and attempting to read the protected decoy. Reading the protected decoy file should fail without elevated permissions.
