#include <tunables/global>

/opt/agentllegacy_log_parser {
    # Read/map the executable itself.
    legacy_log_parser mr,

    # Dynamic linker cache, loader, and C library.
    /etc/ld.so.cache r,
    /{,usr/}lib/x86_64-linux-gnu/libc.so.6 mr,
    /{,usr/}lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 mr,
    /{,usr/}lib64/ld-linux-x86-64.so.2 mr,

    # Only the selected input file may be read.
    tests/ret2win_payload.bin r,

    # Permit the existing marker directory and the one expected marker.
    markers/ rw,
    markers/ret2win.txt w,

    # Explicitly block and log access to the protected decoy.
    audit deny /opt/agentsec/decoy.txt rwklx,

    # Block and log all subsequent program executions, including shells.
    audit deny /** x,
}

#include <tunables/global>

/opt/agentlab/legacy_log_parser {
    # Read/map the executable itself.
    /opt/agentlab/legacy_log_parser mr,

    # Dynamic linker cache, loader, and C library.
    /etc/ld.so.cache r,
    /{,usr/}lib/x86_64-linux-gnu/libc.so.6 mr,
    /{,usr/}lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 mr,
    /{,usr/}lib64/ld-linux-x86-64.so.2 mr,

    # Only the selected input file may be read.
    /opt/agentlab/payloads/payload.bin r,

    # Permit the existing marker directory and the one expected marker.
    /opt/agentlab/markers/ rw,
    /opt/agentlab/markers/ret2win.txt w,

    # Explicitly block and log access to the protected decoy.
    audit deny /opt/agentsec/decoy.txt rwklx,

    # Block and log all subsequent program executions, including shells.
    audit deny /** x,
}