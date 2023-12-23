import 'package:fleather/fleather.dart';
import 'package:fleather_mention/fleather_mention.dart';
import 'package:flutter/material.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Flutter Demo',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: const MyHomePage(),
      );
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final controller = FleatherController();
  final focusNode = FocusNode();
  final editorKey = GlobalKey<EditorState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Fleather mention demo')),
      body: Column(
        children: <Widget>[
          FleatherToolbar.basic(controller: controller),
          Divider(height: 1),
          Expanded(
            child: FleatherMention.withEditor(
              triggers: ['#', '@'],
              optionsBuilder: (trigger, query) {
                final List<String> data;
                if (trigger == '#') {
                  data = ['Android', 'iOS', 'Windows', 'macOs', 'Web', 'Linux'];
                } else {
                  data = [
                    'John',
                    'Michael',
                    'Dave',
                    'Susan',
                    'Emilia',
                    'Cathy'
                  ];
                }
                return data
                    .where((e) => e.toLowerCase().contains(query.toLowerCase()))
                    .map((e) => MentionData(value: e, trigger: trigger))
                    .toList();
              },
              child: FleatherEditor(
                controller: controller,
                focusNode: focusNode,
                editorKey: editorKey,
                embedBuilder: (context, node) {
                  final mentionWidget = defaultMentionEmbedBuilder(
                    context,
                    node,
                    onTap: (data) => ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(data.value))),
                  );
                  if (mentionWidget != null) {
                    return mentionWidget;
                  }
                  return defaultFleatherEmbedBuilder(context, node);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
