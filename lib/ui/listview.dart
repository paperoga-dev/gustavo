import "dart:async";

import "package:flutter/material.dart";
import "package:shared_preferences/shared_preferences.dart";

class ExListView extends StatefulWidget {
  final Future<List<String>> items;
  final String labelText;
  final String prefKey;
  final String defaultValue;
  final String waitingMessage;

  const ExListView({
    super.key,
    required this.items,
    required this.labelText,
    required this.prefKey,
    required this.defaultValue,
    required this.waitingMessage,
  });

  @override
  State<ExListView> createState() => _ExListViewState();
}

class _ExListViewState extends State<ExListView> {
  final _prefs = SharedPreferencesAsync();
  late Future<List<String>> _items;
  var _selected = -1;

  @override
  void initState() {
    super.initState();

    _items = widget.items.then(
      (items) async {
        if (!await _prefs.containsKey(widget.prefKey)) {
          await _prefs.setString(widget.prefKey, widget.defaultValue);
        }

        _selected = items.indexOf(await _prefs.getString(widget.prefKey) ?? "");

        return items;
      },
      onError: (err) {
        throw err;
      },
    );
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<String>>(
    future: _items,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Center(child: Text(widget.waitingMessage));
      } else {
        if (snapshot.hasError) {
          return Center(child: Text("❌ Error: ${snapshot.error}"));
        } else {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.labelText),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final isSelected = index == _selected;

                    return ListTile(
                      title: Text(
                        snapshot.data![index],
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                        ),
                      ),
                      tileColor: isSelected ? Colors.blue : null,
                      onTap: () async {
                        await _prefs.setString(
                          widget.prefKey,
                          snapshot.data![index],
                        );
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
    },
  );
}
