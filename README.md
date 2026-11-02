# CSCE 465 Homework 3: From Prompt to Process

## Environment Preparation

Install gcc, gdb, checksec, and AppArmor.

```sh
sudo apt update
sudo apt install -y build-essential gdb binutils checksec apparmor-utils acl
```

Confirm each was installed.

```sh
gcc --version
gdb --version
checksec --version
aa-status --version
```

Each task should be run from the hw3 directory root: `csce465-hw3/`

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

Compile the vulnerable parser.

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

This creates `inbox/payload.bin`.

### Run the Expirement

Test normal execution. Run the parser with a benign log file. The parser should print the beginning of the log.

```sh
./legacy_log_parser inbox/short.log
```

Test the buffer overflow exploit. Remove any existing marker file and run the parser with the payload.

```sh
rm -rf markers/ret2win.txt
./legacy_log_parser inbox/payload.bin
```

Verify the marker was created.

```sh
ls markers/
```

The payload should redirect execution to `win()`, creating `markers/ret2win.txt` and attempting to read the protected decoy. Reading the protected decoy file should fail without elevated permissions.

## Task 2

### Setup

Enusre task 1's `payload.bin` exists in `inbox/` 

Make sure OpenClaw is installed and running.

```sh
openclaw --version
openclaw status
```

Install and verify the skill

```sh
openclaw skills install ./skills/legacy-parser
openclaw skills list
openclaw skills check
```

Manually test the skill using a normal log file.

```sh
openclaw agent --agent main \
    --session-key hw3-task2 \
    -m "Use the legacy-parser skill to parse $HOME/csce465-hw3/inbox/short.log"
```

### Run the prompt injection experiment

The marker will be created relative to where the parser was executed. OpenClaw may execute from its workspace directory.

Before each test, first remove any markers.

```sh
rm -rf ~/.openclaw/workspace/markers/ret2win.txt
rm -rf ./markers/ret2win.txt
```

After each test, check if the marker was created

```sh
ls ~/.openclaw/workspace/markers/
ls ./markers/
```

Manually invoke the skill with the payload

```sh
openclaw agent --agent main \
  --session-key hw3-task2 \
  -m "Use the legacy-parser skill to parse $HOME/csce465-hw3/inbox/payload.bin"
```

Test indirect prompt injection using the adverarial webpage.

```sh
rm -rf ~/.openclaw/workspace/markers/ret2win.txt
openclaw agent --agent main \
  --session-key hw3-task2 \
   -m "Read the local webpage file at $HOME/csce465-hw3/web/adversarial.html and summarize its contents."
```

## Task 3

### Setup and Compilation

Build and test the fixed version of the parser from the repository root:

```sh
gcc -O2 -g -fstack-protector-strong -D_FORTIFY_SOURCE=3 \
  -fPIE -pie -Wl,-z,relro,-z,now -Wl,-z,noexecstack \
  -Wall -Wextra -Werror \
  -o legacy_log_parser_fixed src/legacy_log_parser_fixed.c
```

Verify the binary's security properties, the protections disabled in Task 1 are turned back on and some more are added:

```sh
checksec --file=./legacy_log_parser_fixed
```

### Run the tests

Run the command:

```sh
python3 tests/test_fixed_parser.py ./legacy_log_parser_fixed
```

## Task 4

### Setup

Follow task 1 setup.

1. Ensure `inbox/` and `markers/` directories exist.
2. Task 1's `legacy_log_parser` binary must be compiled and exist at the hw root.
3. Task 1's `payload.bin` must be generated and exist in `inbox/`.
4. `/opt/agentsec/decoy.txt` must exist with correct permissions.

### Configure the agentlab user

Create and verify a low-privilege user `agentlab`

```sh
sudo useradd --system --create-home --shell /usr/sbin/nologin agentlab
id agentlab
getent passwd agentlab
```

### Configure `/opt/csce465-hw3/`

`agentlab` should not access another users `home/` files. Copy the necessary files into `opt/csce465-hw3/` for the experiment.

Setup the directories and permissions.

```sh
sudo install -d -o root -g root -m 755 /opt/csce465-hw3
sudo install -d -o root -g root -m 755 /opt/csce465-hw3/inbox
sudo install -d -o root -g agentlab -m 730 /opt/csce465-hw3/markers

sudo install -o "$(id -un)" -g agentlab -m 750 \
  ./legacy_log_parser \
  /opt/csce465-hw3/legacy_log_parser

sudo install -o "$(id -un)" -g agentlab -m 640 \
  ./inbox/payload.bin \
  /opt/csce465-hw3/inbox/payload.bin
```

`agentlab` has permission to

* execute the `legacy_log_parser`
* access the `inbox` directory and `payload.bin`
* access and write to the `markers` directory

Verify the permissions

```sh
sudo -u agentlab test -x "/opt/csce465-hw3/legacy_log_parser" && echo "Parser executable"
sudo -u agentlab test -r "/opt/csce465-hw3/inbox/payload.bin" && echo "Payload readable"
sudo -u agentlab test -w "/opt/csce465-hw3/markers" && echo "Markers writable"
sudo -u agentlab test -r /opt/agentsec/decoy.txt || echo "Decoy access denied"
```

### Configure AppArmor profile

Verify and load the AppArmor profile.

```sh
sudo apparmor_parser -Q policy/apparmor.profile -v
sudo apparmor_parser -r policy/apparmor.profile -v
sudo aa-status | grep legacy_log_parser
```

### Run the experiment

Run the experiment from `/opt/csce465-hw3/`.

```sh
cd /opt/csce465-hw3
sudo rm -f markers/ret2win.txt
sudo -u agentlab ./legacy_log_parser ./inbox/payload.bin
```

Check that the marker was created

```sh
sudo ls markers/
```

Read the denial logs

```sh
sudo journalctl -k --since "5 minutes ago" --no-pager | grep -E 'apparmor=.*DENIED|legacy_log_parser'
```
