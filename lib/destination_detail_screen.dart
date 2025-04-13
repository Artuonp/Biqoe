import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'reservation_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class DestinationDetailScreen extends StatefulWidget {
  final Map<String, dynamic> destino;
  final String userId;

  const DestinationDetailScreen({
    super.key,
    required this.destino,
    required this.userId,
  });

  @override
  DestinationDetailScreenState createState() => DestinationDetailScreenState();
}

class DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  List<Map<String, dynamic>> selectedPackages = [];

  @override
  void initState() {
    super.initState();
    selectedPackages = [];
  }

  void _togglePackageSelection(Map<String, dynamic> paquete) {
    setState(() {
      if (selectedPackages.contains(paquete)) {
        selectedPackages.remove(paquete);
      } else {
        selectedPackages.add(paquete);
      }
    });
  }

  void _openLink(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'No se pudo abrir el enlace: $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    final images = widget.destino['imagen'] is List
        ? (widget.destino['imagen'] as List<dynamic>).cast<String>()
        : [];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 300,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  if (images.isNotEmpty)
                    PageView.builder(
                      controller: _pageController,
                      itemCount: images.length,
                      onPageChanged: (index) =>
                          setState(() => _currentPage = index),
                      itemBuilder: (context, index) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: images[index],
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.grey[200],
                              child: const Center(),
                            ),
                            errorWidget: (context, url, error) =>
                                const Icon(Icons.error),
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Center(
                          child: Text('Sin imágenes',
                              style: TextStyle(fontFamily: 'Poppins'))),
                    ),
                  if (images.length > 1)
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(images.length, (index) {
                          return Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == index
                                  ? Colors.white
                                  : Colors.white.withOpacity(0.5),
                            ),
                          );
                        }),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.destino['nombre'],
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Poppins',
                              color: Color.fromRGBO(17, 48, 73, 1))),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: Color.fromARGB(255, 17, 48, 73)),
                          const SizedBox(width: 4),
                          Text(
                              '${widget.destino['ubicacion']}${widget.destino['lugar'] != null ? ', ${widget.destino['lugar']}' : ''}',
                              style: const TextStyle(
                                  color: Colors.grey, fontFamily: 'Poppins')),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openLink(widget.destino['coordenadas']),
                  child: SizedBox(
                    height: 35,
                    width: 80,
                    child: Image.asset('assets/images/Google maps logo.png',
                        fit: BoxFit.contain),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (widget.destino['paquetes'] != null &&
                widget.destino['paquetes'].isNotEmpty) ...[
              const Text('Paquetes disponibles',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Poppins',
                      color: Color.fromRGBO(17, 48, 73, 1))),
              const SizedBox(height: 8),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 2.2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: widget.destino['paquetes'].length,
                itemBuilder: (context, index) {
                  final paquete =
                      widget.destino['paquetes'][index] as Map<String, dynamic>;
                  final isSelected = selectedPackages.contains(paquete);

                  return GestureDetector(
                    onTap: () => _togglePackageSelection(paquete),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color.fromRGBO(17, 48, 73, 1)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Colors.white
                              : const Color.fromRGBO(17, 48, 73, 1),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        children: [
                          if (isSelected)
                            const Positioned(
                              top: 4,
                              right: 4,
                              child: Icon(Icons.check_circle,
                                  color: Colors.white, size: 20),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Paquete ${paquete['numero'] ?? index + 1}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color.fromRGBO(17, 48, 73, 1),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '\$${(paquete['precio'] ?? 0).toStringAsFixed(2)}',
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : const Color.fromRGBO(17, 48, 73, 1),
                                    fontSize: 16,
                                    fontFamily: 'Poppins',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              if (selectedPackages.isNotEmpty) ...[
                const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Paquetes seleccionados (${selectedPackages.length}):',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Poppins',
                            color: Color.fromRGBO(17, 48, 73, 1)),
                      ),
                      const SizedBox(height: 8),
                      ...selectedPackages.map((paquete) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Paquete ${paquete['numero']}',
                                    style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontWeight: FontWeight.bold,
                                        color: Color.fromRGBO(17, 48, 73, 1))),
                                if (paquete['miniDescripcion'] != null &&
                                    paquete['miniDescripcion'].isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 0.0),
                                    child: Text(
                                      '-${paquete['miniDescripcion']}-',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontFamily: 'Poppins',
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            subtitle: MarkdownBody(
                              data: paquete['descripcion'] ?? 'Sin descripción',
                              styleSheet: MarkdownStyleSheet(
                                p: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    color: Color.fromRGBO(17, 48, 73,
                                        1) // Color para la descripción principal
                                    ),
                                strong: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color.fromRGBO(17, 48, 73, 1)),
                                listBullet: const TextStyle(
                                    fontFamily: 'Poppins',
                                    color: Color.fromRGBO(17, 48, 73, 1)),
                              ),
                            ),
                            trailing: Text(
                              '\$${(paquete['precio'] ?? 0).toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontFamily: 'Poppins',
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromRGBO(17, 48, 73, 1)),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
              Center(
                child: ElevatedButton(
                  onPressed: selectedPackages.isNotEmpty
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ReservationScreen(
                                userId: widget.userId,
                                selectedPackages: selectedPackages,
                                planName: widget.destino['nombre'],
                                location: widget.destino['ubicacion'],
                                supplier: widget.destino['supplier'],
                              ),
                            ),
                          )
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: selectedPackages.isNotEmpty
                        ? const Color.fromRGBO(17, 48, 73, 1)
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 15),
                  ),
                  child: Text(
                    'Continuar con ${selectedPackages.length} paquete(s)',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontFamily: 'Poppins'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      backgroundColor: const Color.fromARGB(255, 243, 247, 254),
    );
  }
}
