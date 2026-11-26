/// 서버에서는 화면이 없으니 알릴 곳도 없다. 서버는 이 메서드를 덮어써 저장에 쓴다.
class ChangeNotifier {
  void notifyListeners() {}
}
