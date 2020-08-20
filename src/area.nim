import strutils
import neverwinter/[gff, resman, tlk]
import helper

type
  Area = object
    name, resRef, tag: string
    height, width: int
    flags: int
    xFlagInterior, xFlagUnderground, xFlagNatural: bool
    noRest: bool
    playerVsPlayer: int
    tileset: string
    onEnter, onExit: string
    loadScreenID: int
    isNight: bool
    dayNightCycle: int
    chanceLightning, chanceRain, chanceSnow: int
    windPower: int
    fogClipDist: float
    modListenCheck, modSpotCheck: int
    comments: string

  AreaFlag {.size: 4.} = enum
    areaInterior = "interior" # exterior if unset
    areaUnderground = "underground" # aboveground if unset
    areaNatural = "natural" # urban if unset

  AreaFlags = set[AreaFlag]

proc toFlags(v: int): AreaFlags =
  cast[AreaFlags](v)

proc areaList*(list: seq[ResRef], rm: ResMan, dlg: SingleTlk, tlk: Option[SingleTlk]): seq[Area] =
  for rr in list:
    let
      are = rm.getGffRoot(rr)
      flag = are["Flags", 0.GffDword].int
      flags = flag.toFlags
    var area = Area(
      name: are["Name", GffCExoLocString].getStr(dlg, tlk),
      resref: rr.resRef,
      tag: are["Tag", GffCExoString],
      flags: flag,
      xFlagInterior: flags.contains(areaInterior),
      xFlagUnderground: flags.contains(areaUnderground),
      xFlagNatural: flags.contains(areaNatural),
      comments: are["Comments", GffCExoString],
      loadScreenID: are["LoadScreenID", 0.GffWord].int,
      fogClipDist: are["FogClipDist", 0.GffFloat],
    )
    for k, v in area.fieldPairs:
      let label = k.capitalizeAscii
      when v is int:
        case label
        of "NoRest", "PlayerVsPlayer", "IsNight", "DayNightCycle":
          v = are[label, 0.GffByte].int
        of "Height", "Width", "ChanceLightning", "ChanceRain", "ChanceSnow",
            "WindPower", "ModListenCheck", "ModSpotCheck":
          v = are[label, -1.GffInt]
      when v is string:
        case label
        of "Tileset", "OnEnter", "OnExit":
          v = $are[label, GffResRef]
    result &= area
