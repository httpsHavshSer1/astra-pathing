import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'field_canvas.dart';
import 'glass.dart';
import 'model.dart';
import 'studio_state.dart';

class Editor extends StatefulWidget {
  final StudioState state;
  const Editor({super.key, required this.state});

  @override
  State<Editor> createState() => _EditorState();
}

class _EditorState extends State<Editor> {
  static const _handleWidth = 8.0;
  late double _leftWidth;
  late double _rightWidth;
  bool _leftHover = false;
  bool _rightHover = false;
  StudioState get s => widget.state;

  @override
  void initState() {
    super.initState();
    _leftWidth = s.leftSidebarWidth;
    _rightWidth = s.rightSidebarWidth;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final inspector = c.maxWidth >= 1180;
      final minFieldWidth = inspector ? 500.0 : 410.0;
      final leftMax = math.max(
        190.0,
        math.min(
          360.0,
          c.maxWidth -
              _handleWidth * (inspector ? 2 : 1) -
              minFieldWidth -
              (inspector ? 220.0 : 0.0),
        ),
      );
      final leftWidth = _leftWidth.clamp(190.0, leftMax).toDouble();
      final rightMax = math.max(
        220.0,
        math.min(
          360.0,
          c.maxWidth - _handleWidth * 2 - minFieldWidth - leftWidth,
        ),
      );
      final rightWidth = _rightWidth.clamp(220.0, rightMax).toDouble();
      return Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: ink)),
          Column(
            children: [
              Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .018),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withValues(alpha: .07),
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    InkWell(onTap: s.home, child: const Brand(compact: true)),
                    const SizedBox(width: 12),
                    Container(
                      width: 1,
                      height: 18,
                      color: Colors.white.withValues(alpha: .1),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.folder_outlined, size: 14, color: muted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: () => rename(context, true),
                        child: Text(
                          s.project.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    GlassButton(
                      'Save project',
                      icon: Icons.save_outlined,
                      onTap: s.busy ? null : () => s.saveProject(),
                      compact: true,
                    ),
                    const SizedBox(width: 9),
                    GlassButton(
                      'Export JSON',
                      icon: Icons.file_upload_outlined,
                      onTap: s.busy || s.wallCollision != null
                          ? null
                          : s.exportRobot,
                      compact: true,
                      primary: true,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      key: const Key('paths-sidebar'),
                      width: leftWidth,
                      child: leftPanel(context),
                    ),
                    resizeHandle(
                      key: const Key('left-sidebar-resize'),
                      label: 'Resize paths sidebar',
                      hovered: _leftHover,
                      onHover: (value) => setState(() => _leftHover = value),
                      onDrag: (delta) => setState(() {
                        _leftWidth = (_leftWidth + delta).clamp(190.0, leftMax);
                      }),
                      onEnd: () => s.saveSidebarWidths(_leftWidth, _rightWidth),
                      onReset: () {
                        setState(() => _leftWidth = 247);
                        s.saveSidebarWidths(_leftWidth, _rightWidth);
                      },
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          toolbar(context, inspector),
                          Expanded(child: FieldCanvas(state: s)),
                          compactTimeline(),
                        ],
                      ),
                    ),
                    if (inspector) ...[
                      resizeHandle(
                        key: const Key('right-sidebar-resize'),
                        label: 'Resize inspector',
                        hovered: _rightHover,
                        onHover: (value) => setState(() => _rightHover = value),
                        onDrag: (delta) => setState(() {
                          _rightWidth = (_rightWidth - delta).clamp(
                            220.0,
                            rightMax,
                          );
                        }),
                        onEnd: () =>
                            s.saveSidebarWidths(_leftWidth, _rightWidth),
                        onReset: () {
                          setState(() => _rightWidth = 254);
                          s.saveSidebarWidths(_leftWidth, _rightWidth);
                        },
                      ),
                      SizedBox(
                        key: const Key('inspector-sidebar'),
                        width: rightWidth,
                        child: inspectorPanel(context),
                      ),
                    ],
                  ],
                ),
              ),
              if (s.status.isNotEmpty || s.wallCollision != null)
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .025),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: .06),
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.circle,
                        size: 5,
                        color:
                            s.wallCollision != null ||
                                s.status.contains('failed')
                            ? const Color(0xFFF3B4AD)
                            : mint,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          s.wallCollision == null
                              ? s.status
                              : 'Robot crosses the outer wall near segment ${s.wallCollision!.segment + 1}. Move the waypoint or curve.',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9,
                            color: s.wallCollision == null
                                ? muted
                                : const Color(0xFFFF7F96),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      );
    },
  );
  Widget resizeHandle({
    required Key key,
    required String label,
    required bool hovered,
    required ValueChanged<bool> onHover,
    required ValueChanged<double> onDrag,
    required VoidCallback onEnd,
    required VoidCallback onReset,
  }) => Semantics(
    label: label,
    child: MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => onHover(true),
      onExit: (_) => onHover(false),
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onEnd(),
        onDoubleTap: onReset,
        child: Container(
          width: _handleWidth,
          color: const Color(0xFF10131C),
          alignment: Alignment.center,
          child: Container(
            width: hovered ? 2 : 1,
            height: 46,
            color: hovered ? const Color(0xFFAA98CE) : const Color(0xFF3B3E4B),
          ),
        ),
      ),
    ),
  );
  Widget divider() =>
      Divider(height: 1, color: Colors.white.withValues(alpha: .07));
  Widget leftPanel(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF151821),
      border: Border(
        right: BorderSide(color: Colors.white.withValues(alpha: .07)),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 9, 4),
          child: Row(
            children: [
              const Eyebrow('Paths'),
              const Spacer(),
              ToolButton(
                Icons.file_open_outlined,
                'Open project or path',
                onTap: s.open,
              ),
              ToolButton(Icons.add_rounded, 'New path', onTap: s.newPath),
            ],
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 185),
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: s.project.paths.length,
            itemBuilder: (context, i) {
              final active = i == s.project.active, p = s.project.paths[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => s.selectPath(i),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(0, 7, 4, 7),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: active
                            ? const Color(0xFF252A35)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 31,
                            color: active
                                ? const Color(0xFF9C91B4)
                                : Colors.transparent,
                          ),
                          const SizedBox(width: 9),
                          Icon(
                            Icons.route_rounded,
                            size: 16,
                            color: active ? const Color(0xFFB2A6C8) : muted,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: active ? text : muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${p.points.length} waypoints',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: 'Path actions',
                            padding: EdgeInsets.zero,
                            icon: const Icon(
                              Icons.more_horiz,
                              size: 15,
                              color: muted,
                            ),
                            onSelected: (value) {
                              s.selectPath(i);
                              switch (value) {
                                case 'rename':
                                  rename(context, false);
                                case 'duplicate':
                                  s.duplicatePath();
                                case 'delete':
                                  s.deletePath();
                              }
                            },
                            itemBuilder: (_) => [
                              const PopupMenuItem(
                                value: 'rename',
                                child: Text('Rename'),
                              ),
                              const PopupMenuItem(
                                value: 'duplicate',
                                child: Text('Duplicate'),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete path'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        divider(),
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 10, 14, 5),
          child: Eyebrow('Waypoints'),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: s.path.points.length,
            itemBuilder: (context, i) {
              final selected = i == s.selected, p = s.path.points[i];
              final color = i == 0
                  ? const Color(0xFF8DA6C5)
                  : i == s.path.points.length - 1
                  ? const Color(0xFFBE9FAA)
                  : const Color(0xFFA9A4B8);
              return Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => s.selectPoint(i),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 0,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(4),
                        color: selected
                            ? const Color(0xFF252A35)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 3,
                            height: 32,
                            color: selected
                                ? const Color(0xFF9C91B4)
                                : Colors.transparent,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 27,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${i + 1}'.padLeft(2, '0'),
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 11,
                                color: color,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  i == 0
                                      ? 'Start pose'
                                      : i == s.path.points.length - 1
                                      ? 'End pose'
                                      : 'Pose waypoint',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${p.x.toStringAsFixed(1)}, ${p.y.toStringAsFixed(1)} in',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${(p.heading * 180 / math.pi).round()}°',
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 10,
                              color: muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 3, 12, 7),
          child: Row(
            children: [
              ToolButton(
                Icons.arrow_upward_rounded,
                'Move earlier',
                onTap: s.selected > 0 ? () => s.reorderPoint(-1) : null,
              ),
              ToolButton(
                Icons.arrow_downward_rounded,
                'Move later',
                onTap: s.selected >= 0 && s.selected < s.path.points.length - 1
                    ? () => s.reorderPoint(1)
                    : null,
              ),
              ToolButton(
                Icons.add_box_outlined,
                'Insert waypoint',
                onTap: s.waypoint == null ? null : s.insertPoint,
              ),
              const Spacer(),
              ToolButton(
                Icons.delete_outline_rounded,
                'Delete waypoint',
                onTap: s.waypoint == null ? null : s.deletePoint,
              ),
            ],
          ),
        ),
        divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 9, 4),
          child: Row(
            children: [
              const Eyebrow('Event markers'),
              const Spacer(),
              ToolButton(
                Icons.add_rounded,
                'Add event marker',
                onTap: () => addMarker(context),
              ),
            ],
          ),
        ),
        if (s.path.markers.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Text(
              'No event markers',
              style: TextStyle(fontSize: 10, color: muted),
            ),
          ),
        if (s.path.markers.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 110),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: s.path.markers.length,
              itemBuilder: (context, i) {
                final m = s.path.markers[i];
                return Padding(
                  padding: const EdgeInsets.only(left: 18, right: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.diamond_outlined,
                        size: 12,
                        color: Color(0xFFF2CF9F),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          m.name,
                          style: const TextStyle(fontSize: 10),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(m.fraction * 100).round()}%',
                        style: const TextStyle(fontSize: 9, color: muted),
                      ),
                      ToolButton(
                        Icons.close_rounded,
                        'Remove marker',
                        onTap: () => s.edit(() => s.path.markers.removeAt(i)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    ),
  );
  Widget toolbar(BuildContext context, bool inspector) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(color: Colors.white.withValues(alpha: .05)),
      ),
    ),
    child: Row(
      children: [
        Glass(
          radius: 10,
          padding: const EdgeInsets.all(3),
          child: Row(
            children: [
              ToolButton(
                Icons.near_me_outlined,
                'Select / move',
                active: s.tool == EditorTool.select,
                onTap: () => s.setTool(EditorTool.select),
              ),
              ToolButton(
                Icons.add_location_alt_outlined,
                'Plot points',
                active: s.tool == EditorTool.place,
                onTap: () => s.setTool(EditorTool.place),
              ),
              ToolButton(
                Icons.alt_route_rounded,
                'Pick start and goal for new route',
                active: s.tool == EditorTool.route,
                onTap: s.beginRouteSelection,
              ),
              ToolButton(
                Icons.pan_tool_outlined,
                'Pan field',
                active: s.tool == EditorTool.pan,
                onTap: () => s.setTool(EditorTool.pan),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        GlassButton(
          'Generate path',
          icon: Icons.route_rounded,
          compact: true,
          onTap: s.generateRoute,
        ),
        const SizedBox(width: 8),
        ToolButton(
          Icons.undo_rounded,
          'Undo · Ctrl Z',
          onTap: s.canUndo ? s.undo : null,
        ),
        ToolButton(
          Icons.redo_rounded,
          'Redo · Ctrl Y',
          onTap: s.canRedo ? s.redo : null,
        ),
        const Spacer(),
        PopupMenuButton<String>(
          tooltip: 'View and path options',
          icon: const Icon(Icons.tune_rounded, size: 19, color: muted),
          onSelected: (value) {
            switch (value) {
              case 'grid':
                s.toggle('grid');
              case 'snap':
                s.toggle('snap');
              case 'handles':
                s.toggle('handles');
              case 'robot':
                s.toggle('robot');
              case 'mirror':
                s.mirror();
              case 'route':
                s.beginRouteSelection();
            }
          },
          itemBuilder: (_) => [
            CheckedPopupMenuItem(
              value: 'grid',
              checked: s.showGrid,
              child: const Text('Field grid'),
            ),
            CheckedPopupMenuItem(
              value: 'snap',
              checked: s.snap,
              child: const Text('Snap to 6 in'),
            ),
            CheckedPopupMenuItem(
              value: 'handles',
              checked: s.showHandles,
              child: const Text('Bézier controls'),
            ),
            CheckedPopupMenuItem(
              value: 'robot',
              checked: s.showFootprint,
              child: const Text('Show robot'),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'route',
              child: Text('Pick new start and goal'),
            ),
            const PopupMenuItem(value: 'mirror', child: Text('Mirror path')),
          ],
        ),
        if (!inspector)
          ToolButton(
            Icons.tune_rounded,
            'Path inspector',
            onTap: () => showDialog<void>(
              context: context,
              builder: (context) => Dialog(
                child: SizedBox(
                  width: 300,
                  height: 640,
                  child: AnimatedBuilder(
                    animation: s,
                    builder: (_, child) => inspectorPanel(context),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
  Widget inspectorPanel(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF151821),
      border: Border(
        left: BorderSide(color: Colors.white.withValues(alpha: .07)),
      ),
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Eyebrow('Inspector'),
              const Spacer(),
              if (s.waypoint != null)
                PopupMenuButton<String>(
                  tooltip: 'Waypoint actions',
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.more_horiz, size: 17, color: muted),
                  onSelected: (value) {
                    if (value == 'heading') s.holdHeading();
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'heading',
                      child: Text('Apply heading to all waypoints'),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            s.waypoint == null
                ? 'Select a waypoint'
                : 'Waypoint ${s.selected + 1}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (s.waypoint != null) ...[
            Row(
              children: [
                Expanded(
                  child: NumericField(
                    'Position X',
                    value: s.waypoint!.x,
                    suffix: 'in',
                    min: -72,
                    max: 72,
                    onChanged: (v) => s.setPosition(x: v),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: NumericField(
                    'Position Y',
                    value: s.waypoint!.y,
                    suffix: 'in',
                    min: -72,
                    max: 72,
                    onChanged: (v) => s.setPosition(y: v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            NumericField(
              'Robot heading',
              value: s.waypoint!.heading * 180 / math.pi,
              suffix: 'deg',
              min: -180,
              max: 180,
              onChanged: (v) => s.setHeading(v * math.pi / 180),
            ),
          ],
          const SizedBox(height: 14),
          divider(),
          Material(
            color: Colors.transparent,
            child: ExpansionTile(
              title: const Text(
                'Motion settings',
                style: TextStyle(fontSize: 11, color: text),
              ),
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: false,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: s.applyFastMotion,
                    child: const Text('Use 60 in/s preset'),
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'Smoothing',
                      style: TextStyle(fontSize: 10, color: muted),
                    ),
                    const Spacer(),
                    Text(
                      '${(s.path.smoothing * 100).round()}%',
                      style: const TextStyle(fontSize: 10, color: violet),
                    ),
                  ],
                ),
                Slider(
                  value: s.path.smoothing,
                  onChangeStart: (_) => s.record(),
                  onChanged: s.updateSmoothing,
                  onChangeEnd: (_) => s.persist(),
                ),
                const SizedBox(height: 5),
                NumericField(
                  'Max linear speed',
                  value: s.path.maxSpeed,
                  suffix: 'in/s',
                  min: 1,
                  max: 120,
                  onChanged: (v) => s.edit(() => s.path.maxSpeed = v),
                ),
                const SizedBox(height: 13),
                NumericField(
                  'Max acceleration',
                  value: s.path.maxAcceleration,
                  suffix: 'in/s²',
                  min: 1,
                  max: 200,
                  onChanged: (v) => s.edit(() => s.path.maxAcceleration = v),
                ),
                const SizedBox(height: 13),
                NumericField(
                  'Max angular speed',
                  value: s.path.maxOmega,
                  suffix: 'deg/s',
                  min: 5,
                  max: 720,
                  onChanged: (v) => s.edit(() => s.path.maxOmega = v),
                ),
                const SizedBox(height: 13),
                NumericField(
                  'Max angular acceleration',
                  value: s.path.maxAlpha,
                  suffix: 'deg/s²',
                  min: 5,
                  max: 1440,
                  onChanged: (v) => s.edit(() => s.path.maxAlpha = v),
                ),
                const SizedBox(height: 13),
                NumericField(
                  'Sample interval',
                  value: s.path.samplePeriod,
                  suffix: 's',
                  min: .01,
                  max: .2,
                  onChanged: (v) => s.edit(() => s.path.samplePeriod = v),
                ),
              ],
            ),
          ),
          divider(),
          const SizedBox(height: 20),
          const Eyebrow('Robot size'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NumericField(
                  'Width',
                  value: s.project.robotWidth,
                  suffix: 'in',
                  min: 1,
                  max: 30,
                  onChanged: (v) => s.setRobotSize(width: v),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: NumericField(
                  'Length',
                  value: s.project.robotLength,
                  suffix: 'in',
                  min: 1,
                  max: 30,
                  onChanged: (v) => s.setRobotSize(length: v),
                ),
              ),
            ],
          ),
          if (s.wallCollision != null) ...[
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.only(top: 12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFF303540))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: Color(0xFFFF7F96),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Robot crosses the outer wall near segment ${s.wallCollision!.segment + 1}. Move the waypoint or reshape the curve before export.',
                      style: const TextStyle(
                        fontSize: 10,
                        height: 1.45,
                        color: Color(0xFFFF7F96),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ),
  );
  Widget compactTimeline() => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: const Color(0xFF10111D),
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: .07)),
      ),
    ),
    child: Row(
      children: [
        ToolButton(
          s.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          'Play / pause',
          onTap: s.togglePlay,
        ),
        Expanded(
          child: Slider(
            value: s.generated.duration == 0
                ? 0
                : s.playhead / s.generated.duration,
            onChanged: (v) => s.seek(v * s.generated.duration),
          ),
        ),
        SizedBox(
          width: 42,
          child: Text(
            s.playhead.toStringAsFixed(1),
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 10, color: muted),
          ),
        ),
      ],
    ),
  );

  Widget timeline() => Container(
    height: 137,
    padding: const EdgeInsets.fromLTRB(22, 11, 22, 10),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .02),
      border: Border(
        top: BorderSide(color: Colors.white.withValues(alpha: .07)),
      ),
    ),
    child: Column(
      children: [
        Row(
          children: [
            const Eyebrow('Trajectory preview'),
            const Spacer(),
            Text(
              '${s.generated.length.toStringAsFixed(1)} in',
              style: const TextStyle(fontSize: 10, color: text),
            ),
            const SizedBox(width: 18),
            Text(
              '${s.generated.duration.toStringAsFixed(2)} s',
              style: const TextStyle(fontSize: 10, color: text),
            ),
            const SizedBox(width: 18),
            const Text(
              'VELOCITY',
              style: TextStyle(fontSize: 8, letterSpacing: 1, color: violet),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Expanded(
          child: Row(
            children: [
              ToolButton(
                Icons.skip_previous_rounded,
                'Restart preview',
                onTap: () => s.seek(0),
              ),
              const SizedBox(width: 2),
              Tooltip(
                message: 'Play / pause · Space',
                child: InkWell(
                  onTap: s.togglePlay,
                  borderRadius: BorderRadius.circular(25),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: violet.withValues(alpha: .18),
                      shape: BoxShape.circle,
                      border: Border.all(color: violet.withValues(alpha: .3)),
                    ),
                    child: Icon(
                      s.playing
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: violet,
                      size: 22,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: CustomPaint(
                        size: const Size(double.infinity, 35),
                        painter: VelocityPainter(s.generated, s.playhead),
                      ),
                    ),
                    SizedBox(
                      height: 26,
                      child: Slider(
                        value: s.generated.duration == 0
                            ? 0
                            : s.playhead / s.generated.duration,
                        onChanged: (v) => s.seek(v * s.generated.duration),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                width: 58,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      s.playhead.toStringAsFixed(2),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: mint,
                      ),
                    ),
                    const Text(
                      'SECONDS',
                      style: TextStyle(
                        fontSize: 7,
                        letterSpacing: 1,
                        color: muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            const SizedBox(width: 102),
            const Text('0.00', style: TextStyle(fontSize: 8, color: muted)),
            const Spacer(),
            Text(
              '${s.generated.duration.toStringAsFixed(2)} s',
              style: const TextStyle(fontSize: 8, color: muted),
            ),
            const SizedBox(width: 73),
          ],
        ),
      ],
    ),
  );
  Future<void> rename(BuildContext context, bool project) async {
    final controller = TextEditingController(
      text: project ? s.project.name : s.path.name,
    );
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(project ? 'Name your project' : 'Name your path'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) {
      s.edit(() {
        if (project) {
          s.project.name = value.trim();
        } else {
          s.path.name = value.trim();
        }
      });
    }
    // The dialog owns its text field until its closing animation completes.
  }

  Future<void> addMarker(BuildContext context) async {
    if (s.path.markers.length >= 100) return;
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark this moment'),
        content: SizedBox(
          width: 330,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'At ${s.playhead.toStringAsFixed(2)} seconds on the preview timeline.',
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: 80,
                decoration: const InputDecoration(
                  labelText: 'Command name',
                  hintText: 'e.g. intake',
                ),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
              const SizedBox(height: 10),
              const Text(
                'Use the exact commandMap key from your FTC program.',
                style: TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Add marker'),
          ),
        ],
      ),
    );
    if (value != null && value.trim().isNotEmpty) {
      s.edit(
        () => s.path.markers.add(
          EventMarker(
            value.trim(),
            s.generated.duration == 0 ? 0 : s.playhead / s.generated.duration,
          ),
        ),
      );
    }
  }
}
