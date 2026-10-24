import 'package:flutter/material.dart';
import 'cosmos.dart';
import 'field_canvas.dart';
import 'glass.dart';
import 'route_logo.dart';
import 'studio_state.dart';

class Landing extends StatelessWidget {
  final StudioState state;
  final double phase;
  final VoidCallback onGuide;
  const Landing({
    super.key,
    required this.state,
    required this.phase,
    required this.onGuide,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth > 1050;
      return Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: CustomPaint(painter: CosmosPainter(phase: phase)),
            ),
          ),
          Positioned.fill(
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 58 : 30,
                    vertical: 28,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Brand(),
                          const Spacer(),
                          ToolButton(
                            state.reducedMotion
                                ? Icons.motion_photos_off_rounded
                                : Icons.motion_photos_on_rounded,
                            'Toggle ambient animation',
                            onTap: state.toggleMotion,
                          ),
                          const SizedBox(width: 12),
                          GlassButton(
                            'Open project',
                            icon: Icons.folder_open_rounded,
                            onTap: state.open,
                            compact: true,
                          ),
                        ],
                      ),
                      SizedBox(height: wide ? 34 : 20),
                      SizedBox(
                        height: wide ? 510 : 420,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (wide)
                              Positioned(
                                left: constraints.maxWidth * .49,
                                right: 0,
                                top: 15,
                                bottom: 5,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF151722),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: const Color(0xFF343542),
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(7),
                                    child: Column(
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 17,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.crop_square_rounded,
                                                size: 15,
                                                color: muted,
                                              ),
                                              const SizedBox(width: 8),
                                              const Eyebrow('Field preview'),
                                              const Spacer(),
                                              Flexible(
                                                child: Text(
                                                  state.project.name,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: const TextStyle(
                                                    fontSize: 10,
                                                    color: muted,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Divider(
                                          height: 1,
                                          color: Color(0xFF343542),
                                        ),
                                        Expanded(
                                          child: CustomPaint(
                                            painter: FieldPainter(
                                              state,
                                              1.06,
                                              Offset.zero,
                                            ),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              left: 0,
                              top: 48,
                              width: wide ? 570 : constraints.maxWidth - 80,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Plan robot paths.\nPreview every move.',
                                    style: TextStyle(
                                      fontSize: wide ? 59 : 47,
                                      height: 1.13,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: -2.5,
                                    ),
                                  ),
                                  const SizedBox(height: 22),
                                  const SizedBox(
                                    width: 390,
                                    child: Text(
                                      'Set poses on the field, generate a route,\ncheck clearance, and export the path\nfor your autonomous program.',
                                      style: TextStyle(
                                        fontSize: 14,
                                        height: 1.85,
                                        color: muted,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 27),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GlassButton(
                                        'Launch studio',
                                        icon: Icons.arrow_outward_rounded,
                                        primary: true,
                                        onTap: () => state.enter(),
                                      ),
                                      const SizedBox(width: 12),
                                      GlassButton(
                                        'Start a new project',
                                        onTap: () => state.enter(fresh: true),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Eyebrow('Projects'),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: InkWell(
                              onTap: () => state.enter(),
                              borderRadius: BorderRadius.circular(8),
                              child: Glass(
                                padding: const EdgeInsets.all(21),
                                child: Row(
                                  children: [
                                    const RouteLogo(size: 57),
                                    const SizedBox(width: 18),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Eyebrow(
                                            state.hasRecovery
                                                ? 'Recent project'
                                                : 'Example project',
                                            color: violet,
                                          ),
                                          const SizedBox(height: 7),
                                          Text(
                                            state.project.name,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '${state.project.paths.length} path${state.project.paths.length == 1 ? '' : 's'}  ·  ${state.path.points.length} waypoints  ·  FTC 23477',
                                            style: const TextStyle(
                                              color: muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    const Icon(
                                      Icons.arrow_outward_rounded,
                                      color: muted,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: InkWell(
                              onTap: onGuide,
                              borderRadius: BorderRadius.circular(8),
                              child: Glass(
                                padding: const EdgeInsets.all(21),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(
                                          Icons.auto_stories_outlined,
                                          color: mint,
                                          size: 19,
                                        ),
                                        Spacer(),
                                        Icon(
                                          Icons.arrow_outward_rounded,
                                          color: muted,
                                          size: 16,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    const Text(
                                      'From screen to field',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      wide
                                          ? 'A quick guide to your first autonomous.'
                                          : 'Your first autonomous.',
                                      style: const TextStyle(
                                        color: muted,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}
