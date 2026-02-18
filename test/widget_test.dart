// This is a basic Flutter widget test.
import 'package:flutter_test/flutter_test.dart';
import 'package:biqoe/main.dart';

void main() {
  testWidgets('App start smoke test', (WidgetTester tester) async {
    // CORRECCIÓN: Quitamos el parámetro 'destinations' que ya no existe en MyApp.
    // Nota: Como tu app usa Firebase, este test básico fallará si intentas correrlo
    // sin configurar Mocks de Firebase, pero esto elimina el error rojo del editor.

    await tester.pumpWidget(const MyApp());
  });
}
