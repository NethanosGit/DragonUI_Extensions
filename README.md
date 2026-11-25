# DragonUI_Extensions

Extra options for [DragonUI](../DragonUI), loaded as a separate addon.

## Features

- **Show on Target** for unit frames (Player, Target, Focus, Pet, Boss), action bars (Main,
  Right, Left, Bottom Left, Bottom Right), additional bars (Stance, Pet, Totem, Extra Bar 1) and
  XP & Rep bars. When on, the entry is shown while a target exists. It combines with
  DragonUI's *Show on Hover Only* and *Show in Combat Only*: the entry is shown when any checked
  condition is met, and DragonUI's *Hover/Combat Logic* is treated as OR. It is exclusive with
  *Hide in Combat* for that entry.
  - Open the settings window with `/duiext`.
- **Frames > Player Auras**: *Show on Hover*, *Show in Combat* and *Show on Target* for your buffs,
  debuffs and weapon enchants, as one group. Any checked condition shows them; with none checked
  they are always shown. Hidden auras ignore the mouse. Stored in DragonUI's profile under
  `extensions.auras`.
- **Frames > Nameplates > Style** (tab): *WoW Forever (Thin)* nameplate art, ported from
  [DragonUI pull request #586](https://github.com/NeticSoul/DragonUI/pull/586): the original
  borders, focus ring, cast bar and level badge. Only the art changes; sizes, fonts, text placement
  and icons follow your settings. With *Level > Position* outside the bar the level is drawn in the
  badge, on that side, using the Level tab's font size, style, colours and *Show Frame Under*; with
  *Before the Name* the level stays in the name. It runs on top of DragonUI's Modern style; choosing
  Heritage in DragonUI_Options turns it off. The pull request's own look uses 166x13 bars with a
  cast bar height of 6.
  The artwork in `Textures/Forever` is copyright Blizzard Entertainment (sources in
  `Textures/Forever/provenance.json`). Stored as `modules.nameplates.extForeverStyle` and
  `extForeverPrevStyle`.
- **Frames > Nameplates > Health** (tab): the health text Font Size (-3 to 10), with no style restrictions. It works
  in the Modern style too, where DragonUI_Options locks the slider and sizes the text like the name.
  Stored as `modules.nameplates.healthNumberFontSize`, the same key DragonUI_Options uses.
  The same tab has **Cut Texture on Health Loss** (off by default): in the Modern and WoW Forever styles the health
  fill is cut at the health value instead of being squeezed into it. Stored as
  `modules.nameplates.extHealthCutFill`.
- **Frames > Nameplates > Name** (tab): Font Size of the name, from -3 to 10 in steps of 0.5. DragonUI_Options
  stops at 1. The name is drawn at 9 + the value; the power text uses 7 + the value.
  Stored as `modules.nameplates.fontSize`, the same key DragonUI_Options uses. If the value is below
  1, DragonUI_Options' slider shows its own minimum, so use this page to change it.
  *Ignore Nameplate Width* stops the name being limited to the plate width, so it is never cut with
  "..." (`modules.nameplates.extNameNoCrop`).
- **Frames > Nameplates > Level** (tab): Position of the level number. *Before the Name* keeps DragonUI's layout.
  *Outside the Bar, Left* and *Outside the Bar, Right* draw it beside the health bar, outside the
  name. Whether the level shows at all is still set by DragonUI_Options' Level section.
  Stored as `modules.nameplates.levelPlacement`.
  *Style* picks Outline, Shadow or Outline & Shadow for the outside level text
  (`modules.nameplates.extLevelStyle`).
  *Horizontal Offset* (-50 to 50) moves the outside level left or right, including its frame and the
  Forever badge (`modules.nameplates.extLevelOffsetX`).

## Notes

- Requires DragonUI and DragonUI_Options (both listed as dependencies).
- Depends on DragonUI internals (`_G.DragonUI`, `addon.VisibilityFade`, `addon.ForeverUI`,
  `addon.PanelControls`, `addon.Nameplates.layout.ApplyNameplateFonts` and `SafeSetFont`). A DragonUI
  update that changes these may break this addon.
- Nothing in DragonUI or DragonUI_Options is modified. The window uses DragonUI's own
  textures and fonts at runtime; nothing is copied into this addon.
- Party frames are not included; their visibility is managed by DragonUI's own party rules.
- The show/hide is instant, with no fade.
- The flag is stored in DragonUI's profile as `unitframe.<unit>.show_on_target`.
