// welcome.dart
import 'dart:async';

import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:caldensmart/logger.dart';
import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'package:google_fonts/google_fonts.dart';
import 'sign_in.dart';
import 'sign_up.dart';
import 'verification_code.dart';
import 'forget_password.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

/// Función para iniciar sesión con Google usando AWS Cognito.
Future<void> signInWithGoogle(BuildContext context) async {
  try {
    await Amplify.Auth.signOut(
      options: const SignOutOptions(
        globalSignOut: true,
      ),
    );
    printLog.i('Sesión anterior cerrada.');

    // Abrir sesión en una ventana privada si el navegador o el sistema operativo lo permite
    final res = await Amplify.Auth.signInWithWebUI(
      provider: AuthProvider.google,
      options: const SignInWithWebUIOptions(
        pluginOptions: CognitoSignInWithWebUIPluginOptions(
          isPreferPrivateSession: true,
          browserPackageName: 'com.android.chrome',
        ),
      ),
    );

    if (res.isSignedIn) {
      printLog.i('Inicio de sesión con Google exitoso.');
      showToast('Inicio de sesión exitoso.');

      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/menu');
      }
    } else {
      printLog.i('El inicio de sesión fue cancelado o falló.');
      showToast('Inicio de sesión cancelado.');
    }
  } catch (e, s) {
    showToast('Error al iniciar sesión con Google.');
    printLog.e('Error al iniciar sesión con Google: $e');
    printLog.t('Pila de errores: $s');
  }
}

///*- Widget de estado para la página de bienvenida *-\\\
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  ///*- Crea el estado para WelcomePage *-\\\
  @override
  WelcomePageState createState() => WelcomePageState();
}

// VARIABLES \\
///*- Enumeración de los diferentes tipos de formulario *-\\\
enum FormType {
  welcome,
  login,
  register,
  forgotPassword,
  enterCode,
  registerVerification
}

///*- Estado de WelcomePage que maneja animaciones y formularios *-\\\
class WelcomePageState extends State<WelcomePage>
    with TickerProviderStateMixin {
  ///*- Controlador de animación para la transición de bienvenida a inicio de sesión *-\\\
  late AnimationController welcomeToLoginController;

  ///*- Animación de deslizamiento para la pantalla de bienvenida *-\\\
  late Animation<Offset> welcomeSlideAnimation;

  ///*- Controlador de animación para el formulario de inicio de sesión *-\\\
  late AnimationController loginFormController;

  ///*- Animación de deslizamiento para el formulario de inicio de sesión *-\\\
  late Animation<Offset> loginFormSlideAnimation;

  ///*- Controlador de animación para el primer plano *-\\\
  late AnimationController foregroundController;

  ///*- Animación de desvanecimiento para el primer plano *-\\\
  late Animation<double> foregroundFadeAnimation;

  ///*- Controlador de animación para la posición del foreground *-\\\
  late AnimationController foregroundPositionController;

  ///*- Animación de desplazamiento para la posición del foreground *-\\\
  late Animation<Offset> foregroundSlideAnimation;

  ///*- Formulario actual que se está mostrando *-\\\
  FormType currentForm = FormType.welcome;

  ///*- Controlador para el campo de correo en inicio de sesión *-\\\
  final TextEditingController loginEmailController = TextEditingController();

  ///*- Controlador para el campo de contraseña en inicio de sesión *-\\\
  final TextEditingController loginPasswordController = TextEditingController();

  ///*- Controlador para el campo de correo en registro *-\\\
  final TextEditingController registerEmailController = TextEditingController();

  ///*- Controlador para el campo de contraseña en registro *-\\\
  final TextEditingController registerPasswordController =
      TextEditingController();

  ///*- Controlador para el campo de confirmación de contraseña en registro *-\\\
  final TextEditingController registerConfirmPasswordController =
      TextEditingController();

  ///*- Controlador para el campo de correo en recuperación de contraseña *-\\\
  final TextEditingController forgotPasswordEmailController =
      TextEditingController();

  ///*- Controlador para ingresar el código de recuperación *-\\\
  final TextEditingController enterCodeController = TextEditingController();

  ///*- Controlador para el nuevo campo de contraseña *-\\\
  final TextEditingController newPasswordController = TextEditingController();

  ///*- Controlador para confirmar la nueva contraseña *-\\\
  final TextEditingController confirmPasswordController =
      TextEditingController();

  ///*- Clave global para el formulario de inicio de sesión *-\\\
  final loginFormKey = GlobalKey<FormState>();

  ///*- Clave global para el formulario de registro *-\\\
  final registerFormKey = GlobalKey<FormState>();

  ///*- Variable para el estado del checkbox de aceptar términos *-\\\
  bool acceptTerms = false;

  ///*- Variable para controlar la visibilidad de la contraseña *-\\\
  bool obscurePassword = true;

  late AnimationController logoController;
  late Animation<double> logoFadeAnimation;

  late AnimationController lettersController;
  late Animation<double> lettersFadeAnimation;

  late AnimationController logoExitController;
  late Animation<Offset> logoExitSlideAnimation;
  late Animation<double> logoExitFadeAnimation;

  late AnimationController lettersExitController;
  late Animation<Offset> lettersExitSlideAnimation;
  late Animation<double> lettersExitFadeAnimation;

  /// Método para alternar la visibilidad de la contraseña
  void togglePasswordVisibility() {
    setState(() {
      obscurePassword = !obscurePassword;
    });
  }

  ///*- Inicializa los controladores de animación *-\\\
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      precacheImage(
        const AssetImage('assets/branch/dragon.png'),
        context,
      );
    });
    logoController = AnimationController(
      duration: const Duration(milliseconds: 1300),
      vsync: this,
    );
    logoFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: logoController, curve: Curves.easeOut),
    );

    lettersController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    lettersFadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: lettersController, curve: Curves.linear),
    );

    logoController.forward().then(
      (_) {
        lettersController.forward().then(
          (_) {
            Future.delayed(
              const Duration(milliseconds: 400),
              () {
                Future.wait([
                  logoExitController.forward(),
                  lettersExitController.forward(),
                ]).then(
                  (_) {
                    setState(
                      () {
                        onIngresarPressed();
                      },
                    );
                  },
                );
              },
            );
          },
        );
      },
    );

    logoExitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    logoExitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -1.0),
    ).animate(CurvedAnimation(
      parent: logoExitController,
      curve: Curves.easeInOut,
    ));
    logoExitFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: logoExitController,
      curve: Curves.easeIn,
    ));

    lettersExitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    lettersExitSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(1.0, 0.0),
    ).animate(CurvedAnimation(
      parent: lettersExitController,
      curve: Curves.easeInOut,
    ));
    lettersExitFadeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: lettersExitController,
      curve: Curves.easeIn,
    ));

    welcomeToLoginController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    welcomeSlideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(0.0, -1.0),
    ).animate(CurvedAnimation(
      parent: welcomeToLoginController,
      curve: Curves.easeInOutCubic,
    ));

    loginFormController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    loginFormSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: loginFormController,
      curve: Curves.easeInOutCubic,
    ));

    foregroundController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    foregroundFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: foregroundController,
        curve: Curves.easeInOutCubic,
      ),
    );

    foregroundController.forward();

    foregroundPositionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    foregroundSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 1),
      end: const Offset(0.0, -0.65),
    ).animate(
      CurvedAnimation(
        parent: foregroundPositionController,
        curve: Curves.easeInOutCubic,
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        checkForUpdate(context);
      }
    });

    fToast.init(navigatorKey.currentState!.context);
  }

  ///*- Elimina los controladores de animación y texto *-\\\
  @override
  void dispose() {
    welcomeToLoginController.dispose();
    loginFormController.dispose();
    foregroundController.dispose();
    foregroundPositionController.dispose();

    logoExitController.dispose();
    lettersExitController.dispose();

    loginEmailController.dispose();
    loginPasswordController.dispose();

    registerEmailController.dispose();
    registerPasswordController.dispose();
    registerConfirmPasswordController.dispose();

    forgotPasswordEmailController.dispose();
    enterCodeController.dispose();
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> confirmPasswordReset(
      String email, String confirmationCode, String newPassword) async {
    try {
      await Amplify.Auth.confirmResetPassword(
        username: email,
        newPassword: newPassword,
        confirmationCode: confirmationCode,
      );
      showToast('Contraseña restablecida correctamente');
      switchForm(FormType.login);
    } on AuthException catch (e) {
      showToast('Error restableciendo la contraseña.');
      printLog.e('Error restableciendo la contraseña: ${e.message}');
    }
  }

  ///*- Función para abrir el enlace de términos y condiciones *-\\\
  Future<void> launchTermsURL() async {
    launchWebURL(linksOfApp('TerminosDeUso'));
  }

  Future<void> launchPrivacyURL() async {
    launchWebURL(linksOfApp('Privacidad'));
  }

  Future<void> signUpUser(String email, String password) async {
    try {
      final userAttributes = {AuthUserAttributeKey.email: email};
      final result = await Amplify.Auth.signUp(
        username: email,
        password: password,
        options: SignUpOptions(userAttributes: userAttributes),
      );
      await _handleSignUpResult(result);
    } on AuthException catch (e) {
      printLog.e('Error registrando usuario: ${e.message}');
      if (e.message.contains('User already exists')) {
        showToast('El usuario ya tiene una cuenta');
      } else {
        showToast('Error registrando usuario');
      }
    }
  }

  Future<void> _handleSignUpResult(SignUpResult result) async {
    switch (result.nextStep.signUpStep) {
      case AuthSignUpStep.confirmSignUp:
        showToast('Se envió el código de verificación');
        switchForm(FormType.registerVerification);
        break;
      case AuthSignUpStep.done:
        showToast('Registro completo');
        Navigator.pushReplacementNamed(context, '/welcome');
        break;
    }
  }

  Future<void> resendResetCode(String email) async {
    try {
      await Amplify.Auth.resetPassword(username: email);
      showToast('Código reenviado al correo');
    } on AuthException catch (e) {
      showToast('Error reenviando el código');
      printLog.e('Error reenviando código ${e.message}');
    }
  }

  Future<void> confirmSignUpCode(String email, String confirmationCode) async {
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: email,
        confirmationCode: confirmationCode,
      );
      await _handleSignUpResult(result);
    } on AuthException catch (e) {
      showToast('Error verificando código');
      printLog.e('Error verificando código: ${e.message}');
    }
  }

  Future<void> resendSignUpCode(String email) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: email);
      showToast('Código reenviado al correo');
    } on AuthException catch (e) {
      showToast('Error reenviando el código');
      printLog.e('Error reenviando el código: ${e.message}');
    }
  }

  ///*- Maneja la presión del botón 'Ingresar' *-\\\
  void onIngresarPressed() {
    setState(() {
      currentForm = FormType.login;
    });

    welcomeToLoginController.forward().then((_) {
      loginFormController.forward();
      foregroundPositionController.forward();
    });
  }

  ///*- Cambia el formulario actual *-\\\
  void switchForm(FormType formType) {
    setState(() {
      currentForm = formType;
      if (currentForm == FormType.welcome) {
        foregroundPositionController.reverse();
      } else {
        foregroundPositionController.forward();
      }
    });
  }

  ///*- Actualiza el estado del checkbox de aceptar términos *-\\\
  void updateAcceptTerms(bool value) {
    setState(() {
      acceptTerms = value;
    });
  }

  ///*- Construye una tarjeta con restricciones
  Widget buildConstrainedCard(Widget child,
      {bool isForgotPassword = false, bool isEnterCode = false}) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: isForgotPassword || isEnterCode
            ? MediaQuery.of(context).size.height * 0.35
            : MediaQuery.of(context).size.height * 0.45,
        maxHeight: isForgotPassword || isEnterCode
            ? MediaQuery.of(context).size.height * 0.7
            : MediaQuery.of(context).size.height * 0.85,
      ),
      child: Card(
        color: const Color(0xFF5C5B57),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
          child: child,
        ),
      ),
    );
  }

  ///*- Construye un campo de formulario de texto con parámetros especificados *-\\\
  Widget buildTextFormField({
    TextEditingController? controller,
    required String hintText,
    required IconData icon,
    required bool obscureText,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      cursorColor: color1,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: color1),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: color0.withValues(alpha: 0.5),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        hintStyle: TextStyle(color: color1.withValues(alpha: 0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: const BorderSide(color: color1),
        ),
      ),
      style: const TextStyle(color: color1),
      validator: validator,
    );
  }

  ///*- Construye el árbol de widgets principal *-\\\
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // Transición suave entre fondo negro y fondo con imagen
          // Transición suave entre fondo negro y fondo con imagen
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 800),
            child: currentForm == FormType.welcome
                ? Container(
                    key: const ValueKey('blackBackground'),
                    color: Colors.black,
                  )
                : Container(
                    key: const ValueKey('imageBackground'),
                    color: Colors.black,
                    child: Image.asset(
                      'assets/branch/csBackground.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
          ),
          SlideTransition(
            position: welcomeSlideAnimation,
            child: buildWelcome(),
          ),
          if (currentForm != FormType.welcome) ...{
            buildForm(),
          },
        ],
      ),
      bottomSheet: Text(
        'Versión $appVersionNumber',
        style: const TextStyle(
          color: color0,
          fontSize: 12,
        ),
      ),
    );
  }

  ///*- Construye la pantalla de bienvenida *-\\\
  Widget buildWelcome() {
    return Container(
      key: const ValueKey<FormType>(FormType.welcome),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SlideTransition(
              position: logoExitSlideAnimation,
              child: FadeTransition(
                opacity: logoExitFadeAnimation,
                child: AnimatedBuilder(
                  animation: logoController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: logoFadeAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, 120 * (1 - logoFadeAnimation.value)),
                        child: child,
                      ),
                    );
                  },
                  child: Image.asset(
                    'assets/branch/dragon.png',
                    width: MediaQuery.of(context).size.width * 0.25,
                    height: MediaQuery.of(context).size.height * 0.25,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            SlideTransition(
              position: lettersExitSlideAnimation,
              child: FadeTransition(
                opacity: lettersExitFadeAnimation,
                child: Transform.translate(
                  offset: Offset(0, MediaQuery.of(context).size.width * -0.1),
                  child: AnimatedBuilder(
                    animation: lettersController,
                    builder: (context, child) {
                      return Column(
                        children: [
                          buildAnimatedText("CALDÉN"),
                          buildAnimatedText("SMART"),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ///*- Construye el formulario basado en el tipo actual *-\\\
  Widget buildForm() {
    return SlideTransition(
      position: loginFormSlideAnimation,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 800),
        switchInCurve: Curves.easeInOutCubic,
        switchOutCurve: Curves.easeInOutCubic,
        layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
          return Stack(
            alignment: Alignment.center,
            children: [
              ...previousChildren,
              if (currentChild != null) currentChild,
            ],
          );
        },
        transitionBuilder: (Widget child, Animation<double> animation) {
          final fadeAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );

          final slideAnimation = Tween<Offset>(
            begin: currentForm == FormType.register ||
                    currentForm == FormType.forgotPassword ||
                    currentForm == FormType.enterCode
                ? const Offset(1.0, 0.0)
                : const Offset(-1.0, 0.0),
            end: Offset.zero,
          ).animate(fadeAnimation);

          return FadeTransition(
            opacity: fadeAnimation,
            child: SlideTransition(
              position: slideAnimation,
              child: child,
            ),
          );
        },
        child: getCurrentFormWidget(),
      ),
    );
  }

  ///*- Retorna el widget del formulario actual basado en el tipo de formulario *-\\\
  Widget getCurrentFormWidget() {
    switch (currentForm) {
      case FormType.login:
        return buildLoginForm(this);
      case FormType.register:
        return buildRegisterForm(this);
      case FormType.forgotPassword:
        return buildForgotPasswordForm(this);
      case FormType.enterCode:
        return buildEnterCodeForm(this); // Para olvido de contraseña
      case FormType.registerVerification:
        return buildRegisterVerificationCodeForm(
            this); // Nuevo formulario de verificación para registro
      default:
        return Container();
    }
  }

  Widget buildAnimatedText(String text) {
    final total = text.length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final letterProgress = (lettersFadeAnimation.value * (total + 0.5)) - i;
        final opacity = letterProgress.clamp(0.0, 1.0);
        return Opacity(
          opacity: opacity,
          child: Text(
            text[i],
            style: text == "CALDÉN"
                ? GoogleFonts.openSans(
                    fontSize: 38,
                    fontWeight: FontWeight.w800,
                    color: color0.withAlpha(255),
                    letterSpacing: 2,
                  )
                : GoogleFonts.questrial(
                    fontSize: 32,
                    fontWeight: FontWeight.w300,
                    color: color0.withAlpha((0.85 * 255).toInt()),
                    letterSpacing: 2,
                  ),
          ),
        );
      }),
    );
  }
}
