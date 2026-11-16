import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../assets/asset_models.dart';
import '../player/novel_player.dart';
import 'controller/playback_pace_controller.dart';
import 'hud/choice_overlay.dart';
import 'hud/dialogue_panel.dart';
import 'hud/top_hud_bar.dart';
import 'modals/backlog_modal.dart';
import 'modals/flowchart_modal.dart';
import 'modals/save_load_modal.dart';
import 'motion.dart';
import 'scene_metadata.dart';
import 'stage/cg_overlay_layer.dart';
import 'stage/character_stage.dart';
import 'stage/scene_backdrop.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.player,
    this.assets,
    this.characters,
    this.initialDebugMode = false,
  });

  final NovelPlayer player;
  final AssetCatalog? assets;
  final CharacterCatalog? characters;
  final bool initialDebugMode;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  final FocusNode _focusNode = FocusNode();
  final PlaybackPaceController _paceController = PlaybackPaceController();

  late bool _debugMode = widget.initialDebugMode;
  bool _hideUi = false;

  AssetCatalog get _assets => widget.assets ?? defaultAssetCatalog;
  CharacterCatalog get _characters => widget.characters ?? defaultCharacterCatalog;

  @override
  void initState() {
    super.initState();
    _paceController.syncWithState(widget.player.state, widget.player.next);
  }

  @override
  void dispose() {
    _paceController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handlePrimaryAdvance(PlaybackState state) {
    if (_hideUi) {
      setState(() => _hideUi = false);
      return;
    }
    _paceController.completeOrAdvance(state, widget.player.next);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event, PlaybackState state) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.space ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.arrowRight) {
      _handlePrimaryAdvance(state);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.backspace) {
      if (state.canStepBack) widget.player.stepBack();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyH) {
      setState(() => _hideUi = !_hideUi);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA) {
      _paceController.toggleAuto(state, widget.player.next);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyL) {
      _openBacklogSheet(context, state);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.f3) {
      setState(() => _debugMode = !_debugMode);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _openBacklogSheet(BuildContext context, PlaybackState state) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '历史记录',
      barrierColor: Colors.black26,
      transitionDuration: M3Motion.medium,
      pageBuilder: (ctx, anim, secondaryAnim) {
        return BacklogModal(
          entries: state.backlog,
          characters: _characters,
          debugMode: _debugMode,
          onJump: (sIdx, lIdx) {
            Navigator.of(ctx).pop();
            widget.player.jumpTo(sIdx, lIdx);
          },
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) =>
          M3Motion.emphasizedScaleFade(child, anim, beginScale: 0.96),
    );
  }

  void _openSaveLoadSheet(BuildContext context) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '存取档',
      barrierColor: Colors.black26,
      transitionDuration: M3Motion.medium,
      pageBuilder: (ctx, anim, secondaryAnim) {
        return SaveLoadModal(
          getSaves: () => widget.player.saves,
          onSave: widget.player.saveSlot,
          onLoad: widget.player.loadSlot,
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) =>
          M3Motion.emphasizedScaleFade(child, anim, beginScale: 0.96),
    );
  }

  void _openFlowchartSheet(BuildContext context, PlaybackState state) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '流程图',
      barrierColor: Colors.black26,
      transitionDuration: M3Motion.medium,
      pageBuilder: (ctx, anim, secondaryAnim) {
        return FlowchartModal(
          script: widget.player.script,
          currentSceneId: state.scene.id,
          debugMode: _debugMode,
          onSelectScene: (sceneId) {
            Navigator.of(ctx).pop();
            widget.player.jumpToScene(sceneId);
          },
        );
      },
      transitionBuilder: (ctx, anim, secondaryAnim, child) =>
          M3Motion.emphasizedScaleFade(child, anim, beginScale: 0.96),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0D14),
      body: StreamBuilder<PlaybackState>(
        stream: widget.player.states,
        initialData: widget.player.state,
        builder: (context, snapshot) {
          final state = snapshot.requireData;
          _paceController.syncWithState(state, widget.player.next);

          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: (node, event) => _handleKeyEvent(node, event, state),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth > 760;
                final showBottomPanel = !_hideUi && !state.line.isSilentBeat;

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _handlePrimaryAdvance(state),
                  onSecondaryTap: () => setState(() => _hideUi = !_hideUi),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Background Layer
                      Positioned.fill(
                        child: SceneBackdrop(
                          backgroundId: state.activeBackgroundId,
                          transition: state.activeTransition,
                          assets: _assets,
                        ),
                      ),

                      // 2. Soft Vignette
                      const Positioned.fill(
                        child: IgnorePointer(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x3805070D),
                                  Color(0x0005070D),
                                  Color(0x0005070D),
                                  Color(0x6605070D),
                                ],
                                stops: [0.0, 0.18, 0.72, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 3. Multi-Character Stage Layer
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CharacterStage(
                            characters: state.characters,
                            viewportSize: constraints.biggest,
                            sceneId: state.scene.id,
                            lineId: state.line.id,
                            assets: _assets,
                          ),
                        ),
                      ),

                      // 4. Event CG Overlay Layer
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CgOverlayLayer(
                            cgId: state.activeCgId,
                            debugMode: _debugMode,
                            assets: _assets,
                          ),
                        ),
                      ),

                      // 5. Top HUD Bar
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: SafeArea(
                          bottom: false,
                          child: AnimatedSlide(
                            duration: M3Motion.medium,
                            curve: M3Motion.emphasized,
                            offset: _hideUi ? const Offset(0, -1.2) : Offset.zero,
                            child: AnimatedOpacity(
                              duration: M3Motion.short,
                              opacity: _hideUi ? 0 : 1,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: wide ? 28 : 14,
                                  vertical: 12,
                                ),
                                child: GalgameTopHud(
                                  state: state,
                                  debugMode: _debugMode,
                                  onToggleDebug: () => setState(() => _debugMode = !_debugMode),
                                  onOpenFlowchart: () => _openFlowchartSheet(context, state),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 6. Dialogue Box & Quick Bar
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: SafeArea(
                          top: false,
                          child: AnimatedSlide(
                            duration: M3Motion.medium,
                            curve: M3Motion.emphasized,
                            offset: showBottomPanel ? Offset.zero : const Offset(0, 0.35),
                            child: AnimatedOpacity(
                              duration: M3Motion.short,
                              opacity: showBottomPanel ? 1 : 0,
                              child: IgnorePointer(
                                ignoring: !showBottomPanel,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    wide ? 52 : 14,
                                    0,
                                    wide ? 52 : 14,
                                    wide ? 20 : 12,
                                  ),
                                  child: Center(
                                    child: ConstrainedBox(
                                      constraints: const BoxConstraints(maxWidth: 980),
                                      child: ListenableBuilder(
                                        listenable: _paceController,
                                        builder: (context, _) {
                                          return GalgameDialogueBox(
                                            state: state,
                                            characters: _characters,
                                            debugMode: _debugMode,
                                            displayedText: _paceController.displayedText,
                                            isTyping: _paceController.isTyping,
                                            autoPlay: _paceController.autoPlay,
                                            skipMode: _paceController.skipMode,
                                            onStepBack: state.canStepBack
                                                ? widget.player.stepBack
                                                : null,
                                            onToggleAuto: () => _paceController.toggleAuto(
                                              state,
                                              widget.player.next,
                                            ),
                                            onToggleSkip: () => _paceController.toggleSkip(
                                              state,
                                              widget.player.next,
                                            ),
                                            onOpenLog: () => _openBacklogSheet(context, state),
                                            onOpenSaveLoad: () => _openSaveLoadSheet(context),
                                            onOpenFlowchart: () =>
                                                _openFlowchartSheet(context, state),
                                            onHideUi: () => setState(() => _hideUi = true),
                                            onRestart: widget.player.restart,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 7. Choice Overlay
                      Positioned.fill(
                        child: AnimatedSwitcher(
                          duration: M3Motion.mediumLong,
                          reverseDuration: M3Motion.short,
                          child: state.isWaitingForChoice && !_hideUi
                              ? ChoiceOverlay(
                                  key: ValueKey('choice_${state.scene.id}_${state.line.id}'),
                                  options: state.line.options,
                                  debugMode: _debugMode,
                                  onChoose: widget.player.choose,
                                )
                              : const SizedBox.shrink(key: ValueKey('no_choice')),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
