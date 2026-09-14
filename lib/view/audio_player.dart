import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../core/app_constants/app_enums.dart';
import '../core/bloc/lyrics_bloc/lyrics_bloc.dart';
import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/bloc/songs_bloc/songs_bloc.dart';
import '../core/common_widgets.dart/player_options_sheet.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_slider_theme.dart';
import 'equalizer_sheet.dart';
import 'lyrics_view.dart';
import 'playing_queue_sheet.dart';

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key, required this.index});

  final int index;

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with TickerProviderStateMixin {
  late MusicControllerBloc _musicControllerBloc;
  late SongsBloc _songsBloc;
  late LyricsBloc _lyricsBloc;
  late AnimationController _rotationController;
  late AnimationController _tonearmController;
  bool _showLyrics = false;
  bool _showAbLoop = false;

  @override
  void initState() {
    super.initState();
    _musicControllerBloc = BlocProvider.of<MusicControllerBloc>(context);
    _songsBloc = BlocProvider.of<SongsBloc>(context);
    _lyricsBloc = BlocProvider.of<LyricsBloc>(context);

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _tonearmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      value: _musicControllerBloc.stateData.isPlaying ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _tonearmController.dispose();
    super.dispose();
  }

  String _formatTime(int ms) {
    final int totalSeconds = ms ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Swipe left -> next song, swipe right -> previous song.
  void _onSwipeChangeSong(DragEndDetails details) {
    final double? velocity = details.primaryVelocity;
    if (velocity == null || velocity == 0) {
      return;
    }
    if (velocity < 0) {
      _musicControllerBloc.add(NextSong());
    } else {
      _musicControllerBloc.add(PreviousSong());
    }
  }

  void _showSpeedPitchSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (BuildContext sheetContext) {
        return BlocBuilder<MusicControllerBloc, MusicControllerState>(
          bloc: _musicControllerBloc,
          builder: (BuildContext context, MusicControllerState state) {
            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 0.5.sh),
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 32.h),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Speed  ${_musicControllerBloc.stateData.speed.toStringAsFixed(2)}x',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16.sp,
                        ),
                      ),
                      SliderTheme(
                        data: appSliderTheme(inactiveColor: AppColors.textTertiary),
                        child: Slider(
                          min: 0.5,
                          max: 2.0,
                          value: _musicControllerBloc.stateData.speed.clamp(
                            0.5,
                            2.0,
                          ),
                          onChanged: (double value) =>
                              _musicControllerBloc.add(SpeedChanged(value)),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'Pitch  ${_musicControllerBloc.stateData.pitch.toStringAsFixed(2)}x',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16.sp,
                        ),
                      ),
                      SliderTheme(
                        data: appSliderTheme(inactiveColor: AppColors.textTertiary),
                        child: Slider(
                          min: 0.5,
                          max: 2.0,
                          value: _musicControllerBloc.stateData.pitch.clamp(
                            0.5,
                            2.0,
                          ),
                          onChanged: (double value) =>
                              _musicControllerBloc.add(PitchChanged(value)),
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: <Widget>[
                          TextButton(
                            onPressed: () {
                              _musicControllerBloc.add(SpeedChanged(0.90));
                              _musicControllerBloc.add(PitchChanged(0.95));
                            },
                            child: Text(
                              'Lo-Fi Preset',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 15.sp,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              _musicControllerBloc.add(SpeedChanged(1.0));
                              _musicControllerBloc.add(PitchChanged(1.0));
                            },
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 15.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showEqualizerSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (BuildContext sheetContext) =>
          EqualizerSheet(musicBloc: _musicControllerBloc),
    );
  }

  IconData get _repeatIcon {
    switch (_musicControllerBloc.stateData.repeatMode) {
      case RepeatMode.off:
      case RepeatMode.all:
        return Icons.repeat_rounded;
      case RepeatMode.one:
        return Icons.repeat_one_rounded;
    }
  }

  Color get _repeatColor {
    return _musicControllerBloc.stateData.repeatMode == RepeatMode.off
        ? AppColors.textPrimary
        : AppColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MusicControllerBloc, MusicControllerState>(
      listener: (BuildContext context, MusicControllerState state) {
        if (_musicControllerBloc.stateData.isPlaying) {
          _rotationController.repeat();
          _tonearmController.forward();
        } else {
          _rotationController.stop();
          _tonearmController.reverse();
        }

        // Queue was cleared (e.g. from the Playing Queue sheet) - nothing
        // left to show here, so close back to the song list.
        if (_musicControllerBloc.stateData.queue.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
              Navigator.of(context).maybePop();
            }
          });
        }
      },
      child: BlocBuilder<MusicControllerBloc, MusicControllerState>(
        bloc: _musicControllerBloc,
        builder: (BuildContext context, MusicControllerState state) {
          final SongModel? song = _musicControllerBloc.stateData.song;
          final bool isFavorite =
              song != null &&
              _songsBloc.stateData.favoriteIds.contains(song.id);

          return Scaffold(
            backgroundColor: AppColors.transparent,
            body: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: QueryArtworkWidget(
                    type: ArtworkType.AUDIO,
                    id: song?.id ?? 0,
                    keepOldArtwork: true,
                    nullArtworkWidget: Container(color: AppColors.background),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100.w, sigmaY: 100.w),
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.72),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(
                    top: MediaQueryData.fromView(View.of(context)).padding.top,
                    bottom: MediaQueryData.fromView(
                      View.of(context),
                    ).padding.bottom,
                  ),
                  child: Column(
                    children: <Widget>[
                      SizedBox(height: 12.h),
                      _buildTopBar(song),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          child: _showLyrics
                              ? LyricsView(
                                  key: const ValueKey<String>('lyrics'),
                                  lyricsBloc: _lyricsBloc,
                                  musicBloc: _musicControllerBloc,
                                )
                              : GestureDetector(
                                  key: const ValueKey<String>('disc'),
                                  onTap: () =>
                                      setState(() => _showLyrics = true),
                                  onHorizontalDragEnd: _onSwipeChangeSong,
                                  child: Center(
                                    child: FittedBox(
                                      child: _buildTurntable(song),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      _buildUtilityRow(song, isFavorite),
                      SizedBox(height: 16.h),
                      _buildProgress(),
                      if (_showAbLoop) ...<Widget>[
                        SizedBox(height: 4.h),
                        _buildAbLoopRow(),
                      ],
                      SizedBox(height: 12.h),
                      _buildControls(),
                      SizedBox(height: 40.h),
                      _buildBottomRow(),
                      SizedBox(height: 60.h),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(SongModel? song) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textPrimary,
              size: 28.sp,
            ),
          ),
          Expanded(
            child: Column(
              children: <Widget>[
                _ScrollingTitle(
                  text: song?.title ?? 'NA',
                  height: 26.h,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  song?.artist ?? 'Unknown Artist',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: AppColors.textPrimary.withValues(alpha: 0.75),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          SizedBox(width: 48.w),
        ],
      ),
    );
  }

  Widget _buildTurntable(SongModel? song) {
    final double discSize = 0.8.sw;

    return SizedBox(
      width: 1.sw,
      height: 1.sw,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Container(
            height: discSize,
            width: discSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.vinylEdge, width: 5.w),
              gradient: const SweepGradient(
                colors: <Color>[
                  AppColors.vinylGroove,
                  Colors.black,
                  AppColors.vinylGroove,
                  Colors.black,
                  AppColors.vinylGroove,
                ],
              ),
            ),
            padding: EdgeInsets.all(0.15.sw),
            child: RotationTransition(
              turns: _rotationController,
              child: ClipOval(
                child: QueryArtworkWidget(
                  type: ArtworkType.AUDIO,
                  id: song?.id ?? 0,
                  keepOldArtwork: true,
                  artworkHeight: discSize,
                  artworkWidth: discSize,
                  nullArtworkWidget: Container(
                    color: AppColors.vinylCenter,
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.music_note,
                      size: 90.sp,
                      color: AppColors.vinylNote,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0.sw,
            right: 0.35.sw,
            child: AnimatedBuilder(
              animation: _tonearmController,
              builder: (BuildContext context, Widget? child) {
                // 0.360 rad used to leave the arm still visually resting on
                // the disc edge in the "off" pose - lifted further out here
                // so off clearly reads as off.
                final double angle = lerpDouble(
                  0.52,
                  0.0,
                  Curves.easeInOut.transform(_tonearmController.value),
                )!;

                return Transform.rotate(
                  angle: angle,
                  alignment: Alignment.topRight,
                  child: child,
                );
              },
              child: CustomPaint(
                size: Size(0.26.sw, 0.30.sw),
                painter: _TonearmPainter(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityRow(SongModel? song, bool isFavorite) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 28.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            onPressed: _showEqualizerSheet,
            icon: Icon(
              Icons.tune_rounded,
              size: 26.sp,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _showAbLoop = !_showAbLoop),
            icon: Icon(
              Icons.compare_arrows_rounded,
              size: 26.sp,
              color: _musicControllerBloc.stateData.hasAbLoop
                  ? AppColors.accent
                  : AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: _showSpeedPitchSheet,
            icon: Icon(
              Icons.speed_rounded,
              size: 26.sp,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: song == null
                ? null
                : () {
                    _songsBloc.add(
                      isFavorite
                          ? RemoveFromFavorites(song.id)
                          : AddToFavorites(song.id),
                    );
                  },
            icon: Icon(
              isFavorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              size: 26.sp,
              color: isFavorite ? AppColors.accent : AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: song == null
                ? null
                : () => PlayerOptionsSheet.show(context, song: song),
            icon: Icon(
              Icons.more_vert_rounded,
              size: 26.sp,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final int duration = _musicControllerBloc.stateData.duration;
    final int position = _musicControllerBloc.stateData.position;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  _formatTime(position),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                  ),
                ),
                Text(
                  _formatTime(duration),
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
          SliderTheme(
            data: appSliderTheme(),
            child: Slider(
              max: duration.toDouble().clamp(1, double.infinity),
              value: position.toDouble().clamp(0, duration.toDouble()),
              onChanged: (double value) =>
                  _musicControllerBloc.add(SeekTo(value.toInt())),
            ),
          ),
        ],
      ),
    );
  }

  /// Tap "A" / "B" to mark the current playback position as that loop point;
  /// once both are set, playback repeats between them (enforced in
  /// MusicControllerBloc against the position it already streams in). "X"
  /// clears both without hiding this row, so the user can re-mark points
  /// without reopening it via the toolbar icon.
  Widget _buildAbLoopRow() {
    final int? a = _musicControllerBloc.stateData.abLoopAMs;
    final int? b = _musicControllerBloc.stateData.abLoopBMs;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          _buildAbPoint(
            label: 'A',
            ms: a,
            onTap: () => _musicControllerBloc.add(SetAbLoopPointA()),
          ),
          SizedBox(width: 24.w),
          _buildAbPoint(
            label: 'B',
            ms: b,
            onTap: () => _musicControllerBloc.add(SetAbLoopPointB()),
          ),
          SizedBox(width: 20.w),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: (a == null && b == null)
                ? null
                : () => _musicControllerBloc.add(ClearAbLoop()),
            icon: Icon(
              Icons.close_rounded,
              size: 18.sp,
              color: (a == null && b == null)
                  ? AppColors.disabled
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbPoint({
    required String label,
    required int? ms,
    required VoidCallback onTap,
  }) {
    final Color color = ms != null ? AppColors.accent : AppColors.textPrimary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 4.h),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 24.w,
              height: 24.w,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5.w),
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (ms != null) ...<Widget>[
              SizedBox(width: 6.w),
              Text(
                _formatTime(ms),
                style: TextStyle(color: color, fontSize: 13.sp),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            onPressed: () => _musicControllerBloc.add(ToggleShuffle()),
            icon: Icon(
              Icons.shuffle_rounded,
              size: 24.sp,
              color: _musicControllerBloc.stateData.isShuffle
                  ? AppColors.accent
                  : AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => _musicControllerBloc.add(PreviousSong()),
            icon: Icon(
              Icons.skip_previous_rounded,
              size: 34.sp,
              color: AppColors.textPrimary,
            ),
          ),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.textPrimary, width: 2.w),
            ),
            padding: EdgeInsets.all(10.w),
            child: GestureDetector(
              onTap: () => _musicControllerBloc.add(PlayPauseToggled()),
              child: Icon(
                _musicControllerBloc.stateData.isPlaying
                    ? Icons.pause
                    : Icons.play_arrow,
                size: 38.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _musicControllerBloc.add(NextSong()),
            icon: Icon(
              Icons.skip_next_rounded,
              size: 34.sp,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            onPressed: () => _musicControllerBloc.add(ChangeRepeatMode()),
            icon: Icon(_repeatIcon, size: 24.sp, color: _repeatColor),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 34.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          InkWell(
            onTap: () => setState(() => _showLyrics = !_showLyrics),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  _showLyrics ? Icons.lyrics_rounded : Icons.lyrics_outlined,
                  size: 22.sp,
                  color: _showLyrics ? AppColors.accent : AppColors.textPrimary,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Lyrics',
                  style: TextStyle(
                    color: _showLyrics
                        ? AppColors.accent
                        : AppColors.textPrimary,
                    fontSize: 15.sp,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => PlayingQueueSheet.show(context),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.queue_music_rounded,
                  size: 22.sp,
                  color: AppColors.textPrimary,
                ),
                SizedBox(width: 8.w),
                Text(
                  'Playing Queue',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScrollingTitle extends StatelessWidget {
  const _ScrollingTitle({
    required this.text,
    required this.style,
    required this.height,
  });

  final String text;
  final TextStyle style;
  final double height;

  /// Some tags carry newlines or long runs of padding spaces - collapse any
  /// whitespace run to a single space so the scrolling title stays tidy.
  static String _clean(String raw) =>
      raw.replaceAll(RegExp(r'\s+'), ' ').trim();

  @override
  Widget build(BuildContext context) {
    final String display = _clean(text);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final TextPainter painter = TextPainter(
            text: TextSpan(text: display, style: style),
            maxLines: 1,
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout();

          if (painter.width <= constraints.maxWidth) {
            return Center(child: Text(display, style: style, maxLines: 1));
          }

          return Marquee(
            text: display,
            style: style,
            velocity: 40.0,
            startAfter: const Duration(seconds: 2),
            startPadding: 40.w,
            pauseAfterRound: const Duration(seconds: 1),
            fadingEdgeStartFraction: 0.12,
            fadingEdgeEndFraction: 0.12,
          );
        },
      ),
    );
  }
}

class _TonearmPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Offset pivot = Offset(size.width - 16, 16);
    final Offset head = Offset(size.width * 0.20, size.height * 0.82);
    final Offset elbow = Offset(size.width * 0.66, size.height * 0.46);

    final Paint armPaint = Paint()
      ..color = const Color(0xFFE8E8E8)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final Path arm = Path()
      ..moveTo(pivot.dx, pivot.dy)
      ..lineTo(elbow.dx, elbow.dy)
      ..lineTo(head.dx, head.dy);

    canvas.drawPath(arm, armPaint);

    canvas.save();
    canvas.translate(head.dx, head.dy);
    canvas.rotate(-math.pi / 5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 20, height: 13),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFFF2F2F2),
    );
    canvas.restore();

    canvas.drawCircle(pivot, 15, Paint()..color = const Color(0xFFD8D8D8));
    canvas.drawCircle(
      pivot,
      15,
      Paint()
        ..color = const Color(0xFF9A9A9A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(pivot, 6, Paint()..color = const Color(0xFF8C8C8C));
  }

  @override
  bool shouldRepaint(covariant _TonearmPainter oldDelegate) => false;
}
