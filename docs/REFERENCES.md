# Fixed-wing references reviewed before implementation

Research date: 2026-10-29. These projects were inspected in separate research checkouts. No code, models, textures, plugins or audio from them were copied into this repository.

| Reference | Version inspected | License / lesson |
|---|---|---|
| [fbcosentino/godot-simplified-flightsim](https://github.com/fbcosentino/godot-simplified-flightsim) | `06cefe53b29e1e557530b277a1ad8c41dc915119` | MIT, © 2022 fbcosentino. Godot 4 GDScript modular aircraft, speed-squared lift/drag, engine/gear controls. Its lift-vs-weight stall flag is not the same as angle-of-attack stall. |
| [wmigor/godot-aircraft-plugin](https://github.com/wmigor/godot-aircraft-plugin) | `395a707dd81edd6530be8e89f3c1a177164289d6` | MIT, © 2025 Igor Akulov. Godot 4.7-declared project; wing-section relative airflow, dynamic pressure, lift/drag/moment and an angle-of-attack airfoil model. More complexity than this first prototype needs. Fixed-wing demos only were relevant. |
| [KidsCanCode: Arcade-style Airplane](https://kidscancode.org/godot_recipes/4.x/3d/simple_airplane/index.html) | Godot 4 article | Useful camera/input design comparison. Explicitly not an aerodynamic simulation; nose-aligned velocity and cosmetic banking. No source/assets imported. |

## Primary background

- [NASA — Lift equation](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/lift-equation/): lift depends on density, speed squared, reference area and lift coefficient.
- [NASA — Drag equation](https://www1.grc.nasa.gov/beginners-guide-to-aeronautics/drag-equation/): analogous dynamic-pressure form for drag.
- [Godot — RigidBody3D](https://docs.godotengine.org/en/stable/classes/class_rigidbody3d.html): inspected to compare a physics-body/force approach with a small deterministic game integrator.

## Chosen approach

An original single-aircraft, fixed-step model avoids taking on a general-purpose simulation framework. The model retains independent world velocity, lift perpendicular to airflow, drag opposite airflow, gravity, thrust, speed-dependent control authority, post-critical-angle lift loss, ground friction and explicit landing outcomes. Keyboard aids trade realism for accessible takeoff and landing. Numerical parameters are game-tuned, not validated against a real aircraft.

All visual geometry in `plane_visual.gd` and `coastal_world.gd`, interface drawing, and synthesized `propeller.wav` are original to this project. The built-in Godot fallback font is used; no font file is redistributed. No third-party attribution notice is required for copied code/assets because none are included. The references above are acknowledged as design research, not bundled dependencies.
