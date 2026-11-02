# #include <tunables/global>

# @{REPO}/legacy_log_parser {
#     @{REPO}/legacy_log_parser mr,

#     # Ubuntu ARM64 runtime paths, based on the VM's ldd output.
#     /etc/ld.so.cache r,
#     /{,usr/}lib/aarch64-linux-gnu/libc.so.6 mr,
#     /{,usr/}lib/aarch64-linux-gnu/ld-linux-aarch64.so.1 mr,
#     /{,usr/}lib/ld-linux-aarch64.so.1 mr,

#     @{REPO}/tests/ret2win_payload.bin r,

#     @{REPO}/markers/ rw,
#     @{REPO}/markers/ret2win.txt w,

#     audit deny /opt/agentsec/decoy.txt rwklx,
#     audit deny /** x,
# }

#include <tunables/global>

legacy_log_parser {
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
