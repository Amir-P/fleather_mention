import 'dart:async';

import 'package:flutter/widgets.dart';

typedef MentionSuggestionsBuilder = FutureOr<Iterable<MentionData>> Function(
    String trigger, String query);

typedef MentionSuggestionItemBuilder = Widget Function(
    BuildContext context, MentionData data, String query);

class MentionOptions {
  final Iterable<String> mentionTriggers;
  final MentionSuggestionsBuilder suggestionsBuilder;
  final MentionSuggestionItemBuilder itemBuilder;

  MentionOptions({
    required this.mentionTriggers,
    required this.suggestionsBuilder,
    required this.itemBuilder,
  }) : assert(mentionTriggers.isNotEmpty);
}

class MentionData {
  final String value, trigger;
  final Map<String, dynamic> payload;

  const MentionData(
      {required this.value, required this.trigger, this.payload = const {}});

  factory MentionData.fromJson(Map<String, dynamic> map) =>
      MentionData(value: map['value'], trigger: map['trigger'], payload: map);

  Map<String, dynamic> toJson() =>
      {...payload, 'value': value, 'trigger': trigger};
}
