# AstraPathing · Flutter desktop

The Windows desktop editor lives in [`flutter/`](flutter/). It uses the purple AstraPath visual language from the earlier Windows application and Choreo's field-centered editing layout. It opens directly into the editor. The React prototype remains in `src/` for comparison and can still be run separately.

## Run the Flutter app

Use Flutter 3.47.4 with Windows desktop support (the version of the supplied working app), then from the `flutter` directory run:

```sh
flutter pub get
flutter run -d windows
```

For one-click Windows use, open [`release/AstraPathing.exe`](release/AstraPathing.exe). It unpacks its runtime automatically into your local app data on first launch. You can copy this single EXE anywhere and run it without manually extracting files. The [portable ZIP](release/AstraPathing-Windows.zip) is also available if you prefer to keep the app files together in a folder. To rebuild the single EXE from source, run `packaging/build_single_exe.ps1` with Flutter 3.47.4 on your PATH, or pass its `flutter.bat` path with `-Flutter`.

The left panel holds paths and waypoints in compact list rows. Drag the thin divider beside either sidebar to resize it; double-click a divider to restore its default width. Drag a waypoint on the field; drag its square Bézier controls to change the curve. The selected pose's heading has its own rotation grip. The right inspector uses plain numeric fields for exact coordinates and heading. The **Motion settings** section opens on demand. Save an `.astra` project or export the active path as timed JSON. Existing `.moonpath.json` projects from the React prototype can be opened in the Flutter app with their Bézier controls preserved.

Click **Generate path** to optimize a smooth route through every placed pose waypoint, or use the route tool to click a new start and goal. Poses that would put the robot across the outer wall slide to the nearest valid position during generation. The hive graphic and interior markings are passable; the generated route checks the robot size against the outer perimeter. **Use 60 in/s preset** in **Motion settings** raises older paths to the 60 in/s and 100 in/s² defaults. Tune these limits for your robot there. The path and robot accents use blue and purple.

Enter your robot's full outside width and length in the inspector. Every pose waypoint appears as a full-size, rotatable robot box with a center point and a marked front edge; click or drag anywhere inside it to edit the pose. Playback shows the same footprint along the route. Dragging or rotating a pose, or increasing the robot size, shifts any colliding pose inside the outer wall. The editor highlights any curve that still carries the robot across the wall; export is blocked until that route is corrected. The editor uses matte controls and a field preview on the home screen.

The field shows nominal 2026–27 BIOBUZZ landmarks based on the [FIRST Competition Manual](https://ftc-resources.firstinspires.org/ftc/game/cm-html) and [Event Field Setup Guide](https://ftc-resources.firstinspires.org/ftc/archive/2027/field/eventfieldguide). These visual silhouettes are not collision geometry. Generated timing uses conservative velocity and acceleration bounds; it is not a time-optimal solver.

## Earlier web prototype

A field-first FTC path editor for Team 23477. This first milestone provides an editable geometric path and an independent robot-heading model.

## Run

Use Node.js 22.12+ (or a newer supported LTS release).

```sh
npm install
npm run dev
```

Open http://127.0.0.1:5173. `npm run build` creates a static production bundle in `dist`; `npm run preview` serves that bundle. `npm test` runs the geometry, history, and serialization tests.

## Editor

- Drag a pose to move it and its attached handles. Drag square controls to shape the actual cubic Bézier curve.
- Drag the gold rotation grip to set robot heading independently. The inspector offers waypoint, start-to-goal, fixed, and tangent heading modes.
- Double-click a curve to subdivide it without changing its geometry. Use Add waypoint or the Waypoint placement tool to extend editing. Intermediate poses can be reordered or deleted in the inspector.
- Pan with Space + drag, the middle mouse button, or H. Wheel to zoom around the pointer; F fits the field; V selects.
- Arrow keys move a selected pose by 0.25 in; Shift increases this to 1 in. Snap uses 1 in and 15° increments; hold Alt to bypass it.
- Ctrl+Z undoes an entire drag or numeric edit; Ctrl+Shift+Z redoes it. Ctrl+S saves and Ctrl+O opens.
- Save downloads a `.moonpath.json` project. Open validates files before replacing the document; that replacement is undoable. Export previews, copies, or downloads the same native JSON.
- A local browser recovery copy is saved after edits. Download project files for portable storage.

The distance slider inspects geometric poses along the path. Length and curvature are numerical estimates, sampled at 200 intervals per segment. It is not a timed drivetrain simulation.

## Architecture

| Directory | Responsibility |
| --- | --- |
| `src/core` | Framework-independent cubic geometry, heading evaluation, path operations, document history, and tests |
| `src/field` | Nominal field dimensions and source references |
| `src/io` | Versioned project schema validation and JSON export |
| `src/editor` | React bridge for transactional document history |
| `src/components` | Interactive SVG canvas, field rendering, and numeric inspector |

Internal distances use inches and angles use radians. The field origin is its center, +X points right, +Y points up, and heading is counterclockwise from +X. Canvas conversion is centralized. Stored cubic controls drive rendering and measurements directly. Heading and geometric tangent are separate quantities.

The interface uses local IBM Plex fonts, dark graphite surfaces, mint paths, and gold heading controls. Panels collapse to preserve field space. Pointer targets are larger than their visual handles; numeric controls provide a precise alternative to dragging.

## Field and milestone boundaries

The default field is a simplified nominal overhead model of 2026–27 BIOBUZZ, based on the [FIRST Competition Manual](https://ftc-resources.firstinspires.org/ftc/game/cm-html) and [Event Field Setup Guide](https://ftc-resources.firstinspires.org/ftc/archive/2027/field/eventfieldguide). It includes the 144 × 144 in nominal perimeter, tiles, hive frame, flowers, and alliance features. Simplified silhouettes are not collision volumes. The information dialog records dimensions and coordinate conventions.

Automatic obstacle avoidance, footprint collision checking over the full path, drivetrain constraints, trajectory timing, optimization, playback, and Pedro/Road Runner Java adapters belong to subsequent milestones. The current pose can show a perimeter footprint warning, but this does not certify path clearance or robot feasibility.

## Verification

Unit coverage includes cubic endpoints and splitting, preservation under insertion and reversal, arc-length inspection, independent headings, angle wrapping, linked handles, degenerate curves, coordinate transforms, robot footprints, transactional undo/redo, and strict JSON validation. Browser checks exercise insertion, numeric edits, undo/redo, heading edits, and control dragging.
