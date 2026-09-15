import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skeletonizer/skeletonizer.dart';

class SongListSkeleton extends StatelessWidget {
  const SongListSkeleton({super.key, this.itemCount = 10});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        itemCount: itemCount,
        itemBuilder: (BuildContext context, int index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: ListTile(
              contentPadding: EdgeInsets.only(left: 16.w, right: 4.w),
              visualDensity: VisualDensity.compact,
              leading: Bone.square(size: 46.w, uniRadius: 8.r),
              title: Bone.text(width: 160.w),
              subtitle: Bone.text(width: 100.w),
              trailing: const Bone.icon(),
            ),
          );
        },
      ),
    );
  }
}
