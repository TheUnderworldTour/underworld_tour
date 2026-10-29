# Scrolling map generation

`scripts/map_path.gd` builds a directed graph before drawing tokens and curved path ribbons. `node_count` means rows (including a single centered start and finish), so the total number of encounter nodes may exceed that value.

Each row has one to three nodes. Ordered connections between adjacent rows split and merge, using at most three edges in each gap. This is the meaning of active paths: the number of parallel connections at a given stage, not the total number of possible start-to-finish itineraries. Every node is reachable from the start and leads to the finish. The first intermediate row has two nodes (one when the cap is one). Later rows favor two paths: the initial draw uses 15% one, 60% two and 25% three, with consecutive three-node rows reduced to two. A two-row map has only start and finish.

Structure is selected before placement. Nodes then sample separated horizontal zones and vary in depth by up to 18% of row spacing, scaled by `placement_variation`. This preserves order while breaking up fixed lanes and straight rows. The start and finish remain centered at their original depths. Connections use sampled, gently meandering flat ribbons with a shared drift per row gap to keep neighboring branches from bending into one another. Curves meet the node centers and stay just above the board.

Types are START, COMBAT, ELITE, ITEM, SHOP, STORY and FINISH. Intermediate types are currently sampled uniformly; rarity weights and gameplay actions can be added separately. The five encounter names match meshes in `assets/map_scene/map_icons.glb`. Each encounter uses its matching token, with story reused for START and elite for FINISH until dedicated endpoint artwork exists. FINISH remains its own logical type; this does not add a boss encounter.

The imported mesh lineup is loaded once. Each token uses the named mesh without the lineup's display offsets, retains its authored materials, is centered and uniformly scaled to `token_diameter`, and sits just above the highest ground point around its footprint. Each visual has a stable MapNode anchor with `map_node_id` and `node_type` metadata and a Token mesh child, ready for later hover work. Hover labels and highlighting are not implemented yet. `map_nodes` exposes each node's id, row, type, position and outgoing ids; `connections` contains source/destination id pairs.

At the default map width, placement jitter leaves at least 0.3 units of horizontal space between token edges in the same row. Very narrow custom map widths may require reducing token size.

Inspector settings on MapPath:

- `node_count`: number of rows, minimum two.
- `max_active_paths`: one to three; runtime values are also clamped.
- `generation_seed`: zero gives a fresh map, any other value reproduces the layout and types.
- `placement_variation`: zero to one, default 0.8; controls left/right and front/back position variation.
- `path_wobble`: zero to 0.5, default 0.24 world units; zero produces straight connections.
- `token_diameter`: uniform token width, default 1.05 world units; original proportions are retained.
- `path_width`: horizontal extent, clamped to 1.0–3.8 to separate cubes and keep them inside the pillars.
- `start_z` and `end_z`: existing map endpoints.

The camera script and model assets are unchanged. `generate_path()` replaces generated path visuals and graph data without duplicating pillars. Default depth and camera limits are preserved. If changing depth endpoints, adjust the camera's map limits as needed.

## Volcanic terrain

MapSurface now uses `scripts/map_terrain.gd` to build a real 12-by-40 terrain slab with 0.5-unit triangles, shallow hills, and closed sides. Its `height_variation` Inspector setting defaults to 0.45; zero makes the ground flat. It also runs in the editor so the surface is visible before running the scene.

`assets/map_scene/volcanic_ground.gdshader` provides large dark plum/charcoal basalt shapes, muted red stone variation and sparse orange emissive seams. There are no external textures or new model dependencies. The seams are a material effect, not a lava river or physical light sources.

`get_height_at(x, z)` interpolates the same triangles used by the mesh. Token bases sample the terrain around their footprint, paths follow it with a small clearance on both ribbon edges, and pillar bases follow the ground. Paths increase their sample count for long connections. This replaces the old assumption that every node and connection sits on a fixed horizontal plane.

Paths now use `assets/map_scene/dotted_path.gdshader` for muted sandstone dots with a subtle dark rim. The ribbon supplies distance along each curve so dot spacing stays consistent across short, long and curved routes. The shader exposes `path_color`, `edge_color`, `dot_spacing` and `dot_radius` for later visual tuning. This changes only path appearance; logical links, token materials and camera behavior stay the same.

After editing height variation during a running game, call `MapPath.generate_path()` or restart the scene to update token/path heights. The river through the middle, glowing lava lighting, bridges for one/two/three routes, buildings and stairs remain future asset/gameplay work. Those will need explicit elevated route surfaces; this change only supplies gentle ground relief.

## Map lighting

The map scene includes a warm shadow-casting main light, a low-energy purple fill, purple ambient illumination, and three restrained orange edge lights spread along the scrolling board. A dark procedural sky supplies reflection color to reflective surfaces while the visible background stays dark plum. ACES tone mapping controls bright highlights; ambient occlusion adds grounding in the project's Forward+ renderer. Shadows come from the main light only, keeping the accent lights inexpensive. Token meshes and materials are unchanged.

Tune WorldEnvironment for ambient color, tone mapping and occlusion; DirectionalLight3D for main-light warmth and shadow strength; CoolFill for shadow-side readability; and EmberAccents for orange edge lighting. Run the map scene and scroll from end to end to check coverage. This pass does not add hover glow or the future lava river.

## Testing

Open `scenes/map_scene.tscn` in Godot 4.7 and run the current scene (F6); the project's main scene remains the rhythm scene. Scroll with the mouse wheel from bottom to top and back. Confirm smooth movement and clamping, branches/merges, at most three connections between rows, and one start and finish. Check that encounter symbols vary, sit on the board, and have room between them. Start uses the story question-mark token and finish uses the elite skull token.

Inspect the floor at the normal camera angle: dark volcanic stone should replace green grass, shallow hills should change token elevations, and paths should remain visible along the slopes. Try MapSurface height variation at 0.0 and 0.45 before running to compare flat and raised versions.

Select MapPath, set `generation_seed` to 42, and run twice to compare identical maps. Try `max_active_paths` values 1, 2 and 3 and `node_count` values 2, 3 and 9. During a run, inspect GeneratedPath in the Remote scene tree to see encounter names and metadata.

Run the automated regression check from the project folder (substitute your Godot executable):

```text
godot --headless --path . --script tests/test_map_path.gd
```

It covers 320 configurations, reachability, no dead ends, path caps, endpoints, types, token mesh mapping, consistent sizing, terrain seating, preserved materials, horizontal separation, curve attachments and intersections, path clearance, two-path frequency, repeatability (including curves), regeneration cleanup and camera wheel/clamp/slide behavior. It also checks that terrain queries match mesh triangle interiors within 0.0001 units and that relief stays gentle. A successful run prints `failures: 0` and exits with code zero. Automated checks do not replace a visual review of the scene.
