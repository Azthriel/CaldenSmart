// login.dart
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:hugeicons/hugeicons.dart';
import 'welcome.dart';
import '/master.dart';

Future<void> signInWithGoogle() async {
  final GoogleSignIn googleSignIn = GoogleSignIn(
    scopes: [
      'email',
    ],
    // hostedDomain: 'https://caldensmart-dev.auth.sa-east-1.amazoncognito.com',
    // clientId:
    //     '535358063665-kbf4pk5e7kppuo1402q7r2fnk8gjcjg5.apps.googleusercontent.com',
    // serverClientId: 'sa-east-1_IVAQfYQAX',
  );
  try {
    // Inicia sesión con Google
    printLog('Pruebo a iniciar sesión');
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    printLog('Inicie: $googleUser');
    final GoogleSignInAuthentication googleAuth =
        await googleUser!.authentication;

    // Obtén el ID Token de Google
    final idToken = googleAuth.idToken;

    if (idToken != null) {
      // Aquí puedes enviar el idToken a tu backend para validarlo o almacenarlo
      printLog("ID Token: $idToken");
    }

    final res = await Amplify.Auth.signInWithWebUI(
      provider: AuthProvider.google,
      options: const SignInWithWebUIOptions(
        pluginOptions: CognitoSignInWithWebUIPluginOptions(
          isPreferPrivateSession: true,
        ),
      ),
    );

    if (res.isSignedIn) {
      // Usuario autenticado
      printLog("User signed in: ${res.isSignedIn}");
    }
  } catch (e, s) {
    showToast('Error ingresando con Google');
    printLog("Error signing in with Google: $e");
    printLog("Track google $s");
  }
}

/// Widget que construye el formulario de inicio de sesión.
Widget buildLoginForm(WelcomePageState state) {
  // Función de inicio de sesión utilizando Amplify Auth.
  Future<void> signIn(String email, String password) async {
    try {
      SignInResult result = await Amplify.Auth.signIn(
        username: email.trim(),
        password: password.trim(),
      );
      if (result.isSignedIn) {
        printLog('Ingreso exitoso');
        Navigator.pushReplacementNamed(
            state.context.mounted
                ? state.context
                : navigatorKey.currentContext!,
            '/menu');
      }
    } on AuthException catch (e) {
      // Verificamos el mensaje de la excepción para identificar el error
      if (e.message.contains('UserNotFoundException') ||
          e.message.contains('User does not exist')) {
        showToast('No existe una cuenta con ese correo electrónico');
      } else if (e.message.contains('NotAuthorizedException')) {
        showToast('Contraseña incorrecta');
      } else if (e.message.contains('Incorrect username or password')) {
        showToast('Contraseña o Email incorrectos');
      } else {
        showToast('Error de autenticación.');
      }
      printLog('Error iniciando sesión: ${e.message}');
    }
  }

  return Container(
    key: const ValueKey<FormType>(FormType.login),
    padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
    child: Center(
      child: SingleChildScrollView(
        child: state.buildConstrainedCard(
          Form(
            key: state.loginFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Iniciar Sesión',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color3,
                  ),
                ),
                const SizedBox(height: 20),
                // Campo de correo electrónico.
                state.buildTextFormField(
                  controller: state.loginEmailController,
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
                // Campo de contraseña con ícono de ojo animado.
                state.buildTextFormField(
                  controller: state.loginPasswordController,
                  hintText: 'Contraseña',
                  icon: HugeIcons.strokeRoundedSquareLock01,
                  obscureText: state.obscurePassword,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, ingrese su contraseña';
                    }
                    return null;
                  },
                  suffixIcon: GestureDetector(
                    onTap: () {
                      state.togglePasswordVisibility();
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder:
                          (Widget child, Animation<double> animation) {
                        return RotationTransition(
                          turns: child.key == const ValueKey('icon1')
                              ? Tween<double>(begin: 1, end: 0)
                                  .animate(animation)
                              : Tween<double>(begin: 0, end: 1)
                                  .animate(animation),
                          child: child,
                        );
                      },
                      child: state.obscurePassword
                          ? const Icon(
                              Icons.visibility_off,
                              key: ValueKey('icon1'),
                              color: color3,
                            )
                          : const Icon(
                              Icons.visibility,
                              key: ValueKey('icon2'),
                              color: color3,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Botón para recuperar contraseña.
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: () {
                      state.switchForm(FormType.forgotPassword);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: color3,
                    ),
                    child: const Text(
                      '¿Olvidaste tu contraseña?',
                      style: TextStyle(
                        color: color3,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                // Botón para iniciar sesión.
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (state.loginFormKey.currentState!.validate()) {
                        String email = state.loginEmailController.text.trim();
                        String password =
                            state.loginPasswordController.text.trim();
                        signIn(email, password);
                        showToast('Iniciando sesión...');
                      } else {
                        showToast('Por favor, complete todos los campos');
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
                      'Entrar',
                      style: TextStyle(
                        color: color0,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                // // Divisores con "O" en el medio.
                // const Row(
                //   mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                //   children: <Widget>[
                //     Expanded(
                //       child: Divider(
                //         color: color3,
                //         thickness: 1,
                //       ),
                //     ),
                //     SizedBox(width: 10),
                //     Text(
                //       'O',
                //       style: TextStyle(
                //         color: color3,
                //         fontSize: 16,
                //       ),
                //     ),
                //     SizedBox(width: 10),
                //     Expanded(
                //       child: Divider(
                //         color: color3,
                //         thickness: 1,
                //       ),
                //     ),
                //   ],
                // ),
                // const SizedBox(
                //   height: 15,
                // ),
                // // Botón para iniciar sesión con Google.
                // SizedBox(
                //   width: double.infinity,
                //   child: ElevatedButton.icon(
                //     onPressed: () async {
                //       showToast('Iniciando sesión con Google...');
                //       await signInWithGoogle();
                //     },
                //     style: ElevatedButton.styleFrom(
                //       backgroundColor: Colors.white,
                //       padding: const EdgeInsets.symmetric(
                //         horizontal: 20,
                //         vertical: 12,
                //       ),
                //       shape: RoundedRectangleBorder(
                //         borderRadius: BorderRadius.circular(
                //           30.0,
                //         ),
                //         side: const BorderSide(
                //           color: color3,
                //         ),
                //       ),
                //       elevation: 5,
                //     ),
                //     icon: Image.asset(
                //       'assets/google.png',
                //       width: 24,
                //       height: 24,
                //     ),
                //     label: const Text(
                //       'Google',
                //       style: TextStyle(
                //         color: color3,
                //         fontSize: 16,
                //       ),
                //     ),
                //   ),
                // ),
                // const SizedBox(height: 15),
                // Texto para registrarse.
                Center(
                  child: TextButton(
                    onPressed: () {
                      state.switchForm(FormType.register);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: color3,
                    ),
                    child: const Text(
                      '¿No tienes una cuenta?\nRegístrate',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: color3,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
