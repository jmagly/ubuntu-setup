#!/bin/bash

echo "=== Security Parameters Verification ==="
echo ""

# Function to check parameter
check_param() {
    local param=$1
    local current=$(sysctl -n $param 2>/dev/null)
    if [ $? -eq 0 ]; then
        echo "✓ $param = $current"
    else
        echo "✗ $param = Not available"
    fi
}

echo "[File System Security]"
check_param "fs.suid_dumpable"
check_param "fs.protected_hardlinks"
check_param "fs.protected_symlinks"
check_param "fs.protected_fifos"
echo ""

echo "[Kernel Security]"
check_param "kernel.kptr_restrict"
check_param "kernel.dmesg_restrict"
check_param "kernel.yama.ptrace_scope"
check_param "kernel.randomize_va_space"
check_param "kernel.sysrq"
check_param "kernel.unprivileged_bpf_disabled"
echo ""

echo "[Network Security]"
check_param "net.ipv4.tcp_syncookies"
check_param "net.ipv4.ip_forward"
check_param "net.ipv4.conf.all.rp_filter"
check_param "net.ipv4.tcp_timestamps"
check_param "net.core.bpf_jit_harden"
echo ""

echo "[TCP Performance/Security]"
check_param "net.ipv4.tcp_congestion_control"
check_param "net.ipv4.tcp_max_syn_backlog"
echo ""

# Check for issues
echo "[Checking for potential issues]"
if [ $(sysctl -n net.ipv4.ip_forward) -eq 1 ]; then
    echo "⚠ IP forwarding is enabled!"
fi

if [ $(sysctl -n kernel.sysrq) -ne 0 ]; then
    echo "⚠ Magic SysRq is enabled!"
fi

# Check entropy (informational only)
echo ""
echo "[System Entropy]"
echo "Available entropy: $(cat /proc/sys/kernel/random/entropy_avail)"
echo "(Should be > 1000 for good performance)"
