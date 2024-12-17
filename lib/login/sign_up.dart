import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'welcome.dart';
import 'package:caldensmart/master.dart';

/// Widget que construye el formulario de registro.
Widget buildRegisterForm(WelcomePageState state) {
  return Container(
    key: const ValueKey<FormType>(FormType.register),
    padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 20.0),
    child: Center(
      child: SingleChildScrollView(
        child: state.buildConstrainedCard(
          Form(
            key: state.registerFormKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Regístrate',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color3,
                  ),
                ),
                const SizedBox(height: 15),
                state.buildTextFormField(
                  controller: state.registerEmailController,
                  hintText: 'Correo electrónico',
                  icon: HugeIcons.strokeRoundedMail01,
                  obscureText: false,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, ingrese su correo';
                    }
                    final emailRegex = RegExp(
                        r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
                    if (!emailRegex.hasMatch(value)) {
                      return 'Ingrese un correo electrónico válido';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                state.buildTextFormField(
                  controller: state.registerPasswordController,
                  hintText: 'Contraseña',
                  icon: HugeIcons.strokeRoundedSquareLock01,
                  obscureText: state.obscurePassword,
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
                          ? const Icon(Icons.visibility_off,
                              key: ValueKey('icon1'), color: color3)
                          : const Icon(Icons.visibility,
                              key: ValueKey('icon2'), color: color3),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, ingrese su contraseña';
                    }
                    if (value.trim().length < 8) {
                      return 'La contraseña debe tener\nal menos 8 caracteres';
                    }
                    if (!RegExp(r'\d').hasMatch(value.trim())) {
                      return 'La contraseña debe tener\nal menos 1 número';
                    }
                    if (!RegExp(r'[A-Z]').hasMatch(value.trim())) {
                      return 'La contraseña debe tener\nal menos 1 mayúscula';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                state.buildTextFormField(
                  controller: state.registerConfirmPasswordController,
                  hintText: 'Confirmar contraseña',
                  icon: HugeIcons.strokeRoundedSquareLock01,
                  obscureText: state
                      .obscurePassword, // Añadimos visibilidad de la contraseña
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
                          ? const Icon(Icons.visibility_off,
                              key: ValueKey('icon1'), color: color3)
                          : const Icon(Icons.visibility,
                              key: ValueKey('icon2'), color: color3),
                    ),
                  ),

                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, confirme su contraseña';
                    }
                    if (value.trim() !=
                        state.registerPasswordController.text.trim()) {
                      return 'Las contraseñas no coinciden';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Checkbox(
                      value: state.acceptTerms,
                      onChanged: (bool? value) {
                        state.updateAcceptTerms(value ?? false);
                      },
                      activeColor: color3,
                      checkColor: color0,
                    ),
                    Expanded(
                        child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        RichText(
                          text: TextSpan(
                            text: 'Acepto los ',
                            style: const TextStyle(color: color3),
                            children: [
                              TextSpan(
                                text: 'términos de uso',
                                style: const TextStyle(
                                  color: color3,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    state.launchTermsURL();
                                  },
                              ),
                              const TextSpan(
                                text: ' y ',
                                style: TextStyle(color: color3),
                              ),
                              TextSpan(
                                text: 'políticas de privacidad',
                                style: const TextStyle(
                                  color: color3,
                                  decoration: TextDecoration.underline,
                                ),
                                recognizer: TapGestureRecognizer()
                                  ..onTap = () {
                                    state.launchPrivacyURL();
                                  },
                              ),
                            ],
                          ),
                        ),
                      ],
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      if (state.registerFormKey.currentState!.validate()) {
                        if (!state.acceptTerms) {
                          showToast('Debe aceptar los términos y condiciones');
                          return;
                        }
                        state.signUpUser(
                          state.registerEmailController.text.trim(),
                          state.registerPasswordController.text.trim(),
                        );
                      } else {
                        showToast(
                            'Por favor, complete todos los campos correctamente');
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
                      'Registrarse',
                      style: TextStyle(color: color0, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: <Widget>[
                    Expanded(
                      child: Divider(color: color3, thickness: 1),
                    ),
                    SizedBox(width: 10),
                    Text('O', style: TextStyle(color: color3, fontSize: 16)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Divider(color: color3, thickness: 1),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      try {
                        showToast('Registrandose con Google...');
                        await signInWithGoogle(state.context);
                      } catch (error) {
                        showToast('Error al registrarse con Google');
                        printLog('Error al registrarse con google: $error');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                        side: const BorderSide(color: color3),
                      ),
                      elevation: 5,
                    ),
                    icon: Image.asset('assets/misc/google.png',
                        width: 24, height: 24),
                    label: const Text(
                      'Google',
                      style: TextStyle(color: color3, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: () {
                      state.switchForm(FormType.login);
                    },
                    style: TextButton.styleFrom(foregroundColor: color3),
                    child: const Text(
                      '¿Ya tienes una cuenta?\nIniciar sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: color3, fontSize: 16),
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
