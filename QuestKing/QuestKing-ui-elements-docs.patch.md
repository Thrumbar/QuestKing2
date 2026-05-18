# QuestKing UI elements documentation/version patch

```diff
--- a/QuestKing/REFRACTOR_BUNDLE_NOTES.md+++ b/QuestKing/REFRACTOR_BUNDLE_NOTES.md@@ -18,6 +18,7 @@ - ui/progressbar.lua
 - ui/tracker.lua
 - ui/watchbutton.lua
+- ui/optionspanel.lua
 
 Files retained from the source package in this build:
 
@@ -25,6 +26,14 @@ - buttons/scenario.lua
 - options.lua
 - options_override.lua
-- XML/assets/TOC/version files
+- XML/assets files
+
+Latest package additions:
+
+- Added `ui/optionspanel.lua` as the native Blizzard AddOns settings panel for QuestKing.
+- Updated `QuestKing.toc` to load `ui/optionspanel.lua` after `options_override.lua` so the GUI reflects the active option defaults.
+- Updated `core/slashcommand.lua` so `/qk options`, `/qk config`, and `/qk settings` open the new panel.
+- Added standalone slash aliases `/qkoptions` and `/questkingoptions` through the options panel module.
+- Documented the settings UI addition in `REFRACTOR_NOTES.md`, `version.txt`, and `version.new`.
 
 This bundle is intended as a consolidated test package from the conversation refactor pass.
--- a/QuestKing/REFRACTOR_NOTES.md+++ b/QuestKing/REFRACTOR_NOTES.md@@ -94,7 +94,78 @@ 
 After this merge, the old standalone `QuestKingSounds` addon should be removed or disabled. Keeping both active can cause duplicate sound playback.
 
+## Native AddOns settings UI integration
+
+### Summary
+
+QuestKing now includes a native Blizzard AddOns settings panel through:
+- `ui/optionspanel.lua`
+
+The panel exposes the existing QuestKing options in the default Blizzard settings UI instead of requiring users to edit the options files directly.
+
+### What the panel adds
+
+- Registers a QuestKing category under Blizzard's AddOns settings list on modern clients.
+- Falls back to the legacy Interface Options category path when the modern `Settings` API is not available.
+- Uses existing QuestKing option storage instead of introducing a new saved-variable format.
+- Keeps the options UI dependency-free; Ace3 is not required.
+- Adds `/qk options`, `/qk config`, `/qk settings`, `/qkoptions`, and `/questkingoptions` access paths.
+
+### UI controls added
+
+- Blizzard Objective Tracker visibility
+- QuestKing tracker dragging behavior
+- Tracker scale
+- Tracker alpha
+- Item-start quest popups
+- Completed objective display mode
+- Superseded objective hiding
+- Scenario, dungeon, and raid objective behavior
+- Tracker button width
+- Line height
+- Title height
+- Font size
+- Quest item button scale
+- Item and reward anchor side
+- Advanced background
+- Simple backdrop
+- PetTracker compatibility helpers
+
+### Compatibility notes
+
+- Retail / Midnight clients use the modern `Settings.RegisterCanvasLayoutCategory` and `Settings.RegisterAddOnCategory` path when available.
+- Classic-family clients fall back to `InterfaceOptions_AddCategory` when the modern settings system is unavailable.
+- The options panel avoids protected-frame manipulation and only writes QuestKing-owned options, then requests a QuestKing tracker refresh.
+- The panel is loaded after `options_override.lua` so override defaults are visible in the GUI at startup.
+
 ## Changelog
+
+## 3.0.10
+
+### Added
+- Added `ui/optionspanel.lua` as a native Blizzard AddOns settings panel for QuestKing.
+- Added modern Settings API registration for Retail / Midnight clients with a Classic-safe `InterfaceOptions_AddCategory` fallback.
+- Added settings controls for tracker visibility, dragging, scale, alpha, quest popup behavior, objective display, sizing, font layout, item button scale, reward anchoring, backgrounds, and PetTracker compatibility helpers.
+- Added `/qk options`, `/qk config`, `/qk settings`, `/qkoptions`, and `/questkingoptions` access paths.
+
+### Changed
+- Updated `QuestKing.toc` to load `ui/optionspanel.lua` after `options_override.lua` so the panel reads the active configured defaults.
+- Updated `core/slashcommand.lua` to route settings slash commands into the new options panel when available.
+- Documented the new UI panel in the refactor notes, bundle notes, and version files.
+
+### Compatibility
+- Keeps the settings UI dependency-free and Lua 5.1 compatible.
+- Keeps Retail / Midnight, MoP Classic, Cataclysm Classic, TBC Anniversary, and Classic Era compatibility by checking Blizzard settings APIs before use.
+- Avoids new secure hooks or protected-frame manipulation; the panel only updates QuestKing-owned options and requests QuestKing-owned refresh behavior.
+
+### Files changed
+- `QuestKing.toc`
+- `core/slashcommand.lua`
+- `ui/optionspanel.lua`
+- `REFRACTOR_BUNDLE_NOTES.md`
+- `REFRACTOR_NOTES.md`
+- `version.txt`
+- `version.new`
 
 ## 3.0.9
 
--- a/QuestKing/version.txt+++ b/QuestKing/version.txt@@ -1,3 +1,11 @@+3.0.10
+- Added ui/optionspanel.lua as a native Blizzard AddOns settings panel for QuestKing.
+- Registers through the modern Settings API on Retail / Midnight clients and falls back to InterfaceOptions_AddCategory on Classic-family clients.
+- Adds graphical controls for tracker visibility, dragging, scale, alpha, quest popups, completed objective display, objective filtering, tracker sizing, font sizing, item button scale, reward anchoring, backgrounds, and PetTracker compatibility helpers.
+- Adds /qk options, /qk config, /qk settings, /qkoptions, and /questkingoptions commands to open the settings panel.
+- Updates QuestKing.toc to load ui/optionspanel.lua after options_override.lua so the panel reflects override defaults at startup.
+- Keeps the settings UI dependency-free, Lua 5.1 compatible, and isolated to QuestKing-owned option writes and refresh requests.
+
 3.0.9
 - Further reduced Retail/Midnight world-map reward tooltip taint by stopping QuestKing from installing Mainline hooks on Blizzard ObjectiveTracker Show/Update/Manager methods.
 - Keeps Blizzard tracker suppression on Retail/Midnight to a QuestKing-owned event refresh and a single alpha write on managed tracker roots.
--- a/QuestKing/version.new+++ b/QuestKing/version.new@@ -1,3 +1,11 @@+3.0.10
+- Added ui/optionspanel.lua as a native Blizzard AddOns settings panel for QuestKing.
+- Registers through the modern Settings API on Retail / Midnight clients and falls back to InterfaceOptions_AddCategory on Classic-family clients.
+- Adds graphical controls for tracker visibility, dragging, scale, alpha, quest popups, completed objective display, objective filtering, tracker sizing, font sizing, item button scale, reward anchoring, backgrounds, and PetTracker compatibility helpers.
+- Adds /qk options, /qk config, /qk settings, /qkoptions, and /questkingoptions commands to open the settings panel.
+- Updates QuestKing.toc to load ui/optionspanel.lua after options_override.lua so the panel reflects override defaults at startup.
+- Keeps the settings UI dependency-free, Lua 5.1 compatible, and isolated to QuestKing-owned option writes and refresh requests.
+
 3.0.9
 - Further reduced Retail/Midnight world-map reward tooltip taint by stopping QuestKing from installing Mainline hooks on Blizzard ObjectiveTracker Show/Update/Manager methods.
 - Keeps Blizzard tracker suppression on Retail/Midnight to a QuestKing-owned event refresh and a single alpha write on managed tracker roots.

```
