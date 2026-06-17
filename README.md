# RADAR-PD Installer

[![Build Windows GSAS-II runtime wheel](https://github.com/LalitYadav07/radar-pd-installer/actions/workflows/build-windows-runtime.yml/badge.svg)](https://github.com/LalitYadav07/radar-pd-installer/actions/workflows/build-windows-runtime.yml)

RADAR-PD Installer provides a self-contained installation path for the RADAR-PD
graphical application and command-line launcher on Linux and native Windows.

The installer creates a local Python environment, installs the RADAR-PD launcher
package, installs a bundled GSAS-II runtime wheel for the host platform, clones
the RADAR-PD application source, runs a GSAS-II smoke diagnostic, and downloads
the built-in neutron and X-ray search catalogs before reporting success.

## Platform Support

| Platform | Status | Runtime wheel |
| --- | --- | --- |
| Linux x86_64 | Supported | `radar_pd_gsasii_runtime-0.0.1-cp312-cp312-linux_x86_64.whl` |
| Windows x86_64 | Supported | `radar_pd_gsasii_runtime-0.0.1-cp312-cp312-win_amd64.whl` |

Both installers require internet access for Python dependencies and source
checkout. If Python 3.12 is not available, the installers bootstrap a local
Python 3.12 with `uv`.

On apt-based Linux systems, the installer also checks for common system
runtime packages needed by Python virtual environments and GSAS-II binaries.
If missing, it attempts to install them with `sudo apt-get`:

```bash
sudo apt-get update
sudo apt-get install -y python3.12-venv libgfortran5
```

Set `RADAR_PD_AUTO_APT=0` to disable this automatic apt step and receive the
manual command instead.

If an existing Python 3.12 is present but cannot create virtual environments
with pip, the Linux installer first tries the apt repair above. If that does
not fix the active Python, it falls back to a local uv-managed Python 3.12 under
the install bootstrap directory.

The default install also downloads the built-in RADAR-PD neutron and X-ray
catalog archives from the configured Google Drive sources. Use the documented
skip options below if you need an app-only install.

On Linux, the installer preinstalls CPU-only PyTorch from the official PyTorch
CPU wheel index before installing RADAR-PD. This prevents pip from pulling large
CUDA wheels on small CPU-only cloud or workstation images. Set
`RADAR_PD_PREINSTALL_CPU_TORCH=0` if you intentionally want pip/PyPI to choose
the Torch build, or set `RADAR_PD_TORCH_SPEC` / `RADAR_PD_TORCH_INDEX_URL` to
pin a specific CPU Torch build.

## Quick Start: Linux

Install into the current directory:

```bash
mkdir -p radar-pd-local
cd radar-pd-local

curl -LsSf https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.sh \
  | RADAR_PD_VENV="$PWD/env" \
    RADAR_PD_SOURCE_DIR="$PWD/source" \
    RADAR_PD_CACHE_HOME="$PWD/cache" \
    RADAR_PD_BOOTSTRAP_DIR="$PWD/.bootstrap" \
    bash
```

Install only one built-in catalog:

```bash
curl -LsSf https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.sh \
  | RADAR_PD_CATALOGS=neutron bash
```

Skip catalog download:

```bash
curl -LsSf https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.sh \
  | RADAR_PD_SKIP_CATALOGS=1 bash
```

Disable automatic apt installation and print missing system packages instead:

```bash
curl -LsSf https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.sh \
  | RADAR_PD_AUTO_APT=0 bash
```

Use PyPI/default Torch resolution instead of preinstalling CPU-only Torch:

```bash
curl -LsSf https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.sh \
  | RADAR_PD_PREINSTALL_CPU_TORCH=0 bash
```

Launch:

```bash
./launch-radar-pd.sh
```

Install into default user locations instead:

```bash
curl -LsSf https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.sh | bash
```

Default locations:

```text
~/radar-pd-env
~/.local/share/radar-pd/source/Impurity_detection_GSAS_ver6
~/.cache/radar-pd
```

## Quick Start: Windows

Run in PowerShell:

```powershell
mkdir radar-pd-local
cd radar-pd-local

iwr https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.ps1 -OutFile install.ps1
powershell -ExecutionPolicy Bypass -File .\install.ps1 -InstallRoot $PWD
```

Install only one built-in catalog:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -InstallRoot $PWD -Catalogs neutron
```

Skip catalog download:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -InstallRoot $PWD -SkipCatalogs
```

Launch:

```powershell
powershell -ExecutionPolicy Bypass -File .\launch-radar-pd.ps1
```

If port `8501` is already in use, the generated launcher chooses the next free
port in the `8501-8599` range. You can also request a port explicitly:

```powershell
powershell -ExecutionPolicy Bypass -File .\launch-radar-pd.ps1 -Port 8502
```

## Installed Layout

For local-folder installs:

```text
radar-pd-local/
  env/          Python virtual environment
  source/       RADAR-PD application checkout with data/database_* catalogs
  cache/        RADAR-PD data cache
  .bootstrap/   uv and managed Python, only if Python 3.12 was missing
  launch-radar-pd.sh or launch-radar-pd.ps1
```

The installation is intentionally isolated. Removing the install directory
removes the environment, cloned source, cache, and bootstrap files.

## Diagnostics

The installers run this automatically:

```bash
radar-pd doctor --smoke-gsas-project
```

It verifies:

- Python 3.12 is active.
- The bundled GSAS-II runtime can be imported.
- A minimal GSAS-II `.gpx` project can be created and saved.
- Optional user data packs in the RADAR-PD cache can be discovered.

Built-in neutron/X-ray catalog layout is validated by `radar-pd install-catalogs`
during installation.

Run it manually any time:

```bash
radar-pd doctor --smoke-gsas-project
```

Run only the Linux installer preflight without creating the RADAR-PD
environment or downloading app dependencies:

```bash
curl -LsSf https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.sh \
  | RADAR_PD_PREFLIGHT_ONLY=1 bash
```

## Data Catalogs

The default installers download the built-in RADAR-PD catalogs into the cloned
application checkout:

```text
source/data/database_neutron
source/data/database_xray
```

Install or repair them manually:

```bash
radar-pd install-catalogs --source-root /path/to/Impurity_detection_GSAS_ver6 --catalog all
```

Use `--catalog neutron` or `--catalog xray` to install one database, and use
`--force` to replace an existing catalog directory.

Additional user database packs can still be installed into the RADAR-PD cache
with:

```bash
radar-pd install-data --source /path/to/catalog --name standard
```

The launcher package also supports Hugging Face dataset downloads:

```bash
radar-pd install-data --hf-repo owner/radar-pd-data --name standard
```

For reproducible deployments, record the dataset source, revision, and checksum
alongside the RADAR-PD run outputs.

## Manual Pip Installation

Linux:

```bash
sudo apt-get update
sudo apt-get install -y python3.12-venv libgfortran5
python3.12 -m venv radar-pd-env
source radar-pd-env/bin/activate
python -m pip install --upgrade pip
python -m pip install --index-url https://download.pytorch.org/whl/cpu torch
python -m pip install \
  "radar-pd-gsasii-runtime @ https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/wheelhouse/radar_pd_gsasii_runtime-0.0.1-cp312-cp312-linux_x86_64.whl" \
  "radar-pd[app] @ git+https://github.com/LalitYadav07/radar-pd-installer.git#subdirectory=radar_pd"
git clone --depth 1 https://github.com/LalitYadav07/Impurity_detection_GSAS_ver6.git source
radar-pd doctor --smoke-gsas-project
radar-pd ui --source-root "$PWD/source"
```

Windows PowerShell:

```powershell
python -m venv env
.\env\Scripts\python.exe -m pip install --upgrade pip
.\env\Scripts\python.exe -m pip install `
  "radar-pd-gsasii-runtime @ https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/wheelhouse/radar_pd_gsasii_runtime-0.0.1-cp312-cp312-win_amd64.whl" `
  "radar-pd[app] @ git+https://github.com/LalitYadav07/radar-pd-installer.git#subdirectory=radar_pd"
git clone --depth 1 https://github.com/LalitYadav07/Impurity_detection_GSAS_ver6.git source
.\env\Scripts\radar-pd.exe doctor --smoke-gsas-project
.\env\Scripts\radar-pd.exe ui --source-root "$PWD\source"
```

## Runtime Wheels

The GSAS-II runtime wheels are platform-specific and Python 3.12-specific.

- Linux wheel: built from the pinned local RADAR-PD GSAS-II runtime.
- Windows wheel: built by GitHub Actions from the official GSAS-II source tree
  plus the official GSAS-II `win_64_p3.12_n2.2` binary bundle.

The Windows build workflow installs the generated wheel into a clean virtual
environment and runs:

```powershell
radar-pd doctor --smoke-gsas-project
```

## Troubleshooting

### Python 3.12 is missing

No action is normally required. The installers bootstrap Python 3.12 with `uv`.

If you already have Python 3.12 in a nonstandard location:

Linux:

```bash
curl -LsSf https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.sh \
  | PYTHON_BIN=/path/to/python3.12 bash
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 `
  -InstallRoot $PWD `
  -PythonBin C:\Path\To\python.exe
```

### Ubuntu reports `ensurepip is not available`

The system Python can exist without the venv support package. The Linux
installer now checks this before creating the RADAR-PD environment and attempts
to install the matching package automatically on apt-based systems. If the
active Python still cannot create a venv after that, the installer falls back
to a local uv-managed Python 3.12.

Manual fix:

```bash
sudo apt-get update
sudo apt-get install -y python3.12-venv
```

### GSAS-II reports `pyspg not found` or `pypowder is not available`

If the compiled GSAS-II modules exist but Linux cannot load them, the usual
missing dependency is `libgfortran.so.5`. The Linux installer now checks this
before the GSAS-II smoke test and attempts to install `libgfortran5`
automatically on apt-based systems.

Manual fix:

```bash
sudo apt-get update
sudo apt-get install -y libgfortran5
```

### Torch tries to download large CUDA wheels

The Linux installer preinstalls CPU-only Torch by default:

```bash
python -m pip install --index-url https://download.pytorch.org/whl/cpu torch
```

For a GPU machine with enough disk space, opt out and let PyPI choose the Torch
build:

```bash
curl -LsSf https://raw.githubusercontent.com/LalitYadav07/radar-pd-installer/main/install.sh \
  | RADAR_PD_PREINSTALL_CPU_TORCH=0 bash
```

### Windows certificate error while bootstrapping Python

The Windows installer sets `UV_NATIVE_TLS=1` and invokes `uv --native-tls` so
managed workstations can use the Windows certificate store.

If this still fails, install Python 3.12 manually and rerun the installer with
`-PythonBin`.

### Streamlit port is busy

Use a different port:

Linux:

```bash
./launch-radar-pd.sh 8502
```

Windows:

```powershell
powershell -ExecutionPolicy Bypass -File .\launch-radar-pd.ps1 -Port 8502
```

### Git is missing

Install Git first. The installer uses Git to clone the RADAR-PD application
source checkout.

## Repository Contents

```text
install.sh                         Linux installer
install.ps1                        Windows installer
radar_pd/                          Python launcher package
wheelhouse/                        Platform-specific GSAS-II runtime wheels
build_runtime_wheel.py             Runtime wheel builder used by CI
.github/workflows/                 Runtime wheel build and smoke-test workflow
```

## Related Projects

- RADAR-PD application source: <https://github.com/LalitYadav07/Impurity_detection_GSAS_ver6>
- GSAS-II: <https://github.com/AdvancedPhotonSource/GSAS-II>
