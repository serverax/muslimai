#!/bin/bash
export PATH="/usr/bin:/bin:$PATH"

find . -maxdepth 4 -type d | sort > /tmp/sakina_dirs.txt
find . -maxdepth 5 -type f | grep -Ev 'node_modules|target|build|\.dart_tool|\.git|Pods|DerivedData' | sort > /tmp/sakina_file_inventory.txt
echo "File Inventory Count:"
wc -l /tmp/sakina_file_inventory.txt

grep -Ei 'todo|fixme|stub|mock|placeholder|not implemented|panic|unwrap|demo|fake|disabled' -R . \
  --exclude-dir=.git \
  --exclude-dir=target \
  --exclude-dir=node_modules \
  --exclude-dir=build \
  --exclude-dir=.dart_tool \
  > /tmp/sakina_red_flags.txt || true

echo "Red Flags Count:"
wc -l /tmp/sakina_red_flags.txt
echo "Sample Red Flags:"
head -10 /tmp/sakina_red_flags.txt
