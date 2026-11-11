# Transparent dialogue portraits

Created using the built-in imagegen tool. Original expression sheets remain unchanged.

Assets:
- Assets/characters/Maya_Chen/default/maya-dialogue-transparent.png
- Assets/characters/Sam_Okafor/default/sam-dialogue-transparent.png
- Assets/characters/Alex_Rivera/default/alex-dialogue-transparent.png

Prompt used for each original NPC expression sheet:

Edit this exact game expression sprite sheet: remove ONLY the grey background and white grid separators to true alpha transparency in all 12 cells. Preserve exactly all character faces, emotions, hair, suits, colors, pose, scale, positions and the 3 column by 4 row grid. Same 1024x1536 dimensions and cell boundaries. No new art, no rearrangement, no labels. Clean transparent cutouts.

The Godot conversation view uses the existing expression catalog regions with these transparent sheets, then clips the rendered portrait to a circle. Player portraits remain hidden. Verified in-game at 1360x820 and 960x540.

## Player appearances

Built-in imagegen transparent cutouts for commander-01 through commander-04. Each output is saved alongside its original sheet as `Assets/characters/Commander/<variant>/<variant>-dialogue-transparent.png`.

Prompt: Remove ONLY the grey background and white grid separators from this exact 1024x1536 game expression sheet to true alpha transparency. Preserve all 12 faces, expressions, hair and suits exactly with original colors, positions, scale and 3-column 4-row grid. Clean transparent cutouts. No rearrangement or labels.
