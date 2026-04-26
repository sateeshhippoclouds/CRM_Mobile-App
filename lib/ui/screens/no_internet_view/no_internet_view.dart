import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../constants/app_colors.dart';

class NoInternetView extends StatelessWidget {
  NoInternetView({super.key, this.onRefresh, this.isBtnEnabled = true});

  final RefreshCallback? onRefresh;
  bool isBtnEnabled;

  @override
  Widget build(BuildContext context) {
    return Container(
        color: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/no_internet.jpg',
                  width: MediaQuery.of(context).size.width * 3,
                ),
                Text(
                  'No Network Available',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Palette.primary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(
                  height: 15.h,
                ),
                Text(
                  'Please check your internet\nconnection and try again',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Palette.primary,
                    fontSize: 12.sp,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),

                // (isBtnEnabled == true) ? : SizedBox(height: 1.h,)
              ],
            ),
          ),
        ));
  }
}
