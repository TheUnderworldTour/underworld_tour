# AGENTS.md


This document outlines the standard coding styles and naming conventions for our Godot Engine projects to ensure cross-platform compatibility and maintainable code architecture.

## Setup commands
- to be determined

## General Rules
- GDscript strict mode
- Use double quotes and omit semicolons
- User clear, descriptive names for functions, variables, classes, and nodes
- Keep functions focused around a single responsibility
# Godot Naming Conventions

## 1. Files and Directories
Always use **`snake_case`** for folder and file names. This prevents critical case-sensitivity path bugs when exporting games between Windows (case-insensitive) and Linux/Android/iOS (case-sensitive).

*   **GDScript & Assets:** `player_controller.gd`, `main_menu.tscn`, `sword_attack.wav`

## 2. Scene Tree & Nodes
Nodes inside the scene tree should follow **`PascalCase`** to align seamlessly with Godot's built-in native nodes.
*   *Examples:* `Player`, `MainMenu`, `CanvasLayer`, `GlobalAudioManager`

## 3. GDScript Style Guide

| Element | Case Style | Example | Rules & Framework |
| :--- | :--- | :--- | :--- |
| **Classes / Types** | `PascalCase` | `class_name EnemyKnight` | Used for custom resource or node types |
| **Variables** | `snake_case` | `var player_health = 100` | All lowercase with underscores |
| **Functions** | `snake_case` | `func take_damage():` | All lowercase with underscores |
| **Signals** | `snake_case` | `signal door_opened` | Use **past tense** to describe the event |
| **Constants** | `CONSTANT_CASE` | `const MAX_SPEED = 500` | All uppercase with underscores |
| **Enums (Name)** | `PascalCase` | `enum State { ... }` | Group identifier name |
| **Enum Members** | `CONSTANT_CASE` | `IDLE`, `RUNNING` | Values nested inside the enum structure |

### Private & Virtual Identifiers
*   **Private Members:** Prefix internal script properties or functions with a leading underscore (`_`) to signify they shouldn't be accessed by other classes (e.g., `var _internal_id`, `func _update_buffer()`).
*   **Engine Virtual Callbacks:** Godot's native lifetime methods automatically mirror this syntax (e.g., `_ready()`, `_process(delta)`, `_physics_process(delta)`).

### Signal Callbacks
When connecting signals via code or the editor UI, follow this strict prefix pattern:
*   `_on_source_node_name_signal_name` (e.g., `func _on_start_button_pressed()`)

## 4. GDScript Class File Structure
Maintain this uniform line-order within all `.gd` script files to keep definitions predictable:

```gdscript
# 1. Class definition & inheritance
class_name Player
extends CharacterBody2D

# 2. Signals
signal health_changed(new_health)

# 3. Enums
enum State { IDLE, MOVE, ATTACK }

# 4. Constants
const GRAVITY = 980

# 5. Exported @onready variables
@onready var sprite = \$Sprite2D

# 6. Public/Private variables
var current_health = 100
var _current_state = State.IDLE

# 7. Engine virtual methods
func _ready():
    pass

func _physics_process(delta):
    pass

# 8. Public methods
func heal(amount: int) -> void:
    current_health += amount

# 9. Private methods
func _die() -> void:
    queue_free()
```
