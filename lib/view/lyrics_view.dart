import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';

import '../bloc/lyrics/lyrics_bloc.dart';
import '../bloc/music_controller/music_controller_bloc.dart';
import '../core/theme/app_colors.dart';
import '../models/lyrics.dart';
import '../models/online_lyrics_candidate.dart';
import '../service/lyrics_repository.dart';
import '../widgets/common/sheet_shell.dart';
import 'lyrics_editor.dart';

class LyricsView extends StatefulWidget {
  const LyricsView({
    required this.lyricsBloc,
    required this.musicBloc,
    this.onClose,
    super.key,
  });

  final LyricsBloc lyricsBloc;
  final MusicControllerBloc musicBloc;
  final VoidCallback? onClose;

  @override
  State<LyricsView> createState() => _LyricsViewState();
}

class _LyricsViewState extends State<LyricsView> {
  final ScrollController _scrollController = ScrollController();
  List<GlobalKey> _lineKeys = <GlobalKey>[];
  int _keyedLineCount = -1;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _syncKeys(int count) {
    if (_keyedLineCount == count) {
      return;
    }
    _keyedLineCount = count;
    _lineKeys = List<GlobalKey>.generate(count, (_) => GlobalKey());
  }

  void _scrollToActive(int index) {
    if (index < 0 ||
        index >= _lineKeys.length ||
        !_scrollController.hasClients) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final RenderObject? renderObject = _lineKeys[index].currentContext
          ?.findRenderObject();
      if (renderObject is! RenderBox) {
        return;
      }

      final ScrollPosition position = _scrollController.position;
      final RenderAbstractViewport viewport = RenderAbstractViewport.of(
        renderObject,
      );
      final double lineOffset = viewport
          .getOffsetToReveal(renderObject, 0.0)
          .offset;
      final double lineHeight = renderObject.size.height;
      final double viewportHeight = position.viewportDimension;

      final double target = (lineOffset - (viewportHeight - lineHeight) / 2)
          .clamp(position.minScrollExtent, position.maxScrollExtent);

      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Widget _fadeEdges({required Widget child}) {
    return ShaderMask(
      shaderCallback: (Rect bounds) {
        return const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            Colors.black,
            Colors.black,
            Colors.transparent,
          ],
          stops: <double>[0.0, 0.08, 0.92, 1.0],
        ).createShader(bounds);
      },
      blendMode: BlendMode.dstIn,
      child: child,
    );
  }

  Future<void> _openEditor(Lyrics? initial) async {
    final SongModel? song = widget.lyricsBloc.stateData.song;
    if (song == null) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LyricsEditorPage(
          song: song,
          initial: initial,
          lyricsBloc: widget.lyricsBloc,
          musicBloc: widget.musicBloc,
        ),
      ),
    );
  }

  Future<void> _shareLyrics(SongModel song, Lyrics lyrics) async {
    final String path = await LyricsRepository.instance.exportForShare(
      song,
      lyrics,
    );
    await SharePlus.instance.share(
      ShareParams(files: <XFile>[XFile(path)], subject: song.title),
    );
  }

  void _openOnlineSearch() {
    widget.lyricsBloc.add(LyricsOnlineSearchRequested());
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (BuildContext sheetContext) =>
          _OnlineLyricsSheet(lyricsBloc: widget.lyricsBloc),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<LyricsBloc, LyricsState>(
      bloc: widget.lyricsBloc,
      listener: (BuildContext context, LyricsState state) {
        final LyricsStateData data = widget.lyricsBloc.stateData;
        if (data.hasSyncedLyrics) {
          _scrollToActive(data.activeLine);
        }
      },
      builder: (BuildContext context, LyricsState state) {
        final LyricsStateData data = widget.lyricsBloc.stateData;

        switch (data.status) {
          case LyricsStatus.idle:
            return _centered(const Text('Nothing playing'));
          case LyricsStatus.loading:
            return _centered(const CircularProgressIndicator());
          case LyricsStatus.generating:
            return _buildGenerating(data);
          case LyricsStatus.failed:
            return _buildFailed(data);
          case LyricsStatus.absent:
            return _buildAbsent();
          case LyricsStatus.present:
            return _buildPresent(data);
        }
      },
    );
  }

  Widget _centered(Widget child) => Center(
    child: DefaultTextStyle(
      style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
      child: child,
    ),
  );

  Widget _buildAbsent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            'Get lyrics',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            children: <Widget>[
              Expanded(
                child: _SourceChip(
                  label: 'On-device AI',
                  selected: true,
                  onTap: () =>
                      widget.lyricsBloc.add(LyricsGenerateRequested()),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _SourceChip(
                  label: 'Online',
                  selected: false,
                  onTap: _openOnlineSearch,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _SourceChip(
                  label: 'Type it',
                  selected: false,
                  onTap: () => _openEditor(null),
                ),
              ),
            ],
          ),
          SizedBox(height: 20.h),
          Text(
            'Runs offline. Transcribes at the original speed, then re-times '
            'the result to your current playback speed.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: 12.sp,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFailed(LyricsStateData data) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 40.sp,
              color: AppColors.textSecondary,
            ),
            SizedBox(height: 12.h),
            Text(
              data.errorMessage ?? 'Could not generate lyrics',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
            SizedBox(height: 16.h),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8.w,
              runSpacing: 4.h,
              children: <Widget>[
                TextButton(
                  onPressed: () =>
                      widget.lyricsBloc.add(LyricsGenerateRequested()),
                  child: Text(
                    'Generate with AI',
                    style: TextStyle(color: AppColors.accent, fontSize: 14.sp),
                  ),
                ),
                TextButton(
                  onPressed: _openOnlineSearch,
                  child: Text(
                    'Search Online',
                    style: TextStyle(color: AppColors.accent, fontSize: 14.sp),
                  ),
                ),
                TextButton(
                  onPressed: () => _openEditor(data.lyrics),
                  child: Text(
                    'Add manually',
                    style: TextStyle(color: AppColors.accent, fontSize: 14.sp),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerating(LyricsStateData data) {
    return Column(
      children: <Widget>[
        SizedBox(height: 12.h),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      width: 34.w,
                      height: 34.w,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(
                        width: 16.w,
                        height: 16.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.w,
                          color: AppColors.accent,
                          value: data.progress,
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'Transcribing on device',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14.5.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            data.phase.isEmpty ? 'Working…' : data.phase,
                            style: TextStyle(
                              color: AppColors.textTertiary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          widget.lyricsBloc.add(LyricsGenerationCancelled()),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppColors.accent,
                          fontSize: 12.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2.r),
                  child: LinearProgressIndicator(
                    minHeight: 3.h,
                    value: data.progress,
                    backgroundColor: AppColors.surfaceHigh,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.accent,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: _fadeEdges(child: _buildLineList(data, interactive: false)),
        ),
      ],
    );
  }

  Widget _buildPresent(LyricsStateData data) {
    final Lyrics lyrics = data.lyrics!;

    return Column(
      children: <Widget>[
        if (data.isDraft) _buildDraftBanner(data),
        _buildToolbar(data),
        if (lyrics.synced) _buildOffsetRow(data),
        Expanded(
          child: _fadeEdges(
            child: lyrics.synced
                ? _buildLineList(data, interactive: true)
                : SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: 24.w,
                      vertical: 8.h,
                    ),
                    child: Text(
                      lyrics.plainText ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15.sp,
                        height: 1.6,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildOffsetRow(LyricsStateData data) {
    final double offsetS = data.offsetMs / 1000;

    return Padding(
      padding: EdgeInsets.only(top: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () =>
                widget.lyricsBloc.add(LyricsOffsetAdjusted(-100)),
            icon: Icon(
              Icons.remove_circle_outline_rounded,
              size: 16.sp,
              color: AppColors.textTertiary,
            ),
          ),
          GestureDetector(
            onLongPress: () =>
                widget.lyricsBloc.add(LyricsOffsetReset()),
            child: Text(
              'Offset ${offsetS >= 0 ? '+' : ''}${offsetS.toStringAsFixed(1)}s',
              style: TextStyle(
                color: data.offsetMs == 0
                    ? AppColors.textTertiary
                    : AppColors.accent,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => widget.lyricsBloc.add(LyricsOffsetAdjusted(100)),
            icon: Icon(
              Icons.add_circle_outline_rounded,
              size: 16.sp,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftBanner(LyricsStateData data) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 4.h),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              data.lyrics?.source == LyricsSource.online
                  ? 'Found online — check it, then save'
                  : 'AI draft — check it, then save',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 12.sp),
            ),
          ),
          if (data.song != null)
            TextButton(
              onPressed: () =>
                  widget.lyricsBloc.add(LyricsDeleteRequested(data.song!)),
              child: Text(
                'Discard',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12.sp,
                ),
              ),
            ),
          if (data.song != null && data.lyrics != null)
            TextButton(
              onPressed: () => widget.lyricsBloc.add(
                LyricsSaveRequested(data.song!, data.lyrics!),
              ),
              child: Text(
                'Save',
                style: TextStyle(color: AppColors.accent, fontSize: 12.sp),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildToolbar(LyricsStateData data) {
    final Lyrics? lyrics = data.lyrics;
    final String sourceLabel = switch (lyrics?.source) {
      LyricsSource.online => 'ONLINE',
      LyricsSource.edited => 'TYPED',
      LyricsSource.tag => 'TAG',
      LyricsSource.lrc => 'LRC',
      LyricsSource.ai || null => 'AI',
    };
    final String syncLabel = lyrics?.synced ?? false ? 'SYNCED' : 'PLAIN';
    final double speed = widget.musicBloc.stateData.speed;

    return Padding(
      padding: EdgeInsets.fromLTRB(4.w, 2.h, 8.w, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: widget.onClose,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22.sp,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                Text(
                  data.song?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$sourceLabel · $syncLabel · ${speed.toStringAsFixed(2)}×',
                  style: TextStyle(
                    color: AppColors.accent,
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => _openEditor(data.lyrics),
            icon: Icon(
              Icons.edit_outlined,
              size: 20.sp,
              color: AppColors.textSecondary,
            ),
          ),
          PopupMenuButton<String>(
            color: AppColors.surface,
            icon: Icon(
              Icons.more_vert_rounded,
              size: 20.sp,
              color: AppColors.textSecondary,
            ),
            onSelected: (String value) {
              final SongModel? song = widget.lyricsBloc.stateData.song;
              if (value == 'regenerate') {
                widget.lyricsBloc.add(LyricsGenerateRequested());
              } else if (value == 'search_online') {
                _openOnlineSearch();
              } else if (value == 'delete' && song != null) {
                widget.lyricsBloc.add(LyricsDeleteRequested(song));
              } else if (value == 'share' &&
                  song != null &&
                  data.lyrics != null) {
                _shareLyrics(song, data.lyrics!);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'share',
                child: Text('Share .lrc'),
              ),
              const PopupMenuItem<String>(
                value: 'regenerate',
                child: Text('Regenerate with AI'),
              ),
              const PopupMenuItem<String>(
                value: 'search_online',
                child: Text('Search online'),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Text('Remove lyrics'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _lineColor(int index, int activeIndex) {
    if (activeIndex < 0) {
      return AppColors.textSecondary;
    }
    final int distance = (index - activeIndex).abs();
    switch (distance) {
      case 0:
        return AppColors.textPrimary;
      case 1:
        return AppColors.textSecondary;
      case 2:
        return AppColors.textTertiary;
      case 3:
        return AppColors.disabled;
      default:
        return AppColors.surfaceHigh;
    }
  }

  Widget _buildLineList(LyricsStateData data, {required bool interactive}) {
    final List<LyricLine> lines = data.lyrics?.lines ?? const <LyricLine>[];
    _syncKeys(lines.length);

    return SingleChildScrollView(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List<Widget>.generate(lines.length, (int i) {
          final bool isActive = i == data.activeLine;
          final LyricLine line = lines[i];
          return Padding(
            key: _lineKeys.length > i ? _lineKeys[i] : null,
            padding: EdgeInsets.symmetric(vertical: 7.h),
            child: GestureDetector(
              onTap: interactive
                  ? () => widget.musicBloc.add(SeekTo(line.time.inMilliseconds))
                  : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (isActive) ...<Widget>[
                    Container(
                      width: 3.w,
                      margin: EdgeInsets.only(right: 12.w),
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        borderRadius: BorderRadius.circular(2.r),
                      ),
                    ),
                  ],
                  Flexible(
                    child: Text(
                      line.text.isEmpty ? '♪' : line.text,
                      textAlign: isActive ? TextAlign.left : TextAlign.center,
                      style: TextStyle(
                        fontSize: isActive ? 25.sp : 15.sp,
                        height: isActive ? 1.32 : 1.4,
                        fontWeight: isActive
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: _lineColor(i, data.activeLine),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _SourceChip extends StatelessWidget {
  const _SourceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: onTap,
      child: Container(
        height: 36.h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.accent.withValues(alpha: 0.14)
              : AppColors.surface,
          border: selected ? Border.all(color: AppColors.accent) : null,
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5.sp,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _OnlineLyricsSheet extends StatefulWidget {
  const _OnlineLyricsSheet({required this.lyricsBloc});

  final LyricsBloc lyricsBloc;

  @override
  State<_OnlineLyricsSheet> createState() => _OnlineLyricsSheetState();
}

class _OnlineLyricsSheetState extends State<_OnlineLyricsSheet> {
  late final TextEditingController _searchController = TextEditingController(
    text: widget.lyricsBloc.stateData.song?.title ?? '',
  );

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final String query = _searchController.text.trim();
    widget.lyricsBloc.add(
      LyricsOnlineSearchRequested(query: query.isEmpty ? null : query),
    );
  }

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: BlocBuilder<LyricsBloc, LyricsState>(
        bloc: widget.lyricsBloc,
        builder: (BuildContext context, LyricsState state) {
          final LyricsStateData data = widget.lyricsBloc.stateData;
          return SheetShell(
            header: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 8.h),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Search Online',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.sp,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search by title or artist…',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14.sp,
                      ),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 14.w,
                        vertical: 12.h,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(13.r),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: data.onlineSearching
                          ? Padding(
                              padding: EdgeInsets.all(12.w),
                              child: SizedBox(
                                width: 16.w,
                                height: 16.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          : IconButton(
                              visualDensity: VisualDensity.compact,
                              onPressed: _search,
                              icon: Icon(
                                Icons.search_rounded,
                                size: 22.sp,
                                color: AppColors.accent,
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            body: _buildBody(data),
          );
        },
      ),
    );
  }

  Widget _buildBody(LyricsStateData data) {
    if (data.onlineSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            SizedBox(height: 12.h),
            Text(
              'Searching online…',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13.sp),
            ),
          ],
        ),
      );
    }

    if (data.onlineError != null) {
      return Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 28.w),
          child: Text(
            data.onlineError!,
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          ),
        ),
      );
    }

    final List<OnlineLyricsCandidate> candidates =
        data.onlineCandidates ?? const <OnlineLyricsCandidate>[];
    if (candidates.isEmpty) {
      return Center(
        child: Text(
          'No results found online.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      itemCount: candidates.length,
      itemBuilder: (BuildContext context, int index) {
        final OnlineLyricsCandidate candidate = candidates[index];
        final String subtitle =
            '${candidate.artistName.isNotEmpty ? '${candidate.artistName} — ' : ''}'
            '${candidate.hasSynced
                ? 'Synced'
                : candidate.hasPlain
                ? 'Plain text'
                : 'Instrumental'} · ${_formatDuration(candidate.duration)}';

        return InkWell(
          onTap: candidate.hasAny
              ? () {
                  widget.lyricsBloc.add(
                    LyricsOnlineCandidateSelected(candidate),
                  );
                  Navigator.of(context).pop();
                }
              : null,
          child: Opacity(
            opacity: candidate.hasAny ? 1 : 0.5,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 10.h),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 34.w,
                    height: 34.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.iconBg,
                      borderRadius: BorderRadius.circular(9.r),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: AppColors.iconColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          candidate.trackName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textTertiary,
                            fontSize: 11.5.sp,
                            fontWeight: FontWeight.w500,
                            fontFeatures: const <FontFeature>[
                              FontFeature.tabularFigures(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (candidate.hasAny)
                    Text(
                      'Use',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontSize: 12.5.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
