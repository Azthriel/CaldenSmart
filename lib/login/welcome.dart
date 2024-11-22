// welcome.dart
import 'package:flutter/material.dart';
import 'package:caldensmart/master.dart';
import 'sign_in.dart';
import 'sign_up.dart';
import 'verification_code.dart';
import 'forget_password.dart';
import 'package:amplify_flutter/amplify_flutter.dart';

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
  ///*- Controlador de animación para el fondo *-\\\
  late AnimationController backgroundController;

  ///*- Controlador de animación para el texto de bienvenida *-\\\
  late AnimationController welcomeTextController;

  ///*- Animación de desvanecimiento para el texto de bienvenida *-\\\
  late Animation<double> welcomeFadeAnimation;

  ///*- Controlador de animación para el botón *-\\\
  late AnimationController buttonController;

  ///*- Animación de escala para el botón *-\\\
  late Animation<double> buttonAnimation;

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

  ///*- Bandera para mostrar el botón 'Ingresar' *-\\\
  bool showIngresarButton = true;

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

  /// Variable para controlar la visibilidad de la contraseña
  bool obscurePassword = true;

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
    backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 60),
    )..repeat(reverse: true);

    welcomeTextController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    welcomeFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: welcomeTextController,
        curve: Curves.easeInOutCubic,
      ),
    );

    welcomeTextController.forward();

    buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    buttonAnimation = Tween(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(
        parent: buttonController,
        curve: Curves.easeInOutCubic,
      ),
    );

    welcomeToLoginController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
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

    // Controlador y animación para la posición del foreground
    foregroundPositionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    foregroundSlideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -0.12),
      end: const Offset(0.0, -0.41),
    ).animate(CurvedAnimation(
      parent: foregroundPositionController,
      curve: Curves.easeInOutCubic,
    ));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkForUpdate(context);
    });
  }

  ///*- Elimina los controladores de animación y texto *-\\\
  @override
  void dispose() {
    backgroundController.dispose();
    welcomeTextController.dispose();
    buttonController.dispose();
    welcomeToLoginController.dispose();
    loginFormController.dispose();
    foregroundController.dispose();
    foregroundPositionController.dispose();

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
      printLog('Error restableciendo la contraseña: ${e.message}');
    }
  }

  ///*- Función para abrir el enlace de términos y condiciones *-\\\
  Future<void> launchTermsURL() async {
    launchWebURL(linksOfApp(app, 'TerminosDeUso'));
  }

  Future<void> launchPrivacyURL() async {
    launchWebURL(linksOfApp(app, 'Privacidad'));
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
      printLog('Error registrando usuario: ${e.message}');
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
      printLog('Error reenviando código ${e.message}');
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
      printLog('Error verificando código: ${e.message}');
    }
  }

  Future<void> resendSignUpCode(String email) async {
    try {
      await Amplify.Auth.resendSignUpCode(username: email);
      showToast('Código reenviado al correo');
    } on AuthException catch (e) {
      showToast('Error reenviando el código');
      printLog('Error reenviando el código: ${e.message}');
    }
  }

  ///*- Maneja la presión del botón 'Ingresar' *-\\\
  void onIngresarPressed() {
    buttonController.forward().then((value) {
      buttonController.reverse();

      setState(() {
        showIngresarButton = false;
        currentForm = FormType.login;
      });
      welcomeToLoginController.forward().then((_) {
        loginFormController.forward();
        foregroundPositionController.forward();
      });
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

  ///*- Construye una tarjeta con restricciones de tamaño *-\\\
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
        color: color0.withOpacity(0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        elevation: 10,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 15.0),
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
      cursorColor: color3,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(icon, color: color3),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: color1.withOpacity(0.5),
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15.0, horizontal: 20.0),
        hintStyle: TextStyle(color: color3.withOpacity(0.7)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30.0),
          borderSide: const BorderSide(color: color3),
        ),
      ),
      style: const TextStyle(color: color3),
      validator: validator,
    );
  }

  ///*- Construye el árbol de widgets principal *-\\\
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: color1,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: backgroundController,
            builder: (context, child) {
              return CustomPaint(
                painter: CirclePainter(backgroundController.value),
                child: Container(),
              );
            },
          ),
          SlideTransition(
            position: welcomeSlideAnimation,
            child: buildWelcome(),
          ),
          if (currentForm == FormType.welcome && showIngresarButton)
            Positioned(
              bottom: 60.0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: welcomeSlideAnimation,
                child: ScaleTransition(
                  scale: buttonAnimation,
                  child: Center(
                    child: ElevatedButton(
                      onPressed: onIngresarPressed,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color3,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 80, vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30.0),
                        ),
                        elevation: 5,
                      ),
                      child: const Text(
                        'Ingresar',
                        style: TextStyle(
                          color: color0,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (currentForm != FormType.welcome) buildForm(),
          SlideTransition(
            position: foregroundSlideAnimation,
            child: FadeTransition(
              opacity: foregroundFadeAnimation,
              child: IgnorePointer(
                child: Center(
                  child: Image.asset(
                    'assets/Logo_sitio.png',
                    width: MediaQuery.of(context).size.width - 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  ///*- Construye la pantalla de bienvenida *-\\\
  Widget buildWelcome() {
    return Container(
      key: const ValueKey<FormType>(FormType.welcome),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: welcomeFadeAnimation,
              child: const Text(
                'Bienvenido',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: color3,
                  shadows: [
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black26,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(
              height: 40,
            ),
            // Aquí podrías agregar otros widgets de bienvenida si lo deseas
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
}

///*- Pintor personalizado para dibujar círculos animados en el fondo *-\\\
class CirclePainter extends CustomPainter {
  final double animationValue;
  final List<Color> colors = [
    color0,
    color1,
    color2,
    color4.withOpacity(0.5),
    color5.withOpacity(0.5),
    color6.withOpacity(0.5),
    color0.withOpacity(0.3),
    color1.withOpacity(0.3),
    color2.withOpacity(0.3),
    color4.withOpacity(0.3),
  ];

  CirclePainter(this.animationValue);

  ///*- Dibuja los círculos en el canvas *-\\\
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < colors.length; i++) {
      paint.color = colors[i].withOpacity(0.2);
      final radius = 50.0 + (animationValue * 40) * ((i % 5) + 1);
      final dx = size.width * (0.1 + (i * 0.15) % 1.0);
      final dy = size.height * (0.1 + ((i * 0.25) % 1.0));
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  ///*- Determina si el pintor debe repintar *-\\\
  @override
  bool shouldRepaint(covariant CirclePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
