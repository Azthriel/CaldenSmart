import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../master.dart';
import '../aws/dynamo/dynamo.dart';
import 'package:caldensmart/logger.dart';

class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  QRScannerScreenState createState() => QRScannerScreenState();
}

class QRScannerScreenState extends State<QRScannerScreen> {
  MobileScannerController cameraController = MobileScannerController();
  bool isProcessing = false;

  @override
  void dispose() {
    cameraController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color0,
      appBar: AppBar(
        backgroundColor: color1,
        iconTheme: const IconThemeData(color: color0),
        title: Text(
          'Escanear QR de Equipo',
          style: GoogleFonts.poppins(
            color: color0,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(HugeIcons.strokeRoundedArrowLeft02),
          color: color0,
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Container(
              margin: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color1, width: 3),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: MobileScanner(
                  controller: cameraController,
                  onDetect: _onQRDetected,
                ),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color1,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      HugeIcons.strokeRoundedQrCode,
                      color: color0,
                      size: 40,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Apunta la cámara hacia el código QR',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'El equipo se agregará automáticamente a tus dispositivos',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),
                    ElevatedButton.icon(
                      onPressed: () => _pickImageFromGallery(),
                      icon: const Icon(
                        HugeIcons.strokeRoundedImage02,
                        color: color1,
                        size: 20,
                      ),
                      label: Text(
                        'Seleccionar desde Galería',
                        style: GoogleFonts.poppins(
                          color: color1,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onQRDetected(BarcodeCapture capture) async {
    if (isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? qrData = barcodes.first.rawValue;
    if (qrData == null || qrData.isEmpty) return;

    await _processQRData(qrData);
  }

  Future<void> _showAddDeviceConfirmation(String deviceName, String sharedBy,
      String productCode, String serialNumber) async {
    bool? shouldAdd = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: color1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Agregar Equipo',
            style: GoogleFonts.poppins(
              color: color0,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                HugeIcons.strokeRoundedSmartPhone01,
                color: color0,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                '¿Deseas agregar este equipo a tus dispositivos?',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: color3,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(
                      'Equipo: $deviceName',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Compartido por: $sharedBy',
                      style: GoogleFonts.poppins(
                        color: color0,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancelar',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: color0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Agregar',
                style: GoogleFonts.poppins(
                  color: color1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldAdd == true) {
      await _addDeviceToList(deviceName, productCode, serialNumber, sharedBy);
    }
  }

  Future<void> _addDeviceToList(String deviceName, String productCode,
      String serialNumber, String sharedBy) async {
    try {
      // Agregar a la lista global de dispositivos
      todosLosDispositivos.add(MapEntry('individual', deviceName));

      // Hacer query para obtener datos del dispositivo
      await queryItems(productCode, serialNumber);

      previusConnections.add(deviceName);

      await putPreviusConnections(currentUserEmail, previusConnections);

      _showSuccessDialog(deviceName, sharedBy);
    } catch (e) {
      printLog.e('Error agregando dispositivo: $e');
      _showErrorDialog(
          'Error', 'No se pudo agregar el dispositivo. Inténtalo de nuevo.');
    }
  }

  void _showSuccessDialog(String deviceName, String sharedBy) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: color1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            '¡Éxito!',
            style: GoogleFonts.poppins(
              color: color0,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                HugeIcons.strokeRoundedCheckmarkCircle02,
                color: Colors.green,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                'El equipo "$deviceName" se agregó correctamente a tus dispositivos.',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                'Compartido por: $sharedBy',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar diálogo
                Navigator.of(context).pop(); // Volver a pantalla anterior
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: color0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: Text(
                'Continuar',
                style: GoogleFonts.poppins(
                  color: color1,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: color1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: GoogleFonts.poppins(
              color: color0,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                HugeIcons.strokeRoundedAlert02,
                color: Colors.red,
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: GoogleFonts.poppins(
                  color: color0,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Entendido',
                style: GoogleFonts.poppins(
                  color: color0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);

      if (image != null) {
        // Analizar imagen con mobile_scanner
        final BarcodeCapture? capture =
            await cameraController.analyzeImage(image.path);

        if (capture != null && capture.barcodes.isNotEmpty) {
          final String? qrData = capture.barcodes.first.rawValue;
          if (qrData != null && qrData.isNotEmpty) {
            await _processQRData(qrData);
          } else {
            _showErrorDialog('QR no encontrado',
                'No se encontró un código QR válido en la imagen seleccionada.');
          }
        } else {
          _showErrorDialog('QR no encontrado',
              'No se encontró un código QR válido en la imagen seleccionada.');
        }
      }
    } catch (e) {
      printLog.e('Error al seleccionar imagen: $e');
      _showErrorDialog('Error', 'No se pudo procesar la imagen seleccionada.');
    }
  }

  Future<void> _processQRData(String qrData) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      // Intentar parsear el JSON del QR
      Map<String, dynamic> deviceData = jsonDecode(qrData);

      // Verificar que tenga los campos necesarios
      if (!deviceData.containsKey('deviceName') ||
          !deviceData.containsKey('productCode') ||
          !deviceData.containsKey('serialNumber') ||
          !deviceData.containsKey('sharedBy')) {
        _showErrorDialog(
            'QR inválido', 'Este código QR no corresponde a un equipo válido.');
        return;
      }

      String deviceName = deviceData['deviceName'];
      String productCode = deviceData['productCode'];
      String serialNumber = deviceData['serialNumber'];
      String sharedBy = deviceData['sharedBy'];

      // Verificar que el equipo no sea del usuario actual
      if (sharedBy == currentUserEmail) {
        _showErrorDialog('Error', 'No puedes agregar tu propio equipo.');
        return;
      }

      // Verificar que el equipo no esté ya en la lista
      bool deviceExists =
          todosLosDispositivos.any((entry) => entry.key == deviceName);
      if (deviceExists) {
        _showErrorDialog('Equipo duplicado',
            'Este equipo ya está en tu lista de dispositivos.');
        return;
      }

      // Mostrar confirmación antes de agregar
      await _showAddDeviceConfirmation(
          deviceName, sharedBy, productCode, serialNumber);
    } catch (e) {
      printLog.e('Error procesando QR: $e');
      _showErrorDialog('Error',
          'No se pudo procesar el código QR. Asegúrate de que sea válido.');
    } finally {
      setState(() {
        isProcessing = false;
      });
    }
  }
}
