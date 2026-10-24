import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/scheduler.dart';
import 'editor.dart';
import 'glass.dart';
import 'landing.dart';
import 'studio_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final state = StudioState();
  await state.initialize();
  runApp(AstraApp(state: state));
}

class AstraApp extends StatefulWidget {
  final StudioState state;
  final bool animate;
  const AstraApp({super.key, required this.state, this.animate = true});
  @override
  State<AstraApp> createState() => _AstraAppState();
}

class _AstraAppState extends State<AstraApp>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  Duration previous = Duration.zero;
  double phase = 0;
  @override
  void initState() {
    super.initState();
    ticker = createTicker((elapsed) {
      final dt = math.min(.1, (elapsed - previous).inMicroseconds / 1e6);
      previous = elapsed;
      widget.state.tick(dt);
      if (widget.animate &&
          !widget.state.reducedMotion &&
          !widget.state.inEditor &&
          mounted) {
        setState(() => phase = (phase + dt / 18) % 1);
      }
    });
    if (widget.animate) ticker.start();
  }

  @override
  void dispose() {
    ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'AstraPathing',
    debugShowCheckedModeBanner: false,
    theme: studioTheme(),
    home: AnimatedBuilder(
      animation: widget.state,
      builder: (context, child) => CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.keyS, control: true): () =>
              widget.state.saveProject(),
          const SingleActivator(LogicalKeyboardKey.keyO, control: true): () =>
              widget.state.open(),
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              widget.state.undo,
          const SingleActivator(LogicalKeyboardKey.keyY, control: true):
              widget.state.redo,
          const SingleActivator(LogicalKeyboardKey.escape): () {
            if (widget.state.tool == EditorTool.route) {
              widget.state.cancelRouteSelection();
            } else {
              widget.state.seek(widget.state.playhead);
            }
          },
        },
        child: Focus(
          autofocus: true,
          child: Scaffold(
            body: RepaintBoundary(
              key: const Key('app-screenshot'),
              child: widget.state.inEditor
                  ? TooltipVisibility(
                      visible: false,
                      child: Editor(state: widget.state),
                    )
                  : Landing(
                      state: widget.state,
                      phase: phase,
                      onGuide: () => showGuide(context),
                    ),
            ),
          ),
        ),
      ),
    ),
  );
  void showGuide(BuildContext context) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.auto_awesome, color: violet),
          SizedBox(width: 12),
          Text('From screen to field'),
        ],
      ),
      content: SizedBox(
        width: 510,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              guideItem(
                '01',
                'Shape your route',
                'Place pose waypoints, then click Generate path to optimize a smooth trajectory through all of them. The route tool lets you pick a new start and goal.',
              ),
              guideItem(
                '02',
                'Preview the movement',
                'Play or scrub the timeline. Adjust speed limits in Motion settings. Check the result against your robot.',
              ),
              guideItem(
                '03',
                'Save your workspace',
                'Save project keeps every path, constraint, and marker in an .astra file. Local autosave also recovers your latest workspace on launch.',
              ),
              guideItem(
                '04',
                'Export for team 23477',
                'Export the active path as JSON into TeamCode/src/main/assets. It contains sampled_points in meters, with radians and seconds, matching your PolarPathFollower.',
              ),
              const Divider(height: 28),
              const Text(
                'Two separate projects',
                style: TextStyle(fontWeight: FontWeight.w600, color: mint),
              ),
              const SizedBox(height: 8),
              const Text(
                'AstraPathing is the Flutter desktop app. 2025-FTC-23477 is your independent Android robot project. Only exported JSON passes between them.',
                style: TextStyle(color: muted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                'Robot export: lower-left field origin. Editor: field-center inches. Export converts coordinates automatically. Event names need entries in your robot’s commandMap.',
                style: TextStyle(color: muted, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
  Widget guideItem(String n, String title, String body) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(n, style: const TextStyle(color: violet, fontSize: 13)),
        const SizedBox(width: 18),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                body,
                style: const TextStyle(color: muted, fontSize: 12, height: 1.6),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
