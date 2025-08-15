import 'package:flutter/material.dart';
import 'package:main/ui/listview.dart';
import 'package:main/ui/textfield.dart';

import 'constants.dart';

class ModelWidget extends StatefulWidget {
  final List<String> models;

  const ModelWidget({super.key, required this.models});

  @override
  State<ModelWidget> createState() => _ModelWidgetState();
}

class _ModelWidgetState extends State<ModelWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(height: 30),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 10,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: 10,
                  children: [
                    Expanded(
                      child: ExListView(
                        prefKey: uiModel,
                        labelText: "Model:",
                        items: widget.models,
                        defaultValue: "",
                      ),
                    ),
                    ExTextField(
                      labelText: "Temperature:",
                      prefKey: uiModelTemperature,
                      keyboardType: TextInputType.number,
                      defaultValue: -1,
                    ),
                    ExTextField(
                      labelText: "Top_P:",
                      prefKey: uiModelTopP,
                      keyboardType: TextInputType.number,
                      defaultValue: -1,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ExListView(
                  items: [autoMood, ...moods],
                  labelText: "Mood:",
                  prefKey: uiMood,
                  defaultValue: autoMood,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 30),
      ],
    );
  }
}
