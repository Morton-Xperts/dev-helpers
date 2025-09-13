import re, sys, pathlib

env_name = "staging"
path = pathlib.Path("backend") / f".env.{env_name}"
args = []
if path.exists():
    for raw in path.read_text().splitlines():
        s = raw.strip()
        if not s or s.startswith('#') or s.startswith(';'):
            continue
        if s.startswith('export '):
            s = s[7:].lstrip()
        m = re.match(r'([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$', s)
        if not m:
            continue
        key, val = m.group(1), m.group(2)
        # Parse value
        if val:
            if val[0] in ('"', "'"):
                q = val[0]
                i = 1
                out = []
                esc = False
                while i < len(val):
                    c = val[i]
                    if not esc and c == '\\':
                        esc = True
                        i += 1
                        continue
                    if not esc and c == q:
                        i += 1
                        break
                    out.append(c)
                    esc = False
                    i += 1
                value = ''.join(out)
            else:
                out = []
                prev_ws = False
                for c in val:
                    if c == '#' and prev_ws:
                        break
                    out.append(c)
                    prev_ws = c.isspace()
                value = ''.join(out).strip()
        else:
            value = ''
        args.append(f"{key}={value}")
print("\n".join(args))