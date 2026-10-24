# AstraPathing for Windows

Flutter source for the FTC field editor. Use Flutter 3.47.4 for the verified Windows build.

```sh
flutter pub get
flutter run -d windows
flutter test
.\tool\package_windows.ps1
..\packaging\build_single_exe.ps1
```

The application opens in the editor. Select, add, and drag waypoints on the field. Drag the selected waypoint's small Bézier controls to shape the curve; its heading is edited separately. The left panel uses compact rows for paths and waypoints, while the right inspector contains plain numeric fields and expandable motion settings. Drag either sidebar divider to resize it, or double-click a divider to restore its default width. Widths are saved locally.

Place pose waypoints, then click **Generate path** to optimize the connecting Bézier curves through every requested pose. The robot carries speed and heading motion through ordinary intermediate poses; it stops at the start and finish. If a pose would put the robot across the outer wall, generation moves it to the nearest valid center while preserving its heading. The optimizer searches for a shorter traversal time under the current speed and acceleration limits, with a small path-length preference. On an empty path, Generate path switches to two-click start and goal selection; the route tool also lets you pick new endpoints at any time. The hive graphic and interior zone markings are passable to this planner. It samples the rotated robot footprint to keep the generated route inside the outer field perimeter. Undo restores the previous curves and positions.

Set the measured outside **Width** and **Length** in the Robot size inspector, including bumpers and attachments. Each pose waypoint and the playback robot draw that full box with a center point and a marked front edge. Click or drag anywhere inside a waypoint box to select or move it; its heading grip sits just beyond the front edge. Placing, dragging, and rotating waypoints keeps the box inside the outer wall; increasing its dimensions adjusts existing poses as needed. A path whose curve still crosses the wall is flagged and cannot be exported until corrected. Interior field art remains passable.

New paths use 60 in/s linear speed and 100 in/s² linear acceleration defaults. Click **Use 60 in/s preset** in **Motion settings** to apply those limits to an older path, then adjust the limits for your actual robot. Preview and timed JSON use an acceleration-limited travel profile that begins moving immediately. This is a local optimizer over cubic curves and a conservative timing model, not Choreo's drivetrain solver or a guaranteed global optimum. Confirm physical clearance and achievable speed on the field.

Save `.astra` files to keep all project data. The Open action also accepts `.moonpath.json` projects from the earlier web prototype and preserves their Bézier controls. Export JSON produces the existing timed FTC 23477 format. The nominal BIOBUZZ field overlay is a visual guide and does not establish collision clearance.

The packaging script builds the release, copies the x64 Visual C++ runtime from the installed Visual Studio build tools, and writes `../release/AstraPathing-Windows.zip`. The single-file script embeds that ZIP in `../release/AstraPathing.exe`; the EXE extracts its runtime into local app data automatically and launches the editor. Pass `-Flutter 'C:\path\to\flutter.bat'` when Flutter is not on your PATH. The ZIP remains available for folder-based distribution.
