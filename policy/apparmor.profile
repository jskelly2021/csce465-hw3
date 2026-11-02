#include <tunables/global>

/opt/agentlab/legacy_log_parser {
    /opt/agentlab/legacy_log_parser mr,

    /etc/ld.so.cache r,
    /{,usr/}lib/aarch64-linux-gnu/libc.so.6 mr,
    /{,usr/}lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 mr,
    /{,usr/}lib/ld-linux-aarch64.so.1 mr,

    /opt/agentlab/payloads/payload.bin r,

    /opt/agentlab/markers/ rw,
    /opt/agentlab/markers/ret2win.txt w,

    audit deny /opt/agentsec/decoy.txt rwklx,
    audit deny /** x,
}