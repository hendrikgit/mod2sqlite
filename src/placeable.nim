import tables
import neverwinter/[gff, resman, tlk]
import helper

type
  Placeable = object
    name, resref, tag: string
    palette, palette_full: string
    palette_id: int
    faction: string
    faction_id: int
    parent_faction: string
    parent_faction_id: int
    hp: int
    `static`: int
    plot: int
    conversation: string
    comment: string

proc placeableList*(list: seq[ResRef], rm: ResMan, dlg: SingleTlk, tlk: Option[SingleTlk]): seq[Placeable] =
  let isMod = rm[newResRef("module", "ifo".getResType)].isSome
  let palcusInfo = if isMod: rm.getGffRoot("placeablepalcus", "itp")["MAIN", GffList].toPalcusInfo(dlg, tlk) else: PalcusInfo()
  for rr in list:
    let utp = rm.getGffRoot(rr)
    let paletteId = utp["PaletteID", 0.GffByte].int
    result &= Placeable(
      name: utp["LocName", GffCExoLocString].getStr(dlg, tlk),
      resref: rr.resRef,
      tag: utp["Tag", ""],
      palette: palcusInfo.getOrDefault(paletteId).name,
      palette_full: palcusInfo.getOrDefault(paletteId).full,
      palette_id: paletteId,
    )
