import 'package:fleather/fleather.dart';
import 'package:fleather_mention/src/utils.dart';
import 'package:flutter/widgets.dart';

import 'const.dart';

Widget? defaultMentionEmbedBuilder(BuildContext context, EmbedNode node,
    {Function(MentionData)? onTap}) {
  if (node.value.type == mentionEmbedKey && node.value.inline) {
    try {
      final data = MentionData.fromJson(node.value.data);
      return GestureDetector(
        onTap: () => onTap?.call(data),
        child: Text('${data.trigger}${data.value}'),
      );
    } catch (_) {}
  }
  return null;
}
