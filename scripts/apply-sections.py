import sys,json
# 分类配置 sections.json：
#   {"sections":[{"name":"显示名","orig":"原分类","pkgs":["包名", "-排除包名"]}], "other":"其它"}
# 规则：
#   1) pkgs 里点名的包进本分类（可以同时属于多个分类）
#   2) orig 不为空时，原本属于该分类的包自动进本分类，"-包名" 表示踢出去
#   3) 没有任何分类收走的包，统一进 other
OTHER='其它'
# 商店（Sileo/Zebra）按 Section 名的 Unicode 顺序排分类，「其」U+5176 会夹在「微信」「陌陌」中间。
# 给兜底分类加一个全角波浪线前缀 U+FF5E，保证它在店里永远排最后，界面上仍然显示「其它」。
OTHER_OUT='～'+OTHER
try: cfg=json.load(open('sections.json',encoding='utf-8'))
except Exception: cfg={}
# 兼容老格式 {"keep":[...]}：当成「只保留这几个原分类」
raw=cfg.get('sections')
if raw is None:
    raw=[{'name':k,'orig':k,'pkgs':[]} for k in (cfg.get('keep') or [])]
OTHER=(cfg.get('other') or OTHER).strip() or OTHER
OTHER_OUT='～'+OTHER   # cfg 可能改过兜底名，这里重新拼前缀
if not raw:
    print('sections.json 没有分类配置，跳过'); sys.exit(0)
sections=[]
for s in raw:
    if not s or not str(s.get('name','')).strip(): continue
    sections.append({
        'name': str(s['name']).strip(),
        'orig': str(s.get('orig') or '').strip(),
        'pkgs': [str(x) for x in (s.get('pkgs') or [])]
    })
if not sections:
    print('分类配置为空，跳过'); sys.exit(0)
# 用户自己建的「其它」不丢弃：它的勾选并入兜底集合，最终仍然只有一个「其它」
user_other=next((s for s in sections if s['name']==OTHER), None)
sections=[s for s in sections if s['name']!=OTHER]

txt=open('Packages',encoding='utf-8').read()
SEP=chr(10)+chr(10); NL=chr(10)
blocks=[b for b in txt.split(SEP) if b.strip()]
# 解析每个包：包名 / 原分类 / 原始块
pkgs=[]
for b in blocks:
    m=pkg=None
    cur=''
    for l in b.split(NL):
        if l.startswith('Package:'): pkg=l.split(':',1)[1].strip()
        elif l.startswith('Section:'):
            cur=l.split(':',1)[1].strip()
            if cur==OTHER_OUT: cur=OTHER   # 带前缀的兜底分类还原成「其它」
    pkgs.append({'pkg':pkg,'sec':cur,'block':b})

# 计算每个分类收哪些包
members={}   # 分类名 -> [包名]
claimed=set()
for s in sections:
    st=set()
    for x in s['pkgs']:
        if x.startswith('-'): continue
        st.add(x)
    if s['orig']:
        for p in pkgs:
            if p['sec']==s['orig']: st.add(p['pkg'])
    for x in s['pkgs']:
        if x.startswith('-'): st.discard(x[1:])
    members[s['name']]=members.get(s['name'],set())|st
    claimed|=st
rest=set(p['pkg'] for p in pkgs)-claimed
# 用户自己建的「其它」分类：里面手动勾选的包也归兜底，最终只显示一个「其它」
if user_other:
    for x in (user_other.get('pkgs') or []):
        if isinstance(x,str) and x and not x.startswith('-'): rest.add(x)

# 输出：包按分类顺序展开，同一包属于多个分类就出现多条
out=[]; multi=0
bypkg={}
for p in pkgs: bypkg.setdefault(p['pkg'],p)
done_names=set()
for s in sections:
    if s['name'] in done_names: continue   # 同名分类已经合并输出过
    done_names.add(s['name'])
    for name in [p['pkg'] for p in pkgs if p['pkg'] in members[s['name']]]:
        src=bypkg.get(name)
        if not src: continue
        lines=[l for l in src['block'].split(NL) if not l.startswith('Section:')]
        # Section 放在 Description 之前，和 apt-ftparchive 的输出顺序一致
        at=len(lines)
        for i,l in enumerate(lines):
            if l.startswith('Description:'): at=i; break
        lines.insert(at,'Section: '+s['name'])
        out.append(NL.join(lines)); multi+=1
for name in [p['pkg'] for p in pkgs if p['pkg'] in rest]:
    src=bypkg.get(name)
    if not src: continue
    lines=[l for l in src['block'].split(NL) if not l.startswith('Section:')]
    at=len(lines)
    for i,l in enumerate(lines):
        if l.startswith('Description:'): at=i; break
    lines.insert(at,'Section: '+OTHER_OUT)
    out.append(NL.join(lines)); multi+=1

open('Packages','w',encoding='utf-8').write(SEP.join(out)+NL)
names=', '.join(s['name'] for s in sections)
# 统计一律按「插件」算，不按分类记录算：一个插件跨 3 个分类也只算 1 个
uniq=len(set(p['pkg'] for p in pkgs))
print('分类完成：%d 个插件（%d 个进「其它」）；分类 %d 个: %s'
      % (uniq, len(rest), len(sections), names))