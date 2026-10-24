import 'package:flutter/material.dart';
import 'route_logo.dart';

const ink = Color(0xFF080A13);
const surface = Color(0xFF141624);
const violet = Color(0xFFAE94FF);
const mint = Color(0xFF91A9FF);
const text = Color(0xFFF3F1FC);
const muted = Color(0xFF9694AC);

ThemeData studioTheme() => ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  fontFamily: 'Inter',
  scaffoldBackgroundColor: ink,
  colorScheme: const ColorScheme.dark(
    primary: violet,
    secondary: mint,
    surface: surface,
    onSurface: text,
  ),
  textTheme: const TextTheme(
    bodyMedium: TextStyle(fontSize: 13, height: 1.5, color: text),
    bodySmall: TextStyle(fontSize: 11, height: 1.4, color: muted),
  ),
  tooltipTheme: TooltipThemeData(
    decoration: BoxDecoration(
      color: const Color(0xFF27243B),
      borderRadius: BorderRadius.circular(8),
    ),
    textStyle: const TextStyle(fontSize: 11, color: text),
  ),
  sliderTheme: const SliderThemeData(
    trackHeight: 3,
    thumbShape: RoundSliderThumbShape(enabledThumbRadius: 5),
    overlayShape: RoundSliderOverlayShape(overlayRadius: 11),
    inactiveTrackColor: Color(0xFF373448),
  ),
  inputDecorationTheme: InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: const Color(0xFF1D222C),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF353B47)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(4),
      borderSide: const BorderSide(color: Color(0xFF9B90B5)),
    ),
  ),
  dialogTheme: DialogThemeData(
    backgroundColor: const Color(0xFF161523),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  popupMenuTheme: PopupMenuThemeData(
    color: const Color(0xFF222035),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
  ),
);

class Glass extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? tint;
  const Glass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.radius = 8,
    this.tint,
  });
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(radius),
    child: Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: tint ?? const Color(0xFF1B1D29),
        border: Border.all(color: const Color(0xFF343542)),
      ),
      child: child,
    ),
  );
}

class GlassButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool primary, compact;
  const GlassButton(
    this.label, {
    super.key,
    this.icon,
    this.onTap,
    this.primary = false,
    this.compact = false,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap == null
            ? null
            : () {
                FocusManager.instance.primaryFocus?.unfocus();
                onTap!();
              },
        borderRadius: BorderRadius.circular(6),
        hoverColor: Colors.white.withValues(alpha: .09),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            color: primary ? const Color(0xFFA999CF) : const Color(0xFF20222E),
            border: Border.all(
              color: primary
                  ? const Color(0xFFB7A9D4)
                  : const Color(0xFF363744),
            ),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 19,
            vertical: compact ? 10 : 14,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: compact ? 16 : 18,
                  color: primary
                      ? ink
                      : onTap == null
                      ? muted
                      : text,
                ),
                const SizedBox(width: 9),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: primary
                      ? ink
                      : onTap == null
                      ? muted
                      : text,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class ToolButton extends StatelessWidget {
  final IconData icon;
  final String tip;
  final VoidCallback? onTap;
  final bool active;
  const ToolButton(
    this.icon,
    this.tip, {
    super.key,
    this.onTap,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tip,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(5),
        child: Container(
          width: 35,
          height: 35,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(5),
            color: active ? violet.withValues(alpha: .15) : Colors.transparent,
            border: active
                ? Border.all(color: violet.withValues(alpha: .35))
                : null,
          ),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? muted.withValues(alpha: .3)
                : active
                ? violet
                : muted,
          ),
        ),
      ),
    ),
  );
}

class Eyebrow extends StatelessWidget {
  final String label;
  final Color color;
  const Eyebrow(this.label, {super.key, this.color = muted});
  @override
  Widget build(BuildContext context) => Text(
    label,
    style: TextStyle(
      color: color,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: .1,
    ),
  );
}

class Brand extends StatelessWidget {
  final bool compact;
  const Brand({super.key, this.compact = false});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      RouteLogo(size: compact ? 26 : 38),
      SizedBox(width: compact ? 9 : 12),
      Text(
        'AstraPathing',
        style: TextStyle(
          fontSize: compact ? 16 : 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -.7,
        ),
      ),
    ],
  );
}

class NumericField extends StatefulWidget {
  final String label, suffix;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const NumericField(
    this.label, {
    super.key,
    required this.value,
    required this.onChanged,
    this.suffix = '',
    this.min = -double.infinity,
    this.max = double.infinity,
  });
  @override
  State<NumericField> createState() => _NumericFieldState();
}

class _NumericFieldState extends State<NumericField> {
  late final TextEditingController controller = TextEditingController(
    text: formatted(),
  );
  final FocusNode focus = FocusNode();
  String formatted() => widget.value.toStringAsFixed(
    widget.value == widget.value.roundToDouble() ? 0 : 2,
  );
  @override
  void initState() {
    super.initState();
    focus.addListener(() {
      if (!focus.hasFocus) commit();
    });
  }

  void commit() {
    final v = double.tryParse(controller.text);
    if (v != null &&
        v.isFinite &&
        v >= widget.min &&
        v <= widget.max &&
        v != widget.value) {
      widget.onChanged(v);
    }
    controller.text = formatted();
  }

  @override
  void didUpdateWidget(NumericField old) {
    super.didUpdateWidget(old);
    if (!focus.hasFocus) controller.text = formatted();
  }

  @override
  void dispose() {
    controller.dispose();
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.label, style: const TextStyle(color: muted, fontSize: 10)),
      const SizedBox(height: 7),
      TextField(
        controller: controller,
        focusNode: focus,
        style: const TextStyle(fontFamily: 'Inter', fontSize: 12, color: text),
        keyboardType: const TextInputType.numberWithOptions(
          decimal: true,
          signed: true,
        ),
        onSubmitted: (_) => {commit(), focus.unfocus()},
        decoration: InputDecoration(
          suffixText: widget.suffix,
          suffixStyle: const TextStyle(fontSize: 10, color: muted),
        ),
      ),
    ],
  );
}
