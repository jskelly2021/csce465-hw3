# AI Usage - Jacob Kelly

## Entry 1:

**Tool/model and date:** OpenAI ChatGPT (GPT-6), October 24–26, 2026.

**Purpose:** Understand HW3 Task 1 requirements, parser structure, stack overflow exploitation, and dependencies for Task 3. Clarify log printing, NOP sled usage, and Unix file permissions.

**AI Conversation Log files:** `ai_logs/task1_conversation.md`

**What I used:** Guidance on program structure, GDB offset analysis, payload construction, and explanations of ret2win versus traditional stack code injection.

**What I changed:** Implemented and adjusted my own vulnerable parser and exploit. Used the empirically determined 136-byte return-address offset rather than assuming a fixed value.

**How I tested it:** Executed the payload against the vulnerable parser and confirmed that `win()` ran. Verified that reading the protected decoy remained blocked and that changing the payload offset caused the exploit to fail.

**One error, limitation, or rejected suggestion:** Considered using a NOP sled but determined it was unnecessary for ret2win, since the exploit redirects execution to an existing function rather than executing injected stack code.

## Entry 2: Legacy log parser

**Tool/model and date**: OpenAI Codex (GPT-6), October 26, 2026.

**Purpose**: Implement the vulnerable parser and `win()` target.

**AI Conversation Log files**: `ai_logs/legacy_log_parser.md`

**What I used**: Unchecked copy, heap-backed file reading, and non-inline `win()`.

**What I changed**: Required an empty marker file and failure-only marker diagnostics.

**How I tested it**: GCC compilation, parser smoke tests, and a temporary `win()` harness.

**One error, limitation, or rejected suggestion**: Rejected writing text into the marker file.
