import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'package:hugeicons/hugeicons.dart';
import 'welcome.dart';

///-* widget para ingresar código y nueva contraseña cuando olvidas la contraseña *-\\\
Widget buildEnterCodeForm(WelcomePageState state) {
  return Container(
    key: const ValueKey<FormType>(FormType.enterCode),
    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
    child: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(state.context).viewInsets.bottom,
          ),
          child: state.buildConstrainedCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Código de verificación',
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color1),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ingrese el código enviado a su correo y su nueva contraseña',
                  style: TextStyle(fontSize: 18, color: color0),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                state.buildTextFormField(
                  controller: state.enterCodeController,
                  hintText: 'Código',
                  icon: HugeIcons.strokeRoundedMessage02,
                  obscureText: false,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, ingrese el código';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                state.buildTextFormField(
                  controller: state.newPasswordController,
                  hintText: 'Nueva contraseña',
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
                  keyboardType: TextInputType.text,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, ingrese su nueva contraseña';
                    }
                    if (value.trim().length < 8) {
                      return 'La contraseña debe tener\nal menos 8 caracteres';
                    }
                    if (!RegExp(r'\d').hasMatch(value.trim())) {
                      return 'La contraseña debe tener\nal menos 1 número';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (state.enterCodeController.text.trim().isEmpty ||
                          state.newPasswordController.text.trim().isEmpty) {
                        showToast(
                            'Por favor, ingrese el código y la nueva contraseña');
                      } else {
                        await state.confirmPasswordReset(
                          state.forgotPasswordEmailController.text.trim(),
                          state.enterCodeController.text.trim(),
                          state.newPasswordController.text.trim(),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color1,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30.0),
                      ),
                      elevation: 5,
                    ),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(color: color0, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      state.resendResetCode(
                          state.forgotPasswordEmailController.text.trim());
                    },
                    style: TextButton.styleFrom(foregroundColor: color1),
                    child: const Text(
                      'Reenviar código',
                      style: TextStyle(color: color0, fontSize: 14),
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

Widget buildRegisterVerificationCodeForm(WelcomePageState state) {
  return Container(
    key: const ValueKey<FormType>(FormType.enterCode),
    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
    child: Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(state.context).viewInsets.bottom,
          ),
          child: state.buildConstrainedCard(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(HugeIcons.strokeRoundedArrowLeft02,
                          color: color1),
                      onPressed: () {
                        state.switchForm(FormType.register);
                      },
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Verificación de registro',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  'Ingrese el código enviado a su correo para completar el registro',
                  style: TextStyle(
                    fontSize: 18,
                    color: color0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                state.buildTextFormField(
                  controller: state.enterCodeController,
                  hintText: 'Código',
                  icon: HugeIcons.strokeRoundedMessage02,
                  obscureText: false,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Por favor, ingrese el código';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      if (state.enterCodeController.text.trim().isEmpty) {
                        showToast(
                            'Por favor, ingrese el código de verificación');
                      } else {
                        state.confirmSignUpCode(
                            state.registerEmailController.text.trim(),
                            state.enterCodeController.text.trim());
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color1,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0)),
                      elevation: 5,
                    ),
                    child: const Text(
                      'Verificar',
                      style: TextStyle(color: color0, fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 25),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      state.resendSignUpCode(
                          state.registerEmailController.text.trim());
                    },
                    style: TextButton.styleFrom(foregroundColor: color1),
                    child: const Text(
                      'Reenviar código de verificación',
                      style: TextStyle(color: color0, fontSize: 14),
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
