import sys,json
# 分类白名单：sections.json 形如 {"keep":["Tweaks","工具"],"other":"其它"}
# keep 里的 Section 原样保留，其余的包一律改写为 other —— 商店分类页就只剩这几个
OTHER='其它'
try: cfg=json.load(open('sections.json',encoding='utf-8'))
except Exception: cfg={}
keep=set(x.strip() for x in (cfg.get('keep') or []) if str(x).strip())
OTHER=(cfg.get('other') or OTHER).strip() or OTHER
if not keep:
    print('sections.json 里 keep 为空，跳过'); sys.exit(0)
txt=open('Packages',encoding='utf-8').read()
SEP=chr(10)+chr(10)
out=[]; moved=0; total=0
for b in txt.split(SEP):
    if not b.strip(): out.append(b); continue
    total+=1
    lines=b.split(chr(10)); nl=[]; done=False
    for l in lines:
        if l.startswith('Section:'):
            cur=l.split(':',1)[1].strip()
            if cur not in keep:
                nl.append('Section: '+OTHER); moved+=1
            else:
                nl.append(l)
            done=True
        else: nl.append(l)
    # 原本没有 Section 行的包，归到 other，否则 Sileo 会单独列一个空白分类
    if not done: nl.append('Section: '+OTHER); moved+=1
    out.append(chr(10).join(nl))
open('Packages','w',encoding='utf-8').write(SEP.join(out))
print('分类合并完成：共 %d 个包，改写 %d 个；保留分类: %s' % (total, moved, ', '.join(sorted(keep))))