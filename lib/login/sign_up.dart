import 'package:caldensmart/logger.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'welcome.dart';
import 'package:caldensmart/master.dart';

Widget buildRegisterForm(WelcomePageState state) {
  return Container(
    key: const ValueKey<FormType>(FormType.register),
    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
    child: Center(
      child: SingleChildScrollView(
        child: state.buildConstrainedCard(
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(state.context).size.height * 0.75,
              maxWidth: MediaQuery.of(state.context).size.width * 0.9,
            ),
            child: SingleChildScrollView(
              child: Form(
                key: state.registerFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 8),
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
                              ? const Icon(HugeIcons.strokeRoundedViewOff,
                                  key: ValueKey('icon1'), color: color1)
                              : const Icon(HugeIcons.strokeRoundedView,
                                  key: ValueKey('icon2'), color: color1),
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
                    const SizedBox(height: 8),
                    state.buildTextFormField(
                      controller: state.registerConfirmPasswordController,
                      hintText: 'Confirmar contraseña',
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
                              ? const Icon(HugeIcons.strokeRoundedViewOff,
                                  key: ValueKey('icon1'), color: color1)
                              : const Icon(HugeIcons.strokeRoundedView,
                                  key: ValueKey('icon2'), color: color1),
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
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Checkbox(
                          value: state.acceptTerms,
                          onChanged: (bool? value) {
                            state.updateAcceptTerms(value ?? false);
                          },
                          activeColor: color1,
                          checkColor: color0,
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              text: 'Acepto los ',
                              style:
                                  const TextStyle(color: color0, fontSize: 12),
                              children: [
                                TextSpan(
                                  text: 'términos de uso',
                                  style: const TextStyle(
                                    color: color0,
                                    fontSize: 12,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () {
                                      state.launchTermsURL();
                                    },
                                ),
                                const TextSpan(
                                  text: ' y ',
                                  style: TextStyle(color: color0, fontSize: 12),
                                ),
                                TextSpan(
                                  text: 'políticas de privacidad',
                                  style: const TextStyle(
                                    color: color0,
                                    fontSize: 12,
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
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (state.registerFormKey.currentState!.validate()) {
                            if (!state.acceptTerms) {
                              showToast(
                                  'Debe aceptar los términos y condiciones');
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
                          backgroundColor: const Color(0xFF97292c),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
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
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        Expanded(
                          child: Divider(color: color1, thickness: 1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          try {
                            showToast('Registrandose con Google...');
                            await signInWithGoogle(state.context);
                          } catch (error) {
                            showToast('Error al registrarse con Google');
                            printLog
                                .e('Error al registrarse con google: $error');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: color0.withValues(alpha: 0.60),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30.0),
                            side: const BorderSide(color: color1),
                          ),
                          elevation: 5,
                        ),
                        icon: Image.asset('assets/misc/google.png',
                            width: 20, height: 20),
                        label: const Text(
                          'Google',
                          style: TextStyle(
                            color: color0,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          state.switchForm(FormType.login);
                        },
                        style: TextButton.styleFrom(foregroundColor: color1),
                        child: const Text(
                          '¿Ya tienes una cuenta?\nIniciar sesión',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: color0,
                            fontSize: 14,
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
      ),
    ),
  );
}
