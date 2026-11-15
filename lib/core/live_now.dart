import 'package:flutter/foundation.dart';

/// How many lives are on right now, from Popcorn's room list. The top bar's
/// red live button shows it on the Popcorn tab.
final ValueNotifier<int> liveNowCount = ValueNotifier<int>(0);
