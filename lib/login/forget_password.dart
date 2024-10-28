import 'package:flutter/material.dart';
import 'package:amplify_flutter/amplify_flutter.dart'; // Importa Amplify si no está importado.
import 'package:hugeicons/hugeicons.dart';
import 'welcome.dart';
import '/master.dart';

Widget buildForgotPasswordForm(WelcomePageState state) {
  // Función para enviar el código de recuperación.
  Future<void> sendPasswordResetCode(String email) async {
    try {
      // Enviamos el código de recuperación sin estar autenticado.
      await Amplify.Auth.resetPassword(username: email.trim());
      ('Código de recuperación enviado al correo');
      state.switchForm(FormType
          .enterCode); // Cambiamos al formulario para ingresar el código.
    } on AuthException catch (e) {
      if (e.message.contains('UserNotFoundException')) {
        ('No existe una cuenta con ese correo electrónico');
      } else {
        ('Error al enviar el código de recuperación: ${e.message}');
      }
      printLog('Error al enviar el código: ${e.message}');
    }
  }

  return Container(
    key: const ValueKey<FormType>(FormType.forgotPassword),
    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
    child: Center(
      child: SingleChildScrollView(
        child: state.buildConstrainedCard(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(HugeIcons.strokeRoundedArrowLeft01,
                        color: color3),
                    onPressed: () {
                      state.switchForm(FormType.login);
                    },
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Recuperación',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: color3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'Ingrese el correo electrónico de su cuenta',
                style: TextStyle(
                  fontSize: 18,
                  color: color3,
                ),
              ),
              const SizedBox(height: 15),
              state.buildTextFormField(
                controller: state.forgotPasswordEmailController,
                hintText: 'Correo electrónico',
                icon: HugeIcons.strokeRoundedMail01,
                obscureText: false,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Por favor, ingrese su correo electrónico';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              const Text(
                'Se le enviará un código de recuperación para su cuenta',
                style: TextStyle(
                  fontSize: 14,
                  color: color3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (state.forgotPasswordEmailController.text
                        .trim()
                        .isEmpty) {
                      ('Por favor, ingrese su correo electrónico');
                    } else {
                      sendPasswordResetCode(
                          state.forgotPasswordEmailController.text.trim());
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: color3,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30.0),
                    ),
                    elevation: 5,
                  ),
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      color: color0,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
          isForgotPassword: true,
        ),
      ),
    ),
  );
}
