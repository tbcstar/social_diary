
# Regenerate social_diary/Locales/zhCN/Areas.lua from the client's own AreaTable.dbc.
#   py -3 -B tools\dbc_areas.py
# The name block in that DBC holds 16 languages; column 5 is simplified Chinese.
import json, os, re, struct, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
ADDON = os.path.join(ROOT, 'social_diary')
if not os.path.isdir(os.path.join(ADDON, 'Locales')):
    ADDON = ROOT
SCRATCH = os.path.join(ROOT, '_ui-port-scratch')
CACHE = os.path.join(ROOT, '_dbc_names.json')
OUT = os.path.join(ADDON, 'Locales', 'zhCN', 'Areas.lua')

CJK = re.compile('[\u4e00-\u9fff]')

def from_client():
    if not os.path.isdir(SCRATCH):
        raise SystemExit('run this from the port workspace: it reads _ui-port-scratch/extract.py and the client MPQs')
    sys.path.insert(0, SCRATCH)
    os.chdir(SCRATCH)
    import extract as E
    path = 'DBFilesClient\\AreaTable.dbc'
    hits = [a for a in E.archives if a.find(path) is not None]
    archive = hits[-1]
    for a in hits:
        if os.path.basename(a.path).lower() == 'patch-aas.mpq':
            archive = a
    data = archive.read_block(archive.find(path), path)
    rows, fields, recsize, strsize = struct.unpack_from('<IIII', data, 4)
    body = 20
    recs = [struct.unpack_from('<%dI' % fields, data, body + i * recsize) for i in range(rows)]
    block = data[body + rows * recsize: body + rows * recsize + strsize]
    def s(off):
        if not off or off >= strsize:
            return ''
        end = block.find(b'\x00', off)
        return block[off:end].decode('utf-8', 'replace')
    best = (0, 0, {})
    for off in range(0, max(1, fields - 15)):
        good = {}
        for r in recs:
            en, zh = s(r[off]).strip(), s(r[off + 4]).strip()
            if en and zh and en != zh and CJK.search(zh) and all(32 <= ord(c) < 127 for c in en):
                good[en] = zh
        if len(good) > best[0]:
            best = (len(good), off, good)
    return best[2], os.path.basename(archive.path)

def skip(name):
    low = name.lower()
    return (low.startswith('test') or 'unused' in low or low.endswith(' test')
            or low in ('none', 'unknown') or name.startswith('$'))

def lua_str(text):
    return '"' + text.replace('\\', '\\\\').replace('"', '\\"') + '"'

def main():
    areas, archive = from_client()
    areas = {k: v.replace('\u00b7', ' ') for k, v in areas.items() if not skip(k)}
    lines = []
    w = lines.append
    w('local addonName, ns = ...')
    w('')
    w('-- 区域名对照：由客户端自己的 DBC 生成，不用手抄。')
    w('--')
    w('-- 来源：Data\\' + archive + ' 的 DBFilesClient\\AreaTable.dbc（%d 条英中对照）。' % len(areas))
    w('-- 该表的名字是 16 语种块，块内第 5 列就是简体中文（本机客户端 locale=enUS，')
    w('-- 只读英文列，所以要在显示前补上映射）。生成器：tools\\dbc_areas.py。')
    w('-- 改译名别改本文件，改生成器里的过滤或手写表后重跑生成器。')
    w('--')
    w('-- 只给显示用：与 Names.lua 同一张表 CoA.zhNames，绝不用于写存档、比较或索引。')
    w('-- 手写表优先：Names.lua 精校过的词条不被这里覆盖。')
    w('-- DBC 中文里夹在音节之间的间隔号一律换成空格，这是本插件的排版规则（tests/copy_rules.lua）。')
    w('if not ns.Locale.Is("zhCN") then return end')
    w('')
    w('local CoA = ns.Locale.CoA or {}')
    w('ns.Locale.CoA = CoA')
    w('CoA.zhNames = CoA.zhNames or {}')
    w('CoA.enNames = CoA.enNames or {}')
    w('')
    w('local generated = {')
    for en in sorted(areas):
        w('    [%s] = %s,' % (lua_str(en), lua_str(areas[en])))
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
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, 'w', encoding='utf-8', newline='\r\n') as fh:
        fh.write('\n'.join(lines) + '\n')
    print('wrote', OUT, len(areas), 'areas', os.path.getsize(OUT), 'bytes from', archive)

main()
