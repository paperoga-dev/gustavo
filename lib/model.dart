import "package:flutter/material.dart";
import "package:main/constants.dart";
import "package:main/ui/listview.dart";
import "package:main/ui/slider.dart";

class ModelWidget extends StatefulWidget {
  final List<String> models;

  const ModelWidget({super.key, required this.models});

  @override
  State<ModelWidget> createState() => _ModelWidgetState();
}

class _ModelWidgetState extends State<ModelWidget> {
  @override
  Widget build(BuildContext context) => Column(
    children: [
      const SizedBox(height: 30),
      Expanded(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const ExSlider(
                    labelText: "Temperature:",
                    prefKey: uiModelTemperature,
                  ),
                  const ExSlider(labelText: "Top_P:", prefKey: uiModelTopP),
                ],
              ),
            ),
            const Expanded(
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
      const SizedBox(height: 30),
    ],
  );
}
