/// Estado que expone un ViewModel mientras ejecuta una acción del técnico.
///
/// La vista solo necesita saber tres cosas: si hay algo en curso, si la última
/// acción falló y con qué mensaje, y si terminó bien.
class CommandState {
  const CommandState({this.busy = false, this.error, this.message});

  final bool busy;
  final String? error;
  final String? message;

  bool get hasError => error != null;

  static const idle = CommandState();
  static const working = CommandState(busy: true);
}
