# theoremreach_sdk example

An app that opens the reward center and logs every event, on TheoremReach's test apps (iOS 12451, Android 12453). Run it
with `flutter run` from this directory.

- **Open the reward center**, and **Open it at a placement**: the test apps have no placements, so the second opens the
  usual reward center, though its entry carries the placement.
- **Is a survey available?** asks the SDK.
- **Use a light title bar** switches the title bar's colors from the next open.
- **Stop listening for rewards** cancels the `onReward` listener, so a reward waits until **Listen for rewards
  again**.
- **Open the reward center in 5 s**: leave the app within the five seconds, and on Android nothing opens and no event
  comes.
- **Start for … in 5 s**: open the reward center within the five seconds, and the start for the other user comes while
  it's open.

Its iOS app turns view controller based status bar appearance off, as apps made from Flutter's template before 3.13
do, so it shows the plugin setting the status bar over the reward center.
