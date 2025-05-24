#!/bin/bash

echo "=== Deep Entropy System Check ==="
echo "Date: $(date)"
echo ""

# System info
echo "System Information:"
echo "Kernel: $(uname -r)"
echo "Virtualization: $(systemd-detect-virt)"
echo ""

# Check if entropy is stuck at 256
echo "Checking if entropy is stuck at 256..."
for i in {1..5}; do
    entropy=$(cat /proc/sys/kernel/random/entropy_avail)
    echo "Check $i: $entropy"
    sleep 0.5
done

# Check pool size
echo ""
echo "Entropy pool information:"
poolsize=$(cat /proc/sys/kernel/random/poolsize 2>/dev/null || echo "unknown")
echo "Pool size: $poolsize"
echo "Read wake threshold: $(cat /proc/sys/kernel/random/read_wakeup_threshold 2>/dev/null)"
echo "Write wake threshold: $(cat /proc/sys/kernel/random/write_wakeup_threshold 2>/dev/null)"

# Check if we're in a container with limited entropy
echo ""
echo "Container/VM checks:"
if [ -f /proc/vz/veinfo ]; then
    echo "OpenVZ container detected"
fi
if [ -f /proc/1/cgroup ]; then
    grep -q docker /proc/1/cgroup && echo "Docker container detected"
    grep -q lxc /proc/1/cgroup && echo "LXC container detected"
fi

# Check CPU flags
echo ""
echo "CPU entropy support:"
grep -o -E 'rdrand|rdseed' /proc/cpuinfo | sort | uniq | tr '\n' ' '
echo ""

# Check what's using random devices
echo ""
echo "Processes using /dev/random or /dev/urandom:"
fuser -v /dev/random /dev/urandom 2>&1 | grep -v "kernel"

# Test actual randomness generation
echo ""
echo "Testing actual random generation:"
echo -n "From /dev/urandom: "
head -c 8 /dev/urandom | od -x | head -1
echo -n "From /dev/random: "
timeout 2 head -c 8 /dev/random | od -x | head -1 || echo "Blocked (low entropy)"

# Check haveged actual status
echo ""
echo "Haveged daemon check:"
if pgrep haveged > /dev/null; then
    PID=$(pgrep haveged)
    echo "Haveged PID: $PID"
    echo "Memory usage: $(ps -p $PID -o vsz=) KB"
    echo "CPU time: $(ps -p $PID -o time=)"
    
    # Check if it's actually writing to random
    echo "Checking haveged file descriptors:"
    sudo ls -l /proc/$PID/fd/ 2>/dev/null | grep random
else
    echo "Haveged is NOT running!"
fi
