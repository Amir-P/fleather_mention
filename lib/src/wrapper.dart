import 'dart:async';

import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';

import 'utils.dart';

typedef MentionOptionsBuilder = FutureOr<Iterable<MentionData>> Function(
    String trigger, String query);

typedef MentionOnSelected = void Function(MentionData option);

typedef MentionOptionsViewBuilder = Widget Function(BuildContext context,
    MentionOnSelected onSelected, Iterable<MentionData> options);

class FleatherMention extends StatefulWidget {
  final Widget child;
  final FleatherController controller;
  final FocusNode focusNode;
  final GlobalKey<EditorState> editorKey;

  const FleatherMention._({
    Key? key,
    required this.child,
    required this.controller,
    required this.focusNode,
    required this.editorKey,
    required this.triggers,
    required this.optionsBuilder,
    this.optionsViewBuilder,
  }) : super(key: key);

  final Iterable<String> triggers;
  final MentionOptionsBuilder optionsBuilder;
  final MentionOptionsViewBuilder? optionsViewBuilder;

  /// Constructs a FleatherMention with a FleatherEditor as it's child.
  /// The given FleatherEditor should have a FocusNode and editor key.
  factory FleatherMention.withEditor({
    required FleatherEditor child,
    required Iterable<String> triggers,
    required MentionOptionsBuilder optionsBuilder,
    MentionOptionsViewBuilder? optionsViewBuilder,
  }) {
    assert(child.focusNode != null);
    assert(child.editorKey != null);
    return FleatherMention._(
      controller: child.controller,
      focusNode: child.focusNode!,
      editorKey: child.editorKey!,
      triggers: triggers,
      optionsBuilder: optionsBuilder,
      optionsViewBuilder: optionsViewBuilder,
      child: child,
    );
  }

  /// Constructs a FleatherMention with a FleatherField as it's child.
  /// The given FleatherField should have a FocusNode and editor key.
  factory FleatherMention.withField({
    required FleatherField child,
    required Iterable<String> triggers,
    required MentionOptionsBuilder optionsBuilder,
    MentionOptionsViewBuilder? optionsViewBuilder,
  }) {
    assert(child.focusNode != null);
    assert(child.editorKey != null);
    return FleatherMention._(
      controller: child.controller,
      focusNode: child.focusNode!,
      editorKey: child.editorKey!,
      triggers: triggers,
      optionsBuilder: optionsBuilder,
      optionsViewBuilder: optionsViewBuilder,
      child: child,
    );
  }

  @override
  State<FleatherMention> createState() => _FleatherMentionState();
}

class _FleatherMentionState extends State<FleatherMention> {
  OverlayEntry? _mentionOverlay;
  bool _hasFocus = false;
  String? _lastQuery, _lastTrigger;

  FleatherController get _controller => widget.controller;

  FocusNode get _focusNode => widget.focusNode;

  Iterable<MentionData> _options = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onDocumentUpdated);
    _focusNode.addListener(_onFocusChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onDocumentUpdated);
    _focusNode.removeListener(_onFocusChanged);
    _mentionOverlay?.remove();
    _mentionOverlay?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant FleatherMention oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != _controller) {
      oldWidget.controller.removeListener(_onDocumentUpdated);
      _controller.addListener(_onDocumentUpdated);
    }
    if (oldWidget.focusNode != _focusNode) {
      oldWidget.focusNode.removeListener(_onFocusChanged);
      _focusNode.addListener(_onFocusChanged);
    }
  }

  void _onDocumentUpdated() async {
    await _checkForMentionTriggers();
    _updateOrDisposeOverlayIfNeeded();
  }

  Future<void> _checkForMentionTriggers() async {
    _lastTrigger = null;
    _lastQuery = null;
    _options = [];

    if (!_controller.selection.isCollapsed) return;

    final plainText = _controller.document.toPlainText();
    final indexOfLastMentionTrigger = plainText
        .substring(0, _controller.selection.end)
        .lastIndexOf(RegExp(widget.triggers.join('|')));

    if (indexOfLastMentionTrigger < 0) return;

    if (plainText
        .substring(indexOfLastMentionTrigger, _controller.selection.end)
        .contains(RegExp(r'\n'))) {
      return;
    }

    _lastQuery = plainText.substring(
        indexOfLastMentionTrigger + 1, _controller.selection.end);
    _lastTrigger = plainText.substring(
        indexOfLastMentionTrigger, indexOfLastMentionTrigger + 1);
    if (_lastTrigger != null && _lastQuery != null) {
      _options = await widget.optionsBuilder(_lastTrigger!, _lastQuery!);
    }
  }

  void _onFocusChanged() {
    _hasFocus = _focusNode.hasFocus;
    _updateOrDisposeOverlayIfNeeded();
  }

  void _updateOrDisposeOverlayIfNeeded() {
    if (!_hasFocus || _options.isEmpty) {
      _mentionOverlay?.remove();
      _mentionOverlay?.dispose();
      _mentionOverlay = null;
    } else if (_mentionOverlay == null) {
      _mentionOverlay = OverlayEntry(
          builder: (context) => (widget.optionsViewBuilder ??
              _defaultOptionsViewBuilder)(context, _onSelected, _options));
      Overlay.of(context,
              rootOverlay: true,
              debugRequiredFor: widget.editorKey.currentWidget)
          .insert(_mentionOverlay!);
    } else {
      _mentionOverlay?.markNeedsBuild();
    }
  }

  void _onSelected(MentionData data) {
    final controller = widget.controller;
    final mentionStartIndex = controller.selection.end - _lastQuery!.length - 1;
    final mentionedTextLength = _lastQuery!.length + 1;
    controller.replaceText(
      mentionStartIndex,
      mentionedTextLength,
      buildEmbeddableObject(data),
      selection: TextSelection.collapsed(offset: mentionStartIndex + 1),
    );
  }

  @override
  Widget build(BuildContext context) =>
      NotificationListener<ScrollNotification>(
        onNotification: (_) {
          _mentionOverlay?.markNeedsBuild();
          return false;
        },
        child: widget.child,
      );

  Widget _defaultOptionsViewBuilder(_, onSelected, options) {
    final editorState = widget.editorKey.currentState!;
    return _MentionSuggestionList(
      renderObject: editorState.renderEditor,
      textEditingValue: editorState.textEditingValue,
      suggestions: options,
      onSelected: onSelected,
    );
  }
}

const double _overlayMaxHeight = 200;

class _MentionSuggestionList extends StatelessWidget {
  final RenderEditor renderObject;
  final Iterable<MentionData> suggestions;
  final TextEditingValue textEditingValue;
  final MentionOnSelected onSelected;

  const _MentionSuggestionList({
    Key? key,
    required this.renderObject,
    required this.suggestions,
    required this.textEditingValue,
    required this.onSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final endpoints =
        renderObject.getEndpointsForSelection(textEditingValue.selection);
    final editingRegion = Rect.fromPoints(
      renderObject.localToGlobal(Offset.zero),
      renderObject.localToGlobal(renderObject.size.bottomRight(Offset.zero)),
    );
    final baseLineHeight =
        renderObject.preferredLineHeight(textEditingValue.selection.base);
    final mediaQueryData = MediaQuery.of(context);
    final screenHeight = mediaQueryData.size.height;

    double? positionFromTop = endpoints[0].point.dy + editingRegion.top;
    double? positionFromBottom;

    if (positionFromTop + _overlayMaxHeight >
        screenHeight - mediaQueryData.viewInsets.bottom) {
      positionFromTop = null;
      positionFromBottom = screenHeight - editingRegion.bottom + baseLineHeight;
    }

    return Positioned(
      top: positionFromTop,
      bottom: positionFromBottom,
      right: 16,
      left: 16,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: _overlayMaxHeight),
        child: _buildOverlayWidget(context),
      ),
    );
  }

  Widget _buildOverlayWidget(BuildContext context) => Card(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: suggestions
                .map((e) => InkWell(
                      onTap: () => onSelected(e),
                      child: ListTile(title: Text(e.value)),
                    ))
                .toList(),
          ),
        ),
      );
}
