import 'package:flutter/material.dart';
import 'package:main/ui/checkbox.dart';
import 'package:main/ui/listview.dart';
import 'package:main/ui/textfield.dart';

import 'constants.dart';

class BlogWidget extends StatefulWidget {
  final List<String> targetBlogs;

  const BlogWidget({super.key, required this.targetBlogs});

  @override
  State<BlogWidget> createState() => _BlogWidgetState();
}

class _BlogWidgetState extends State<BlogWidget> {
  @override
  Widget build(BuildContext context) {
    return Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 30),
          Expanded(
          child:
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 10,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  spacing: 10,
                  children: [
                    ExTextField(
                      prefKey: uiSourceBlog,
                      labelText: 'Source blog:',
                      defaultValue: "",
                    ),
                    ExCheckBox(prefKey: uiSkipAsks, labelText: "Skip asks", defaultValue: false),
                    ExTextField(
                      prefKey: uiSkipTags,
                      labelText: 'Skip tags:',
                      defaultValue: "",
                    ),
                    ExTextField(
                      prefKey: uiMaxPosts,
                      keyboardType: TextInputType.number,
                      labelText: 'Max posts:',
                      defaultValue: 5,
                    ),
                    ExTextField(
                      prefKey: uiMinLength,
                      keyboardType: TextInputType.number,
                      labelText: 'Min length:',
                      defaultValue: 300,
                    ),
                    ExTextField(
                      prefKey: uiMaxLength,
                      keyboardType: TextInputType.number,
                      labelText: 'Max length:',
                      defaultValue: 5000,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ExListView(
                  items: widget.targetBlogs,
                  prefKey: uiTargetBlog,
                  labelText: 'Target blog:',
                  defaultValue: "",
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
