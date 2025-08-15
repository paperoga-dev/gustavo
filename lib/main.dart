import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:main/blog.dart';
import 'package:main/tumblr/api/client.dart';
import 'package:main/ui/checkbox.dart';
import 'package:main/ui/textoutput.dart';
import 'package:ollama_dart/ollama_dart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'constants.dart';
import 'model.dart';

Future main() async {
  await dotenv.load(fileName: "assets/.env");

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  runApp(const App());

  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitle("Tumblr AI");
    await windowManager.show();
    await windowManager.focus();
  });
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(title: 'Tumblr AI', home: const MainPage());
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = -1;
  Completer<String>? _authCode;
  List<String> _blogs = [];
  List<String> _models = [];
  Client? _tumblrClient;
  HttpServer? _server;
  bool _running = true;
  String _runningMessage = "";
  final ExTextOutputController _logController = ExTextOutputController();

  @override
  void initState() {
    super.initState();
    _startLocalServer().then((_) => {_init()});
  }

  @override
  void dispose() {
    _server?.close(force: true);
    super.dispose();
  }

  Future<void> _startLocalServer() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);

    _server!.listen((HttpRequest request) async {
      if (request.uri.queryParameters.containsKey('code')) {
        final code = request.uri.queryParameters['code'];

        _authCode?.complete(code);

        request.response
          ..statusCode = 200
          ..headers.set('Content-Type', ContentType.html.mimeType)
          ..write(
            '<html lang="en"><body><h3>Login successful. You can close this window.</h3></body></html>',
          );
        await request.response.close();
      } else {
        request.response
          ..statusCode = 404
          ..write('Not Found')
          ..close();
      }
    });
  }

  Future<void> _init() async {
    final client = OllamaClient();
    final modelsResp = await client.listModels();
    _models = modelsResp.models!.map((item) => item.model!).toList();

    _tumblrClient = Client(
      onAuthWebCall: (Uri authUri) async {
        _authCode = Completer<String>();
        if (await canLaunchUrl(authUri)) {
          await launchUrl(authUri, mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch $authUri';
        }

        return await _authCode!.future;
      },
    );

    Map<String, dynamic> user = await _tumblrClient!.get("/user/info");
    setState(() {
      _running = false;
      _blogs = user["user"]["blogs"]
          .map((item) => item["name"])
          .toList()
          .cast<String>();
      _selectedIndex = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: _running,
      child: Scaffold(
        body: Row(
          children: [
            ...(_selectedIndex != -1
                ? [
                    Opacity(
                      opacity: _running ? 0.5 : 1.0,
                      child: NavigationRail(
                        selectedIndex: _selectedIndex,
                        groupAlignment: -1.0,
                        onDestinationSelected: (int index) {
                          setState(() {
                            _selectedIndex = index;
                          });
                        },
                        labelType: NavigationRailLabelType.all,
                        leading: null,
                        trailing: null,
                        destinations: <NavigationRailDestination>[
                          const NavigationRailDestination(
                            icon: Icon(Icons.book_outlined),
                            selectedIcon: Icon(Icons.book),
                            label: Text('Blog'),
                          ),
                          const NavigationRailDestination(
                            icon: Icon(Icons.engineering_outlined),
                            selectedIcon: Icon(Icons.engineering),
                            label: Text('Model'),
                          ),
                          NavigationRailDestination(
                            icon: const Icon(Icons.edit_outlined),
                            selectedIcon: _running
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(),
                                  )
                                : const Icon(Icons.edit),
                            label: const Text('Compose'),
                          ),
                        ],
                      ),
                    ),
                    const VerticalDivider(thickness: 1, width: 1),
                  ]
                : []),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _createPage(_selectedIndex),
              ),
            ),
          ],
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(6.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            spacing: 10,
            children: [
              Expanded(
                child: Text(_runningMessage, textAlign: TextAlign.center),
              ),
              Opacity(
                opacity: _running ? 0.5 : 1.0,
                child: ElevatedButton(
                  onPressed: () {
                    _generatePost()
                        .then((_) {
                          setState(() {
                            _runningMessage = "✅Done!";
                            _running = false;
                          });
                        })
                        .catchError((err) {
                          setState(() {
                            _runningMessage = '❌${err.toString()}';
                            _running = false;
                          });
                        });

                    setState(() {
                      _selectedIndex = 2;
                      _running = true;
                    });
                  },
                  child: Text("🤖Do it!"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _createPage(int? selectedIndex) {
    switch (selectedIndex) {
      case null:
        return SizedBox(height: 10);

      case -1:
        return Center(child: Text("📀Loading data from Tumblr..."));

      case 0:
        return BlogWidget(targetBlogs: _blogs);

      case 1:
        return ModelWidget(models: _models);

      case 2:
        return Column(
          spacing: 10,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(height: 10),
            Opacity(
              opacity: _running ? 0.5 : 1.0,
              child: ExCheckBox(
                prefKey: uiDryRun,
                labelText: "Dry run",
                defaultValue: false,
              ),
            ),
            ExTextOutput(controller: _logController, labelText: "Preview"),
            SizedBox(height: 10),
          ],
        );

      default:
        return SizedBox(height: 10);
    }
  }

  Future<void> _generatePost() async {
    final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

    final sourceBlog = await _prefs.getString(uiSourceBlog);
    final apiKey = dotenv.env['CLIENT_ID']!;
    final skipAsks = await _prefs.getString(uiSkipAsks) == "true";
    final skipTags = (await _prefs.getString(
      uiSkipTags,
    ))!.split(",").map((item) => item.trim());
    final blogInfo = await _tumblrClient!.get(
      "/blog/$sourceBlog/info",
      queryParameters: {"api_key": apiKey},
    );

    final postsCount = blogInfo["blog"]["posts"] as int;

    final pages = List.generate(postsCount ~/ 20, (index) => index * 20);
    for (int i = 0; i < pages.length * 100; i++) {
      final a = Random().nextInt(pages.length);
      final b = Random().nextInt(pages.length);
      final tmp = pages[a];
      pages[a] = pages[b];
      pages[b] = tmp;
    }

    final List<List<Map<String, dynamic>>> pagesContent = [];
    final posts = <String, String>{};
    final links = <String, String>{};

    int inPageIndex = 0;
    int maxPosts = (await _prefs.getInt(uiMaxPosts))!;
    int minLength = (await _prefs.getInt(uiMinLength))!;
    int maxLength = (await _prefs.getInt(uiMaxLength))!;

    while (posts.length < maxPosts) {
      setState(() {
        _runningMessage = "📡Fetched ${posts.length} / $maxPosts posts ...";
      });

      List<Map<String, dynamic>> sourcePosts = [];

      if (pages.isNotEmpty) {
        final page = pages.removeAt(0);
        pagesContent.add(
          (await _tumblrClient!.get(
            "/blog/$sourceBlog/posts",
            queryParameters: {
              "api_key": apiKey,
              "offset": page.toString(),
              "limit": "20",
              "npf": "true",
            },
          ))["posts"].cast<Map<String, dynamic>>(),
        );
        sourcePosts = pagesContent.last;
      } else if (pagesContent.isNotEmpty) {
        int page = inPageIndex++ % pagesContent.length;
        sourcePosts = pagesContent[page];
        if (sourcePosts.isEmpty) {
          pagesContent.removeAt(page);
        }
      } else {
        throw 'Not enough posts found for source blog: $sourceBlog';
      }

      final json = sourcePosts.removeAt(Random().nextInt(sourcePosts.length));

      if (json["content"] == null ||
          json["content"].isEmpty ||
          (skipAsks && json["asking_name"] != null) ||
          (skipTags.isNotEmpty &&
              (json["tags"] as List).any((tag) => skipTags.contains(tag)))) {
        continue;
      }

      final text = (json["content"] as List<dynamic>)
          .where((item) => item["type"] == "text")
          .map((item) => item["text"])
          .where((item) => item.isNotEmpty)
          .join("\n\n");

      if (text.length > minLength && text.length < maxLength) {
        posts[json["id_string"]] = text;
        links[json["id_string"]] = json["post_url"];
      }
    }

    if (posts.length < 5) {
      throw 'Not enough posts found in the blog: $sourceBlog';
    }

    int tries = 5;
    while (tries-- > 0) {
      final client = OllamaClient();

      setState(() {
        _runningMessage = "🧠Calling LLM (trying ${5 - tries}/5) ...";
      });

      _logController.clear();
      int postIndex = 1;
      final postsText = posts.values
          .map((post) => 'POST ${postIndex++}:\n$post')
          .toList()
          .cast<String>();
      String mood = (await _prefs.getString(uiMood))!;
      if (mood == autoMood) {
        mood = moods[Random().nextInt(moods.length)];
      }
      mood = mood.toLowerCase();
      final model = (await _prefs.getString(uiModel))!;
      final start = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final stTemp = (await _prefs.getInt(uiModelTemperature))!;
      final temp = (stTemp < 0 ? Random().nextInt(10) : stTemp) / 10;
      final stTopP = (await _prefs.getInt(uiModelTopP))!;
      final topP = (stTopP < 0 ? Random().nextInt(10) : stTopP) / 10;
      final stream = client.generateChatCompletionStream(
        request: GenerateChatCompletionRequest(
          model: model,
          messages: [
            Message(
              role: MessageRole.system,
              content:
                  '''
Sei uno scrittore creativo con un tono $mood. Ti verranno forniti dei post tratti da un blog.

- Scrivi un nuovo post originale, imitando lo stile di scrittura e il modo di ragionare dei post del blog.
- Assicurati che il contenuto tratti temi coerenti e pertinenti rispetto a quelli presenti nei post del blog.
- Mantieni la struttura tipica dei post originali, evitando di copiarne frasi o passaggi.
- Racchiudi il tuo post tra i tag <output> e </output>
''',
            ),
            Message(
              role: MessageRole.user,
              content: 'Questi sono i post:\n\n${postsText.join('\n\n')}',
            ),
          ],
          options: RequestOptions(temperature: temp, topP: topP),
        ),
      );
      String llmOutput = "";
      await for (final res in stream) {
        final str = res.message.content;
        _logController.append(str);
        llmOutput += str;
      }

      final regex = RegExp(r'<output>(.*?)</output>', dotAll: true);
      final match = regex.firstMatch(llmOutput);

      if (match == null) {
        continue;
      }

      setState(() {
        _runningMessage = "📝Preparing post ...";
      });

      final tumblrPost = match
          .group(1)!
          .trim()
          .split("\n")
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map<Map<String, Object>>((line) => ({"type": "text", "text": line}))
          .toList();

      int llmPostIndex = 0;
      posts.keys.forEach((key) {
        final String linkText = '[${++llmPostIndex}] $key';
        tumblrPost.add({
          "type": "text",
          "text": linkText,
          "formatting": [
            {
              "start": linkText.indexOf("]") + 2,
              "end": linkText.length,
              "type": "link",
              "url": links[key] ?? "",
            },
          ],
        });
      });

      final postObj = {
        "content": tumblrPost,
        "tags": [
          'umore: $mood',
          'modello: $model',
          'durata: ${(DateTime.now().millisecondsSinceEpoch ~/ 1000 - start).toStringAsFixed(2)}s',
          'temperatura: ${temp.toStringAsFixed(1)}',
          'top_p: ${topP.toStringAsFixed(1)}',
        ].join(","),
      };

      _logController.append(
        '\n\n${JsonEncoder.withIndent(' ').convert(postObj)}',
      );

      if ((await _prefs.getString(uiDryRun))! == "false") {
        setState(() {
          _runningMessage = "📨Posting to Tumblr ...";
        });

        await _tumblrClient!.post(
          '/blog/${(await _prefs.getString(uiTargetBlog))!}/posts',
          body: postObj,
        );
      }

      client.endSession();
      break;
    }
  }
}
