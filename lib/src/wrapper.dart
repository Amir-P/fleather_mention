import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

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

  const FleatherMention({
    super.key,
    required this.child,
    required this.controller,
    required this.focusNode,
    required this.editorKey,
    required this.triggers,
    required this.optionsBuilder,
    this.optionsViewBuilder,
  });

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
    return FleatherMention(
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
    return FleatherMention(
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
  final _highlightedOptionIndex = ValueNotifier<int>(0);
  late final Map<Type, Action<Intent>> _actionMap;
  late final MentionCallbackAction<AutocompletePreviousOptionIntent>
      _previousOptionAction;
  late final MentionCallbackAction<AutocompleteNextOptionIntent>
      _nextOptionAction;
  late final MentionCallbackAction<DismissIntent> _hideOptionsAction;
  late final MentionCallbackAction<ButtonActivateIntent> _submitAction;

  static const Map<ShortcutActivator, Intent> _shortcuts =
      <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp):
        AutocompletePreviousOptionIntent(),
    SingleActivator(LogicalKeyboardKey.arrowDown):
        AutocompleteNextOptionIntent(),
    SingleActivator(LogicalKeyboardKey.enter): ButtonActivateIntent(),
  };

  OverlayEntry? _mentionOverlay;

  String? _lastQuery, _lastTrigger;

  FleatherController get _controller => widget.controller;

  FocusNode get _focusNode => widget.focusNode;

  Iterable<MentionData> _options = [];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onDocumentUpdated);
    _focusNode.addListener(_onFocusChanged);
    _previousOptionAction =
        MentionCallbackAction<AutocompletePreviousOptionIntent>(
            onInvoke: _highlightPreviousOption);
    _nextOptionAction = MentionCallbackAction<AutocompleteNextOptionIntent>(
        onInvoke: _highlightNextOption);
    _hideOptionsAction =
        MentionCallbackAction<DismissIntent>(onInvoke: _hideOptions);
    _submitAction =
        MentionCallbackAction<ButtonActivateIntent>(onInvoke: _submit);
    _actionMap = <Type, Action<Intent>>{
      AutocompletePreviousOptionIntent: _previousOptionAction,
      AutocompleteNextOptionIntent: _nextOptionAction,
      DismissIntent: _hideOptionsAction,
      ButtonActivateIntent: _submitAction,
    };
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

  void _submit(_) {
    _onSelected(_options.elementAt(_highlightedOptionIndex.value));
  }

  void _updateHighlight(int index) => _highlightedOptionIndex.value =
      _options.isEmpty ? 0 : index % _options.length;

  void _highlightPreviousOption(_) =>
      _updateHighlight(_highlightedOptionIndex.value - 1);

  void _highlightNextOption(_) =>
      _updateHighlight(_highlightedOptionIndex.value + 1);

  Object? _hideOptions(DismissIntent intent) {
    if (_mentionOverlay != null) {
      _mentionOverlay?.remove();
      _mentionOverlay?.dispose();
      _mentionOverlay = null;
      _updateActions();
      return null;
    }
    return Actions.invoke(context, intent);
  }

  void _updateActions() => _setActionsEnabled(
      _focusNode.hasFocus && _options.isNotEmpty && _mentionOverlay != null);

  void _setActionsEnabled(bool enabled) {
    _previousOptionAction.enabled = enabled;
    _nextOptionAction.enabled = enabled;
    _hideOptionsAction.enabled = enabled;
    _submitAction.enabled = enabled;
  }

  void _onDocumentUpdated() async {
    await _checkForMentionTriggers();
    _updateOverlay();
    _updateActions();
    _updateHighlight(0);
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
    _updateActions();
    _updateOverlay();
  }

  void _updateOverlay() {
    if (!_focusNode.hasFocus || _options.isEmpty) {
      _mentionOverlay?.remove();
      _mentionOverlay?.dispose();
      _mentionOverlay = null;
    } else if (_mentionOverlay == null) {
      _mentionOverlay = OverlayEntry(
        builder: (context) => AutocompleteHighlightedOption(
          highlightIndexNotifier: _highlightedOptionIndex,
          child: (widget.optionsViewBuilder ?? _defaultOptionsViewBuilder)(
              context, _onSelected, _options),
        ),
      );
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
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: _shortcuts,
        child: Actions(
          actions: _actionMap,
          child: NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _mentionOverlay?.markNeedsBuild();
              return false;
            },
            child: widget.child,
          ),
        ),
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
        child: _buildList(context),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final highlightedIndex = AutocompleteHighlightedOption.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: suggestions
              .mapIndexed((i, e) => Builder(builder: (context) {
                    final highlighted = highlightedIndex == i;
                    if (highlighted) {
                      SchedulerBinding.instance
                          .addPostFrameCallback((Duration timeStamp) {
                        Scrollable.ensureVisible(context, alignment: 0.5);
                      });
                    }
                    return InkWell(
                      onTap: () => onSelected(e),
                      child: Container(
                        color:
                            highlighted ? Theme.of(context).focusColor : null,
                        padding: const EdgeInsets.all(16.0),
                        child: Text(e.value),
                      ),
                    );
                  }))
              .toList(),
        ),
      ),
    );
  }
}
