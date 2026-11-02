# CSCE 465 — Homework 3, Task 4: Access Control and AppArmor

**Conversation date:** November 2, 2026  
**Participants:** User and OpenAI ChatGPT (GPT-6)  
**Export scope:** An edited Markdown record of the user-visible Task 4 discussion. User-provided command output is retained verbatim; assistant answers are condensed and reformatted for readability, not a byte-for-byte chat export. System instructions, tool metadata, and the uploaded homework PDF are not reproduced.

---

## 1. User — Task 4 breakdown

> Breakdown task 4. Explain each step that needs to done. Walk through setting up the user permissions and explain the App Armor profile.

## 2. Assistant — Task 4: Access Control and AppArmor (30 points)

Task 4 is about **containing the vulnerable program rather than fixing it**. Take the `legacy_log_parser` from Task 1, run it with limited privileges, and use AppArmor to restrict what it can access—even if your buffer overflow successfully redirects execution to `win()`.

The five main steps from pages 5–6 of the assignment:

1. Create a dedicated, low-privilege Linux user named `agentlab`.
2. Configure file permissions so `agentlab` can access only what it needs.
3. Write an AppArmor security profile restricting the parser.
4. Load the profile, execute the original exploit as `agentlab`, and collect denial logs.
5. Explain how the experiment demonstrates discretionary access control (DAC), mandatory access control (MAC), least privilege, and reference monitors.

There are **two independent layers of access control**:

- **Unix permissions (DAC)** determine what the `agentlab` user can access.
- **AppArmor (MAC)** determines what the specific parser program may access.

The intended outcome is that the exploit still reaches `win()` and creates the allowed marker, but a protected decoy read or execution of unrelated programs is denied. This demonstrates defense in depth.

### Step 1 — Create the low-privilege user

```bash
sudo useradd --system --create-home --shell /usr/sbin/nologin agentlab
```

| Argument | Purpose |
|---|---|
| `--system` | Creates a system/service account rather than a normal interactive user |
| `--create-home` | Creates a home directory for `agentlab` |
| `--shell /usr/sbin/nologin` | Prevents ordinary interactive logins |
| `agentlab` | Username |

By running the vulnerable program as `agentlab`, the program inherits a much smaller set of filesystem permissions. Verify the account:

```bash
id agentlab
getent passwd agentlab
```

`nologin` prevents ordinary interactive logins but does not prevent an administrator from running a program under this identity with `sudo -u agentlab`.

### Step 2 — Configure Unix file permissions (DAC)

DAC is based on ownership, permission bits, and optional ACLs. An example of the difference:

```text
-rwxr-xr-x jacob jacob legacy_log_parser
-rw------- root  root  decoy.txt
```

| Resource | Permission needed | Purpose |
|---|---|---|
| Vulnerable parser | Read and execute | Run the program |
| `inbox/` | Traverse | Reach the payload |
| Payload file | Read | Supply the parser's input |
| `markers/` | Write and traverse | Create the marker |
| `decoy.txt` | None | Must remain protected |
| Other project files | None | Not needed |

Directory `x` permission means traversal; it doesn't grant listing (`r`). POSIX ACLs allow precise permissions without making the whole project world-readable.

From the homework directory:

```bash
cd ~/csce465-agentsec/hw3
HW3="$(pwd -P)"
sudo apt install -y acl
```

Assuming the original payload is named `payload.bin`:

```bash
sudo setfacl -m u:agentlab:--x "$HOME"
sudo setfacl -m u:agentlab:--x "$HOME/csce465-agentsec"
sudo setfacl -m u:agentlab:--x "$HW3"

sudo setfacl -m u:agentlab:r-x "$HW3/legacy_log_parser"
sudo setfacl -m u:agentlab:--x "$HW3/inbox"
sudo setfacl -m u:agentlab:r-- "$HW3/inbox/payload.bin"
sudo setfacl -m u:agentlab:-wx "$HW3/markers"
```

Inspect them:

```bash
getfacl "$HW3/legacy_log_parser"
getfacl "$HW3/inbox/payload.bin"
getfacl "$HW3/markers"
```

Verify access as `agentlab`:

```bash
sudo -u agentlab test -x "$HW3/legacy_log_parser" && echo "Parser executable"
sudo -u agentlab test -r "$HW3/inbox/payload.bin" && echo "Payload readable"
sudo -u agentlab test -w "$HW3/markers" && echo "Markers writable"
sudo -u agentlab test -r /opt/agentsec/decoy.txt || echo "Decoy access denied"
```

The decoy created for Task 1 with `chmod 600` should be inaccessible to `agentlab`. This completes the DAC part.

### Step 3 — Understand and write the AppArmor profile

AppArmor is Linux Mandatory Access Control. In addition to asking whether the *user* has access, the kernel checks whether the *specific program* is allowed to perform a requested operation. The two checks are separate.

Rules such as `/etc/ld.so.cache r,` allow reading that file; `audit deny /opt/agentsec/decoy.txt rwklx,` denies and explicitly audits decoy access.

| AppArmor permission | Meaning |
|---|---|
| `r` | Read |
| `w` | Write |
| `m` | Executable memory mapping for shared libraries |
| `x` | Execute |
| `k` | File locking |
| `l` | Creating hard links |

An initial example profile was generated with the local `$HW3` absolute path:

```bash
mkdir -p policy
cat > policy/apparmor.profile <<EOF_PROFILE
profile legacy_log_parser $HW3/legacy_log_parser {
    # Parser executable
    $HW3/legacy_log_parser mr,

    # Read only the selected payload
    $HW3/inbox/payload.bin r,

    # Write only the ret2win marker
    $HW3/markers/ret2win.txt w,

    # Dynamic linker and shared libraries
    /etc/ld.so.cache r,
    /lib/** mr,
    /lib64/** mr,
    /usr/lib/** mr,
    /usr/lib64/** mr,

    # Block and log access to the fake secret
    audit deny /opt/agentsec/decoy.txt rwklx,

    # Block shell and unrelated executable launches
    audit deny /bin/** x,
    audit deny /usr/bin/** x,
}
EOF_PROFILE
```

The key design decisions are: attach the profile to the parser path; permit the payload read; permit only marker output; explicitly deny the protected file; do not grant general execution of other programs; and permit only startup dependencies.

The broad library glob rules are convenient for a starting profile but should be narrowed using `ldd ./legacy_log_parser` as part of demonstrating least privilege.

AppArmor is default-deny for unspecified access in enforce mode. Thus, the parser cannot access arbitrary unlisted files, programs, network operations, or capabilities just because its Unix user could.

### Step 4 — Load the profile and enforce it

Check for AppArmor kernel support:

```bash
sudo aa-status
```

Validate the profile, then load/reload it:

```bash
sudo apparmor_parser -Q policy/apparmor.profile
sudo apparmor_parser -r policy/apparmor.profile
sudo aa-status | grep legacy_log_parser
```

`-Q` checks compilation without loading. The intended final mode is **enforce** (violations blocked and logged), rather than **complain** (violations generally allowed but logged).

### Step 5 — Run the exploit as `agentlab`

```bash
cd ~/csce465-agentsec/hw3
sudo rm -f markers/ret2win.txt
sudo -u agentlab "$HW3/legacy_log_parser" "$HW3/inbox/payload.bin"
ls -l markers/ret2win.txt
```

Use the original Task 1 vulnerable binary and payload, not the hardened Task 3 binary. The program may segfault after `win()` because the overwritten return address doesn't restore normal control flow. That doesn't negate the exploit reaching `win()`.

The desired behavior is: exploit reaches `win()`; marker file creation is allowed; decoy read is denied; unrelated execution remains denied.

Capture logs:

```bash
sudo journalctl -k --since "10 minutes ago" --no-pager | \
  grep -E 'apparmor=.*DENIED|legacy_log_parser'
# or
sudo dmesg | grep -i apparmor
```

An illustrative AppArmor event:

```text
apparmor="DENIED" operation="open"
profile="legacy_log_parser"
name="/opt/agentsec/decoy.txt"
requested_mask="r" denied_mask="r"
```

**Important nuance:** The fake decoy has `chmod 600`, so DAC can already prevent `agentlab` from reading it. A failed read without an AppArmor denial log does not, by itself, demonstrate MAC enforcement. A separate controlled experiment running the same confined parser as root can show AppArmor denying access even where root's DAC permissions would normally allow it:

```bash
sudo "$HW3/legacy_log_parser" "$HW3/inbox/payload.bin"
```

### Step 6 — Explain the security concepts

| Concept | Connection to Task 4 |
|---|---|
| Reference monitor | Kernel enforcement checks access requests |
| Complete mediation | Each protected operation is checked, not just the initial launch |
| Access matrix | Conceptual subject–object–operation permissions table |
| DAC | Unix ownership, mode bits, and ACLs constrain `agentlab` |
| MAC | AppArmor imposes program-specific restrictions even on root |
| Least privilege | Only necessary reads, writes, and runtime operations are allowed |

Example conceptual access matrix:

| Subject | Parser | Payload | Marker | Decoy |
|---|---|---|---|---|
| `agentlab` (DAC) | Execute | Read | Write | Deny |
| Parser (AppArmor) | Run/load | Read | Write | Deny |
| Root (DAC) | Execute | Read | Write | Read |
| Root running confined parser (effective) | Execute | Read | Write | Deny |

The report should include the team contribution statement, profile design mapped to the five requirements, actual denial logs, and a 400–600-word explanation of the textbook concepts. The profile should be submitted as `policy/apparmor.profile`.

**Core distinction:** Task 3 removes the buffer overflow through a bounds check. Task 4 doesn't fix the bug—it contains what the compromised process can do.

---

## 3. User — Making the profile portable

I'm looking into the App Armor profile and I see we need to supply the full path to the parser, payload, and markers. This is going to be different for each user on their machine to supply this FARMOR profile in our report. Should the profile be user-specific or should we create a common path where one profile will work for all users. The agent lab user is already configured and has a home directory. Can the files live in the agent lab's home, or is that not the point of the assignment here? The alternative would be to supply the App Armor profile, but just leave a note to say that the directory path must be fully configured depending on the user.

```text
ldd ./legacy_log_parser
	linux-vdso.so.1 (0x000076dfb6605000)
	libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6 (0x000076dfb6200000)
	/lib64/ld-linux-x86-64.so.2 (0x000076dfb6607000)
```

## 4. Assistant — Portable profile paths and library dependencies

**Recommendation:** Keep the parser and payload in the existing `hw3/` directory and make the AppArmor profile configurable. This provides a reproducible submission without assuming everyone's Linux username or moving the source files.

### Could the files live in `/home/agentlab`?

Yes. AppArmor doesn't require an executable to live in the running user's home directory. `agentlab` can execute a program owned by another user if DAC permits it. The distinctions are:

- **User permissions:** `agentlab` is the account under which the program executes.
- **File location:** Where the executable and payload are stored.
- **AppArmor profile:** What files and actions that executable can access.

The assignment tells students to run HW3 commands from their project folder so relative paths like `markers/ret2win.txt` resolve correctly. It doesn't require moving the parser into the service account's home directory. There is also a security benefit to having the executable owned by an account other than the compromised low-privilege service user.

### Option 1 — Custom AppArmor variable

AppArmor supports variables so repeated absolute paths only have to be configured in one place:

```text
# Change this path for the local VM.
@{HW3_DIR}=/home/USERNAME/csce465-agentsec/hw3

profile legacy_log_parser @{HW3_DIR}/legacy_log_parser {
    # Parser
    @{HW3_DIR}/legacy_log_parser mr,

    # Input payload
    @{HW3_DIR}/inbox/payload.bin r,

    # Marker output
    @{HW3_DIR}/markers/ret2win.txt w,

    # Runtime dependencies
    /etc/ld.so.cache r,
    /lib/x86_64-linux-gnu/libc.so.6 mr,
    /lib64/ld-linux-x86-64.so.2 mr,

    # Protected file
    audit deny /opt/agentsec/decoy.txt rwklx,

    # Prevent unrelated program execution
    audit deny /bin/** x,
    audit deny /usr/bin/** x,
}
```

Students only need to change `@{HW3_DIR}=...`. That AppArmor variable is resolved at profile compilation time; it is not a shell environment variable.

### Your `ldd` output

The output identifies these filesystem-backed runtime dependencies:

- `/lib/x86_64-linux-gnu/libc.so.6`: the C standard library.
- `/lib64/ld-linux-x86-64.so.2`: the dynamic linker/loader.

`linux-vdso.so.1` is supplied by the kernel and is not a normal filesystem library needing a path rule. These findings allow the profile to avoid broad rules like `/usr/lib/** mr,` in favor of precise libraries. Verify resolved symlink paths with `readlink -f` as needed.

### Option 2 — AppArmor's `@{HOME}` variable

```text
#include <tunables/global>

profile legacy_log_parser @{HOME}csce465-agentsec/hw3/legacy_log_parser {
    @{HOME}csce465-agentsec/hw3/legacy_log_parser mr,
    @{HOME}csce465-agentsec/hw3/inbox/payload.bin r,
    @{HOME}csce465-agentsec/hw3/markers/ret2win.txt w,

    # Remaining rules...
}
```

This can match multiple home-directory patterns, but it is not automatically the current user's home directory. It makes the profile more portable at the cost of broader path matching.

### Comparison

| Approach | Portability | Least privilege | Assessment |
|---|---|---|---|
| Hardcoded personal path | Low | Strong | Requires local edits |
| Configurable `@{HW3_DIR}` | Good | Strong | Recommended at that stage |
| Built-in `@{HOME}` wildcard | High | Less precise | Convenient but broader |
| Move files to `/home/agentlab` | High after installation | Depends on ownership | More setup than needed |
| Fixed `/opt/...` path | High after installation | Strong if controlled | More like a production deployment |

An optional setup script could generate the final profile from `pwd -P` and load it. Regardless of location, `agentlab` should not own a writable copy of the executable that it runs.

---

## 5. User — Experiment results and denial logs

Getting the following output for 2 tests:

```text
jacob@hw1-agent:~/csce465-hw3$ sudo -u agentlab ./legacy_log_parser ./inbox/payload.bin
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
Failed to read /opt/agentsec/decoy.txt: Permission denied
Segmentation fault
jacob@hw1-agent:~/csce465-hw3$ sudo journalctl -k --since "10 minutes ago" --no-pager
Nov 02 19:56:02 hw1-agent kernel: legacy_log_pars[4962]: segfault at 0 ip 0000000000000000 sp 00007ffea09be688 error 14 likely on CPU 2 (core 2, socket 0)
Nov 02 19:56:02 hw1-agent kernel: Code: Unable to access opcode bytes at 0xffffffffffffffd6.
Nov 02 19:57:12 hw1-agent kernel: legacy_log_pars[4997]: segfault at 0 ip 0000000000000000 sp 00007ffc2a82acb8 error 14 likely on CPU 1 (core 1, socket 0)
Nov 02 19:57:12 hw1-agent kernel: Code: Unable to access opcode bytes at 0xffffffffffffffd6.
jacob@hw1-agent:~/csce465-hw3$ sudo ./legacy_log_parser ./inbox/payload.bin
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
markers/ret2win.txt: Permission denied
Failed to read /opt/agentsec/decoy.txt: Permission denied
Segmentation fault
jacob@hw1-agent:~/csce465-hw3$ sudo journalctl -k --since "10 minutes ago" --no-pager
Nov 02 19:56:02 hw1-agent kernel: legacy_log_pars[4962]: segfault at 0 ip 0000000000000000 sp 00007ffea09be688 error 14 likely on CPU 2 (core 2, socket 0)
Nov 02 19:56:02 hw1-agent kernel: Code: Unable to access opcode bytes at 0xffffffffffffffd6.
Nov 02 19:57:12 hw1-agent kernel: legacy_log_pars[4997]: segfault at 0 ip 0000000000000000 sp 00007ffc2a82acb8 error 14 likely on CPU 1 (core 1, socket 0)
Nov 02 19:57:12 hw1-agent kernel: Code: Unable to access opcode bytes at 0xffffffffffffffd6.
Nov 02 19:57:55 hw1-agent kernel: legacy_log_pars[5011]: segfault at 0 ip 0000000000000000 sp 00007ffe41775fb8 error 14 likely on CPU 1 (core 1, socket 0)
Nov 02 19:57:55 hw1-agent kernel: Code: Unable to access opcode bytes at 0xffffffffffffffd6.
Nov 02 19:57:55 hw1-agent kernel: audit: type=1400 audit(1793649475.135:180): apparmor="DENIED" operation="capable" class="cap" profile="legacy_log_parser" pid=5011 comm="legacy_log_pars" capability=1  capname="dac_override"
Nov 02 19:57:55 hw1-agent kernel: audit: type=1400 audit(1793649475.135:181): apparmor="DENIED" operation="open" class="file" profile="legacy_log_parser" name="/opt/agentsec/decoy.txt" pid=5011 comm="legacy_log_pars" requested_mask="r" denied_mask="r" fsuid=0 ouid=0
```

It appears that when running the legacy log parser as agent lab the parser is executed and the buffer overflow occurs but the decoy file is denied access the attempt to access the decoy doesn't appear in the log for this so I'm assuming this is due to the earlier change mod permissions and not the app armor profile. When attempting the same command using sudo it appears that the app armor profile does come into play and blocks the decoy read and also the marker's write. Is this an accurate assessment of the log

## 6. Assistant — Interpretation of DAC and MAC test results

**Mostly correct.** The logs show an important difference between DAC (Unix permissions) and MAC (AppArmor), but they do **not** establish that AppArmor's marker file path rule caused the failed marker write.

### Running as `agentlab`

```bash
sudo -u agentlab ./legacy_log_parser ./inbox/payload.bin
```

Output included:

```text
AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
Failed to read /opt/agentsec/decoy.txt: Permission denied
Segmentation fault
```

Conclusions:

- The exploit reached `win()`, evidenced by the attempt to read the decoy.
- The decoy read was denied, consistent with its `chmod 600` Unix permissions.
- There was no corresponding logged AppArmor denial during the `agentlab` test; DAC may have blocked access first.
- The later segfault with instruction pointer `0x0` is consistent with corrupted control flow after returning from `win()`.

No logged AppArmor denial **does not prove the profile was inactive**. DAC and MAC can restrict the same attempted action.

### Running as root

```bash
sudo ./legacy_log_parser ./inbox/payload.bin
```

The kernel recorded:

```text
apparmor="DENIED" operation="capable"
profile="legacy_log_parser"
capname="dac_override"
```

AppArmor denied the root-run process use of `CAP_DAC_OVERRIDE`, which ordinarily lets privileged processes bypass many Unix file permission checks.

The kernel also recorded:

```text
apparmor="DENIED" operation="open"
profile="legacy_log_parser"
name="/opt/agentsec/decoy.txt"
requested_mask="r"
denied_mask="r"
fsuid=0
```

This directly confirms that AppArmor blocked the decoy read even when the process was running as root (`fsuid=0`). This is strong evidence for MAC.

### Why did marker creation fail as root?

The root-run output included:

```text
markers/ret2win.txt: Permission denied
```

However, there was **no file-level AppArmor denial for that marker path** in the supplied log. The `dac_override` capability denial might explain the failure, especially if the directory or existing file has restrictive Unix permissions. Do not claim the marker path rule denied it without a corresponding log.

Suggested checks:

```bash
ls -ld markers
ls -l markers/ret2win.txt
getfacl markers
getfacl markers/ret2win.txt
```

Then reset the marker and rerun as `agentlab`:

```bash
sudo rm -f markers/ret2win.txt
sudo -u agentlab ./legacy_log_parser ./inbox/payload.bin
ls -l markers/ret2win.txt
```

The marker's presence would verify that the program reached `win()` and its intended write was permitted by the combined policies. The assistant recommended **not** adding `capability dac_override` merely to get the root test to write the marker, because that grants an unnecessary privilege.

| Observation | Interpretation |
|---|---|
| `agentlab` executes payload | Vulnerable parser accessible |
| `win()` attempts decoy read | Exploit reached its target |
| `agentlab` read gets permission denied | Consistent with DAC restrictions |
| Root gets AppArmor decoy denial | MAC enforcement confirmed |
| Root gets `dac_override` denial | AppArmor restricts privileged capabilities |
| Program crashes at address `0x0` | Control flow remains corrupted after `win()` |

The two tests together are useful report evidence, but successful marker creation as `agentlab` still needed explicit verification at that point.

---

## 7. User — Moving the runtime experiment into `/opt`

Okay, I've confirmed the AppArmor profile functions as intended. I now want to run this experiment with the legacy parser and payload in the opt directory so that a user does not need to access another user's files The parser program can still be owned by a user help me configure this

*Note: The user sent this request twice with the same wording; it is shown once here.*

## 8. Assistant — Configure a portable `/opt` deployment

**Recommendation:** Put the runtime files in `/opt/csce465-hw3` and keep the fake decoy in `/opt/agentsec/decoy.txt`. This gives everyone the same absolute path, avoids access to another student's home directory, and allows the parser and payload to remain owned by a normal user rather than `agentlab`.

Suggested layout:

```text
/opt/
├── agentsec/
│   └── decoy.txt                 # Protected fake secret
└── csce465-hw3/
    ├── legacy_log_parser        # Owned by regular user
    ├── inbox/
    │   └── payload.bin          # Readable by agentlab
    └── markers/
        └── ret2win.txt          # Created by exploit
```

The original source project remains in `~/csce465-hw3`, and only runtime files are copied.

### Create directories and choose ownership

```bash
sudo install -d -o root -g root -m 755 /opt/csce465-hw3
sudo install -d -o root -g root -m 755 /opt/csce465-hw3/inbox
sudo install -d -o root -g agentlab -m 730 /opt/csce465-hw3/markers
```

| Directory | Owner | Mode | Purpose |
|---|---|---|---|
| `/opt/csce465-hw3` | root | `755` | Allow traversal |
| `inbox/` | root | `755` | Allow traversal to payload |
| `markers/` | `root:agentlab` | `730` | Allow marker creation without listing contents |

### Copy the vulnerable parser and payload

```bash
cd ~/csce465-hw3
sudo install -o "$(id -un)" -g agentlab -m 750 \
  ./legacy_log_parser \
  /opt/csce465-hw3/legacy_log_parser

sudo install -o "$(id -un)" -g agentlab -m 640 \
  ./inbox/payload.bin \
  /opt/csce465-hw3/inbox/payload.bin
```

Expected modes/owners:

```text
-rwxr-x--- jacob agentlab legacy_log_parser
-rw-r----- jacob agentlab payload.bin
```

It is fine for the normal user to own the executable and payload. Keeping parent directories root-owned prevents the compromised `agentlab` process from replacing these files.

### Update the profile to fixed paths

Proposed `policy/apparmor.profile`:

```text
profile legacy_log_parser /opt/csce465-hw3/legacy_log_parser {
    # Parser executable
    /opt/csce465-hw3/legacy_log_parser mr,

    # Payload
    /opt/csce465-hw3/inbox/payload.bin r,

    # Marker output
    /opt/csce465-hw3/markers/ret2win.txt w,

    # Runtime dependencies
    /etc/ld.so.cache r,
    /lib/x86_64-linux-gnu/libc.so.6 mr,
    /usr/lib/x86_64-linux-gnu/libc.so.6 mr,
    /lib64/ld-linux-x86-64.so.2 mr,
    /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 mr,

    # Protected decoy
    audit deny /opt/agentsec/decoy.txt rwklx,

    # Disallow launching shells and other executables
    audit deny /bin/** x,
    audit deny /usr/bin/** x,
}
```

The library paths reflect the user's `ldd` result plus typical resolved symlink equivalents; actual paths should be checked:

```bash
readlink -f /lib/x86_64-linux-gnu/libc.so.6
readlink -f /lib64/ld-linux-x86-64.so.2
```

Validate and load:

```bash
sudo apparmor_parser -Q policy/apparmor.profile
sudo apparmor_parser -r policy/apparmor.profile
sudo aa-status | grep legacy_log_parser
```

If a previous profile is installed in `/etc/apparmor.d`, update it too so it won't reload the wrong attachment on reboot. Suggested persistent installation:

```bash
sudo install -m 644 policy/apparmor.profile \
  /etc/apparmor.d/opt.csce465-hw3.legacy_log_parser
sudo apparmor_parser -r \
  /etc/apparmor.d/opt.csce465-hw3.legacy_log_parser
```

### Verify DAC permissions

```bash
sudo -u agentlab test -x /opt/csce465-hw3/legacy_log_parser \
  && echo "Parser executable"
sudo -u agentlab test -r /opt/csce465-hw3/inbox/payload.bin \
  && echo "Payload readable"
sudo -u agentlab test -w /opt/csce465-hw3/markers \
  && echo "Marker directory writable"
```

All three should succeed.

### Execute from `/opt` and check results

Because `win()` writes the marker using a relative path, execute from `/opt/csce465-hw3`:

```bash
cd /opt/csce465-hw3
sudo rm -f markers/ret2win.txt
sudo -u agentlab ./legacy_log_parser ./inbox/payload.bin
sudo ls -l /opt/csce465-hw3/markers/ret2win.txt
```

The expected file accesses are:

- Allowed marker: `/opt/csce465-hw3/markers/ret2win.txt`.
- Denied fake secret: `/opt/agentsec/decoy.txt`.

Collect the kernel logs:

```bash
sudo journalctl -k --since "5 minutes ago" --no-pager | \
  grep -E 'apparmor=.*DENIED|legacy_log_pars'
```

As before, if DAC denies `agentlab` access to the decoy, the kernel may not emit a separate AppArmor denial for that attempt. An optional root-run test can illustrate MAC independently, clearing the marker first.

### Recommended report explanation

- The vulnerable executable and payload are owned by the regular user.
- Group permissions let `agentlab` execute the parser and read the payload.
- A dedicated marker directory permits the necessary write.
- Root-owned parent directories prevent the service account from replacing executable files.
- The fake decoy remains inaccessible via Unix permissions and is independently denied by AppArmor.
- All students can reproduce the same fixed `/opt/csce465-hw3` profile after documenting the installation procedure.

The assistant recommended this `/opt` approach as a clean separation between the development workspace and the confined runtime installation. The conversation did not include subsequent test results for the `/opt` deployment.

---

## 9. User — Export and AI usage record

Export this conversation to markdown.

Provide an entry for my AI_USAGE.md with this format:

```markdown
## Entry 7: Task 4 Breakdown

**Tool/model and date**: OpenAI ChatGPT (GPT-6), November 2, 2026.

**Purpose**:
**AI Conversation Log files**:
**What I used**:
**What I changed**:
**How I tested it**:
**One error, limitation, or rejected suggestion**:
```

---

## Appendix — Relevant source

The discussion referenced **CSCE 465/765 Homework 3 — From Prompt to Process**, especially Task 4 on pages 5–6, and terminal output supplied by the user. The original PDF was provided to the assistant but is not duplicated in this Markdown file.
