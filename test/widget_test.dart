// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutterapp7/lib/video_player_screen.dart'; // Assuming main.dart or where CustomVideoPlayer is
import 'package:perfect_volume_control/perfect_volume_control.dart'; // For mocking
import 'package:flutter/services.dart'; // For SystemChrome mock

// Helper function to pump the CustomVideoPlayer widget
Future<void> pumpCustomVideoPlayer(WidgetTester tester, {required String videoPath, required String videoTitle}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold( // Scaffold is needed for MediaQuery, dialogs etc.
        body: CustomVideoPlayer(
          videoPath: videoPath,
          videoTitle: videoTitle,
        ),
      ),
    ),
  );
}

void main() {
  // Mock for PerfectVolumeControl if it uses platform channels directly in init.
  // If it's only method calls, direct mocking might not be needed for these UI tests.
  setUpAll(() {
    // Mock SystemChrome
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall methodCall) async {
        if (methodCall.method == 'SystemChrome.setPreferredOrientations') {
          return null;
        }
        if (methodCall.method == 'SystemChrome.setSystemUIOverlayStyle') {
          return null;
        }
        if (methodCall.method == 'SystemChrome.setEnabledSystemUIMode') {
          return null;
        }
        return null;
      },
    );

    // Mock PerfectVolumeControl if it makes calls during initState that affect tests
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      PerfectVolumeControl.channel, // Use the actual channel name from the plugin
      (MethodCall methodCall) async {
        if (methodCall.method == 'getVolume') {
          return 0.5; // Default volume
        }
        if (methodCall.method == 'setVolume') {
          return null;
        }
        if (methodCall.method == 'hideUI') {
          return null;
        }
        return null;
      },
    );
  });


  testWidgets('1. CustomVideoPlayer pumps successfully', (WidgetTester tester) async {
    await pumpCustomVideoPlayer(tester, videoPath: '/dummy/video.mp4', videoTitle: 'Dummy Video');
    await tester.pumpAndSettle(); // Allow time for VlcPlayerController to initialize (or attempt to)
    expect(find.byType(CustomVideoPlayer), findsOneWidget);
  });

  testWidgets('2. Initial UI Elements are present', (WidgetTester tester) async {
    await pumpCustomVideoPlayer(tester, videoPath: '/dummy/video.mp4', videoTitle: 'Initial UI Test');
    
    // VlcPlayerController initialization is async. We need to pump until it settles.
    // The placeholder (CircularProgressIndicator) should be visible initially.
    expect(find.byType(CircularProgressIndicator), findsOneWidget, reason: "CircularProgressIndicator should be visible before VLC initializes");
    
    // Pump and settle to allow VlcPlayerController to initialize and update notifiers
    await tester.pumpAndSettle(Duration(seconds: 2)); // Give ample time for async init

    // After initialization (mocked or real if platform allows), the player UI should build.
    // Controls are initially hidden, so these specific icons/texts might not be found directly
    // unless we tap the screen first.

    // Check for play icon (it's in the bottom bar, which is initially hidden)
    // So, first tap to show controls
    expect(find.byType(GestureDetector).first, findsOneWidget); // Main gesture detector
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.play_arrow), findsOneWidget, reason: "Play icon should be visible after controls are shown");
    
    // Check for initial time display "00:00" (also in bottom bar)
    expect(find.text('00:00'), findsWidgets, reason: "Initial time display should be 00:00"); // Finds two: current and total

    // Verify top bar elements (e.g., title, back button) are now visible
    expect(find.text('Initial UI Test'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);

    // Verify CircularProgressIndicator is gone if player initialized
    // This depends on how VlcPlayerController behaves in test environment without real video.
    // If it never "initializes" successfully in test, placeholder might remain.
    // For now, we assume it might initialize or at least the UI structure for the player is there.
    // If VlcPlayer widget is present, it means the isInitializedNotifier became true.
    expect(find.byType(VlcPlayer), findsOneWidget, reason: "VlcPlayer widget should be present after initialization attempt");
    expect(find.byType(CircularProgressIndicator), findsNothing, reason: "CircularProgressIndicator should be gone after VlcPlayer is shown");
  });

  testWidgets('3. Play/Pause Toggle', (WidgetTester tester) async {
    await pumpCustomVideoPlayer(tester, videoPath: '/dummy/video.mp4', videoTitle: 'PlayPause Test');
    await tester.pumpAndSettle(Duration(seconds: 2)); // Allow init

    // Tap screen to make controls visible
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    // Initial state should be play_arrow (as autoPlay is false, then listener plays)
    // The listener auto-plays, so it should quickly become 'pause'
    expect(find.byIcon(Icons.pause), findsOneWidget, reason: "Should be pause icon after auto-play from listener");

    // Tap pause button
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pumpAndSettle(); // Allow notifier to update and UI to rebuild
    expect(find.byIcon(Icons.play_arrow), findsOneWidget, reason: "Should change to play icon after tapping pause");

    // Tap play button
    await tester.tap(find.byIcon(Icons.play_arrow));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pause), findsOneWidget, reason: "Should change back to pause icon after tapping play");
  });

  testWidgets('4. Controls Visibility Toggle', (WidgetTester tester) async {
    await pumpCustomVideoPlayer(tester, videoPath: '/dummy/video.mp4', videoTitle: 'ControlsVisibility Test');
    await tester.pumpAndSettle(Duration(seconds: 2));

    // Initially, controls (like title text or play/pause) should not be visible
    expect(find.text('ControlsVisibility Test'), findsNothing);
    expect(find.byIcon(Icons.play_arrow), findsNothing); // Assuming it's not visible due to controls hidden

    // Tap screen to make controls visible
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.text('ControlsVisibility Test'), findsOneWidget, reason: "Title should be visible after first tap");
    // Assuming auto-play by listener, it should be pause icon
    expect(find.byIcon(Icons.pause), findsOneWidget, reason: "Pause icon should be visible after first tap");

    // Tap screen again to hide controls
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();

    expect(find.text('ControlsVisibility Test'), findsNothing, reason: "Title should be hidden after second tap");
    expect(find.byIcon(Icons.pause), findsNothing, reason: "Pause icon should be hidden after second tap");
  });

 testWidgets('5. Lock Screen Toggle', (WidgetTester tester) async {
    await pumpCustomVideoPlayer(tester, videoPath: '/dummy/video.mp4', videoTitle: 'LockScreen Test');
    await tester.pumpAndSettle(Duration(seconds: 2)); // Allow init

    // 1. Make controls visible
    await tester.tap(find.byType(GestureDetector).first);
    await tester.pumpAndSettle();
    expect(find.text('LockScreen Test'), findsOneWidget, reason: "Controls should be visible");

    // 2. Find and tap the lock_open button (it's in the bottom bar)
    expect(find.byIcon(Icons.lock_open), findsOneWidget);
    await tester.tap(find.byIcon(Icons.lock_open));
    await tester.pumpAndSettle();

    // 3. Verify controls (top/bottom bars) hide
    expect(find.text('LockScreen Test'), findsNothing, reason: "Title (top bar) should hide after locking");
    expect(find.byIcon(Icons.pause), findsNothing, reason: "Pause icon (bottom bar) should hide after locking");
    // _isLocked is true. The lock button itself (Icons.lock_open or Icons.lock) is not yet visible.
    // _lockButtonVisible is false.

    // 4. Simulate a tap on the screen. Main controls remain hidden, but single lock icon appears.
    await tester.tap(find.byType(GestureDetector).first); // Tap anywhere on the screen
    await tester.pumpAndSettle();
    
    expect(find.text('LockScreen Test'), findsNothing, reason: "Title should still be hidden when locked and tapped");
    expect(find.byIcon(Icons.lock), findsOneWidget, reason: "Lock icon (locked state) should appear after tapping screen while locked");

    // 5. Tap the visible Icons.lock icon to unlock
    await tester.tap(find.byIcon(Icons.lock));
    await tester.pumpAndSettle();

    // Verify controls become visible again
    expect(find.text('LockScreen Test'), findsOneWidget, reason: "Title should reappear after unlocking");
    expect(find.byIcon(Icons.pause), findsOneWidget, reason: "Pause icon should reappear after unlocking");
    expect(find.byIcon(Icons.lock_open), findsOneWidget, reason: "Open lock icon should be back in the controls");
    expect(find.byIcon(Icons.lock), findsNothing, reason: "Closed lock icon should be gone after unlocking");
  });
}
