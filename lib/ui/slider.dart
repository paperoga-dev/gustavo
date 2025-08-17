import "dart:async";

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

class ExSlider extends StatefulWidget {
  final String labelText;
  final String prefKey;

  const ExSlider({super.key, required this.labelText, required this.prefKey});

  @override
  State<ExSlider> createState() => _ExSliderState();
}

class _ExSliderState extends State<ExSlider> {
  final _prefs = SharedPreferencesAsync();
  final List<String> _values = [
    "Random",
    ...List.generate(11, (i) => (i / 10).toStringAsFixed(1)),
  ];
  double _sliderIndex = 0;

  @override
  void initState() {
    super.initState();

    unawaited(_initSelected());
  }

  Future<void> _initSelected() async {
    if (!await _prefs.containsKey(widget.prefKey)) {
      await _prefs.setDouble(widget.prefKey, -1);
    }

    final double sliderIndex = (await _prefs.getDouble(widget.prefKey))! + 1;

    if (!mounted) {
      return;
    }

    setState(() {
      _sliderIndex = sliderIndex;
    });
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text("${widget.labelText} ${_values[_sliderIndex.round()]}"),
      Slider(
        value: _sliderIndex,
        max: (_values.length - 1).toDouble(),
        divisions: _values.length - 1,
        label: _values[_sliderIndex.round()],
        onChanged: (newIndex) async {
          await _prefs.setDouble(widget.prefKey, newIndex - 1);

          setState(() {
            _sliderIndex = newIndex;
          });
        },
      ),
    ],
  );
}
