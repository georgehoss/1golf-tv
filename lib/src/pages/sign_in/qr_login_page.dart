import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../controllers/auth_controller.dart';
import '../../utils/image_index.dart';

/// QR login page for the TV app: shows a QR code the user scans with their
/// phone to authorize the device (see AuthController.startQRLogin).
class QRLoginPage extends StatefulWidget {
  const QRLoginPage({super.key});

  @override
  State<QRLoginPage> createState() => _QRLoginPageState();
}

class _QRLoginPageState extends State<QRLoginPage> {
  late AuthController authController;
  final FocusNode _refreshBtnFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    authController = Get.find<AuthController>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      authController.startQRLogin();
      _refreshBtnFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _refreshBtnFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(color: Color(0xFF041E42)),
          ),
          SizedBox(
            width: Get.width * 0.9,
            height: Get.height * 0.9,
            child: Center(child: Obx(() => _buildContent())),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (authController.isLoading.value &&
        authController.deviceAuth.value == null) {
      return _buildLoadingState();
    }

    if (authController.errorMessage.value.isNotEmpty &&
        authController.deviceAuth.value == null) {
      return _buildErrorState();
    }

    if (authController.deviceAuth.value != null) {
      return _buildQRCodeState();
    }

    return _buildLoadingState();
  }

  Widget _buildLoadingState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(ImageIndex.logo, height: 80),
        const SizedBox(height: 40),
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 20),
        const Text(
          'Preparando código QR...',
          style: TextStyle(color: Colors.white, fontSize: 20),
        ),
      ],
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(ImageIndex.logo, height: 80),
        const SizedBox(height: 40),
        const Icon(Icons.error_outline, color: Colors.red, size: 60),
        const SizedBox(height: 20),
        Text(
          authController.errorMessage.value,
          style: const TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 30),
        _buildRefreshButton(),
      ],
    );
  }

  Widget _buildQRCodeState() {
    final deviceAuth = authController.deviceAuth.value!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 40, right: 20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  const Text(
                    'Inicia sesión con tu teléfono',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildStep('1', 'Abre la cámara de tu teléfono'),
                  const SizedBox(height: 10),
                  _buildStep('2', 'Escanea el código QR'),
                  const SizedBox(height: 10),
                  _buildStep('3', 'Inicia sesión en tu cuenta'),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Código: ',
                          style: TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        Text(
                          deviceAuth.userCode,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Obx(
                    () => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          color: authController.remainingSeconds.value < 60
                              ? Colors.orange
                              : Colors.white70,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'El código expira en: ${authController.formattedRemainingTime}',
                          style: TextStyle(
                            color: authController.remainingSeconds.value < 60
                                ? Colors.orange
                                : Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildRefreshButton(),
                ],
              ),
            ),
          ),
          Column(
            children: [
              Image.asset(ImageIndex.logo, height: 100),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(right: 40),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    QrImageView(
                      data: deviceAuth.verificationUriComplete,
                      version: QrVersions.auto,
                      size: 200,
                      backgroundColor: Colors.white,
                      eyeStyle: const QrEyeStyle(
                        eyeShape: QrEyeShape.square,
                        color: Color(0xFF000354),
                      ),
                      dataModuleStyle: const QrDataModuleStyle(
                        dataModuleShape: QrDataModuleShape.square,
                        color: Color(0xFF000354),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000354),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Escanea para iniciar sesión',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStep(String number, String text) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFFBB03B),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Color(0xFF041E42),
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ],
    );
  }

  Widget _buildRefreshButton() {
    return FocusableActionDetector(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.select): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.enter): const ActivateIntent(),
      },
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (intent) {
            authController.refreshQRCode();
            return null;
          },
        ),
      },
      child: Focus(
        focusNode: _refreshBtnFocus,
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              child: ElevatedButton.icon(
                onPressed: () => authController.refreshQRCode(),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Generar nuevo código'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: hasFocus
                      ? const Color(0xFFFBB03B)
                      : Colors.grey[800],
                  foregroundColor: Color(0xFF041E42),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  textStyle: const TextStyle(fontSize: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(
                      color: hasFocus ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
