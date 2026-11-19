# DragonUI_Extensions

Extra options for [DragonUI](../DragonUI), loaded as a separate addon.

## Features

- **Show on Target** for unit frames (Player, Target, Focus, Pet, Boss), action bars (Main,
  Right, Left, Bottom Left, Bottom Right), additional bars (Stance, Pet, Totem, Extra Bar 1) and
  XP & Rep bars. When on, the entry is shown while a target exists and
  hidden otherwise. It is exclusive with DragonUI's *Show on Hover Only*, *Show in Combat Only*
  and *Hide in Combat* for that entry.
  - Open the settings window with `/duiext`.

## Notes

- Requires DragonUI and DragonUI_Options (both listed as dependencies).
- Depends on DragonUI internals (`_G.DragonUI`, `addon.VisibilityFade`, `addon.ForeverUI`,
  `addon.PanelControls`). A DragonUI update that changes these may break this addon.
- Nothing in DragonUI or DragonUI_Options is modified. The window uses DragonUI's own
  textures and fonts at runtime; nothing is copied into this addon.
- Party frames are not included; their visibility is managed by DragonUI's own party rules.
- The show/hide is instant, with no fade.
- The flag is stored in DragonUI's profile as `unitframe.<unit>.show_on_target`.
