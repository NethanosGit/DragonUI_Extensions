# DragonUI_Extensions

Extra options for [DragonUI](../DragonUI), loaded as a separate addon.

## Features

- **Show on Target** for unit frames (Player, Target, Focus, Pet, Boss). Adds a third option
  next to *Show on Hover Only* and *Show in Combat Only* in each frame's Visibility group in
  DragonUI's editor mode. When on, the frame is shown while a target exists and hidden otherwise.
  It is exclusive with the other two options.

## Notes

- Depends on DragonUI internals (`_G.DragonUI`, `addon.VisibilityFade`, `addon.EditorSettings`).
  A DragonUI update that changes these may break this addon. It exits quietly if they are missing.
- Party frames are not included; their visibility is managed by DragonUI's own party rules.
- The show/hide is instant, with no fade.
- The flag is stored in DragonUI's profile as `unitframe.<unit>.show_on_target`.
