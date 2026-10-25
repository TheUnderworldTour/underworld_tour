<!-- docs/rfcs/YYYY-MM-DD-short-title.md (or docs/adr/, whichever your repo uses) -->

# RFC: Deciding on style guidelines

<!-- Decision record header. Leave Status as "Proposed" until your team decides,
     before or after the reviews. Then fill in the outcome and the decision date.
     The document stays where it is; this header is what makes it a record. -->

| Field | Value |
| --- | --- |
| Author | Matt Vemuri |
| Date | 2026-10-25 |
| Status | Proposed |
| Decision Date | (fill when decided) |
| Deciders | (who agreed to the outcome) |
| Superseded By | N/A |

## Problem and Context

The team needs to decide on a unified style so we can figure out what each piece of the UI looks like. We're in the starting phases, so we didn't really need it prior, but going forward need figure out what look we are going for.

If we don't have a clear idea of the style we want, when creating UI elements, assets, and animations, we could end up creating a bunch of disjointed pieces that don't mesh well. This is exarcerbated by the fact that we are unable to meet frequently for collaboration, so most work is done remote.

## Options

### Option A: Low-Poly

Using less than a thousand polygons per model. Since the polygon count is low, there is a lack of facial features, which leads to less expressivity in the models. This could be resolved to intentional posing and dialogue. It is simple to produce and leaves more space for other visual effects. 

### Option B: High-Poly

Having more human, realistic models. More complex, but lends to realism and afford expressivity through facial expressions. More work to produce models from scratch,, but steps can and have been taken to adapt previous low-poly assets.

### Option C: Pixel Art

Lowering the resolution to being 64 bit or less. Simple to use 2D pngs, that can just be directly imported into Godot. Not as complex as High Poly, and there are addons to streamline the production of pixel art in the current workflow. Could be harder to animate. 

### Option D: Do Nothing

Not deciding on a firm style, will lead to differing mental images of the final product, and when we combine the pieces we work on separately, we will end up with a jumbled mess.

## Analysis

If we go forward with a High-Poly style, we will have larger files, especially for 3D models that we may use. This could lead to longer load times, or a larger end product shipped. Based on past works, creating low poly models should only take a few hours of time for each, since there are prior assets to rely on. Pivoting to a pixelated art style shouldn't be too hard, due to past experiences with creating it. 

## Recommendation and Verification Plan

I'd recommend going for the Low-Poly style, since that was the idea I had in mind while designing character assets. It would also mesh well with our timeline, since we should be focusing on gameplay instead of visuals.

We'd know this option worked based on how well we progress with this in mind. When designing UI assets such as health bars, menus, and items, whether or not we're able to complete them in a reasonable time frame and whether they look good put together.

For testing if the system works, it really just comes down to deadlines, whether we can have visuals done in a resasonable timeline.

## Constraints

We should not be using generative AI when creating visual or audio assets.

## Delegation and Validation

- **What you handed to AI tools** on this decision, whether that was the analysis, the prototype, the tests, or the writing.
- **What checks made that reasonable**: tests, CI, review gates, a staging environment, a rollback path. Name the ones that actually exist in your repo, not the ones you intend to build.
- **Where you stopped and validated the result yourself, and why those points.** If this decision is hard to reverse, say what you personally checked before committing to it.


What is assessed is in the [AI policy](https://capstone.alexulbrich.com/assignments/introduction/#ai-policy-applies-to-every-assignment).

## Decision

Proposed, until your team decides. Then accepted, rejected, or superseded, with the date and who chaired the decision. If superseded, link the RFC that replaces this one.