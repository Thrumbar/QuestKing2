# QuestKing Quest Item Button item:id Secure Fix

## Version
3.0.18

## Problem
The previous secure item-button patch changed the watch-frame quest item button to use `SecureActionButtonTemplate`, but it fed the secure button a full item link through the secure item action. On current clients this routed through `UseItemByName()` and was still blamed on QuestKing as `ADDON_ACTION_FORBIDDEN` / `UNKNOWN()`.

## Fix
- Kept the watch item button as a secure action button.
- Removed QuestKing-owned active item-use calls from the click path.
- Removed the explicit XML `OnClick` override so the inherited secure click handler owns the click.
- Changed the secure item payload from a full item link to a plain `item:<itemID>` token.
- Set both `item` and `item1` attributes for cross-version secure-template compatibility.
- Kept modified left-clicks from firing the item action by using `ATTRIBUTE_NOOP`.

## Files changed
- `ui/itembutton.lua`
- `ui/itembutton.xml`
- `version.txt`

## Notes
This supersedes the earlier `3.0.17` secure OnClick patch.
