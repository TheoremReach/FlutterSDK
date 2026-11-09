#!/usr/bin/env bash
# A fresh app from the running Flutter's template, beside the package's checkout in package/, with the package as a
# path dependency and a main.dart that calls it.
set -euo pipefail

flutter create --org com.theoremreach --platforms=android,ios floor_app
cd floor_app
flutter pub add 'theoremreach_sdk:{"path":"../package"}'

cat > lib/main.dart <<'DART'
import 'package:flutter/material.dart';
import 'package:theoremreach_sdk/theoremreach_sdk.dart';

void main() {
  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('TheoremReach floor app')))));
  TheoremReach.onReward.listen((int quantity) {});
  TheoremReach.initialize(apiKey: 'f4bfc509292953a3cf4274038763', userId: 'FLUTTER_FLOOR_APP_USER')
      .then((_) => TheoremReach.showRewardCenter(placementId: 'placement'));
}
DART

rm -f test/widget_test.dart
