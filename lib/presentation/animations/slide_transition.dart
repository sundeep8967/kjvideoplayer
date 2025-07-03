import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

class CustomSlideTransition {
  static Route<T> createRoute<T extends Object?>(
    Widget page, {
    SlideDirection direction = SlideDirection.fromRight,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionDuration: AppConstants.shortAnimation,
      reverseTransitionDuration: AppConstants.shortAnimation,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        Offset begin;
        
        switch (direction) {
          case SlideDirection.fromRight:
            begin = const Offset(1.0, 0.0);
            break;
          case SlideDirection.fromLeft:
            begin = const Offset(-1.0, 0.0);
            break;
          case SlideDirection.fromTop:
            begin = const Offset(0.0, -1.0);
            break;
          case SlideDirection.fromBottom:
            begin = const Offset(0.0, 1.0);
            break;
        }
        
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;
        
        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );
        
        var offsetAnimation = animation.drive(tween);
        
        return SlideTransition(
          position: offsetAnimation,
          child: child,
        );
      },
    );
  }
}

enum SlideDirection {
  fromRight,
  fromLeft,
  fromTop,
  fromBottom,
}