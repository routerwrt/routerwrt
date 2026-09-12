#!/bin/sh

echo "Content-Type: text/plain"
echo

dmesg | tail -n 120
