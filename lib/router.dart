// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sigma/analysis/face_review.dart';
import 'package:sigma/capture/capture.dart';
import 'package:sigma/ephemeral/post_capture.dart';
import 'package:sigma/inference/face_mesh.dart';
import 'package:sigma/ephemeral/disclaimer.dart';

/// Author: Ian Wilkey and Barney Jin
final class Results {
  final FaceMesh mesh;
  final Future<String> aifut;
  String? full;
  Results({
    required this.mesh,
    required this.aifut,
    this.full
  });
}

final GoRouter SIGMA_ROUTER = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) => sheetPage(
        state: state,
        from: SwipeFrom.left,
        child: WelcomeScreen(nextRouteName: "/capture")
      ),
    ),
    GoRoute(
      path: '/capture',
      pageBuilder: (context, state) => sheetPage(
        state: state,
        from: SwipeFrom.right,
        child: FaceCaptureState(
          onCapturePressed: (final FaceMesh mesh) {
            final Results res = Results(mesh: mesh, aifut: openAiResultsFuture(
              mesh: mesh
            ));
            context.go(
              '/processing',
              extra: res,
            );
          },
        ),
      ),
    ),
    GoRoute(
      path: '/processing',
      pageBuilder: (context, state) {
        final Results res = state.extra! as Results;
        return sheetPage(
          from: SwipeFrom.right,
          state: state,
          child: ProcessingResultsScreen(
            mesh: res.mesh,
            resultsFuture: res.aifut,
            onSeeFullResults: (text) {
              res.full = text;
              context.go('/review', extra: res);
            },
          ),
        );
      },
    ),
    GoRoute(
      path: '/review',
      pageBuilder: (context, state) {
        final Results res = state.extra! as Results;
        return sheetPage(
          from: SwipeFrom.right,
          state: state,
          child: FaceReviewState(
            mesh: res.mesh, 
            aiResponse: res.full!,
            onDone: () {
              context.go('/');
            },
          ),
        );
      },
    ),
  ],
);

enum SwipeFrom { left, right }

CustomTransitionPage<void> sheetPage({
  required GoRouterState state,
  required Widget child,
  SwipeFrom from = SwipeFrom.right,
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    opaque: true,
    barrierDismissible: false,
    transitionDuration: const Duration(milliseconds: 420),
    reverseTransitionDuration: const Duration(milliseconds: 360),
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final CurvedAnimation primary = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final double dir = (from == SwipeFrom.right) ? 1.0 : -1.0;
      final Animation<Offset> inSlide = Tween<Offset>(
        begin: Offset(dir, 0),
        end: Offset.zero,
      ).animate(primary);
      final Animation<Offset> outSlide = Tween<Offset>(
        begin: Offset.zero,
        end: Offset(-0.18 * dir, 0),
      ).animate(primary);
      final Animation<double> shadow = Tween<double>(
        begin: 0.0,
        end: 0.22,
      ).animate(primary);
      return Stack(
        fit: StackFit.expand,
        children: [
          SlideTransition(
            position: outSlide,
            child: const ColoredBox(color: Colors.black),
          ),
          SlideTransition(
            position: inSlide,
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                IgnorePointer(
                  child: AnimatedBuilder(
                    animation: shadow,
                    builder: (context, _) {
                      return Align(
                        alignment:
                            (from == SwipeFrom.right) ? Alignment.centerLeft : Alignment.centerRight,
                        child: Container(
                          width: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: (from == SwipeFrom.right)
                                  ? Alignment.centerLeft
                                  : Alignment.centerRight,
                              end: (from == SwipeFrom.right)
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              colors: [
                                Colors.black.withOpacity(shadow.value),
                                Colors.black.withOpacity(0.0),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
