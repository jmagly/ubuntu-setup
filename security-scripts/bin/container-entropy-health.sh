#!/bin/bash

# For containerized environments where entropy might show as 256

echo "=== Entropy Health Check (Container-Aware) ==="
echo ""

ENTROPY=$(cat /proc/sys/kernel/random/entropy_avail)

if [ "$ENTROPY" = "256" ]; then
    echo "Entropy Pool: 256 (Container/VPS limit - this is normal)"
    
    # Real test is whether random generation works
    echo -n "Random generation test: "
    if timeout 1 head -c 100 /dev/urandom > /dev/null 2>&1; then
        echo "✓ WORKING"
        echo "Status: Your random generation is healthy"
    else
        echo "✗ FAILED"
        echo "Status: Problem with random generation"
    fi
else
    echo "Entropy Pool: $ENTROPY bits"
    if [ $ENTROPY -gt 2000 ]; then
        echo "Status: ✓ Excellent"
    elif [ $ENTROPY -gt 1000 ]; then
        echo "Status: ⚠ Good"
    else
        echo "Status: ✗ Low"
    fi
fi

# Check services
echo ""
echo "Entropy Services:"
systemctl is-active --quiet haveged && echo "✓ haveged: running" || echo "✗ haveged: not running"

# Quick performance test
echo ""
echo -n "Performance test: "
TIME=$(( $(date +%s%N) ))
openssl rand -base64 1024 > /dev/null 2>&1
TIME=$(( $(date +%s%N) - TIME ))
MSEC=$(( TIME / 1000000 ))
echo "Generated 1KB random data in ${MSEC}ms"

if [ $MSEC -lt 100 ]; then
    echo "Performance: ✓ Excellent"
else
    echo "Performance: ⚠ Slow"
fi
