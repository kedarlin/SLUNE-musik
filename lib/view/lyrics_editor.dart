import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../bloc/lyrics/lyrics_bloc.dart';
import '../bloc/music_controller/music_controller_bloc.dart';
import '../core/theme/app_colors.dart';
import '../models/lyrics.dart';

class LyricsEditorPage extends StatefulWidget {
  const LyricsEditorPage({
    required this.song,
    required this.initial,
    required this.lyricsBloc,
    required this.musicBloc,
    super.key,
  });

  final SongModel song;
  final Lyrics? initial;
  final LyricsBloc lyricsBloc;
  final MusicControllerBloc musicBloc;

  @override
  State<LyricsEditorPage> createState() => _LyricsEditorPageState();
}

class _EditableLine {
  _EditableLine(this.time, String text)
    : controller = TextEditingController(text: text);
  Duration time;
  final TextEditingController controller;
}

class _LyricsEditorPageState extends State<LyricsEditorPage> {
  late bool _timed;
  final List<_EditableLine> _lines = <_EditableLine>[];
  final TextEditingController _plainController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final Lyrics? initial = widget.initial;
    _timed = initial == null || initial.synced;

    if (initial != null && initial.synced) {
      for (final LyricLine line in initial.lines) {
        _lines.add(_EditableLine(line.time, line.text));
      }
    } else if (initial != null && !initial.synced) {
      _plainController.text = initial.plainText ?? '';
    }
    if (_lines.isEmpty && _timed) {
      _lines.add(_EditableLine(Duration.zero, ''));
    }
  }

  @override
  void dispose() {
    for (final _EditableLine line in _lines) {
      line.controller.dispose();
    }
    _plainController.dispose();
    super.dispose();
  }

  Duration get _playbackPosition =>
      Duration(milliseconds: widget.musicBloc.stateData.position);

  String _fmt(Duration d) {
    final int m = d.inMinutes;
    final int s = d.inSeconds % 60;
    final int cs = (d.inMilliseconds % 1000) ~/ 10;
    return '$m:${s.toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  void _addLine() {
    setState(() {
      _lines.add(_EditableLine(_playbackPosition, ''));
    });
  }

  void _removeLine(int index) {
    setState(() {
      _lines.removeAt(index).controller.dispose();
    });
  }

  Future<void> _pasteBulk() async {
    final TextEditingController input = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        backgroundColor: AppColors.surfaceHigh,
        title: Text(
          'Paste lyrics',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 16.sp),
        ),
        content: TextField(
          controller: input,
          maxLines: 10,
          minLines: 5,
          style: TextStyle(color: AppColors.textPrimary, fontSize: 14.sp),
          decoration: const InputDecoration(hintText: 'One line per row…'),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (ok ?? false) {
      final List<String> rows = input.text
          .split('\n')
          .map((String e) => e.trim())
          .where((String e) => e.isNotEmpty)
          .toList();
      setState(() {
        for (final String row in rows) {
          _lines.add(_EditableLine(Duration.zero, row));
        }
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => input.dispose());
  }

  void _save() {
    final Lyrics lyrics;
    if (_timed) {
      final List<LyricLine> lines = _lines
          .where((_EditableLine l) => l.controller.text.trim().isNotEmpty)
          .map(
            (_EditableLine l) =>
                LyricLine(time: l.time, text: l.controller.text.trim()),
          )
          .toList();
      if (lines.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      lyrics = Lyrics.synced(lines, LyricsSource.edited);
    } else {
      final String plain = _plainController.text.trim();
      if (plain.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      lyrics = Lyrics.plain(plain, LyricsSource.edited);
    }
    widget.lyricsBloc.add(LyricsSaveRequested(widget.song, lyrics));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(
          'Edit lyrics',
          style: TextStyle(color: AppColors.textPrimary, fontSize: 17.sp),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _save,
            child: Text(
              'Save',
              style: TextStyle(color: AppColors.accent, fontSize: 15.sp),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12.w),
            child: Row(
              children: <Widget>[
                SegmentedButton<bool>(
                  segments: const <ButtonSegment<bool>>[
                    ButtonSegment<bool>(value: true, label: Text('Timed')),
                    ButtonSegment<bool>(value: false, label: Text('Plain')),
                  ],
                  selected: <bool>{_timed},
                  onSelectionChanged: (Set<bool> s) =>
                      setState(() => _timed = s.first),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _pasteBulk,
                  icon: Icon(Icons.content_paste_rounded, size: 16.sp),
                  label: const Text('Paste'),
                ),
              ],
            ),
          ),
          Expanded(child: _timed ? _buildTimedList() : _buildPlain()),
        ],
      ),
      floatingActionButton: _timed
          ? FloatingActionButton.small(
              backgroundColor: AppColors.accent,
              onPressed: _addLine,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildPlain() {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: TextField(
        controller: _plainController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15.sp,
          height: 1.5,
        ),
        decoration: const InputDecoration(
          hintText: 'Lyrics…',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildTimedList() {
    return ReorderableListView.builder(
      padding: EdgeInsets.fromLTRB(12.w, 4.h, 12.w, 88.h),
      itemCount: _lines.length,
      onReorder: (int oldIndex, int newIndex) {
        setState(() {
          final int target = newIndex > oldIndex ? newIndex - 1 : newIndex;
          _lines.insert(target, _lines.removeAt(oldIndex));
        });
      },
      itemBuilder: (BuildContext context, int index) {
        final _EditableLine line = _lines[index];
        return Padding(
          key: ValueKey<_EditableLine>(line),
          padding: EdgeInsets.symmetric(vertical: 4.h),
          child: Row(
            children: <Widget>[
              GestureDetector(
                onTap: () => setState(() => line.time = _playbackPosition),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    _fmt(line.time),
                    style: TextStyle(
                      color: AppColors.accent,
                      fontSize: 12.sp,
                      fontFeatures: const <FontFeature>[
                        FontFeature.tabularFigures(),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: TextField(
                  controller: line.controller,
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14.sp,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: UnderlineInputBorder(),
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => _removeLine(index),
                icon: Icon(
                  Icons.close_rounded,
                  size: 18.sp,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
