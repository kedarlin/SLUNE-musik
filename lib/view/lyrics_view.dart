import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:share_plus/share_plus.dart';

import '../core/bloc/lyrics_bloc/lyrics_bloc.dart';
import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/models/lyrics.dart';
import '../core/models/online_lyrics_candidate.dart';
import '../core/services/lyrics_repository.dart';
import '../core/theme/app_colors.dart';
import 'lyrics_editor.dart';

/// The panel shown in place of the turntable disc. Line-synced when timed
/// lyrics exist, otherwise a scrollable block, otherwise an empty state with
/// Generate / Add-manually actions.
class LyricsView extends StatefulWidget {
  const LyricsView({
    required this.lyricsBloc,
    required this.musicBloc,
    super.key,
  });

  final LyricsBloc lyricsBloc;
  final MusicControllerBloc musicBloc;

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

  /// Keeps the active line centered in the panel, karaoke-style.
  ///
  /// This deliberately does not use `Scrollable.ensureVisible`: that helper
  /// only scrolls when the target would otherwise leave the viewport, so
  /// once a line was already visible somewhere on screen it never moved
  /// again - the highlight kept tracking the right line, but the scroll
  /// position didn't follow it. Computing the centering offset directly and
  /// animating to it on every active-line change is what actually keeps it
  /// centered as playback advances.
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
      // Offset that would put this line's top edge at the viewport's top.
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

  /// Opens the online-lookup picker. The search kicks off immediately; the
  /// sheet itself just renders whatever the bloc's `online*` state fields
  /// are doing - loading, an error, or the candidate list to pick from.
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.lyrics_outlined,
            size: 44.sp,
            color: AppColors.textSecondary,
          ),
          SizedBox(height: 14.h),
          Text(
            'No lyrics for this song',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14.sp),
          ),
          SizedBox(height: 18.h),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () => widget.lyricsBloc.add(LyricsGenerateRequested()),
            icon: const Icon(Icons.auto_awesome_rounded),
            label: const Text('Generate with AI'),
          ),
          SizedBox(height: 10.h),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.accent),
            onPressed: _openOnlineSearch,
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('Search Online'),
          ),
          SizedBox(height: 8.h),
          TextButton(
            onPressed: () => _openEditor(null),
            child: Text(
              'Add manually',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
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
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 18.w,
                height: 18.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2.w,
                  value: data.progress,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  data.phase.isEmpty ? 'Generating lyrics…' : data.phase,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13.sp,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    widget.lyricsBloc.add(LyricsGenerationCancelled()),
                child: Text(
                  'Cancel',
                  style: TextStyle(color: AppColors.accent, fontSize: 13.sp),
                ),
              ),
            ],
          ),
        ),
        Expanded(child: _buildLineList(data, interactive: false)),
      ],
    );
  }

  Widget _buildPresent(LyricsStateData data) {
    final Lyrics lyrics = data.lyrics!;

    return Column(
      children: <Widget>[
        if (data.isDraft) _buildDraftBanner(data),
        _buildToolbar(data),
        Expanded(
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
      ],
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
    return Padding(
      padding: EdgeInsets.only(right: 8.w, top: 2.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
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
              child: Text(
                line.text.isEmpty ? '♪' : line.text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isActive ? 17.sp : 15.sp,
                  height: 1.4,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? AppColors.textPrimary
                      : AppColors.textPrimary.withValues(alpha: 0.45),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// Bottom sheet for the "Search Online" flow. Purely a picker - it shows
/// whatever LRCLIB returned and lets the user tap the row that's actually
/// their song; nothing is auto-selected and nothing here ever navigates
/// outside the app.
class _OnlineLyricsSheet extends StatelessWidget {
  const _OnlineLyricsSheet({required this.lyricsBloc});

  final LyricsBloc lyricsBloc;

  String _formatDuration(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.75,
        child: BlocBuilder<LyricsBloc, LyricsState>(
          bloc: lyricsBloc,
          builder: (BuildContext context, LyricsState state) {
            final LyricsStateData data = lyricsBloc.stateData;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(height: 10.h),
                Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 14.h, 20.w, 8.h),
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
                      if (!data.onlineSearching)
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => lyricsBloc.add(
                            LyricsOnlineSearchRequested(),
                          ),
                          icon: Icon(
                            Icons.refresh_rounded,
                            size: 20.sp,
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(child: _buildBody(data)),
              ],
            );
          },
        ),
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

    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
      itemCount: candidates.length,
      separatorBuilder: (_, _) => Divider(height: 1.h, color: AppColors.divider),
      itemBuilder: (BuildContext context, int index) {
        final OnlineLyricsCandidate candidate = candidates[index];
        final String subtitle = <String>[
          if (candidate.artistName.isNotEmpty) candidate.artistName,
          if (candidate.albumName.isNotEmpty) candidate.albumName,
          _formatDuration(candidate.duration),
        ].join(' · ');
        final String chip = candidate.hasSynced
            ? 'Synced'
            : candidate.hasPlain
            ? 'Plain'
            : 'Instrumental';

        return ListTile(
          enabled: candidate.hasAny,
          onTap: () {
            lyricsBloc.add(LyricsOnlineCandidateSelected(candidate));
            Navigator.of(context).pop();
          },
          title: Text(
            candidate.trackName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.sp),
          ),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: (candidate.hasSynced ? AppColors.accent : AppColors.divider)
                  .withValues(alpha: candidate.hasSynced ? 0.16 : 0.6),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Text(
              chip,
              style: TextStyle(
                color: candidate.hasSynced
                    ? AppColors.accent
                    : AppColors.textSecondary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}
