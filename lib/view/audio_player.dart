import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:marquee/marquee.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../core/bloc/music_controller_bloc.dart/music_controller_bloc.dart';
import '../core/theme/app_colors.dart';

class MusicPlayerPage extends StatefulWidget {
  const MusicPlayerPage({super.key, required this.index});

  final int index;

  @override
  State<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends State<MusicPlayerPage>
    with SingleTickerProviderStateMixin {
  late MusicControllerBloc _musicControllerBloc;
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _musicControllerBloc = BlocProvider.of<MusicControllerBloc>(context);
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  String _formatTime(int ms) {
    final int sec = ms ~/ 1000;
    final String m = (sec ~/ 60).toString().padLeft(2, '0');
    final String s = (sec % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MusicControllerBloc, MusicControllerState>(
      listener: (BuildContext context, MusicControllerState state) {
        if (_musicControllerBloc.stateData.isPlaying) {
          _rotationController.repeat();
        } else {
          _rotationController.stop();
        }
      },
      child: BlocBuilder<MusicControllerBloc, MusicControllerState>(
        bloc: _musicControllerBloc,
        builder: (BuildContext context, MusicControllerState state) {
          return Scaffold(
            backgroundColor: AppColors.transparent,
            body: Stack(
              children: <Widget>[
                Positioned.fill(
                  child: QueryArtworkWidget(
                    type: ArtworkType.AUDIO,
                    id: _musicControllerBloc.stateData.song?.id ?? 0,
                    keepOldArtwork: true,
                    nullArtworkWidget: Container(color: AppColors.blackBg),
                  ),
                ),
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 100.w, sigmaY: 100.w),
                    child: Container(color: Colors.black54),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          border: Border.all(
                            color: AppColors.grey5,
                            width: 6.w,
                          ),
                          borderRadius: BorderRadius.circular(200.r),
                          gradient: const SweepGradient(
                            colors: <Color>[
                              AppColors.grey1,
                              Colors.black,
                              AppColors.grey1,
                              Colors.black,
                              AppColors.grey1,
                            ],
                          ),
                        ),
                        padding: EdgeInsets.all(0.1.sw),
                        child: RotationTransition(
                          turns: _rotationController,
                          child: ClipOval(
                            child: QueryArtworkWidget(
                              type: ArtworkType.AUDIO,
                              id: _musicControllerBloc.stateData.song?.id ?? 0,
                              keepOldArtwork: true,
                              artworkHeight: 0.5.sw,
                              artworkWidth: 0.5.sw,
                              nullArtworkWidget: Container(
                                height: 0.5.sw,
                                width: 0.5.sw,
                                color: AppColors.grey3,
                                alignment: Alignment.center,
                                child: Icon(
                                  Icons.music_note,
                                  size: 110.sp,
                                  color: AppColors.grey4,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Speed: ${_musicControllerBloc.stateData.speed.toStringAsFixed(2)}x',
                      ),
                      Slider(
                        min: 0.7,
                        max: 1.5,
                        value: _musicControllerBloc.stateData.speed,
                        onChanged: (double value) {
                          _musicControllerBloc.add(SpeedChanged(value));
                        },
                        thumbColor: AppColors.lightBlue,
                        activeColor: AppColors.lightBlue,
                        inactiveColor: AppColors.grey2,
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Pitch: ${_musicControllerBloc.stateData.pitch.toStringAsFixed(2)}x',
                      ),
                      Slider(
                        min: 0.5,
                        max: 2.0,
                        value: _musicControllerBloc.stateData.pitch,
                        onChanged: (double value) {
                          _musicControllerBloc.add(PitchChanged(value));
                        },
                        thumbColor: AppColors.lightBlue,
                        activeColor: AppColors.lightBlue,
                        inactiveColor: AppColors.grey2,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        '${_formatTime(_musicControllerBloc.stateData.position)} / ${_formatTime(_musicControllerBloc.stateData.duration)}',
                        style: const TextStyle(fontSize: 18),
                      ),
                      Slider(
                        max: _musicControllerBloc.stateData.duration
                            .toDouble()
                            .clamp(1, double.infinity),
                        value: _musicControllerBloc.stateData.position
                            .toDouble()
                            .clamp(
                              0,
                              _musicControllerBloc.stateData.duration
                                  .toDouble(),
                            ),
                        onChanged: (double value) {
                          _musicControllerBloc.add(SeekTo(value.toInt()));
                        },
                        thumbColor: AppColors.lightBlue,
                        activeColor: AppColors.lightBlue,
                        inactiveColor: AppColors.grey2,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        spacing: 20.w,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          ElevatedButton(
                            onPressed: () {
                              _musicControllerBloc.add(PreviousSong());
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 0,
                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                              backgroundColor: AppColors.transparent,
                            ),
                            child: Icon(
                              Icons.skip_previous,
                              size: 28.sp,
                              color: Colors.white,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _musicControllerBloc.add(PlayPauseToggled());
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 0,

                              shape: CircleBorder(
                                side: BorderSide(
                                  color: AppColors.white,
                                  width: 2.w,
                                ),
                              ),
                              padding: const EdgeInsets.all(16),
                              backgroundColor: AppColors.transparent,
                            ),
                            child: Icon(
                              _musicControllerBloc.stateData.isPlaying
                                  ? Icons.pause
                                  : Icons.play_arrow,
                              size: 32.sp,
                              color: Colors.white,
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              _musicControllerBloc.add(NextSong());
                            },
                            style: ElevatedButton.styleFrom(
                              elevation: 0,

                              shape: const CircleBorder(),
                              padding: const EdgeInsets.all(16),
                              backgroundColor: AppColors.transparent,
                            ),
                            child: Icon(
                              Icons.skip_next,
                              size: 28.sp,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  alignment: Alignment.topCenter,
                  padding: EdgeInsets.only(
                    top: 0.05.sh,
                    left: 16.w,
                    right: 16.w,
                  ),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        onPressed: () {
                          context.pop();
                        },
                        icon: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.white,
                          size: 24.sp,
                        ),
                      ),
                      Flexible(
                        child: SizedBox(
                          height: 24.h,
                          child: Marquee(
                            text:
                                _musicControllerBloc.stateData.song?.title ??
                                'NA',
                            velocity: 40.0,
                            startAfter: const Duration(seconds: 2),
                            startPadding: 40.w,
                            pauseAfterRound: const Duration(seconds: 1),
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: const <Shadow>[
                                Shadow(
                                  blurRadius: 8,
                                  color: Colors.black87,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
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
}
