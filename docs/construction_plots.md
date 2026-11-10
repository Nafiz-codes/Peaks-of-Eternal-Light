# Fixed construction plots

Open **B → Build** and choose one of the nine items. The camera frames its assigned plot. Hold the left mouse button over the ground to drag the preview, use **Q/R** to rotate in 15-degree steps, then choose **Confirm placement** or press **Enter**. Releasing the mouse does not spend resources. **Escape** or **Cancel** restores the walking view.

The whole rotated footprint, a 0.6 m service margin and each crew station's entrance must remain within its own plot. Terrain support, collision, rover departure clearance and crew reachability are checked again at confirmation. An invalid preview is red and cannot be confirmed. A valid preview is cyan. No object can use another item's plot.

Plots are defined in `src/world/construction_plots.gd`, with dimensions in metres. The layout uses the same outpost-local coordinates on all four sites and grades each pad against the surrounding site terrain. Plots are separated by service space; the lander and rover departure area remain open. Solar and communications occupy the perimeter, with crew and life-support facilities grouped around the base. Procedural rocks avoid the plots.

All nine items can be relocated through the build menu. Solar and crew-station relocation is free; already-built paid structures retain the existing no-repurchase behavior. Cancel restores the original structure and its saved transform. Destruction does not remove the assigned plot. Exact accepted transforms continue to use the existing save format.

Existing saves are not rejected or automatically rearranged. Legacy buildings remain at their saved positions, and their surrounding terrain is protected from pad grading. Moving or rebuilding them uses the new plots. A legacy building can obstruct a plot until it is moved or removed. Terrain protection is recalculated on scene load.

Bright boundaries and labels appear in build mode. Small physical survey stakes remain outside build mode. The selected plot is highlighted; unrelated outpost HUD layers are hidden during placement and restored afterward.

Validation: `tests/world/test_construction_plots.gd` exercises all nine items across all four sites, full-footprint containment, rotation room, invalid confirmation, placement, relocation cancellation and save compatibility. Existing collision and route restrictions still apply to individual rotations.
