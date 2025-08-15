import "dart:async";

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

class ExCheckBox extends StatefulWidget {
  final String labelText;
  final String prefKey;
  final bool defaultValue;

  const ExCheckBox({
    super.key,
    required this.labelText,
    required this.prefKey,
    required this.defaultValue,
  });

  @override
  State<ExCheckBox> createState() => _ExCheckBoxState();
}

class _ExCheckBoxState extends State<ExCheckBox> {
  final _prefs = SharedPreferencesAsync();
  var _checked = false;

  @override
  void initState() {
    super.initState();

    unawaited(_initCheck());
  }

  Future<void> _initCheck() async {
    if (!await _prefs.containsKey(widget.prefKey)) {
      await _prefs.setString(widget.prefKey, widget.defaultValue.toString());
    }

    final checked = (await _prefs.getString(widget.prefKey)) == "true";

    if (!mounted) {
      return;
    }

    setState(() {
      _checked = checked;
    });
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Checkbox(
        value: _checked,
        onChanged: (value) async {
          await _prefs.setString(widget.prefKey, value.toString());
          setState(() {
            _checked = value!;
          });
        },
      ),
      Text(widget.labelText),
    ],
  );
}
