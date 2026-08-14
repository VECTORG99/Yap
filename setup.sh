#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Yap — Instalación del Agente IA local para ChincoLinux
# ============================================================
# Este script se ejecuta UNA SOLA VEZ al instalar.
# Al cambiar de rama (main ↔ lowmem ↔ ultra-lowmem),
# solo se necesita re-ejecutarlo para descargar el modelo
# faltante. El resto de pasos detectan lo ya instalado.
# ============================================================

YAP_VERSION="1.0.0"
YAP_DIR="/opt/yap"
MODEL_DIR="$YAP_DIR/models"
CONFIG_DIR="/etc/yap"
WHITELIST_DIR="$CONFIG_DIR/whitelist"
PSEINT_DIR="$CONFIG_DIR/pseint"
BIN_DIR="/usr/local/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LLAMACPP_REPO="https://github.com/ggerganov/llama.cpp.git"
LLAMACPP_BRANCH="b5097"

# Tamaños reales de cada modelo (para información al usuario)
MODELO_3B_BYTES="1.9 GB"
MODELO_1B_BYTES="0.81 GB"

RAMAS=(main lowmem ultra-lowmem)
RAMA_ACTUAL=$(git -C "$SCRIPT_DIR" branch --show-current 2>/dev/null || echo "desconocida")

# Detectar si esto es una REINSTALACIÓN o primera instalación
ES_REINSTALACION=false
[ -f "$BIN_DIR/llama-cli" ] && ES_REINSTALACION=true

echo "================================================================"
echo "  YAP v$YAP_VERSION — Instalación del Agente IA Local"
echo "================================================================"
echo ""
echo "  Rama activa:       $RAMA_ACTUAL"
if $ES_REINSTALACION; then
  echo "  Tipo de ejecución: REINSTALACIÓN (componentes ya existen)"
else
  echo "  Tipo de ejecución: INSTALACIÓN INICIAL"
fi
echo ""

# --- 1. Dependencias del sistema ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 1/6 — Dependencias del sistema"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Propósito: Instalar los paquetes necesarios para compilar"
echo "  llama.cpp y ejecutar el agente Yap."
echo ""
echo "  Paquetes a instalar:"
echo "    • build-essential   — Compilador gcc/g++ y herramientas base"
echo "    • cmake             — Generador de archivos de compilación"
echo "    • curl, wget, git   — Descargas y control de versiones"
echo "    • python3, pip      — Entorno Python del agente"
echo "    • libnotify-bin     — Cliente notify-send (alertas gráficas)"
echo "    • libcurl4-openssl-dev — Headers libcurl (requerido por llama.cpp)"
echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  ［EJECUTANDO］sudo apt-get install ..."
echo "  ──────────────────────────────────────────────────────────────"
echo ""

sudo apt-get update -qq
sudo apt-get install -y -qq \
  build-essential cmake curl wget git pkg-config \
  python3 python3-pip \
  libnotify-bin notify-osd \
  libcurl4-openssl-dev \
  --no-install-recommends

echo "  ✓ Dependencias instaladas correctamente."
echo ""

# --- 2. Compilar llama.cpp ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 2/6 — Compilación de llama.cpp"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if $ES_REINSTALACION && [ -f "$BIN_DIR/llama-cli" ]; then
  echo "  llama-cli ya está compilado en $BIN_DIR/llama-cli"
  echo "  Saltando compilación (usar 'sudo rm $BIN_DIR/llama-cli' para forzar)."
  echo ""
else
  echo "  Propósito: Compilar el runtime de inferencia llama.cpp"
  echo "  desde el código fuente con enlace estático."
  echo ""
  echo "  Repositorio:  $LLAMACPP_REPO"
  echo "  Tag:          $LLAMACPP_BRANCH"
  echo "  Clonado:      superficial (--depth 1) — solo el último commit"
  echo "  Directorio:   temporal (se elimina al terminar)"
  echo ""
  echo "  Flags de compilación (CMake):"
  echo "    • -DCMAKE_BUILD_TYPE=Release     → optimizado para velocidad"
  echo "    • -DBUILD_SHARED_LIBS=OFF        → ENLACE ESTÁTICO"
  echo "    • -DLLAMA_CUDA=OFF               → sin GPU NVIDIA"
  echo "    • -DLLAMA_METAL=OFF              → sin GPU Apple"
  echo "    • -DLLAMA_CURL=OFF               → sin soporte CURL"
  echo ""
  echo "  ────────────────────────────────────────────────────────────"
  echo "  ［EJECUTANDO］git clone + cmake + cmake --build"
  echo "  ────────────────────────────────────────────────────────────"
  echo "  (la compilación puede tomar 5-15 minutos según el hardware)"
  echo ""

  LLAMA_BUILD=$(mktemp -d)
  cd "$LLAMA_BUILD"
  git clone --depth 1 --branch "$LLAMACPP_BRANCH" "$LLAMACPP_REPO" 2>/dev/null
  cd llama.cpp
  mkdir -p build && cd build
  cmake .. -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=OFF -DLLAMA_CUDA=OFF -DLLAMA_METAL=OFF -DLLAMA_CURL=OFF
  cmake --build . --config Release -j"$(nproc)" 2>&1
  sudo cp bin/llama-cli /usr/local/bin/llama-cli
  rm -rf "$LLAMA_BUILD"

  echo ""
  echo "  ✓ llama.cpp compilado e instalado en $BIN_DIR/llama-cli"
  echo "    (binario estático — sin dependencia de libllama.so)"
  echo ""
fi

# --- 3. Gestión de modelos ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 3/6 — Gestión del modelo de lenguaje"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Detectar archivos de modelo existentes
MODELOS_EXISTENTES=()
shopt -s nullglob
for f in "$MODEL_DIR"/*.gguf; do
  MODELOS_EXISTENTES+=("$f")
done
shopt -u nullglob

# Determinar qué modelo necesita esta rama
MODEL_FILENAME=$(grep 'MODEL_PATH =' "$SCRIPT_DIR/yap.py" | sed "s|.*/||;s|\"||g")
SIZE=$(echo "$MODEL_FILENAME" | sed 's/Llama-3.2-//;s/-Instruct-Q4_K_M.gguf//')
MODEL_FILE="$MODEL_DIR/$MODEL_FILENAME"
MODEL_URL="https://huggingface.co/bartowski/Llama-3.2-${SIZE}-Instruct-GGUF/resolve/main/${MODEL_FILENAME}"

echo "  Modelo REQUERIDO por la rama '$RAMA_ACTUAL':"
echo "    • Archivo:  $MODEL_FILENAME"
TAM_MODELO=""; [ "$SIZE" = "3B" ] && TAM_MODELO="$MODELO_3B_BYTES"; [ "$SIZE" = "1B" ] && TAM_MODELO="$MODELO_1B_BYTES"
echo "    • Tamaño:   $TAM_MODELO"
echo "    • Formato:  GGUF Q4_K_M (cuantización 4 bits, mezcla K-quant)"
echo "    • URL:      $MODEL_URL"
echo ""

if [ ${#MODELOS_EXISTENTES[@]} -gt 0 ]; then
  echo "  Modelos YA EXISTENTES en $MODEL_DIR:"
  for f in "${MODELOS_EXISTENTES[@]}"; do
    BASENAME=$(basename "$f")
    SIZE_BYTES=$(ls -lh "$f" | awk '{print $5}')
    if [ "$BASENAME" = "$MODEL_FILENAME" ]; then
      echo "    ✓ $BASENAME  ($SIZE_BYTES) ← ACTIVO (usado por esta rama)"
    else
      echo "    • $BASENAME  ($SIZE_BYTES) → INACTIVO (disponible para otras ramas)"
    fi
  done
  echo ""
  echo "  NOTA: Los modelos no utilizados NO se eliminan."
  echo "  Al cambiar a otra rama que los necesite, estarán listos."
  echo ""
fi

sudo mkdir -p "$MODEL_DIR"

if [ -f "$MODEL_FILE" ]; then
  echo "  ────────────────────────────────────────────────────────────"
  echo "  ［CONFIRMACIÓN］El modelo requerido YA EXISTE."
  echo "  ────────────────────────────────────────────────────────────"
  echo ""
  echo "  Tamaño: $(ls -lh "$MODEL_FILE" | awk '{print $5}')"
  echo "  Ruta:   $MODEL_FILE"
  echo ""
else
  echo "  ────────────────────────────────────────────────────────────"
  echo "  ［EJECUTANDO］sudo wget — descargando modelo..."
  echo "  ────────────────────────────────────────────────────────────"
  echo "  (la descarga puede tomar varios minutos)"
  echo ""
  sudo wget --progress=bar:force -O "$MODEL_FILE" "$MODEL_URL"
  echo ""
  echo "  ✓ Descarga completa."
  echo "    Tamaño: $(ls -lh "$MODEL_FILE" | awk '{print $5}')"
  echo "    Ruta:   $MODEL_FILE"
  echo ""
fi

# --- 4. Instalar agente Yap y whitelist ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 4/6 — Instalación del agente y whitelists"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Archivos de configuracion (whitelists):"
echo "    • $WHITELIST_DIR/apps.conf  — Aplicaciones permitidas"
echo "    • $WHITELIST_DIR/web.conf   — Dominios permitidos"
echo "    • $PSEINT_DIR/ejercicios.conf  — Ejercicios PSeInt"
echo "    • $PSEINT_DIR/guia_ejercicios.pdf  — Guia visual de ejercicios"
echo ""
echo "  Herramienta educativa:"
echo "    • PSeInt                     — Instalado via .run en /opt/pseint/"
echo ""
echo "  Agente principal:"
echo "    • $YAP_DIR/yap.py           — Copia del script (respaldo)"
echo "    • $BIN_DIR/yap              — Enlace simbólico → $SCRIPT_DIR/yap.py"
echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  ［EJECUTANDO］sudo mkdir + cp + ln -sf + git config"
echo "  ──────────────────────────────────────────────────────────────"
echo ""

sudo mkdir -p "$WHITELIST_DIR"
sudo cp "$SCRIPT_DIR/whitelist/apps.conf" "$WHITELIST_DIR/"
sudo cp "$SCRIPT_DIR/whitelist/web.conf" "$WHITELIST_DIR/"
sudo mkdir -p "$PSEINT_DIR"
sudo cp "$SCRIPT_DIR/whitelist/pseint/ejercicios.conf" "$PSEINT_DIR/"
sudo cp "$SCRIPT_DIR/whitelist/pseint/guia_ejercicios.pdf" "$PSEINT_DIR/"
# ── Cursos ─────────────────────────────────────────────────
sudo mkdir -p "$CONFIG_DIR/cursos"
sudo cp "$SCRIPT_DIR/cursos/"*.json "$CONFIG_DIR/cursos/" 2>/dev/null || true
echo "  OK: cursos instalados en $CONFIG_DIR/cursos/"
# ── Agente opencode ──────────────────────────────────────────
sudo mkdir -p "$CONFIG_DIR/agent"
sudo cp "$SCRIPT_DIR/yap-agent.md" "$CONFIG_DIR/agent/yap.md"
echo "  OK: agente Yap instalado en $CONFIG_DIR/agent/"
sudo cp "$SCRIPT_DIR/yap.py" "$YAP_DIR/yap.py"
sudo chmod +x "$YAP_DIR/yap.py"
sudo ln -sf "$SCRIPT_DIR/yap.py" "$BIN_DIR/yap"

# Configurar git hooks para mostrar información al cambiar de rama
chmod +x "$SCRIPT_DIR/.githooks/post-checkout" 2>/dev/null || true
(cd "$SCRIPT_DIR" && git config core.hooksPath .githooks 2>/dev/null) || true

echo "  ✓ Agente instalado."
echo "  ✓ Git hook post-checkout activado — mostrará información"
echo "    al hacer 'git checkout <rama>'."
echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  ［MECANISMO DE ACTUALIZACIÓN］"
echo "  ──────────────────────────────────────────────────────────────"
echo "  El enlace simbólico $BIN_DIR/yap apunta directamente"
echo "  al archivo $SCRIPT_DIR/yap.py dentro del repositorio."
echo ""
echo "  • Al hacer 'git pull' → el código se actualiza automáticamente"
echo "  • Al hacer 'git checkout <rama>' → el agente cambia de rama"
echo "    al instante y se muestra: rama anterior → rama actual,"
echo "    cambios de modelo, y el siguiente paso recomendado."
echo "  • NO es necesario re-ejecutar setup.sh al cambiar entre"
echo "    main y lowmem (mismo modelo 3B)"
echo ""

# --- 5. Instalar aplicaciones recomendadas ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 5/6 — Instalación de aplicaciones sugeridas"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Aplicaciones incluidas en la whitelist (instalacion opcional):"
echo "    • libreoffice    — Suite ofimatica"
echo "    • evince         — Visor de PDF"
echo "    • firefox-esr    — Navegador web"
echo "    • micro          — Editor de texto en terminal"
echo "    • htop           — Monitor de procesos"
echo "    • pseint         — Entorno de programacion (via .run)"
echo ""
echo "  ──────────────────────────────────────────────────────────────"
echo "  [EJECUTANDO] Instalacion de PSeInt + apt-get"
echo "  ──────────────────────────────────────────────────────────────"
echo ""

# Instalar PSeInt via .run (detecta si ya esta instalado)
PSEINT_RUN="/opt/pseint/pseint"
if [ ! -x "$PSEINT_RUN" ]; then
    echo "    Descargando e instalando PSeInt..."
    PSEINT_TMP=$(mktemp -d)
    sudo wget -q "https://downloads.sourceforge.net/project/pseint/20230531/pseint-l64-20230531.tgz" -O "$PSEINT_TMP/pseint.tgz" 2>/dev/null || true
    if [ -f "$PSEINT_TMP/pseint.tgz" ]; then
        sudo mkdir -p /opt/pseint
        sudo tar xzf "$PSEINT_TMP/pseint.tgz" -C /opt/pseint 2>/dev/null || true
        rm -rf "$PSEINT_TMP"
        echo "    PSeInt instalado en /opt/pseint/"
    else
        echo "    [AVISO] No se pudo descargar PSeInt. Instalalo manualmente desde pseint.sourceforge.net"
        echo "            El tutorial funcionara igual sin PSeInt grafico."
    fi
else
    echo "    PSeInt ya instalado en /opt/pseint/"
fi
echo ""

sudo apt-get install -y -qq \
  libreoffice evince firefox-esr micro htop \
  --no-install-recommends 2>/dev/null || true

echo "  ✓ Aplicaciones instaladas (o ya existentes)."
echo ""

# --- 5b. AppArmor (opcional) ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 5b/6 — AppArmor (opcional)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if command -v aa-status &>/dev/null; then
  echo "  AppArmor detectado en el sistema."
  if [ -f "$SCRIPT_DIR/apparmor/usr.local.bin.yap" ]; then
    echo "  Instalando perfil de Yap..."
    sudo cp "$SCRIPT_DIR/apparmor/usr.local.bin.yap" /etc/apparmor.d/
    sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.yap 2>/dev/null && \
      echo "  ✓ Perfil AppArmor de Yap cargado en modo enforce." || \
      echo "  [AVISO] No se pudo cargar el perfil. Revisa con 'yap --apparmor-status'."
  else
    echo "  [AVISO] No se encontró el perfil AppArmor en el repositorio."
  fi
else
  echo "  AppArmor no está instalado. Instalando..."
  sudo apt-get install -y -qq apparmor apparmor-utils --no-install-recommends 2>/dev/null && {
    if [ -f "$SCRIPT_DIR/apparmor/usr.local.bin.yap" ]; then
      sudo cp "$SCRIPT_DIR/apparmor/usr.local.bin.yap" /etc/apparmor.d/
      sudo apparmor_parser -r /etc/apparmor.d/usr.local.bin.yap 2>/dev/null && \
        echo "  ✓ Perfil AppArmor de Yap cargado en modo enforce." || \
        echo "  [AVISO] No se pudo cargar el perfil. Revisa con 'yap --apparmor-status'."
    fi
  } || echo "  [AVISO] No se pudo instalar AppArmor. Yap funcionará sin confinement."
fi
echo ""

# --- 6. Verificación ---
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  PASO 6/6 — Verificación de la instalación"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "  ──────────────────────────────────────────────────────────────"
echo "  ［VERIFICANDO COMPONENTES］"
echo "  ──────────────────────────────────────────────────────────────"
echo ""

# Resumen de modelos
echo "  Modelos disponibles en $MODEL_DIR:"
shopt -s nullglob
for f in "$MODEL_DIR"/*.gguf; do
  BASENAME=$(basename "$f")
  SIZE_H=$(ls -lh "$f" | awk '{print $5}')
  if [ "$BASENAME" = "$MODEL_FILENAME" ]; then
    echo "    ✓ $BASENAME  ($SIZE_H)  ← ACTIVO"
  else
    echo "    • $BASENAME  ($SIZE_H)  → INACTIVO (cambiar rama para usar)"
  fi
done
shopt -u nullglob
echo ""

echo "  Estado de componentes:"
echo "  +----------------------+--------------------------------+"
LLAMA_OK=$(command -v llama-cli && echo "OK" || echo "FALLO")
MODELO_OK=$(ls -lh "$MODEL_FILE" 2>/dev/null | awk '{print $5}' || echo "NO ENCONTRADO")
YAP_OK=$(command -v yap && echo "OK" || echo "FALLO")
NOTIFY_OK=$(command -v notify-send && echo "OK" || echo "FALLO")
APPS_OK=$( [ -f $WHITELIST_DIR/apps.conf ] && echo "CONFIGURADO" || echo "FALTANTE")
WEB_OK=$( [ -f $WHITELIST_DIR/web.conf ] && echo "CONFIGURADO" || echo "FALTANTE")
printf "  | %-20s | %-30s |\n" "llama-cli"     "$LLAMA_OK"
printf "  | %-20s | %-30s |\n" "Modelo activo" "$MODELO_OK"
printf "  | %-20s | %-30s |\n" "yap (comando)"  "$YAP_OK"
printf "  | %-20s | %-30s |\n" "notify-send"   "$NOTIFY_OK"
printf "  | %-20s | %-30s |\n" "Whitelist apps" "$APPS_OK"
printf "  | %-20s | %-30s |\n" "Whitelist web"  "$WEB_OK"
APPARMOR_OK=$(aa-status 2>/dev/null | grep -q "yap" && echo "ACTIVO" || echo "NO INSTALADO")
printf "  | %-20s | %-30s |\n" "AppArmor"       "$APPARMOR_OK"
echo "  +----------------------+--------------------------------+"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  ✓ YAP v$YAP_VERSION — Instalación completada"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Uso básico:"
echo "    yap Abre LibreOffice               # Abrir aplicación"
echo "    yap Busca https://wikipedia.org/...  # Webfetch + resumen"
echo "    yap Busca qué es Linux              # Búsqueda Wikipedia"
echo "    yap ¿Qué es Debian?                 # Consulta directa al LLM"
echo ""
echo "  Cambiar de rama:"
echo "    git checkout main         # 3B, ctx 4096, FP16  → ~3.5 GB RAM"
echo "    git checkout lowmem         # 3B, ctx 2048, Q8_0 → ~3.1 GB RAM"
echo "    git checkout ultra-lowmem   # 1B, ctx 2048, Q8_0 → ~1.8 GB RAM"
echo ""
echo "  El symlink en /usr/local/bin/yap apunta al repositorio."
echo "  El cambio de rama es inmediato, no requiere re-instalación."
echo ""
