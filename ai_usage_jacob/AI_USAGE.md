# AI Usage - Jacob Kelly

## Entry 1:

**Tool/model and date**:

**Purpose**:

**AI Conversation Log files**:

**What I used**:

**What I changed**:

**How I tested it**:

**One error, limitation, or rejected suggestion**:

## Entry 2: Legacy log parser

**Tool/model and date**: OpenAI Codex (GPT-6), October 26, 2026.

**Purpose**: Implement the vulnerable parser and `win()` target.

**AI Conversation Log files**: [Conversation](ai_logs/2026-10-26-legacy-log-parser.md).

**What I used**: Unchecked copy, heap-backed file reading, and non-inline `win()`.

**What I changed**: Required an empty marker file and failure-only marker diagnostics.

**How I tested it**: GCC compilation, parser smoke tests, and a temporary `win()` harness.

**One error, limitation, or rejected suggestion**: Rejected writing text into the marker file.
