# QuestKing 3.0.35 — PetTracker Bar Width

## Issue

PetTracker's zone-progress bar extended farther across the watch frame than
QuestKing's quest progress bars, making the combined tracker look unbalanced.

## Root Cause

The PetTracker adapter sized the zone-progress bar to the full PetTracker
content width (`buttonWidth - 4`). QuestKing's quest progress bars use the
narrower shared presentation rule `buttonWidth - 36`, with an 80-pixel
minimum.

At the configured 280-pixel row width, this made the PetTracker bar 276 pixels
wide while a quest progress bar was 244 pixels wide.

## Fix

- PetTracker's zone-progress bar now uses the same 16-pixel left inset,
  20-pixel right inset, and width calculation as a QuestKing quest progress
  bar.
- PetTracker's frame and species text rows retain their existing content width.
- PetTracker's supported anchor offset keeps its dependent species rows in
  their existing positions after the bar is centered.

## Preserved Behavior

- QuestKing 3.0.34's bounded PetTracker startup recovery is unchanged.
- PetTracker's Zone Tracker setting, completed-zone visibility, species rows,
  and context menu remain PetTracker-controlled.
- Quest, scenario, bonus-objective, macro-taint, and secure quest-item behavior
  is unchanged.
