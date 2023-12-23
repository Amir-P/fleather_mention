import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

import 'const.dart';

EmbeddableObject buildEmbeddableObject(MentionData data) =>
    EmbeddableObject(mentionEmbedKey, inline: true, data: data.toJson());

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

class MentionCallbackAction<T extends Intent> extends CallbackAction<T> {
  MentionCallbackAction({required super.onInvoke, this.enabled = true});

  bool enabled;

  @override
  bool isEnabled(covariant T intent) => enabled;

  @override
  bool consumesKey(covariant T intent) => enabled;
}
