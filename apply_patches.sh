#!/usr/bin/env bash
set -euo pipefail

RTL_DIR="${1:-fpga_core/rtl}"
SCHED="$RTL_DIR/scheduler.sv"
MICRO="$RTL_DIR/microcode_rom.sv"

echo ">> RTL dir: $RTL_DIR"

# ---- scheduler.sv patch ----
if [[ -f "$SCHED" ]]; then
  [[ -f "$SCHED.bak" ]] || cp "$SCHED" "$SCHED.bak"

  # Replace nonblocking '<=' with blocking '=' ONLY inside the first always_comb...end block.
  python3 - "$SCHED" <<'PYCODE'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
s = p.read_text()

# Find the first always_comb block (handles nested begin/end by counting)
start = None
for m in re.finditer(r'\balways_comb\b', s):
    start = m.start()
    break

if start is None:
    print("No always_comb found; skipping scheduler.sv patch")
    sys.exit(0)

# Find 'begin' after always_comb
begin_m = re.search(r'\bbegin\b', s[start:])
if not begin_m:
    print("No 'begin' after always_comb; aborting")
    sys.exit(1)

i = start + begin_m.end()
depth = 1
end_idx = None
while i < len(s):
    m = re.search(r'\bbegin\b|\bend\b', s[i:])
    if not m: break
    tok = m.group(0)
    i2 = i + m.end()
    if tok == 'begin':
        depth += 1
    else:
        depth -= 1
        if depth == 0:
            end_idx = i + m.start()
            break
    i = i2

if end_idx is None:
    print("Matching 'end' for always_comb not found; aborting")
    sys.exit(1)

pre = s[:start]
mid = s[start:end_idx]
post = s[end_idx:]

# In the ALWAYS_COMB region, convert '<=' that are real nonblocking assigns to '='
# Heuristic: replace '<=' when it looks like assignment (surrounded by identifiers)
mid_fixed = re.sub(r'(?P<lhs>\b[\w\[\]\.]+\s*)<=', r'\g<lhs>=', mid)

new = pre + mid_fixed + post
if new != s:
    p.write_text(new)
    print("Patched scheduler.sv always_comb <= -> =")
else:
    print("No changes made to scheduler.sv (already clean?)")
PYCODE

  echo ">> Diff for scheduler.sv (context):"
  diff -u "$SCHED.bak" "$SCHED" || true
else
  echo "WARNING: $SCHED not found; skipping"
fi

# ---- microcode_rom.sv patch ----
if [[ -f "$MICRO" ]]; then
  [[ -f "$MICRO.bak" ]] || cp "$MICRO" "$MICRO.bak"

  # Append ', 4'b0' before '};' on lines that assign to 'data = { ... };' and do NOT already include 4'b0
  python3 - "$MICRO" <<'PYCODE'
import sys, re, pathlib
p = pathlib.Path(sys.argv[1])
lines = p.read_text().splitlines()
out = []
changed = False

for line in lines:
    if re.search(r'\bdata\s*=\s*\{.*\};', line) and "4'b0" not in line:
        line = re.sub(r'\};\s*$', r", 4'b0};", line)
        changed = True
    out.append(line)

if changed:
    p.write_text("\n".join(out) + "\n")
    print("Patched microcode_rom.sv to append , 4'b0 to data assignments")
else:
    print("No changes needed in microcode_rom.sv")
PYCODE

  echo ">> Diff for microcode_rom.sv (context):"
  diff -u "$MICRO.bak" "$MICRO" || true
else
  echo "WARNING: $MICRO not found; skipping"
fi

echo "Done."
