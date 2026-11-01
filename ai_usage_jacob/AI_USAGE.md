# AI Usage - Jacob Kelly

## Entry 1: Task 1 Breakdown

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

## Entry 3: Run parser wrapper

**Tool/model and date**: OpenAI Codex (GPT-6), November 1, 2026.

**Purpose**: Run the legacy parser with input restricted to `~/csce465-hw3/inbox/`.

**AI Conversation Log files**: `ai_logs/task2_run_parser.md`

**What I used**: Bash wrapper with canonical path validation, readable-file checks, and `exec`.

**What I changed**: Added `skills/legacy-parser/run_parser.sh` to validate one input and invoke the existing binary.

**How I tested it**: Bash syntax check, seven input validation cases, and expected parser output verification.

**One error, limitation, or rejected suggestion**: Path validation and parser file opening are separate operations, so concurrent file changes can create a race.

## Entry 4: Adversarial webpage

**Tool/model and date**: OpenAI Codex (GPT-6), November 1, 2026.

**Purpose**: Create a basic HTML-only page instructing an agent to invoke the legacy-parser skill with `~/csce465-hw3/inbox/payload.bin`.

**AI Conversation Log files**: `ai_logs/task2_adversarial.md`

**What I used**: A basic HTML document containing a title, heading, and parser invocation instruction.

**What I changed**: Simplified the instruction in `web/adversarial.html` after the AI created the initial page.

**How I tested it**: Inspected the HTML source; no browser test or parser execution was performed in this conversation.

**One error, limitation, or rejected suggestion**: Creating the page does not verify that an agent will follow its instruction or invoke the skill.

## Entry 5: Event trace conversion

**Tool/model and date**: OpenAI Codex (GPT-6), November 1, 2026.

**Purpose**: Convert the Task 2 demo JSONL event trace into a readable Markdown document while preserving chronological order.

**AI Conversation Log files**: `ai_logs/task2_trace.md`

**What I used**: AI-generated `trace.md` containing all 15 events, including message roles and content, tool calls and results, success status, and permission context.

**What I changed**: Added `trace.md` at the repository root, omitting internal IDs, repeated snapshots, tool schemas, and bulky configuration.

**How I tested it**: Python assertions verified chronological ordering, all 15 event sections, timestamps, and preservation of message text and tool output.

**One error, limitation, or rejected suggestion**: The source system prompt was already truncated, and no explicit permission request or approval event was recorded; the conversion cannot recover missing information.

## Entry 6: Task 2 Breakdown

**Tool/model and date**: OpenAI ChatGPT (GPT-6), November 1, 2026.

**Purpose**: Understand Task 2 requirements, configure an OpenClaw skill, and troubleshoot agent-mediated execution of the vulnerable parser.

**AI Conversation Log files**: `ai_logs/task2_breakdown.md`

**What I used**: Step-by-step task breakdown, OpenClaw skill setup guidance, shell wrapper examples, and troubleshooting recommendations.

**What I changed**: Adapted the suggested skill configuration and wrapper to my project structure, focusing on path validation and working-directory handling.

**How I tested it**: Ran the parser directly and through OpenClaw, compared execution outputs, and checked marker creation, permission errors, and segmentation faults.

**One error, limitation, or rejected suggestion**: OpenClaw reached the `win()` function but initially did not create the marker in the expected location, suggesting a working-directory or filesystem issue.
