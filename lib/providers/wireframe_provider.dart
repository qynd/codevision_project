import 'package:flutter/material.dart';

class WireframeProvider extends ChangeNotifier {
  bool _isWireframe = false;

  bool get isWireframe => _isWireframe;

  void toggleWireframe() {
    _isWireframe = !_isWireframe;
    notifyListeners();
  }
}
