profile legacy_log_parser /opt/csce465-hw3/legacy_log_parser {
    # Parser executable
    /opt/csce465-hw3/legacy_log_parser mr,

    # Payload
    /opt/csce465-hw3/inbox/payload.bin r,

    # Marker output
    /opt/csce465-hw3/markers/ret2win.txt w,

    # Runtime dependencies
    /etc/ld.so.cache r,
    /usr/lib/x86_64-linux-gnu/libc.so.6 mr,
    /usr/lib/x86_64-linux-gnu/ld-linux-x86-64.so.2 mr,

    # Protected decoy
    audit deny /opt/agentsec/decoy.txt rwklx,

    # Disallow launching shells and other executables
    audit deny /bin/** x,
    audit deny /usr/bin/** x,
}
