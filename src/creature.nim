import options, tables, strutils
import neverwinter/[gff, resman, tlk, twoda]
import helper

type
  Creature = object
    firstName, lastName, xName: string
    templateResRef, tag: string
    paletteID: int
    xPalette, xPaletteFull: string
    challengeRating, cRAdjust: int
    maxHitPoints: int
    xLevel: int
    xClass1: int
    xClass1Name: string
    xClass1Level: int
    xClass2: int
    xClass2Name: string
    xClass2Level: int
    xClass3: int
    xClass3Name: string
    xClass3Level: int
    factionID: int
    xParentFactionID: int
    xFactionName, xParentFactionName: string
    race: int
    xRaceName: string
    gender: int
    xGenderName: string
    lawfulChaotic, goodEvil: int
    xAlignment: string
    naturalAC: int
    str, dex, con, `int`, wis, cha: int
    lootable, disarmable, isImmortal, noPermDeath, plot, interruptable: int
    walkRate: int
    conversation: string
    comment: string

  CreatureName = tuple
    first, last, full: string

  ClassInfo = object
    name1, name2, name3: string
    id1, id2, id3: int
    level1, level2, level3: int

  AlignmentRange = range[0 .. 100]

  Alignment = object
    lawfulChaotic, goodEvil: AlignmentRange

proc toClassInfo(classList: GffList, classes2da: TwoDA, dlg: SingleTlk, tlk: Option[SingleTlk]): ClassInfo =
  result.id1 = -1
  result.id2 = -1
  result.id3 = -1
  if classList.len >= 1:
    result.id1 = classList[0]["Class", GffInt]
    result.name1 = classes2da[result.id1, "Name"].get.tlkText(dlg, tlk)
    result.level1 = classList[0]["ClassLevel", GffShort]
  if classList.len >= 2:
    result.id2 = classList[1]["Class", GffInt]
    result.name2 = classes2da[result.id2, "Name"].get.tlkText(dlg, tlk)
    result.level2 = classList[1]["ClassLevel", GffShort]
  if classList.len == 3:
    result.id3 = classList[2]["Class", GffInt]
    result.name3 = classes2da[result.id3, "Name"].get.tlkText(dlg, tlk)
    result.level3 = classList[2]["ClassLevel", GffShort]

proc creatureName(utc: GffRoot, dlg: SingleTlk, tlk: Option[SingleTlk]): CreatureName =
  result.first = utc["FirstName", GffCExoLocString].getStr(dlg, tlk)
  result.last = utc["LastName", GffCExoLocString].getStr(dlg, tlk)
  result.full = result.first
  if result.last.len > 0:
    result.full &= " " & result.last

proc name(a: Alignment): string =
  let lc = case a.lawfulChaotic
  of 70 .. 100: "L"
  of 31 .. 69: "N"
  of 0 .. 30: "C"
  let ge = case a.goodEvil
  of 70 .. 100: "G"
  of 31 .. 69: "N"
  of 0 .. 30: "E"
  if lc == ge: "TN" else: lc & ge

proc creatureList*(list: seq[ResRef], rm: ResMan, dlg: SingleTlk, tlk: Option[SingleTlk]): seq[Creature] =
  let
    isMod = rm[newResRef("module", "ifo".getResType)].isSome
    classes2da = rm.get2da("classes")
    racialtypes = rm.get2da("racialtypes")
    gender = rm.get2da("gender")
    factionInfo = if isMod: rm.getGffRoot("repute", "fac").toFactionInfo else: FactionInfo()
  var
    crs: Table[string, int]
    palcusInfo: PalcusInfo
  if isMod:
    let creaturepalcus = rm.getGffRoot("creaturepalcus", "itp")["MAIN", GffList]
    for c in creaturepalcus.flatten:
      if not c.hasField("RESREF", GffResRef): continue
      crs[$c["RESREF", GffResRef]] = c["CR", GffFloat].toInt
    palcusInfo = creaturepalcus.toPalcusInfo(dlg, tlk)
  for rr in list:
    let
      utc = rm.getGffRoot(rr)
      name = utc.creatureName(dlg, tlk)
      paletteId = utc["PaletteID", 0.GffByte].int
      factionId = utc["FactionID", 0.GffWord].int
      factionName = factionInfo.names.getOrDefault(factionId, "")
      parentFactionId = factionInfo.parents.getOrDefault(factionId, -1)
      parentFactionName = factionInfo.names.getOrDefault(parentFactionId, "")
      classInfo = utc["ClassList", GffList].toClassInfo(classes2da, dlg, tlk)
      alignment = Alignment(lawfulChaotic: utc["LawfulChaotic", GffByte], goodEvil: utc["GoodEvil", GffByte])
    var creature = Creature(
      firstName: name.first,
      lastName: name.last,
      xName: name.full,
      templateResRef: rr.resRef,
      paletteID: paletteId,
      xPalette: palcusInfo.getOrDefault(paletteId).name,
      xPaletteFull: palcusInfo.getOrDefault(paletteId).full,
      xClass1: classInfo.id1,
      xClass1Name: classInfo.name1,
      xClass1Level: classInfo.level1,
      xClass2: classInfo.id2,
      xClass2Name: classInfo.name2,
      xClass2Level: classInfo.level2,
      xClass3: classInfo.id3,
      xClass3Name: classInfo.name3,
      xClass3Level: classInfo.level3,
      xLevel: classInfo.level1 + classInfo.level2 + classInfo.level3,
      factionID: factionId,
      xFactionName: factionName,
      xParentFactionID: parentFactionId,
      xParentFactionName: parentFactionName,
      xAlignment: alignment.name,
      lawfulChaotic: alignment.lawfulChaotic,
      goodEvil: alignment.goodEvil,
      xRaceName: racialtypes[utc["Race", 0.GffByte], "Name"].get.tlkText(dlg, tlk),
      xGenderName: gender[utc["Gender", 0.GffByte], "Name"].get.tlkText(dlg, tlk),
      tag: utc["Tag", GffCExoString],
      comment: utc["Comment", GffCExoString],
      conversation: $utc["Conversation", GffResRef],
      maxHitPoints: utc["MaxHitPoints", 0.GffShort],
      challengeRating: crs.getOrDefault(rr.resRef, -1),
      crAdjust: utc["CRAdjust", 0.GffInt],
      walkRate: utc["WalkRate", 0.GffInt],
    )
    for k, v in creature.fieldPairs:
      when v is int:
        let label = k.capitalizeAscii
        case label
        of "Race", "Gender", "NaturalAC", "Str", "Dex", "Con", "Int", "Wis", "Cha",
            "Lootable", "Disarmable", "IsImmortal", "NoPermDeath", "Plot", "Interruptable":
          v = utc[label, 0.GffByte].int
    result &= creature
