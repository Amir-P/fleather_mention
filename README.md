# Fleather Mention

*It's under development and not production ready yet.*

Fleather Mention is a plugin to provide @mentions or #hashtag functionality for the Fleather rich text editor.

## Features

* Easy to use
* Customizable trigger characters
* Async suggestion list builder

## Getting started

Add it to your dependencies.

```yaml
dependencies:
  flutter:
    sdk: flutter
  fleather: ^1.2.2
  fleather_mention: ^0.0.2
```

## Usage

1. Create mention options

```dart
final options = MentionOptions(
  mentionTriggers: ['@'],
  suggestionsBuilder: (trigger, query) {
    final data = ['Android', 'iOS', 'Windows', 'macOs', 'Web', 'Linux'];
    return data
        .where((e) => e.toLowerCase().contains(query.toLowerCase()))
        .map((e) => MentionData(value: e, trigger: trigger))
        .toList();
  },
  itemBuilder: (_, data, __) => Text(data.value),
);
```

2. Wrap your `FleatherEditor` with `FleatherMention.withEditor`:

```dart
@override
Widget build(BuildContext context) {
  return FleatherMention.withEditor(
    options: options,
    child: FleatherEditor(
      controller: controller,
      focusNode: focusNode,
      editorKey: editorKey,
      embedBuilder: (context, node) {
        final mentionWidget = mentionEmbedBuilder(context, node);
        if (mentionWidget != null) {
          return mentionWidget;
        }
        throw UnimplementedError();
      },
    ),
  );
}
```
or your `FleatherField` with `FleatherMention.withField`:
```dart
@override
Widget build(BuildContext context) {
  return FleatherMention.withField(
    options: options,
    child: FleatherField(
      controller: controller,
      focusNode: focusNode,
      editorKey: editorKey,
      embedBuilder: (context, node) {
        final mentionWidget = mentionEmbedBuilder(context, node);
        if (mentionWidget != null) {
          return mentionWidget;
        }
        throw UnimplementedError();
      },
    ),
  );
}
```

## Known issues

* ~~Jumping to new line after selecting mention from suggestions list~~
* Not customizable popup
* Bad design of mention inline embed
