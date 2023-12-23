# Fleather Mention

*It's under development and not production ready yet.*

Fleather Mention is a plugin to provide @mentions or #hashtag functionality for the Fleather rich text editor.

## Features

* Easy to use
* Customizable trigger characters
* Async suggestion list builder
* Navigation between options with keyboard

## Getting started

Add it to your dependencies.

```yaml
dependencies:
  flutter:
    sdk: flutter
  fleather: ^1.12.0
  fleather_mention: ^0.0.3
```

## Usage

Wrap `FleatherEditor` with `FleatherMention.withEditor` and `FleatherField` with `FleatherMention.withField`:

```dart
FleatherMention.withEditor(
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
      final mentionWidget = defaultMentionEmbedBuilder(context, node);
      if (mentionWidget != null) {
        return mentionWidget;
      }
      return defaultFleatherEmbedBuilder(context, node);
    },
  ),
);
```