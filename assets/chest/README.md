# Chest source asset

`ChestV1.fbx` references the absent `PolyPack_Main1.png` texture. Preserve the
original FBX here; `.gdignore` excludes this incomplete, unused source from Godot
imports. P0-3 currently builds the golden inheritance chest in `run/run_arena.gd`.
Remove `.gdignore` only when the matching texture is supplied and the asset is
ready for integration. This resolves fresh-project import errors by excluding
the incomplete source; it does not restore its missing artwork.
