import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/lyrics/lyrics_bloc.dart';
import '../bloc/music_controller/music_controller_bloc.dart';
import '../core/app_constants/app_enums.dart';
import '../core/theme/app_colors.dart';
import '../widgets/common/scrolling_title.dart';
import '../widgets/player/player_options_sheet.dart';
import '../widgets/player/speed_pitch_sheet.dart';
import 'equalizer_sheet.dart';
import 'lyrics_view.dart';
import 'playing_queue_sheet.dart';

const double _ringSize = 344;
const double _ringOuterR = 164;
const double _ringInnerR = 150;
const double _ringHalf = 172;

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key, required this.index});

  final int index;

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage> {
  late MusicControllerBloc _musicControllerBloc;
  late LyricsBloc _lyricsBloc;
  bool _showLyrics = false;
  bool _abLoopArmed = false;

  @override
  void initState() {
    super.initState();
    _musicControllerBloc = BlocProvider.of<MusicControllerBloc>(context);
    _lyricsBloc = BlocProvider.of<LyricsBloc>(context);
  }

  String _formatTime(int ms) {
    final int totalSeconds = ms ~/ 1000;
    final int minutes = totalSeconds ~/ 60;
    final int seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

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

  void _onAbChipTap() {
    final MusicControllerStateData data = _musicControllerBloc.stateData;
    if (data.hasAbLoop) {
      _musicControllerBloc.add(ClearAbLoop());
      setState(() => _abLoopArmed = false);
    } else if (data.abLoopAMs != null) {
      _musicControllerBloc.add(SetAbLoopPointB());
    } else if (_abLoopArmed) {
      _musicControllerBloc.add(SetAbLoopPointA());
    } else {
      setState(() => _abLoopArmed = true);
    }
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

  @override
  Widget build(BuildContext context) {
    return BlocListener<MusicControllerBloc, MusicControllerState>(
      listener: (BuildContext context, MusicControllerState state) {
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
          final MusicControllerStateData data = _musicControllerBloc.stateData;
          final SongModel? song = data.song;

          return Scaffold(
            backgroundColor: AppColors.background,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  _buildTopBar(context, song, data),
                  Expanded(
                    child: GestureDetector(
                      onHorizontalDragEnd: _onSwipeChangeSong,
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 260),
                        child: _showLyrics
                            ? LyricsView(
                                key: const ValueKey<String>('lyrics'),
                                lyricsBloc: _lyricsBloc,
                                musicBloc: _musicControllerBloc,
                                onClose: () =>
                                    setState(() => _showLyrics = false),
                              )
                            : _buildRingAndInfo(song, data),
                      ),
                    ),
                  ),
                  _buildTransportRow(),
                  SizedBox(height: 22.h),
                  _buildBottomStatsRow(context, data),
                  SizedBox(height: 18.h),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    SongModel? song,
    MusicControllerStateData data,
  ) {
    return Padding(
      key: const ValueKey<String>('topbar'),
      padding: EdgeInsets.fromLTRB(8.w, 6.h, 8.w, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 24.sp,
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8.r),
            onTap: () => PlayingQueueSheet.show(context),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
              child: Text(
                'QUEUE · ${data.queue.length}',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.8,
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: song == null
                ? null
                : () => PlayerOptionsSheet.show(context, song: song),
            icon: Icon(
              Icons.more_vert_rounded,
              color: AppColors.textSecondary,
              size: 20.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingAndInfo(SongModel? song, MusicControllerStateData data) {
    return Column(
      key: const ValueKey<String>('ring'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          onTap: () => setState(() => _showLyrics = true),
          child: _OrbitalRing(song: song, data: data),
        ),
        _buildTimeRow(data),
        Padding(
          padding: EdgeInsets.fromLTRB(24.w, 18.h, 24.w, 0),
          child: Column(
            children: <Widget>[
              ScrollingTitle(
                text: song?.title ?? 'NA',
                height: 24.h,
                style: TextStyle(
                  fontSize: 19.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                song?.artist ?? 'Unknown Artist',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRow(MusicControllerStateData data) {
    final bool looping = data.hasAbLoop;
    final bool aSet = data.abLoopAMs != null;
    final bool armed = _abLoopArmed && !aSet;

    final String abLabel = looping
        ? 'A–B on'
        : aSet
        ? 'A–B: tap for end'
        : armed
        ? 'A–B: tap for start'
        : 'A–B off';
    final bool abActive = looping || aSet || armed;

    return Padding(
      padding: EdgeInsets.only(top: 18.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            _formatTime(data.position),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          Text(
            ' / ',
            style: TextStyle(
              color: AppColors.disabled,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            _formatTime(data.duration),
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
          SizedBox(width: 10.w),
          Container(width: 1, height: 14.h, color: AppColors.divider),
          SizedBox(width: 10.w),
          InkWell(
            onTap: _onAbChipTap,
            child: Text(
              abLabel,
              style: TextStyle(
                color: abActive ? AppColors.loop : AppColors.textTertiary,
                fontSize: 12.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransportRow() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          IconButton(
            onPressed: () => _musicControllerBloc.add(ToggleShuffle()),
            icon: Icon(
              Icons.shuffle_rounded,
              size: 21.sp,
              color: _musicControllerBloc.stateData.isShuffle
                  ? AppColors.accent
                  : AppColors.textSecondary,
            ),
          ),
          SizedBox(width: 4.w),
          IconButton(
            onPressed: () => _musicControllerBloc.add(PreviousSong()),
            icon: Icon(
              Icons.skip_previous_rounded,
              size: 26.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: 4.w),
          InkWell(
            borderRadius: BorderRadius.circular(35.r),
            onTap: () => _musicControllerBloc.add(PlayPauseToggled()),
            child: Container(
              width: 70.w,
              height: 70.w,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _musicControllerBloc.stateData.isPlaying
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                size: 28.sp,
                color: Colors.black,
              ),
            ),
          ),
          SizedBox(width: 4.w),
          IconButton(
            onPressed: () => _musicControllerBloc.add(NextSong()),
            icon: Icon(
              Icons.skip_next_rounded,
              size: 26.sp,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(width: 4.w),
          IconButton(
            onPressed: () => _musicControllerBloc.add(ChangeRepeatMode()),
            icon: Icon(
              _repeatIcon,
              size: 21.sp,
              color: _musicControllerBloc.stateData.repeatMode == RepeatMode.off
                  ? AppColors.textSecondary
                  : AppColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStatsRow(
    BuildContext context,
    MusicControllerStateData data,
  ) {
    final double pitchSt = ratioToSemitones(data.pitch).round().toDouble();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _StatTile(
              label: 'SPEED',
              value: '${data.speed.toStringAsFixed(2)}×',
              valueColor: AppColors.accent,
              onTap: () => SpeedPitchSheet.show(context, _musicControllerBloc),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _StatTile(
              label: 'PITCH',
              value:
                  '${pitchSt >= 0 ? '+' : ''}${pitchSt.toInt()} st',
              valueColor: AppColors.textPrimary,
              onTap: () => SpeedPitchSheet.show(context, _musicControllerBloc),
            ),
          ),
          SizedBox(width: 10.w),
          InkWell(
            borderRadius: BorderRadius.circular(14.r),
            onTap: () {
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                useSafeArea: true,
                backgroundColor: Colors.transparent,
                builder: (BuildContext sheetContext) =>
                    EqualizerSheet(musicBloc: _musicControllerBloc),
              );
            },
            child: Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 22.sp,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14.r),
      onTap: onTap,
      child: Container(
        height: 64.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
                color: AppColors.textTertiary,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 19.sp,
                fontWeight: FontWeight.w700,
                color: valueColor,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrbitalRing extends StatelessWidget {
  const _OrbitalRing({required this.song, required this.data});

  final SongModel? song;
  final MusicControllerStateData data;

  @override
  Widget build(BuildContext context) {
    final double dur = data.duration > 0 ? data.duration.toDouble() : 1;
    final double posFrac = (data.position / dur).clamp(0.0, 1.0);
    final double? aFrac = data.abLoopAMs == null
        ? null
        : (data.abLoopAMs! / dur).clamp(0.0, 1.0);
    final double? bFrac = data.abLoopBMs == null
        ? null
        : (data.abLoopBMs! / dur).clamp(0.0, 1.0);
    final double ringSize = _ringSize.w;
    final double artSize = ringSize - 92.w;

    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          CustomPaint(
            size: Size(ringSize, ringSize),
            painter: _OrbitalRingsPainter(
              positionFraction: posFrac,
              loopAFraction: aFrac,
              loopBFraction: bFrac,
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(18.r),
            child: QueryArtworkWidget(
              type: ArtworkType.AUDIO,
              id: song?.id ?? 0,
              keepOldArtwork: true,
              artworkFit: BoxFit.cover,
              artworkWidth: artSize,
              artworkHeight: artSize,
              nullArtworkWidget: Container(
                width: artSize,
                height: artSize,
                color: AppColors.surface,
                alignment: Alignment.center,
                child: Icon(
                  Icons.music_note_rounded,
                  size: 44.sp,
                  color: AppColors.iconColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrbitalRingsPainter extends CustomPainter {
  _OrbitalRingsPainter({
    required this.positionFraction,
    required this.loopAFraction,
    required this.loopBFraction,
  });

  final double positionFraction;
  final double? loopAFraction;
  final double? loopBFraction;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double halfSize = size.width / 2;
    final double outerRadius = halfSize * (_ringOuterR / _ringHalf);
    final double innerRadius = halfSize * (_ringInnerR / _ringHalf);
    final double outerStroke = halfSize * (3 / _ringHalf);
    final double innerStroke = halfSize * (6 / _ringHalf);
    const double startAngle = -math.pi / 2;

    canvas.drawCircle(
      center,
      outerRadius,
      Paint()
        ..color = AppColors.divider
        ..style = PaintingStyle.stroke
        ..strokeWidth = outerStroke,
    );

    if (positionFraction > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: outerRadius),
        startAngle,
        2 * math.pi * positionFraction,
        false,
        Paint()
          ..color = AppColors.accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = outerStroke
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawCircle(
      center,
      innerRadius,
      Paint()
        ..color = AppColors.surface
        ..style = PaintingStyle.stroke
        ..strokeWidth = innerStroke,
    );

    final double? a = loopAFraction;
    final double? b = loopBFraction;
    if (a != null && b != null && b > a) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: innerRadius),
        startAngle + 2 * math.pi * a,
        2 * math.pi * (b - a),
        false,
        Paint()
          ..color = AppColors.loop
          ..style = PaintingStyle.stroke
          ..strokeWidth = innerStroke
          ..strokeCap = StrokeCap.round,
      );
    }

    final double markerAngle = startAngle + 2 * math.pi * positionFraction;
    canvas.drawCircle(
      Offset(
        center.dx + outerRadius * math.cos(markerAngle),
        center.dy + outerRadius * math.sin(markerAngle),
      ),
      halfSize * (7.5 / _ringHalf),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _OrbitalRingsPainter oldDelegate) {
    return oldDelegate.positionFraction != positionFraction ||
        oldDelegate.loopAFraction != loopAFraction ||
        oldDelegate.loopBFraction != loopBFraction;
  }
}
