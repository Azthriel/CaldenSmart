#!/usr/bin/env bash
set -euo pipefail

# ============================================================
#  CaldenSmart - Deploy Script (Linux)
#  Lee version desde pubspec.yaml, genera ZIP y AAB
# ============================================================

APP_DIR="/home/gonza-trillo/Desktop/caldensmart"
VERSIONS_DIR="/home/gonza-trillo/Desktop/Copia de versiones"
UPLOAD_DIR="/home/gonza-trillo/Desktop/Versión a subir"
PUBSPEC="$APP_DIR/pubspec.yaml"

# ── Verificar que existe pubspec.yaml ────────────────────────
if [[ ! -f "$PUBSPEC" ]]; then
    echo "[ERROR] No se encontró pubspec.yaml en $APP_DIR"
    exit 1
fi

# ── Leer version desde pubspec.yaml (sin build number) ───────
VERSION=$(grep -E '^version:' "$PUBSPEC" | head -n1 | sed -E 's/^version:[[:space:]]*//' | cut -d'+' -f1 | tr -d '[:space:]\r')

if [[ -z "$VERSION" ]]; then
    echo "[ERROR] No se pudo leer la versión de pubspec.yaml"
    exit 1
fi

# ── Cabecera ─────────────────────────────────────────────────
echo ""
echo " ╔══════════════════════════════════════════╗"
echo " ║       CaldenSmart  -  Deploy Script      ║"
echo " ╠══════════════════════════════════════════╣"
echo " ║  Versión detectada : $VERSION"
echo " ╚══════════════════════════════════════════╝"
echo ""

# ── Verificar carpetas destino ───────────────────────────────
# Si "Copia de versiones" es un symlink roto (disco no montado), cortar acá
if [[ -L "$VERSIONS_DIR" && ! -e "$VERSIONS_DIR" ]]; then
    echo "[ERROR] El symlink de \"Copia de versiones\" está roto:"
    echo "        $VERSIONS_DIR"
    echo "        → Apunta a: $(readlink "$VERSIONS_DIR")"
    echo "        ¿Está montado el disco \"Nuevo vol\"?"
    exit 1
fi

mkdir -p "$VERSIONS_DIR"
mkdir -p "$UPLOAD_DIR"

# ============================================================
#  PASO 1 — ZIP de la carpeta completa
# ============================================================
ZIP_DEST="$VERSIONS_DIR/caldensmart$VERSION.zip"

echo "[1/3] Creando ZIP de la carpeta completa..."
echo "       Fuente  : $APP_DIR"
echo "       Destino : $ZIP_DEST"
echo ""

# -r recursivo, -q silencioso (sacá la -q si querés ver el progreso)
# Excluye build/ y .dart_tool/ para que el zip no pese una banda
# (borrá las líneas -x si querés la copia 100% completa)
rm -f "$ZIP_DEST"
(
    cd "$(dirname "$APP_DIR")"
    zip -r -q "$ZIP_DEST" "$(basename "$APP_DIR")" \
        -x "*/build/*" \
        -x "*/.dart_tool/*"
)

echo " OK - ZIP generado correctamente."
echo ""

# ============================================================
#  PASO 2 — flutter build appbundle
# ============================================================
echo "[2/3] Ejecutando flutter build appbundle..."
echo ""

cd "$APP_DIR"
flutter build appbundle

echo ""
echo " OK - Build completado."
echo ""

# ============================================================
#  PASO 3 — Renombrar y mover el .aab
# ============================================================
echo "[3/3] Moviendo AppBundle a \"Versión a subir\"..."

AAB_SRC="$APP_DIR/build/app/outputs/bundle/release/app-release.aab"
AAB_DEST="$UPLOAD_DIR/CaldenSmart$VERSION.aab"

if [[ ! -f "$AAB_SRC" ]]; then
    echo "[ERROR] No se encontró el .aab en:"
    echo "        $AAB_SRC"
    exit 1
fi

cp -f "$AAB_SRC" "$AAB_DEST"

echo " OK - AAB copiado correctamente."
echo ""

# ============================================================
#  RESUMEN FINAL
# ============================================================
echo " ╔══════════════════════════════════════════╗"
echo " ║          Deploy Finalizado!              ║"
echo " ╠══════════════════════════════════════════╣"
echo " ║  Versión    : $VERSION"
echo " ║  ZIP        : caldensmart$VERSION.zip"
echo " ║  AppBundle  : CaldenSmart$VERSION.aab"
echo " ╚══════════════════════════════════════════╝"
echo ""

# Sonido de notificación (si existe paplay/canberra, si no, campana de terminal)
if command -v paplay &>/dev/null && [[ -f /usr/share/sounds/freedesktop/stereo/complete.oga ]]; then
    paplay /usr/share/sounds/freedesktop/stereo/complete.oga
else
    printf '\a'
fi