"""Extract only product photos from user-authorized iPhone Mirroring captures."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter
import hashlib,json
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT.parents[1]/'baemin-private-evidence'/'2026-10-26-baemin-easy'
OUT=ROOT/'assets'/'captured'
OUT.mkdir(exist_ok=True)
manifest=[]
def smooth_ui_patch(im,box):
    # App controls cover plain photo backdrop at these selected corners.
    x0,y0,x1,y1=box
    fill=im.copy(); px=fill.load(); src=im.load()
    for y in range(y0,y1):
        left=src[max(0,x0-2),y];right=src[min(im.width-1,x1+2),y]
        for x in range(x0,x1):
            t=(x-x0)/(x1-x0)
            px[x,y]=tuple(round(a*(1-t)+b*t) for a,b in zip(left,right))
    mask=Image.new('L',im.size);ImageDraw.Draw(mask).rectangle(box,fill=255)
    return Image.composite(fill,im,mask.filter(ImageFilter.GaussianBlur(1.2)))
def save(name,source,box,patches=()):
    p=SOURCE/source;im=Image.open(p).convert('RGB').crop(box)
    for patch in patches:im=smooth_ui_patch(im,patch)
    if name=='easy-sundae-observed.png':
        clean=Image.open(SOURCE/'E01-search.png').convert('RGB').crop((41,650,272,881)).resize(im.size,Image.Resampling.LANCZOS)
        mask=Image.new('L',im.size);draw=ImageDraw.Draw(mask)
        draw.rectangle((104,480,184,563),fill=255)
        draw.rectangle((14,534,133,592),fill=255)
        im=Image.composite(clean,im,mask.filter(ImageFilter.GaussianBlur(5)))
    target=OUT/name;im.save(target,optimize=True)
    manifest.append({'asset':name,'source':source,'sourceSha256':hashlib.sha256(p.read_bytes()).hexdigest(),'crop':box,'size':im.size,'uiBackdropRepairs':list(patches),'cursorRepairSource':'E01-search.png' if name=='easy-sundae-observed.png' else None,'outputSha256':hashlib.sha256(target.read_bytes()).hexdigest()})
# No account identity, cart contents, purchase counts, rating, or location is copied.
save('easy-milk-observed.png','E05-milk-detail.png',(16,235,620,839),[(506,507,594,593),(18,538,128,588)])
save('easy-sundae-observed.png','E02-sundae-detail.png',(16,235,620,839),[(506,507,594,593),(18,538,128,588)])
# Source is the unobstructed product tile available before the connection dropped.
# Keep its captured add control rather than reconstructing the food it obscures.
save('easy-pork-gukbap-observed.png','E01-search.png',(290,650,521,881))
(OUT/'easy-mirror-manifest.json').write_text(json.dumps({'observedDate':'2026-10-26','method':'CUA native iPhone Mirroring capture; crop with limited control-backdrop repair','assets':manifest},ensure_ascii=False,indent=2))
