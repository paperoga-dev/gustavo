import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ExListView extends StatefulWidget {
  final List<String> items;
  final String labelText;
  final String prefKey;
  final String defaultValue;

  const ExListView({
    super.key,
    required this.items,
    required this.labelText,
    required this.prefKey,
    required this.defaultValue
  });

  @override
  State<ExListView> createState() => _ExListViewState();
}

class _ExListViewState extends State<ExListView> {
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();
  int _selected = -1;

  @override
  void initState() {
    super.initState();

    _initSelected();
  }

  Future<void> _initSelected() async {
    if (!await _prefs.containsKey(widget.prefKey)) {
      await _prefs.setString(widget.prefKey, widget.defaultValue.toString());
    }

    final int selected = widget.items.indexOf(
      await _prefs.getString(widget.prefKey) ?? "",
    );

    if (!mounted) return;

    setState(() {
      _selected = selected;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.labelText),
        Expanded(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.items.length,
            itemBuilder: (context, index) {
              final isSelected = index == _selected;

              return ListTile(
                title: Text(
                  widget.items[index],
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
                tileColor: isSelected ? Colors.blue : null,
                onTap: () async {
                  await _prefs.setString(widget.prefKey, widget.items[index]);
                  setState(() {
                    _selected = index;
                  });
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
