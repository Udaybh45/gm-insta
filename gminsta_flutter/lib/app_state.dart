// Global state for tab management (so videos pause when switching tabs)
import 'package:flutter/material.dart';

final ValueNotifier<int> activeTabNotifier = ValueNotifier<int>(0);
