import 'package:flutter/material.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:provider/provider.dart';

class RangeSliderWidget extends StatefulWidget {
  final double minValue;
  final double maxValue;
  final double? currentMin;
  final double? currentMax;
  final Function(double, double) onChanged;
  final String label;
  final String? minLabel;
  final String? maxLabel;

  const RangeSliderWidget({
    super.key,
    required this.minValue,
    required this.maxValue,
    this.currentMin,
    this.currentMax,
    required this.onChanged,
    required this.label,
    this.minLabel,
    this.maxLabel,
  });

  @override
  State<RangeSliderWidget> createState() => _RangeSliderWidgetState();
}

class _RangeSliderWidgetState extends State<RangeSliderWidget> {
  late RangeValues _rangeValues;
  final TextEditingController _minController = TextEditingController();
  final TextEditingController _maxController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _rangeValues = RangeValues(
      widget.currentMin ?? widget.minValue,
      widget.currentMax ?? widget.maxValue,
    );
    _updateControllers();
  }

  @override
  void didUpdateWidget(RangeSliderWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentMin != oldWidget.currentMin ||
        widget.currentMax != oldWidget.currentMax) {
      _rangeValues = RangeValues(
        widget.currentMin ?? widget.minValue,
        widget.currentMax ?? widget.maxValue,
      );
      _updateControllers();
    }
  }

  void _updateControllers() {
    _minController.text = _rangeValues.start.toInt().toString();
    _maxController.text = _rangeValues.end.toInt().toString();
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final theme = themeManager.effectiveTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.onSurface,
              ),
            ),
            const SizedBox(height: 12),

            // Range Slider
            RangeSlider(
              values: _rangeValues,
              min: widget.minValue,
              max: widget.maxValue,
              divisions: 100,
              activeColor: theme.primary,
              inactiveColor: theme.primary.withValues(alpha: 0.3),
              labels: RangeLabels(
                '\$${_rangeValues.start.toInt()}',
                '\$${_rangeValues.end.toInt()}',
              ),
              onChanged: (RangeValues values) {
                setState(() {
                  _rangeValues = values;
                  _updateControllers();
                });
                widget.onChanged(values.start, values.end);
              },
            ),

            const SizedBox(height: 8),

            // Input fields
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.minLabel ?? 'Min',
                      hintText: '\$${widget.minValue.toInt()}',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      final newValue =
                          double.tryParse(value) ?? widget.minValue;
                      if (newValue <= _rangeValues.end) {
                        setState(() {
                          _rangeValues =
                              RangeValues(newValue, _rangeValues.end);
                        });
                        widget.onChanged(_rangeValues.start, _rangeValues.end);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: widget.maxLabel ?? 'Max',
                      hintText: 'No limit',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (value) {
                      final newValue =
                          double.tryParse(value) ?? widget.maxValue;
                      if (newValue >= _rangeValues.start) {
                        setState(() {
                          _rangeValues =
                              RangeValues(_rangeValues.start, newValue);
                        });
                        widget.onChanged(_rangeValues.start, _rangeValues.end);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
