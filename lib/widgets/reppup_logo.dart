import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReppUpLogo extends StatelessWidget {
  const ReppUpLogo({
    super.key,
    this.height,
    this.width,
  });

  final double? height;
  final double? width;

  static const assetPath = 'assets/images/reppup_logo.svg';

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SvgPicture.asset(
        assetPath,
        height: height,
        width: width,
        fit: BoxFit.contain,
        alignment: Alignment.center,
      ),
    );
  }
}
