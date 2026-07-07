# Quest Watch Objective Indentation Fix

## Changed files

- `QuestKing/ui/watchbutton.lua`
- `QuestKing/buttons/quest.lua`

## Fix

- Enabled indented word wrapping for tracker objective font strings when the WoW client supports `FontString:SetIndentedWordWrap(true)`.
- Added a compatibility fallback for clients where `SetIndentedWordWrap` is unavailable by converting leading spaces into a real left inset before rendering.
- Added per-line layout inset support through `line:SetLayoutInsets(leftInset, rightInset)`.
- Changed quest objective, quest completion, and available campaign detail rows to use a real objective-line inset instead of leading spaces in the text.
- Updated wrapped objective anchoring so additional wrapped lines align with the objective text instead of falling back to the far left edge of the quest watch row.

## Result

Long quest objective lines now wrap under their own objective text, making the right-side quest watch list easier to read.
