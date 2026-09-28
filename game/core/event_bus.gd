extends Node
## Global signal hub (autoload `EventBus`).
##
## Declares signals only: no state and no logic. Use it for communication between features that
## must not know about each other. Name facts in past tense, and intents as `*_requested`.

## Something wants to show plain text lines in the message box. Replaced by the dialogue system later.
@warning_ignore("unused_signal")
signal dialogue_requested(lines: PackedStringArray)

## Someone speaks: like dialogue_requested, with a speaker name shown in the message box.
@warning_ignore("unused_signal")
signal conversation_requested(speaker: String, lines: PackedStringArray)

## A modal UI (message box, fade, menus) opened or closed. The player ignores input while any is open.
@warning_ignore("unused_signal")
signal modal_opened(modal_id: StringName)
@warning_ignore("unused_signal")
signal modal_closed(modal_id: StringName)

## The player asked to end the day (e.g. used the bed). `Main` runs the day transition.
@warning_ignore("unused_signal")
signal sleep_requested(source: Node)

## The day transition finished and a new day began. `reason` is `&"slept"` or `&"exhausted"`.
@warning_ignore("unused_signal")
signal day_transition_finished(reason: StringName)

## The player stepped into a MapTransition. `Main` runs the map transition.
@warning_ignore("unused_signal")
signal map_transition_requested(map_id: StringName, spawn_id: StringName, source: Node)

## A map finished loading and the player is in it.
@warning_ignore("unused_signal")
signal map_changed(map_id: StringName)
