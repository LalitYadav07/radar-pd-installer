#!/usr/bin/env bash
set -euo pipefail

DIST_REPO="${RADAR_PD_DIST_REPO:-https://github.com/LalitYadav07/radar-pd-installer.git}"
RAW_BASE="${RADAR_PD_RAW_BASE:-https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main}"
APP_REPO="${RADAR_PD_APP_REPO:-https://github.com/LalitYadav07/Impurity_detection_GSAS_ver6.git}"
PYTHON_BIN="${PYTHON_BIN:-python3.12}"
VENV_DIR="${RADAR_PD_VENV:-$HOME/radar-pd-env}"
SOURCE_DIR="${RADAR_PD_SOURCE_DIR:-$HOME/.local/share/radar-pd/source/Impurity_detection_GSAS_ver6}"
CACHE_HOME="${RADAR_PD_CACHE_HOME:-$HOME/.cache/radar-pd}"
CATALOGS="${RADAR_PD_CATALOGS:-all}"
BOOTSTRAP_DIR="${RADAR_PD_BOOTSTRAP_DIR:-$(pwd)/.radar-pd-bootstrap}"
PYTHON_INSTALL_DIR="${RADAR_PD_PYTHON_INSTALL_DIR:-$BOOTSTRAP_DIR/python}"
UV_BIN="${UV_BIN:-}"
RUNTIME_WHEEL="$RAW_BASE/wheelhouse/radar_pd_gsasii_runtime-0.0.1-cp312-cp312-linux_x86_64.whl"
LAUNCH_SCRIPT="${RADAR_PD_LAUNCH_SCRIPT:-$(pwd)/launch-radar-pd.sh}"
AUTO_APT="${RADAR_PD_AUTO_APT:-1}"
PREINSTALL_CPU_TORCH="${RADAR_PD_PREINSTALL_CPU_TORCH:-1}"
TORCH_INDEX_URL="${RADAR_PD_TORCH_INDEX_URL:-https://download.pytorch.org/whl/cpu}"
TORCH_SPEC="${RADAR_PD_TORCH_SPEC:-torch}"

apt_install_packages() {
  local packages=("$@")
  if [[ "${#packages[@]}" -eq 0 ]]; then
    return 0
  fi

  if ! command -v apt-get >/dev/null 2>&1; then
    echo "Missing required system package(s): ${packages[*]}" >&2
    echo "This installer can auto-install them only on apt-based Linux systems." >&2
    echo "Install the equivalent package(s) for your distribution and rerun." >&2
    return 1
  fi

  if [[ "$AUTO_APT" != "1" ]]; then
    echo "Missing required system package(s): ${packages[*]}" >&2
    echo "RADAR_PD_AUTO_APT=0 is set. Install them manually and rerun:" >&2
    echo "  sudo apt-get update && sudo apt-get install -y ${packages[*]}" >&2
    return 1
  fi

  echo "Installing required Ubuntu/Debian system package(s): ${packages[*]}"
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    if ! apt-get update; then
      return 1
    fi
    if ! DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"; then
      return 1
    fi
  elif command -v sudo >/dev/null 2>&1; then
    if ! sudo apt-get update; then
      return 1
    fi
    if ! sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y "${packages[@]}"; then
      return 1
    fi
  else
    echo "sudo is not available. Install the required package(s) manually and rerun:" >&2
    echo "  apt-get update && apt-get install -y ${packages[*]}" >&2
    return 1
  fi
}

bootstrap_python_with_uv() {
  echo "Bootstrapping a local Python 3.12 with uv under: $PYTHON_INSTALL_DIR"

  if [[ -z "$UV_BIN" ]]; then
    if command -v uv >/dev/null 2>&1; then
      UV_BIN="$(command -v uv)"
    else
      if ! command -v curl >/dev/null 2>&1; then
        echo "curl is required to install uv when Python 3.12 is missing or cannot create venvs." >&2
        exit 1
      fi
      mkdir -p "$BOOTSTRAP_DIR/uv"
      echo "Installing uv locally under: $BOOTSTRAP_DIR/uv"
      curl -LsSf https://astral.sh/uv/install.sh | UV_UNMANAGED_INSTALL="$BOOTSTRAP_DIR/uv" sh
      UV_BIN="$BOOTSTRAP_DIR/uv/uv"
    fi
  fi

  "$UV_BIN" python install 3.12 --install-dir "$PYTHON_INSTALL_DIR"
  PYTHON_BIN=""
  for candidate in "$PYTHON_INSTALL_DIR"/*/bin/python3.12; do
    if [[ -x "$candidate" ]]; then
      PYTHON_BIN="$candidate"
      break
    fi
  done
  if [[ -z "$PYTHON_BIN" ]]; then
    echo "uv installed Python 3.12, but no python3.12 executable was found under $PYTHON_INSTALL_DIR" >&2
    exit 1
  fi
  echo "Using bootstrapped Python: $PYTHON_BIN"
}

python_minor_version() {
  "$PYTHON_BIN" - <<'PYTHON_MINOR_VERSION'
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}")
PYTHON_MINOR_VERSION
}

check_python_venv() {
  local tmp_dir
  local log_file
  tmp_dir="$(mktemp -d)"
  log_file="$(mktemp)"
  if "$PYTHON_BIN" -m venv "$tmp_dir" >"$log_file" 2>&1; then
    rm -rf "$tmp_dir" "$log_file"
    return 0
  fi
  echo "Python venv preflight failed:" >&2
  sed 's/^/  /' "$log_file" >&2
  rm -rf "$tmp_dir" "$log_file"
  return 1
}

check_shared_library() {
  local library="$1"
  "$PYTHON_BIN" - "$library" <<'PYTHON_SHARED_LIBRARY'
import ctypes
import sys

try:
    ctypes.CDLL(sys.argv[1])
except OSError as exc:
    raise SystemExit(str(exc))
PYTHON_SHARED_LIBRARY
}

if ! command -v "$PYTHON_BIN" >/dev/null 2>&1; then
  echo "Python 3.12 executable '$PYTHON_BIN' was not found."
  bootstrap_python_with_uv
fi

"$PYTHON_BIN" - <<'PYTHON_VERSION_CHECK'
import sys
if sys.version_info[:2] != (3, 12):
    raise SystemExit(
        f"RADAR-PD requires Python 3.12, got "
        f"{sys.version_info.major}.{sys.version_info.minor} at {sys.executable}"
    )
PYTHON_VERSION_CHECK

if ! command -v git >/dev/null 2>&1; then
  echo "git is required to fetch the RADAR-PD source checkout." >&2
  exit 1
fi

venv_ok=0
if check_python_venv; then
  venv_ok=1
else
  python_mm="$(python_minor_version)"
  if apt_install_packages "python${python_mm}-venv" && check_python_venv; then
    venv_ok=1
  fi
fi

if [[ "$venv_ok" != "1" ]]; then
  echo "Falling back to uv-managed Python because $PYTHON_BIN cannot create a venv with pip."
  bootstrap_python_with_uv
  check_python_venv
fi

if ! check_shared_library "libgfortran.so.5" >/dev/null 2>&1; then
  echo "libgfortran.so.5 is missing; GSAS-II compiled modules require it."
  if ! apt_install_packages "libgfortran5"; then
    echo "Unable to install libgfortran5 automatically. Install it manually and rerun:" >&2
    echo "  sudo apt-get update && sudo apt-get install -y libgfortran5" >&2
    exit 1
  fi
  check_shared_library "libgfortran.so.5"
fi

if [[ "${RADAR_PD_PREFLIGHT_ONLY:-0}" == "1" ]]; then
  echo "RADAR-PD Linux installer preflight passed."
  exit 0
fi

mkdir -p "$CACHE_HOME"
export RADAR_PD_CACHE_HOME="$CACHE_HOME"

echo "Creating/updating virtual environment: $VENV_DIR"
"$PYTHON_BIN" -m venv "$VENV_DIR"
"$VENV_DIR/bin/python" -m pip install --upgrade pip

if [[ "$PREINSTALL_CPU_TORCH" == "1" ]]; then
  echo "Installing CPU-only PyTorch from: $TORCH_INDEX_URL"
  "$VENV_DIR/bin/python" -m pip install --index-url "$TORCH_INDEX_URL" "$TORCH_SPEC"
else
  echo "Skipping CPU-only PyTorch preinstall because RADAR_PD_PREINSTALL_CPU_TORCH=$PREINSTALL_CPU_TORCH."
fi

echo "Installing RADAR-PD from GitHub..."
"$VENV_DIR/bin/python" -m pip install \
  "radar-pd-gsasii-runtime @ $RUNTIME_WHEEL" \
  "radar-pd[app] @ git+$DIST_REPO#subdirectory=radar_pd"
"$VENV_DIR/bin/python" -m pip install --upgrade --force-reinstall --no-deps \
  "radar-pd @ git+$DIST_REPO#subdirectory=radar_pd"

if [[ -d "$SOURCE_DIR/.git" ]]; then
  echo "Updating RADAR-PD source checkout: $SOURCE_DIR"
  git -C "$SOURCE_DIR" pull --ff-only
else
  echo "Cloning RADAR-PD source checkout: $SOURCE_DIR"
  mkdir -p "$(dirname "$SOURCE_DIR")"
  git clone --depth 1 "$APP_REPO" "$SOURCE_DIR"
fi

echo "Running GSAS-II smoke diagnostic..."
"$VENV_DIR/bin/radar-pd" doctor --smoke-gsas-project

if [[ "${RADAR_PD_SKIP_CATALOGS:-0}" == "1" ]]; then
  echo "Skipping built-in catalog download because RADAR_PD_SKIP_CATALOGS=1."
else
  catalog_args=(install-catalogs --source-root "$SOURCE_DIR" --catalog "$CATALOGS")
  if [[ "${RADAR_PD_FORCE_CATALOGS:-0}" == "1" ]]; then
    catalog_args+=(--force)
  fi
  echo "Installing built-in RADAR-PD catalogs: $CATALOGS"
  "$VENV_DIR/bin/radar-pd" "${catalog_args[@]}"
fi

mkdir -p "$(dirname "$LAUNCH_SCRIPT")"
cat > "$LAUNCH_SCRIPT" <<LAUNCH_SCRIPT_CONTENT
#!/usr/bin/env bash
set -euo pipefail

PORT="\${1:-8501}"
ADDRESS="\${RADAR_PD_ADDRESS:-127.0.0.1}"
export RADAR_PD_CACHE_HOME="$CACHE_HOME"

exec "$VENV_DIR/bin/radar-pd" ui --source-root "$SOURCE_DIR" --address "\$ADDRESS" --port "\$PORT"
LAUNCH_SCRIPT_CONTENT
chmod +x "$LAUNCH_SCRIPT"

echo
echo "Install complete."
echo
echo "Activate:"
echo "  source \"$VENV_DIR/bin/activate\""
echo
echo "Launch GUI:"
echo "  \"$LAUNCH_SCRIPT\""
echo "  \"$LAUNCH_SCRIPT\" 8502"
echo
echo "If catalogs are not present yet, install/copy them after activation, for example:"
echo "  RADAR_PD_CACHE_HOME=\"$CACHE_HOME\" radar-pd install-data --source /path/to/catalog --name standard"
