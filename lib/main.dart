import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:flutter/material.dart";
import "package:flutter_dotenv/flutter_dotenv.dart";
import "package:main/blog.dart";
import "package:main/constants.dart";
import "package:main/model.dart";
import "package:main/tumblr/api/client.dart";
import "package:main/ui/checkbox.dart";
import "package:main/ui/textoutput.dart";
import "package:ollama_dart/ollama_dart.dart";
import "package:shared_preferences/shared_preferences.dart";
import "package:url_launcher/url_launcher.dart";
import "package:window_manager/window_manager.dart";

Future main() async {
  await dotenv.load(fileName: "assets/.env");

  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  runApp(const App());

  await windowManager.waitUntilReadyToShow();
  await windowManager.setTitle("Tumblr AI");
  await windowManager.show();
  await windowManager.focus();
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) =>
      const MaterialApp(title: "Tumblr AI", home: MainPage());
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  var _selectedIndex = -1;
  Completer<String>? _authCode;
  List<String> _blogs = [];
  List<String> _models = [];
  late Client _tumblrClient;
  HttpServer? _server;
  var _running = true;
  var _runningMessage = "";
  final _logController = ExTextOutputController();

  @override
  void initState() {
    super.initState();
    unawaited(
      _startLocalServer().then((_) async {
        await _init();
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_server?.close(force: true));
    super.dispose();
  }

  Future<void> _startLocalServer() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 3000);

    _server!.listen((request) async {
      if (request.uri.queryParameters.containsKey("code")) {
        final String? code = request.uri.queryParameters["code"];

        _authCode?.complete(code);

        request.response
          ..statusCode = 200
          ..headers.set("Content-Type", ContentType.html.mimeType)
          ..write(
            '<html lang="en"><body><h3>Login successful. You can close this window.</h3></body></html>',
          );
        await request.response.close();
      } else {
        request.response
          ..statusCode = 404
          ..write("Not Found")
          // ignore: unawaited_futures
          ..close();
      }
    });
  }

  Future<void> _init() async {
    final client = OllamaClient();
    final ModelsResponse modelsResp = await client.listModels();
    _models = modelsResp.models!.map((item) => item.model!).toList();

    _tumblrClient = Client(
      onAuthWebCall: (authUri) async {
        _authCode = Completer<String>();
        if (await canLaunchUrl(authUri)) {
          await launchUrl(authUri, mode: LaunchMode.externalApplication);
        } else {
          throw Exception("Could not launch $authUri");
        }

        return _authCode!.future;
      },
    );

    Map<String, dynamic> user = await _tumblrClient.get("/user/info");
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
  Widget build(BuildContext context) => IgnorePointer(
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
                      groupAlignment: -1,
                      onDestinationSelected: (index) {
                        setState(() {
                          _selectedIndex = index;
                        });
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: <NavigationRailDestination>[
                        const NavigationRailDestination(
                          icon: Icon(Icons.book_outlined),
                          selectedIcon: Icon(Icons.book),
                          label: Text("Blog"),
                        ),
                        const NavigationRailDestination(
                          icon: Icon(Icons.engineering_outlined),
                          selectedIcon: Icon(Icons.engineering),
                          label: Text("Model"),
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
                          label: const Text("Compose"),
                        ),
                      ],
                    ),
                  ),
                  const VerticalDivider(thickness: 1, width: 1),
                ]
              : []),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _createPage(_selectedIndex),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 10,
          children: [
            Expanded(child: Text(_runningMessage, textAlign: TextAlign.center)),
            Opacity(
              opacity: _running ? 0.5 : 1.0,
              child: ElevatedButton(
                onPressed: () {
                  unawaited(
                    _generatePost()
                        .then((_) {
                          setState(() {
                            _runningMessage = "✅Done!";
                            _running = false;
                          });
                        })
                        .catchError((err) {
                          setState(() {
                            _runningMessage = "❌$err";
                            _running = false;
                          });
                        }),
                  );

                  setState(() {
                    _selectedIndex = 2;
                    _running = true;
                  });
                },
                child: const Text("🤖Do it!"),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _createPage(int? selectedIndex) {
    switch (selectedIndex) {
      case null:
        return const SizedBox(height: 10);

      case -1:
        return const Center(child: Text("📀Loading data from Tumblr..."));

      case 0:
        return BlogWidget(targetBlogs: _blogs);

      case 1:
        return ModelWidget(models: _models);

      case 2:
        return Column(
          spacing: 10,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 10),
            Opacity(
              opacity: _running ? 0.5 : 1.0,
              child: const ExCheckBox(
                prefKey: uiDryRun,
                labelText: "Dry run",
                defaultValue: false,
              ),
            ),
            ExTextOutput(controller: _logController, labelText: "Preview"),
            const SizedBox(height: 10),
          ],
        );

      default:
        return const SizedBox(height: 10);
    }
  }

  Future<void> _generatePost() async {
    final prefs = SharedPreferencesAsync();

    final String sourceBlog = (await prefs.getString(uiSourceBlog))!;
    final String apiKey = dotenv.env["CLIENT_ID"]!;
    final skipAsks = await prefs.getString(uiSkipAsks) == "true";
    final Iterable<String> skipTags = (await prefs.getString(
      uiSkipTags,
    ))!.split(",").map((item) => item.trim());
    final Map<String, dynamic> blogInfo = await _tumblrClient.get(
      "/blog/$sourceBlog/info",
      queryParameters: {"api_key": apiKey},
    );

    final postsCount = blogInfo["blog"]["posts"] as int;

    final List<int> pages = List.generate(
      postsCount ~/ 20,
      (index) => index * 20,
    );
    for (var i = 0; i < pages.length * 100; i++) {
      final int a = Random().nextInt(pages.length);
      final int b = Random().nextInt(pages.length);
      final int tmp = pages[a];
      pages[a] = pages[b];
      pages[b] = tmp;
    }

    final List<List<Map<String, dynamic>>> pagesContent = [];
    final posts = <String, String>{};
    final links = <String, String>{};

    var inPageIndex = 0;
    int maxPosts = (await prefs.getInt(uiMaxPosts))!;
    int minLength = (await prefs.getInt(uiMinLength))!;
    int maxLength = (await prefs.getInt(uiMaxLength))!;

    while (posts.length < maxPosts) {
      setState(() {
        _runningMessage = "📡Fetched ${posts.length} / $maxPosts posts ...";
      });

      List<Map<String, dynamic>> sourcePosts = [];

      if (pages.isNotEmpty) {
        final int page = pages.removeAt(0);
        pagesContent.add(
          (await _tumblrClient.get(
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
        throw Exception("Not enough posts found for source blog: $sourceBlog");
      }

      final Map<String, dynamic> json = sourcePosts.removeAt(
        Random().nextInt(sourcePosts.length),
      );

      if (json["content"] == null ||
          json["content"].isEmpty ||
          (skipAsks && json["asking_name"] != null) ||
          (skipTags.isNotEmpty &&
              (json["tags"] as List).any(skipTags.contains))) {
        continue;
      }

      final String text = (json["content"] as List<dynamic>)
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
      throw Exception("Not enough posts found in the blog: $sourceBlog");
    }

    var tries = 5;
    while (tries-- > 0) {
      final client = OllamaClient();

      setState(() {
        _runningMessage = "🧠Calling LLM (trying ${5 - tries}/5) ...";
      });

      _logController.clear();
      var postIndex = 1;
      final List<String> postsText = posts.values
          .map((post) => "POST ${postIndex++}:\n$post")
          .toList()
          .cast<String>();
      String mood = (await prefs.getString(uiMood))!;
      if (mood == autoMood) {
        mood = moods[Random().nextInt(moods.length)];
      }
      mood = mood.toLowerCase();
      final String model = (await prefs.getString(uiModel))!;
      final int start = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final int stTemp = (await prefs.getInt(uiModelTemperature))!;
      final double temp = (stTemp < 0 ? Random().nextInt(10) : stTemp) / 10;
      final int stTopP = (await prefs.getInt(uiModelTopP))!;
      final double topP = (stTopP < 0 ? Random().nextInt(10) : stTopP) / 10;
      final Stream<GenerateChatCompletionResponse> stream = client
          .generateChatCompletionStream(
            request: GenerateChatCompletionRequest(
              model: model,
              messages: [
                Message(
                  role: MessageRole.system,
                  content:
                      """
Sei uno scrittore creativo con un tono $mood. Ti verranno forniti dei post tratti da un blog.

- Scrivi un nuovo post originale, imitando lo stile di scrittura e il modo di ragionare dei post del blog.
- Assicurati che il contenuto tratti temi coerenti e pertinenti rispetto a quelli presenti nei post del blog.
- Mantieni la struttura tipica dei post originali, evitando di copiarne frasi o passaggi.
- Racchiudi il tuo post tra i tag <output> e </output>
""",
                ),
                Message(
                  role: MessageRole.user,
                  content: 'Questi sono i post:\n\n${postsText.join('\n\n')}',
                ),
              ],
              options: RequestOptions(temperature: temp, topP: topP),
            ),
          );
      var llmOutput = StringBuffer();
      await for (final res in stream) {
        final String str = res.message.content;
        _logController.append(str);
        llmOutput.write(str);
      }

      final regex = RegExp("<output>(.*?)</output>", dotAll: true);
      final RegExpMatch? match = regex.firstMatch(llmOutput.toString());

      if (match == null) {
        continue;
      }

      setState(() {
        _runningMessage = "📝Preparing post ...";
      });

      final List<Map<String, Object>> tumblrPost = match
          .group(1)!
          .trim()
          .split("\n")
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .map<Map<String, Object>>((line) => {"type": "text", "text": line})
          .toList();

      var llmPostIndex = 0;
      for (final String key in posts.keys) {
        final linkText = "[${++llmPostIndex}] $key";
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
      }

      int elapsed = DateTime.now().millisecondsSinceEpoch ~/ 1000 - start;
      final Map<String, Object> postObj = {
        "content": tumblrPost,
        "tags": [
          "umore: $mood",
          "modello: $model",
          "durata: ${elapsed}s",
          "temperatura: ${temp.toStringAsFixed(1)}",
          "top_p: ${topP.toStringAsFixed(1)}",
        ].join(","),
      };

      _logController.append(
        "\n\n${const JsonEncoder.withIndent(' ').convert(postObj)}",
      );

      if ((await prefs.getString(uiDryRun))! == "false") {
        setState(() {
          _runningMessage = "📨Posting to Tumblr ...";
        });

        await _tumblrClient.post(
          "/blog/${(await prefs.getString(uiTargetBlog))!}/posts",
          body: postObj,
        );
      }

      client.endSession();
      break;
    }
  }
}
