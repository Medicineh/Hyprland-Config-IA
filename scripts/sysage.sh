#!/bin/bash
install=$(stat -c '%W' /)
now=$(date +%s)
diff=$((now - install))
days=$((diff / 86400))
y=$((days / 365))
rest=$((days % 365))
m=$((rest / 30))
d=$((rest % 30))
parts=()
((y > 0)) && parts+=("${y}a")
((m > 0)) && parts+=("${m}m")
parts+=("${d}d")
echo "${parts[*]}"
