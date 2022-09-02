import 'package:fleather/fleather.dart';
import 'package:flutter/widgets.dart';

import 'options.dart';
import 'overlay.dart';
import 'utils.dart';

class FleatherMention extends StatefulWidget {
  final Widget child;
  final MentionOptions options;
  final FleatherController controller;
  final FocusNode focusNode;
  final GlobalKey<EditorState> editorKey;

  const FleatherMention._({
    Key? key,
    required this.controller,
    required this.options,
    required this.child,
    required this.focusNode,
    required this.editorKey,
  }) : super(key: key);

  /// Constructs a FleatherMention with a FleatherEditor as it's child.
  /// The given FleatherEditor should have a FocusNode and editor key.
  factory FleatherMention.withEditor(
      {required MentionOptions options, required FleatherEditor child}) {
    assert(child.focusNode != null);
    assert(child.editorKey != null);
    return FleatherMention._(
      controller: child.controller,
      focusNode: child.focusNode!,
      editorKey: child.editorKey!,
      options: options,
      child: child,
    );
  }

  /// Constructs a FleatherMention with a FleatherField as it's child.
  /// The given FleatherField should have a FocusNode and editor key.
  factory FleatherMention.withField(
      {required MentionOptions options, required FleatherField child}) {
    assert(child.focusNode != null);
    assert(child.editorKey != null);
    return FleatherMention._(
      controller: child.controller,
      focusNode: child.focusNode!,
      editorKey: child.editorKey!,
      options: options,
      child: child,
    );
  }

  @override
  State<FleatherMention> createState() => _FleatherMentionState();
}

class _FleatherMentionState extends State<FleatherMention> {
  MentionOverlay? _mentionOverlay;
  bool _hasFocus = false;
  String? _lastQuery, _lastTrigger;

  FleatherController get _controller => widget.controller;

  FocusNode get _focusNode => widget.focusNode;

  MentionOptions get _options => widget.options;

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

  void _onDocumentUpdated() {
    _checkForMentionTriggers();
    _updateOrDisposeOverlayIfNeeded();
  }

  void _checkForMentionTriggers() {
    _lastTrigger = null;
    _lastQuery = null;

    if (!_controller.selection.isCollapsed) return;

    final plainText = _controller.document.toPlainText();
    final indexOfLastMentionTrigger = plainText
        .substring(0, _controller.selection.end)
        .lastIndexOf(RegExp(_options.mentionTriggers.join('|')));

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
  }

  void _onFocusChanged() {
    _hasFocus = _focusNode.hasFocus;
    _updateOrDisposeOverlayIfNeeded();
  }

  void _updateOverlayForScroll() => _mentionOverlay?.updateForScroll();

  void _updateOrDisposeOverlayIfNeeded() {
    if (!_hasFocus || _lastQuery == null || _lastTrigger == null) {
      _mentionOverlay?.dispose();
      _mentionOverlay = null;
    } else {
      _mentionOverlay?.dispose();
      _mentionOverlay = MentionOverlay(
        query: _lastQuery!,
        trigger: _lastTrigger!,
        context: context,
        debugRequiredFor: widget.editorKey.currentWidget!,
        itemBuilder: _options.itemBuilder,
        suggestionSelected: _handleMentionSuggestionSelected,
        suggestions:
            _options.suggestionsBuilder.call(_lastTrigger!, _lastQuery!),
        textEditingValue: widget.editorKey.currentState!.textEditingValue,
        renderObject: widget.editorKey.currentState!.renderEditor,
      );
      _mentionOverlay!.show();
    }
  }

  void _handleMentionSuggestionSelected(MentionData data) {
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
          _updateOverlayForScroll();
          return false;
        },
        child: widget.child,
      );
}
