#!/usr/bin/env python3
# 读取 overrides.json，把自定义 Name/Description 注入 Packages 对应包
import json, os, sys
ov = {}
if os.path.exists('overrides.json'):
    try: ov = json.load(open('overrides.json', encoding='utf-8'))
    except Exception: ov = {}
if not ov:
    sys.exit(0)

# 归一化 key：统一按文件名（去 debs/ 前缀）匹配
norm = {}
for k, v in ov.items():
    norm[k.split('/')[-1]] = v

text = open('Packages', encoding='utf-8').read()
out = []
matched = 0
for b in text.split('\n\n'):
    if not b.strip():
        out.append(b); continue
    lines = b.split('\n')
    fn = None
    for l in lines:
        if l.startswith('Filename:'):
            fn = l.split(':', 1)[1].strip(); break
    key = fn.split('/')[-1] if fn else None
    o = norm.get(key) if key else None
    if o:
        # 统一 name / desc(description 两种键都认)
        oname = o.get('name') or ''
        odesc = o.get('desc') or o.get('description') or ''
        o = {'name': oname, 'desc': odesc}
    if o and (o['name'] or o['desc']):
        matched += 1
        new = []
        has_name = any(l.startswith('Name:') for l in lines)
        i = 0
        while i < len(lines):
            l = lines[i]
            if l.startswith('Name:'):
                if o.get('name'): new.append('Name: ' + o['name'])
                else: new.append(l)
                i += 1; continue
            if l.startswith('Description:'):
                if o.get('desc'):
                    d = o['desc'].strip()
                    first, _, rest = d.partition('\n')
                    new.append('Description: ' + first)
                    for x in rest.split('\n'):
                        if x.strip(): new.append(' ' + x.strip())
                    i += 1
                    while i < len(lines) and lines[i][:1] == ' ':
                        i += 1
                    continue
                else:
                    new.append(l); i += 1
                    while i < len(lines) and lines[i][:1] == ' ':
                        new.append(lines[i]); i += 1
                    continue
            new.append(l); i += 1
        if not has_name and o.get('name'):
            fin = []; ins = False
            for l in new:
                fin.append(l)
                if not ins and l.startswith('Version:'):
                    fin.append('Name: ' + o['name']); ins = True
            if not ins: fin.append('Name: ' + o['name'])
            new = fin
        b = '\n'.join(new)
    out.append(b)
open('Packages', 'w', encoding='utf-8').write('\n\n'.join(out))
print('overridden packages:', matched)
