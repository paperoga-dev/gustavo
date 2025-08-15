import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ExTextFieldType { text, number }

class ExTextField extends StatefulWidget {
  final String labelText;
  final String prefKey;
  final TextInputType? keyboardType;
  final dynamic defaultValue;
  final bool? obscureText;

  const ExTextField({
    super.key,
    required this.labelText,
    required this.prefKey,
    required this.defaultValue,
    this.keyboardType,
    this.obscureText,
  });

  @override
  State<ExTextField> createState() => _ExTextFieldState();
}

class _ExTextFieldState extends State<ExTextField> {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();

    _focusNode.addListener(() async {
      if (!_focusNode.hasFocus) {
        await save();
      }
    });

    _initController();
  }

  Future<void> save() async {
    switch (widget.keyboardType) {
      case TextInputType.number:
        await _prefs.setInt(widget.prefKey, int.parse(_controller.text));
        break;
      default:
        await _prefs.setString(widget.prefKey, _controller.text);
        break;
    }
  }

  Future<void> _initController() async {
    if (!await _prefs.containsKey(widget.prefKey)) {
      switch (widget.keyboardType) {
        case TextInputType.number:
          await _prefs.setInt(widget.prefKey, widget.defaultValue);
          break;
        default:
          await _prefs.setString(widget.prefKey, widget.defaultValue);
          break;
      }
    }

    final String value = widget.keyboardType == TextInputType.number ?
        (await _prefs.getInt(widget.prefKey))!.toString() :
        (await _prefs.getString(widget.prefKey))!;

    if (!mounted) return;

    setState(() {
      _controller.text = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType ?? TextInputType.text,
      obscureText: widget.obscureText ?? false,
      decoration: InputDecoration(
        border: OutlineInputBorder(),
        labelText: widget.labelText,
      ),
    );
  }
}
