# Why the placeholder image might not show (and how we fix it)

The character slots (BattlerSlots) should show a sprite for each hero and enemy. When you see **empty dark rectangles** with only the name and HP bar, the texture is not reaching the TextureRect, or the TextureRect is not drawing it. Below is what’s going on and what the code does about it.

---

## 1. Where the image comes from

- **File**: `assets/character_placeholder.png`
- **In code**: The battle scene loads it once and passes it to every slot. Each slot can also try to load it itself if it receives `null`.

So there are two places that can show an image:

- **Battle scene** (`battle_scene.gd`): In `_ready()` it does `load("res://assets/character_placeholder.png")` (and falls back to `preload(...)`). That texture is passed to each slot in `_build_arena()` as `slot.setup(party[i], tex)`.
- **BattlerSlot** (`battler_slot.gd`): In `setup()` it only uses that texture if it’s not `null`. If it is `null`, the slot tries, in order:
  1. `_load_placeholder_here()` — Godot’s ResourceLoader
  2. `_load_placeholder_from_file()` — raw file read + PNG decode
  3. `_make_fallback_texture()` — generated checker pattern (no file)

So the **image can come from** the battle scene’s load, or from any of these three methods inside the slot.

---

## 2. Why the image might not show

Common causes:

1. **Path or import**
   - `res://assets/character_placeholder.png` must exist and be the correct path (case-sensitive on some systems).
   - Godot turns PNGs into imported textures (e.g. `.ctex`). If the import failed or the file was added outside Godot, `load()` / ResourceLoader can return `null`.

2. **When the game runs**
   - With **Run Project (F5)**, `res://` is the project folder. So `res://assets/character_placeholder.png` is `project_folder/assets/character_placeholder.png`.
   - In **exported** games, `res://` points to the exported pack. If the PNG wasn’t included or the path in code doesn’t match, load fails.

3. **TextureRect never gets a texture**
   - If every load attempt returns `null`, the slot would only show the fallback. If you see **nothing** (no checker either), then either:
     - The fallback isn’t being applied (bug), or
     - The TextureRect has no size or is hidden (layout/visibility).

4. **TextureRect has no size**
   - If the container gives the TextureRect zero width or height, it won’t draw. We set `custom_minimum_size = Vector2(80, 100)` so the layout reserves space. We also set `size` in `setup()` so the control has an explicit size in case the container wasn’t giving it one.

So “image not showing” usually means either **no texture** (load/import/path) or **TextureRect not drawing** (size/layout).

---

## 3. What each loading method does (in `battler_slot.gd`)

### A. Texture passed from battle scene

- **What**: `battle_scene.gd` does `load("res://assets/character_placeholder.png")` (or `preload`) and passes the result to `slot.setup(party[i], tex)`.
- **When it works**: When Godot finds the resource and the import is valid.
- **When it fails**: Wrong path, missing file, or import not done (e.g. file added while editor was closed). Then `tex` is `null` and the slot uses its own methods.

### B. `_load_placeholder_here()` — ResourceLoader

- **What**: `ResourceLoader.load(PLACEHOLDER_PATH, "Texture2D", ...)`. Uses Godot’s resource system (imported texture).
- **When it works**: Same as (A): correct path and successful import.
- **Why we have it**: Loading inside the slot can sometimes succeed when the battle scene’s load failed (e.g. different “current” path or cache).

### C. `_load_placeholder_from_file()` — raw file + PNG decode

- **What**: Opens the file with `FileAccess.open(PLACEHOLDER_PATH, READ)`, reads all bytes, then `Image.load_png_from_buffer(bytes)` and `ImageTexture.create_from_image(img)`.
- **When it works**: The file exists at `res://assets/character_placeholder.png` and is valid PNG. **Does not use** Godot’s texture import (no `.ctex`).
- **When it fails**: File missing, wrong path, or not valid PNG. Then we fall back to the checker.

This is the method that often fixes “image still not showing” when (A) and (B) fail (e.g. export or import quirks).

### D. `_make_fallback_texture()` — checker pattern

- **What**: Builds a 64×64 image in memory (dark + cyan checker), then `ImageTexture.create_from_image(img)`. No file.
- **When it works**: Always (no I/O).
- **Purpose**: So the slot **always** has a texture. If you see the checker, the slot and TextureRect are working and the only problem was loading the PNG.

---

## 4. What we did so the texture actually draws

In `setup()` we:

1. Set `texture_rect.texture = tex` (from whichever method succeeded).
2. Set `texture_rect.custom_minimum_size = Vector2(80, 100)` so the layout gives the TextureRect at least 80×100.
3. Set `texture_rect.size = Vector2(80, 100)` so the control has an explicit size (helps in some layouts).

In `_ready()` we already set:

- `expand_mode = EXPAND_IGNORE_SIZE` so the TextureRect can be smaller than the texture and still get layout space.
- `stretch_mode = STRETCH_KEEP_ASPECT_CENTERED` so the texture is scaled to fit and centered.

So we both **get a texture** (up to three load attempts + fallback) and **give the TextureRect a fixed size** so it’s not drawn at 0×0.

---

## 5. If it still doesn’t show

1. **Check the file**: In the Godot FileSystem panel, confirm `assets/character_placeholder.png` exists. Right‑click → Reimport.
2. **See if the fallback shows**: If you see a **cyan/dark checker** in the slots, the PNG load failed but the slot and TextureRect work; then the issue is only path/import/file. If you don’t even see the checker, the problem is layout or the TextureRect being hidden/disabled.
3. **Path**: In code we use `res://assets/character_placeholder.png`. If you moved the file, update `PLACEHOLDER_PATH` in `battler_slot.gd` and the load path in `battle_scene.gd`.

Once the PNG path and file are correct, method (C) `_load_placeholder_from_file()` is the one that most often gets the image on screen when the others don’t.
