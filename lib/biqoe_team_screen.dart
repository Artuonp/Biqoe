import 'package:flutter/material.dart';
import 'verify_screen.dart';
import 'add_destination_screen.dart';
import 'modify_destination_screen.dart';
import 'delete_destination_screen.dart';
import 'tasa_screen.dart';

class BiqoeTeamScreen extends StatelessWidget {
  final String userId; // Agregamos el parámetro userId

  const BiqoeTeamScreen(
      {super.key, required this.userId}); // Constructor actualizado

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color.fromARGB(255, 243, 248, 255),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Primer botón - Verificar destinos
              ElevatedButton(
                onPressed: () {
                  // Navegar a la pantalla "Verificar destinos"
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => VerifyScreen(userId: userId)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle,
                        color: Color.fromRGBO(17, 48, 73, 1)),
                    SizedBox(width: 8),
                    Text(
                      'Verificar destinos',
                      style: TextStyle(
                          fontSize: 16, color: Color.fromRGBO(17, 48, 73, 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16), // Espacio entre botones

              // Segundo botón - Agregar destinos
              ElevatedButton(
                onPressed: () {
                  // Navegar a la pantalla "Agregar destinos"
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AddScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_circle,
                        color: Color.fromRGBO(17, 48, 73, 1)),
                    SizedBox(width: 8),
                    Text(
                      'Agregar destinos',
                      style: TextStyle(
                          fontSize: 16, color: Color.fromRGBO(17, 48, 73, 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16), // Espacio entre botones

              // Tercer botón - Modificar destinos
              ElevatedButton(
                onPressed: () {
                  // Navegar a la pantalla "Modificar destinos"
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const ModifyDestinationScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.edit, color: Color.fromRGBO(17, 48, 73, 1)),
                    SizedBox(width: 8),
                    Text(
                      'Modificar destinos',
                      style: TextStyle(
                          fontSize: 16, color: Color.fromRGBO(17, 48, 73, 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16), // Espacio entre botones

              // Cuarto botón - Eliminar destinos
              ElevatedButton(
                onPressed: () {
                  // Navegar a la pantalla "Eliminar destinos"
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const DeleteDestinationScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.delete, color: Color.fromRGBO(17, 48, 73, 1)),
                    SizedBox(width: 8),
                    Text(
                      'Eliminar destinos',
                      style: TextStyle(
                          fontSize: 16, color: Color.fromRGBO(17, 48, 73, 1)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16), // Espacio entre botones

              // Quinto botón - Tasa
              ElevatedButton(
                onPressed: () {
                  // Navegar a la pantalla "Tasa"
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TasaScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.monetization_on,
                        color: Color.fromRGBO(17, 48, 73, 1)),
                    SizedBox(width: 8),
                    Text(
                      'Tasa',
                      style: TextStyle(
                          fontSize: 16, color: Color.fromRGBO(17, 48, 73, 1)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color.fromARGB(255, 243, 248, 255));
  }
}
