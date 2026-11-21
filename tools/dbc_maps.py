
# Regenerate social_diary/Locales/zhCN/Maps.lua from the client's own Map.dbc and
# BattlemasterList.dbc.
#   py -3 -B tools\dbc_maps.py
# The client ships these two tables twice: patch-M.mpq holds the English names, and
# patch-ZH.mpq (loaded later, so it wins) holds the same records with simplified
# Chinese written into the name column. Both archives are read here.
import json, os, re, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ADDON = os.path.join(ROOT, 'social_diary')
if not os.path.isdir(os.path.join(ADDON, 'Locales')):
    ADDON = ROOT
# The extractor and the client MPQ reader live in the port workspace, which is a
# parent of the addon (the addon itself travels without them).
SCRATCH = None
_here = HERE
while _here and _here != os.path.dirname(_here):
    if os.path.isdir(os.path.join(_here, '_ui-port-scratch')):
        SCRATCH = os.path.join(_here, '_ui-port-scratch')
        break
    _here = os.path.dirname(_here)
OUT = os.path.join(ADDON, 'Locales', 'zhCN', 'Maps.lua')

CJK = re.compile('[\u4e00-\u9fff]')

def archives():
    if not os.path.isdir(SCRATCH):
        raise SystemExit('run this from the port workspace: it reads _ui-port-scratch/extract.py and the client MPQs')
    sys.path.insert(0, SCRATCH)
    cwd = os.getcwd()
    os.chdir(SCRATCH)
    import extract as E
    os.chdir(cwd)
    return E

def read(E, mpq, table):
    path = 'DBFilesClient\\' + table + '.dbc'
    hits = [a for a in E.archives if a.find(path) is not None]
    if not hits:
        raise SystemExit('no archive carries ' + path)
    chosen = hits[-1]
    for a in hits:
        if os.path.basename(a.path).lower() == mpq:
            chosen = a
    data = chosen.read_block(chosen.find(path), path)
    rows, fields, recsize, strsize = struct.unpack_from('<IIII', data, 4)
    body = 20
    recs = [struct.unpack_from('<%dI' % fields, data, body + i * recsize) for i in range(rows)]
    block = data[body + rows * recsize: body + rows * recsize + strsize]
    def s(off):
        if not off or off >= strsize:
            return ''
        end = block.find(b'\x00', off)
        return block[off:end].decode('utf-8', 'replace')
    return recs, s, os.path.basename(chosen.path)

def pairs(E, table, wanted):
    '''English->Chinese from the two archives, plus id->Chinese for Map.dbc.'''
    en_recs, en_s, en_arch = read(E, 'patch-m.mpq', table)
    zh_recs, zh_s, zh_arch = read(E, 'patch-zh.mpq', table)
    best = (0, 0, {})
    for off in range(0, min(len(en_recs[0]), 20)):
        good = {}
        for a, b in zip(en_recs, zh_recs):
            en, zh = en_s(a[off]).strip(), zh_s(b[off]).strip()
            if en and zh and en != zh and CJK.search(zh) and all(32 <= ord(c) < 127 for c in en):
                good.setdefault(en, zh)
        if len(good) > best[0]:
            best = (len(good), off, good)
    count, off, table_pairs = best
    ids = {}
    if wanted:
        for a, b in zip(en_recs, zh_recs):
            zh = zh_s(b[off]).strip()
            if zh and CJK.search(zh) and not skip(en_s(a[off]).strip()):
                ids.setdefault(a[0], zh)
    return table_pairs, ids, (en_arch, zh_arch, off, count)

PLACEHOLDER = re.compile(r'^(dev|test|dbg|adt|debug)', re.I)

def skip(name):
    '''True for a record the client never shows a player (an English name).'''
    low = name.lower()
    return (PLACEHOLDER.search(name) is not None or 'unused' in low or 'devmap' in low
            or re.search(r'^\d+ppl_', low) is not None or low.endswith('_bg')
            or name.startswith('$')
            or low in ('none', 'unknown', 'instancename'))

def lua_str(text):
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'

def main():
    E = archives()
    map_pairs, map_ids, map_src = pairs(E, 'Map', True)
    bg_pairs, _, bg_src = pairs(E, 'BattlemasterList', False)
    names = {}
    for table in (map_pairs, bg_pairs):
        for en, zh in table.items():
            if not skip(en):
                names.setdefault(en, zh.replace('\u00b7', ' '))
    ids = {k: v.replace('\u00b7', ' ') for k, v in map_ids.items()}
    lines = []
    w = lines.append
    w('local addonName, ns = ...')
    w('')
    w('-- 地图、副本、战场、竞技场名对照：由客户端自己的 DBC 生成，不用手抄。')
    w('--')
    w('-- 名字 %d 条：Map.dbc %d 行（英文取 %s，中文取 %s，名字列第 %d 列）、' % (len(names), map_src[3], map_src[0], map_src[1], map_src[2]))
    w('-- BattlemasterList.dbc %d 行（第 %d 列）；id 表 %d 条（Map.dbc 第 1 列 -> 名字）。' % (bg_src[3], bg_src[2], len(ids)))
    w('-- 本机客户端装了两份同名表：patch-M.mpq 是英文名，patch-ZH.mpq 后加载（优先级更高），')
    w('-- 把同一个名字列写成了简体中文——所以中文名的权威来源是客户端自己，不是社区译名。')
    w('-- 生成器：tools\\dbc_maps.py。改译名别改本文件，改生成器后重跑。')
    w('--')
    w('-- 只给显示用：与 Names.lua 同一张表 CoA.zhNames，绝不用于写存档、比较或索引。')
    w('-- 手写表优先：Names.lua 精校过的词条不被这里覆盖（下面的 or）。')
    w('-- CoA.maps 同理只补缺：Locales/zhCN/CoA.lua 里手写的 id 译名保留。')
    w('if not ns.Locale.Is("zhCN") then return end')
    w('')
    w('local CoA = ns.Locale.CoA or {}')
    w('ns.Locale.CoA = CoA')
    w('CoA.zhNames = CoA.zhNames or {}')
    w('CoA.enNames = CoA.enNames or {}')
    w('CoA.maps = CoA.maps or {}')
    w('')
    w('local generated = {')
    for en in sorted(names):
        w('    [%s] = %s,' % (lua_str(en), lua_str(names[en])))
    w('}')
    w('')
    w('local generatedMaps = {')
    for i in sorted(ids):
        w('    [%d] = %s,' % (i, lua_str(ids[i])))
    w('}')
    w('')
    w('for english, chinese in pairs(generated) do')
    w('    CoA.zhNames[english] = CoA.zhNames[english] or chinese')
    w('end')
    w('')
    w('-- 反向表（设置页搜索用中文也能找到条目），同样不覆盖已有。')
    w('for english, chinese in pairs(generated) do')
    w('    CoA.enNames[chinese] = CoA.enNames[chinese] or english')
    w('end')
    w('')
    w('for id, chinese in pairs(generatedMaps) do')
    w('    CoA.maps[id] = CoA.maps[id] or chinese')
    w('end')
    w('')
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\r\n') as fh:
        fh.write('\n'.join(lines) + '\n')
    print('wrote', OUT, len(names), 'names', len(ids), 'ids', os.path.getsize(OUT), 'bytes')
    for probe in ('Shadowfang Keep', 'War Song Gulch'.replace(' ',''), 'Arathi Basin', 'Nagrand Arena HD'):
        print(' ', probe, '->', names.get(probe))
    print('  id 33 ->', ids.get(33), '| id 607 ->', ids.get(607))

main()