# Compatibility shims: what is real and what is degraded

CoA runs the 3.3.5a (WotLK) client API, not retail. These files rebuild the
retail global names the addon was written against, so the business code keeps
reading like the retail documentation. Load order (social_diary.toc): right
after Core/Addon.lua, before Locales/. Every definition is guarded with
"if not X then" and never replaces something the client already has.

## Core/Compat/Env.lua
- Enum: only UIMapType (World 1, Continent 2, Zone 3), ItemClass (CoA's
  ItemTemplate values, Generic 8), TooltipDataType.Unit are added; the client's
  Enum table is extended, never replaced.
- issecretvalue: constant false. 3.3.5 has no secret values; the name exists
  because retail-shaped guards ask for it.
- strsplit/strtrim/strjoin/Mixin/CreateFromMixins/wipe: native in 3.3.5, only
  filled in when missing.
- UnitTokenFromGUID: scans player/target/focus/mouseover/pet/partyN/raidN;
  a GUID that names no current unit gives nil.
- UnitFullName: UnitName(unit) already returns name, realm on 3.3.5, so this
  answers the same pair; the name itself exists in retail only. Used by
  Dev/Diagnostics.lua.
- GetNumGroupMembers: raid count in a raid, party count + 1 in a party, 0 solo.
- GetItemInfoInstant: 7-tuple (id, type, subtype, equipLoc, icon, classID,
  subclassID). 3.3.5's class/subclass are localized names, so the ids are
  reverse-mapped through GetItemClassInfo/GetItemSubClassInfo. A never-seen
  item returns just the id.
- C_Timer: one hidden OnUpdate frame drives After/NewTimer/NewTicker; every
  handle has :Cancel(). NewTimer runs once by default.
- C_AddOns: GetAddOnMetadata/IsAddOnLoaded over the 3.3.5 globals.
- C_ChatInfo: empty (no call sites need it).
- C_LFGInfo, C_ChallengeMode, C_EncounterTimeline, C_RecentAllies,
  C_EncodingUtil, scrubsecretvalues: names Dev/Diagnostics.lua probes for and
  the client does not have, so /sd env reports "no". No caller reaches into
  them; C_EncodingUtil would need CBOR from retail, which 3.3.5 lacks.
- For the record: Dev/*.lua ships in the TOC (the upstream do-not-package block
  is kept as a comment only). The probes read the shims above; nothing in
  Dev/ invents data when an API is missing.

## Core/Compat/Extras.lua
- C_CVar: GetCVar/SetCVar/GetCVarBool over the 3.3.5 globals.
- C_Bank, C_CreatureInfo, C_DamageMeter, C_DeathRecap, C_GamePad,
  C_InputInterfaceStyle, C_InstanceEncounter, C_LootHistory, C_NamePlate,
  InputUtil: empty tables. Every call site guards the method, so the feature
  that needs one simply does not run (no crash, no fabricated data).
- CreateVector3D: a plain table with GetXYZ; only exists for honesty where a
  caller positions something.
- MenuUtil: element recorder, rendered through 3.3.5's EasyMenu. Unknown
  capitalized methods are no-ops. Without EasyMenu the menu does not open.
- TooltipDataProcessor: hooks GameTooltip OnTooltipSetUnit and calls the
  registered Unit callback with { guid, unit } (the only fields the addon reads).

## Core/Compat/Textures.lua
- Texture:SetColorTexture is added to the shared widget method table and maps
  to SetTexture(r, g, b, a). No-op in the test mock (widgets have their own
  methods there).
- Texture:SetAtlas is a no-op; C_Texture.GetAtlasInfo always returns nil, so
  every caller's coloured-texture fallback is what actually draws.
- CreateFrame strips the "BackdropTemplate" token from the template argument
  (3.3.5 raises on unknown templates) and passes any other templates through;
  3.3.5 frames already support SetBackdrop.

## Core/Compat/Map.lua
- C_Map.GetBestMapForUnit: SetMapToCurrentZone + GetCurrentMapAreaID, cached by
  zone/subzone text; the player's world-map view is saved and restored.
- C_Map.GetMapInfo: SetMapByID + GetMapInfo, restoring the view; returns
  { name, mapType (1 world / 2 continent / 3 zone), parentMapID, mapID }.
- C_Map.GetPlayerMapPosition: the native 3.3.5 call, wrapped in { GetXY() };
  nil unless the map is the player's current one.
- GetWorldPosFromMapPos, GetMapPosFromWorldPos, GetMapWorldSize,
  GetMapArtLayers, GetMapArtLayerTextures, C_MapExplorationInfo: nil/empty.
  Projecting across sub-maps therefore never happens: a point that cannot be
  placed is skipped.
- Enum.UIMapType lives in Env.lua (Core/Location.lua needs it before this file).

## Core/Compat/Items.lua
- C_Item: GetItemInfo (11-tuple passthrough), GetItemInfoInstant,
  GetItemIconByID, GetItemQualityByID, GetDetailedItemLevelInfo (nil for an
  item ilvl of 0), GetItemID (link parsing).
- C_Container.GetContainerItemInfo: the 3.3.5 seven values reshaped into the
  retail table, keeping both naming sets (icon/iconFileID, count/stackCount,
  locked/isLocked, quality, readable, lootable, hyperlink, itemID).
- C_Container.ContainerIDToInventoryID: 19 + bag.

## Core/Compat/Quests.lua
- C_QuestLog: IsQuestFlaggedCompleted, IsOnQuest/GetTitleForQuestID (scan the
  quest log titles; the 9th GetQuestLogTitle return is the quest id),
  GetQuestLink. IsQuestWatched is not provided (nil).
- C_Spell: the 3.3.5 spell functions, including GetSpellInfo/GetSpellLink/
  IsSpellKnown/GetSpellTexture/GetSpellDescription.

## Core/Compat/Units.lua
- C_UnitAuras.GetAuraDataByIndex: built from 3.3.5 UnitAura. Returns
  { name, icon, applications, dispelName, duration, expirationTime,
  sourceUnit, isStealable, spellId, auraInstanceID }.
  auraInstanceID is "spellId:expirationTime", so it changes when an aura is
  refreshed (the campfire code reads a new instance as "recast").
  3.3.5 hands back no spell id, so only the names in its table (the campfire
  countdown, "Welcoming Campfire" = 1229739) can be resolved to an id; an
  unknown aura reports spellId = nil.
- C_UnitAuras.GetPlayerAuraBySpellID: scans the player's helpful auras.
- C_Secrets.ShouldAurasBeSecret: false (nothing is secret on 3.3.5).
- C_PlayerInfo.GUIDIsPlayer: a "Player-" prefix test.
- C_PartyInfo: IsGUIDInGroup via unit-token scan; IsDelveInProgress false.
  The retail PlayerLocation methods are not provided; their callers fall back.
- C_FriendList.IsIgnoredByGuid: resolves the GUID to a name and scans the
  3.3.5 ignore list; an absent unit is not ignored.
- GetSpecialization/GetSpecializationInfo: nil (the client has no notion).

## Core/Compat/PvP.lua
- C_PvP.GetScoreInfo: 3.3.5 GetBattlefieldScore reshaped, with race/raceName
  and class/classToken both present (3.3.5 returns localized names; the field
  list at FrameXML/WorldStateFrame.lua:703 already carries race, class,
  classToken, so only the per-row guid is absent).
  row.stats is NOT provided: the 3.3.5 stat columns cannot be mapped onto
  retail stat ids with confidence, and a wrong number is worse than none.
- GetActiveMatchState is always nil: 3.3.5 has no match state, so the retail
  PVP_MATCH_* story stands down. Winner/duration come from the 3.3.5 calls.

## Core/Compat/Settings.lua
- Settings.RegisterCanvasLayoutCategory / RegisterAddOnCategory /
  OpenToCategory, backed by InterfaceOptions_AddCategory (which needs
  frame.name). OpenToCategory(InterfaceOptionsFrame_OpenToCategory) is called
  twice because 3.3.5's first call only raises the frame.

## Client facts this layer is built on
- GetInstanceInfo returns 7 values on 3.3.5 (no instance id); callers fall back
  to GetCurrentMapAreaID()/the zone name. Core/Instances.Enter also accepts a
  missing instanceID.
- UnitPosition does not exist; the shim defines it returning nil, so
  ns.WorldWhere() is nil and no distance is ever invented. Proximity uses
  UnitIsVisible + CheckInteractDistance(unit, 1..4) only.
## Map shim behaviour worth knowing
- C_Map.GetMapInfo answers only what the client can describe. SetMapByID does
  not fail on a bad id (it keeps the current view), so an id that leaves the
  view where it was is reported as nil, not as the player's zone.
- SetMapByID takes a WorldMapArea.dbc id, and GetCurrentMapAreaID answers one
  past it: the client's own FrameXML subtracts one before every SetMapByID.
  So the ids this addon stores (all from GetBestMapForUnit, which is
  GetCurrentMapAreaID) are one past what MapInfo has to ask for, and MapInfo
  asks for mapID - 1 and accepts only that id back (21 Nov 2026: the city
  list showed "map 1453" and a stale read-back hid the offset).
- parentMapID is nil: this client's zone list is flat and carries no parent
  links, and guessing one from the continent would invent a tree. Code that
  needs to climb (ns.City, ns.ZoneOf) already handles a nil parent.
- Only the id the client answered for is cached, so an alias is re-resolved
  rather than pinned to the first answer.
- C_Map.GetBestMapForUnit is the player's area id only as far as
  SetMapToCurrentZone can describe it; a sub-map id the zone list does not hold
  answers as the zone the player stands in (3.3.5 has no per-sub-map player
  area).

## How each name is filled in (PORT.md rule 9)
The client's own FrameXML already provides some of these names, so a whole-table
guard would skip them and leave the members the client lacks nil. Those names are
filled in member by member: the client's own copy stays and only the missing
members are added. The rest are absent from the client's FrameXML entirely, so
there the whole-table guard ("if not X then") is the correct shape.

- Client-provided, filled in member by member: Enum (extended),
  C_Map (the client defines only GetBestMapForUnit; GetMapInfo,
  GetPlayerMapPosition and the nil-returning world-coordinate members are added),
  C_CVar, C_NamePlate, C_Timer, GetItemInfoInstant, GetNumGroupMembers.
  Criterion: the name appears in the client's own FrameXML (the cache
  tools/client_native.txt is built from it), so it exists in game and only its
  missing members are ours to add. C_Timer is the one case where the client's
  file defines the calls itself; the fill-ins then do nothing.
- Absent from the client's FrameXML, so the whole table is ours: C_AddOns,
  C_ChatInfo, C_Item, C_Container, C_QuestLog, C_Spell, C_UnitAuras, C_Secrets,
  C_PlayerInfo, C_PartyInfo, C_FriendList, C_PvP, C_Texture, C_Bank,
  C_CreatureInfo, C_DamageMeter, C_DeathRecap, C_GamePad, C_InputInterfaceStyle,
  C_InstanceEncounter, C_LootHistory, C_MapExplorationInfo, InputUtil, MenuUtil,
  TooltipDataProcessor, Settings, CreateVector2D, CreateVector3D, UnitPosition,
  UnitTokenFromGUID, GetSpecialization/GetSpecializationInfo, issecretvalue.
- GetAtlasInfo: a widget method in this directory next to SetAtlas and
  SetColorTexture, plus a bare guarded global at Core/Compat/Textures.lua:40,
  because audit R1 also counts the name as a global. Both answer nil.

## Audit note
The R1 member-level warnings for C_Map.GetMapInfo / GetPlayerMapPosition /
GetMapArtLayers / GetMapArtLayerTextures are an audit vocabulary gap, not a shim
gap: tools/coa_audit.py records a member definition only when the member name is
itself in RETAIL_GLOBALS (the retail_kind gate before the member branch in
_sites), and those four are not in that list. The defs are present in Map.lua
(C_Map = C_Map or {}, then one fill-in per member).
