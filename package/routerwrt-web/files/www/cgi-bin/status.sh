#!/bin/sh

echo "Content-Type: application/json"
echo

LOAD="$(cut -d' ' -f1 /proc/loadavg)"

MEM_TOTAL="$(awk '/MemTotal/ {print $2}' /proc/meminfo)"
MEM_AVAIL="$(awk '/MemAvailable/ {print $2}' /proc/meminfo)"

MEM_USED=$((100 - (MEM_AVAIL * 100 / MEM_TOTAL)))

cat <<EOF
{
  "load1": $LOAD,
  "mem_used": $MEM_USED
}
EOF
