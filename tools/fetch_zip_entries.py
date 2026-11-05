#!/usr/bin/env python3
"""从远程 zip 里只下载需要的几个文件（HTTP Range），不下整个包。
用法：python3 tools/fetch_zip_entries.py <zip 地址> <文件名结尾,逗号分隔> <输出目录>
Godot 4.3 的导出模板包有 1GB，网页版只需要其中的 web_nothreads_*.zip（约 17MB）。
"""
import struct, urllib.request, zlib, sys, os
URL=sys.argv[1]; WANT=sys.argv[2].split(','); OUT=sys.argv[3]
def get(a,b):
    r=urllib.request.Request(URL, headers={'Range':f'bytes={a}-{b}'})
    return urllib.request.urlopen(r, timeout=300).read()
size=int(urllib.request.urlopen(urllib.request.Request(URL, method='HEAD')).headers['Content-Length'])
tail=get(size-65536, size-1)
i=tail.rfind(b'PK\x05\x06'); eocd=tail[i:]
cd_size, cd_off = struct.unpack('<II', eocd[12:20])
if cd_off==0xFFFFFFFF or cd_size==0xFFFFFFFF:
    j=tail.rfind(b'PK\x06\x06'); z=tail[j:]
    cd_size, cd_off = struct.unpack('<QQ', z[40:56])
cd=get(cd_off, cd_off+cd_size-1)
p=0; entries={}
while p < len(cd) and cd[p:p+4]==b'PK\x01\x02':
    meth=struct.unpack('<H',cd[p+10:p+12])[0]
    csz,usz=struct.unpack('<II',cd[p+20:p+28]); nl,el,cl=struct.unpack('<HHH',cd[p+28:p+34])
    off=struct.unpack('<I',cd[p+42:p+46])[0]
    name=cd[p+46:p+46+nl].decode(); extra=cd[p+46+nl:p+46+nl+el]
    q=0
    while q < len(extra):
        hid,hl=struct.unpack('<HH',extra[q:q+4])
        if hid==1:
            vals=extra[q+4:q+4+hl]; k=0
            if usz==0xFFFFFFFF: usz=struct.unpack('<Q',vals[k:k+8])[0]; k+=8
            if csz==0xFFFFFFFF: csz=struct.unpack('<Q',vals[k:k+8])[0]; k+=8
            if off==0xFFFFFFFF: off=struct.unpack('<Q',vals[k:k+8])[0]; k+=8
        q+=4+hl
    entries[name]=(meth,csz,usz,off)
    p+=46+nl+el+cl
print('entries', len(entries)); 
os.makedirs(OUT, exist_ok=True)
for w in WANT:
    name=[n for n in entries if n.endswith(w)][0]
    meth,csz,usz,off=entries[name]
    h=get(off, off+29)
    nl,el=struct.unpack('<HH',h[26:30])
    data=get(off+30+nl+el, off+30+nl+el+csz-1)
    if meth==8: data=zlib.decompress(data,-15)
    assert len(data)==usz,(name,len(data),usz)
    open(os.path.join(OUT, os.path.basename(name)),'wb').write(data)
    print('got', name, usz)
