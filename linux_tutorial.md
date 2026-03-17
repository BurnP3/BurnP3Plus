---
layout: default
title: Running BurnP3+ on Linux
---

# Running **BurnP3+** on Linux

### Here we provide a complete guide to setting up and running **BurnP3+** on Linux using the SyncroSim console and the `rsyncrosim` R package — no GUI required.

**BurnP3+** is a <a href="https://syncrosim.com/" target="_blank">SyncroSim</a> package that simulates wildfire ignition, spread, and suppression over many thousands of iterations to produce spatially explicit burn probability maps. It uses <a href="https://github.com/CWFMF/FireSTARR" target="_blank">FireSTARR</a> (or other fire growth engines) under the hood and requires spatial inputs including weather streams, fuel grids, topography, and ignition zones. Full **BurnP3+** documentation is available at <a href="https://burnp3.github.io/BurnP3Plus/" target="_blank">https://burnp3.github.io/BurnP3Plus</a>.

Most **BurnP3+** workflows assume you are working through the SyncroSim Studio graphical interface on Windows. However, if you are running analyses on a Linux server, a high-performance computing (HPC) cluster, or an automated pipeline, you need to work headlessly. This guide walks through everything required to get **BurnP3+** running on Linux — from a bare system all the way through a complete model run using both the SyncroSim console and the `rsyncrosim` R package. Throughout this tutorial, terminology associated with SyncroSim will be italicized, and whenever possible, links will be provided to the SyncroSim <a href="https://docs.syncrosim.com/home/index.html" target="_blank">online documentation</a>.

<br>

## Linux Tutorial

This tutorial will walk you through running **BurnP3+** on Linux. The steps include:

1. <a href="#step1"> Installing SyncroSim on Linux </a>
    * <a href="#mono"> Install Mono </a>
    * <a href="#miniconda"> Install Miniconda </a>
    * <a href="#syncrosim"> Install SyncroSim </a>
    * <a href="#gdal"> Set up the GDAL Conda environment </a>
    * <a href="#env"> Configure your environment for runtime </a>
2. <a href="#step2"> Installing <b>BurnP3+</b> and FireSTARR </a>
3. <a href="#step3"> Running <b>BurnP3+</b> from the SyncroSim console </a>
    * <a href="#runcontrol"> Configuring run control and multiprocessing </a>
    * <a href="#runscenario"> Running a scenario </a>
    * <a href="#transformers"> Running individual transformers </a>
    * <a href="#slurm"> Example SLURM job script </a>
4. <a href="#step4"> Troubleshooting </a>

<br>

<p id="step1"> <h2> <b>Step 1: Installing SyncroSim on Linux</b> </h2> </p>

Before you begin, make sure the following are in place:

- A Linux system (Ubuntu 20.04+ recommended; other distributions supported)
- `sudo` or administrator access (or `$HOME/bin` access on shared systems)
- Internet access for downloading packages (or pre-downloaded files for airgapped installs)
- At least 4 GB of free disk space
- **Mono** — the open-source .NET runtime SyncroSim uses on Linux
- **Miniconda** — for the GDAL C# bindings required for spatially explicit runs

> **Why Mono?** SyncroSim is a .NET application. On Linux, it runs via Mono, which provides the runtime environment. On Windows, the native .NET runtime is used instead.

> **Why Conda?** SyncroSim needs a helper tool called GDAL to read and write spatial raster files. On Linux, the easiest way to install GDAL with the correct bindings is through a Conda environment, which avoids conflicts with system libraries.

<br>

<p id="mono"> <h3> Install Mono </h3> </p>

Mono provides the .NET runtime needed to execute SyncroSim on Linux.

**Ubuntu / Debian**

On Ubuntu or Debian-based systems, add the official Mono repository and install using the `gpg --keyring` method (required on Ubuntu 22.04 and later):

```bash
# Install GPG dependencies (required on minimal Ubuntu cloud images)
sudo apt-get update
sudo apt-get install -y gnupg2 dirmngr

# Initialize the gnupg directory for root
sudo gpg --list-keys

# Import the Mono signing key into a dedicated keyring file
sudo gpg --no-default-keyring \
    --keyring /usr/share/keyrings/mono-keyring.gpg \
    --keyserver hkp://keyserver.ubuntu.com:80 \
    --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF

# Add the Mono repository, referencing the keyring
echo "deb [signed-by=/usr/share/keyrings/mono-keyring.gpg] \
    https://download.mono-project.com/repo/ubuntu stable-focal main" \
    | sudo tee /etc/apt/sources.list.d/mono-official-stable.list

sudo apt-get update
sudo apt-get install -y mono-complete
```

**RHEL / Rocky Linux / Fedora**

On Red Hat-based systems, Mono is installed via an RPM repository. Follow the official instructions for your distribution at <a href="https://www.mono-project.com/download/stable/" target="_blank">mono-project.com/download/stable</a>; the steps vary slightly between RHEL versions.

> **Other distributions (Arch, openSUSE, etc.):** Use your distribution's package manager to install `mono-complete` or an equivalent package. Refer to the Mono project documentation for distro-specific guidance.

Always install the **latest** version of Mono — there is no hard minimum, but older builds can exhibit compatibility issues with SyncroSim. Verify your installation:

```bash
mono --version
# Mono JIT compiler version 6.x.x.xxx
```

<br>

<p id="miniconda"> <h3> Install Miniconda </h3> </p>

Conda is used to set up the GDAL environment that SyncroSim needs for spatial operations. Install Miniconda, which is a lightweight version of the full Conda distribution:

```bash
curl -fsSL https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
    -o /tmp/miniconda.sh
bash /tmp/miniconda.sh -b -p $HOME/miniconda3
rm /tmp/miniconda.sh

# Initialize conda for your shell
$HOME/miniconda3/bin/conda init bash
source ~/.bashrc
```

It is good practice to configure `conda-forge` as your primary channel and disable the default channel to avoid package conflicts:

```bash
conda config --remove channels defaults 2>/dev/null || true
conda config --add channels conda-forge
conda config --set channel_priority strict
```

<br>

<p id="syncrosim"> <h3> Install SyncroSim </h3> </p>

Download and extract the SyncroSim Linux build. You can find the latest version number on the <a href="https://syncrosim.com/download/" target="_blank">SyncroSim downloads page</a>:

```bash
# Download SyncroSim (adjust version as needed)
curl -fsSL "https://downloads.syncrosim.com/3-1-28/syncrosim-linux-3-1-28.zip" \
    -o /tmp/syncrosim.zip

unzip -q /tmp/syncrosim.zip -d $HOME/syncrosim
rm /tmp/syncrosim.zip

# Make the executables executable
chmod 755 $HOME/syncrosim/SyncroSim.Console.exe \
          $HOME/syncrosim/SyncroSim.PackageManager.exe
```

For convenience, create shell wrappers so you can invoke `ssim` and `ssimpm` from anywhere on the system:

```bash
SYNCROSIM_DIR="$HOME/syncrosim"

sudo tee /usr/local/bin/ssim > /dev/null << EOF
#!/bin/bash
mono ${SYNCROSIM_DIR}/SyncroSim.Console.exe "\$@"
EOF

sudo tee /usr/local/bin/ssimpm > /dev/null << 'EOF'
#!/bin/bash
mono ${SYNCROSIM_DIR}/SyncroSim.PackageManager.exe "$@"
EOF

sudo chmod +x /usr/local/bin/ssim /usr/local/bin/ssimpm
```

> **Note:** If you are working in a shared environment or HPC cluster without `sudo` access, add `$HOME/bin` to your `PATH` and place the wrapper scripts there instead.

<br>

<p id="gdal"> <h3> Set up the GDAL Conda environment </h3> </p>

SyncroSim needs **GDAL** to work with spatial raster files (such as `.tif`). On Linux, the easiest way to install it is through a Conda environment. The steps below create a small, isolated environment just for this purpose — think of it as a self-contained toolkit that SyncroSim can reach into when it needs to read or write spatial data.

```bash
# Create a new environment named "gdal-mono" — do NOT install into base
conda create -y --name gdal-mono gdal-csharp=1.1.1

# Copy the GDAL helper files into the SyncroSim folder
cp $HOME/miniconda3/envs/gdal-mono/lib/*_csharp.dll $HOME/syncrosim/
cp $HOME/miniconda3/envs/gdal-mono/lib/*.so* $HOME/syncrosim/

# Remove the conda-forge SQLite libraries; Mono requires the system version
rm $HOME/syncrosim/libsqlite3.so*
```

> **What this does:** The `gdal-csharp` package provides the "glue" between SyncroSim (a .NET application) and GDAL (a C library). Copying the `.dll` files and shared library `.so` files into the SyncroSim folder makes them available when SyncroSim starts up.

> **Important:** Always use a **named environment** (like `gdal-mono`) rather than installing into `base`. Installing GDAL into the base environment has been found to cause library conflicts that prevent SyncroSim from loading spatial tools correctly.

Now, tell SyncroSim where your Conda installation lives:

```bash
ssim --conda --path="$HOME/miniconda3"
```

This registers the Conda path in SyncroSim's configuration so it can locate the environment at runtime.

<br>

<p id="env"> <h3> Configure your environment for runtime </h3> </p>

Before running any spatially explicit model, activate the `gdal-mono` environment and set the library search path:

```bash
conda activate gdal-mono
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}
export PROJ_LIB=/usr/share/proj
```

> **What `LD_LIBRARY_PATH` does:** This tells Linux where to find the GDAL shared libraries bundled in your Conda environment. Without it, SyncroSim will not be able to load the spatial tools and map-related operations will fail. If you see errors about missing libraries, this is usually the first thing to check.

Add these lines to your `~/.bashrc` or to a project-specific activation script if you are running **BurnP3+** frequently.

### Install R Package Dependencies

BurnP3+ and FireSTARR require several R packages. Install them from source to ensure they compile against your system libraries:
```bash
# Extract all dependencies from installed package scripts and install
PACKAGES=$(grep -rh "library\|require" \
    $HOME/syncrosim/Packages/burnP3Plus/2.6.5/*.R \
    $HOME/syncrosim/Packages/burnP3PlusFireSTARR/1.5.5/*.R 2>/dev/null \
    | grep -oP "(?<=library\()['\"]?[A-Za-z0-9.]+['\"]?(?=\))|(?<=require\()['\"]?[A-Za-z0-9.]+['\"]?(?=\))" \
    | tr -d "'\"" | sort -u)

# Verify the package list before installing
echo "$PACKAGES"

Rscript -e "
pkgs <- c($(echo "$PACKAGES" | sed "s/.*/'&'/" | paste -sd,))
pkgs <- pkgs[!pkgs %in% rownames(installed.packages())]
if (length(pkgs) > 0) install.packages(pkgs, type='source', repos='https://cloud.r-project.org')
"
```

> Review the output of `echo "$PACKAGES"` before proceeding. It should be a clean list of R package names with no unexpected characters or blank lines. If the list looks correct, run the `Rscript` command to install.

> **Why install from source?** Pre-built R package binaries may link against system library versions that conflict with your Ubuntu installation. Installing from source ensures packages compile against the libraries actually present on your system. Note that the `arrow` package can take 10–15 minutes to compile.

<br>

<p id="step2"> <h2> <b>Step 2: Installing BurnP3+ and FireSTARR</b> </h2> </p>

**BurnP3+** is distributed as a SyncroSim *package*. The FireSTARR fire growth engine is distributed as a companion *package*. There are two ways to install them: directly from the SyncroSim package server (recommended), or from a local file (useful for airgapped or offline systems).

**Install from the package server**

The easiest approach is to install directly using the SyncroSim package manager, which downloads and installs the *package* in one step:

```bash
# Install BurnP3+ from the package server
ssimpm --install=burnP3Plus --version=2.6.5

# Install the FireSTARR companion package
ssimpm --install=burnP3PlusFireSTARR --version=1.5.5
```

> **Tip:** Check the <a href="https://github.com/BurnP3/BurnP3Plus/releases" target="_blank">BurnP3Plus GitHub releases page</a> for the current version numbers of **BurnP3+** and its compatible FireSTARR release. Always install versions that are listed as compatible with each other.

Verify the *packages* installed correctly:

```bash
ssimpm --list --installed
```

You should see `burnP3Plus` and `burnP3PlusFireSTARR` in the output.

**Offline / Airgapped Install**

If your server does not have internet access, download the *package* files on another machine and transfer them manually. Download the `.ssimpkg` files from the <a href="https://github.com/BurnP3/BurnP3Plus/releases" target="_blank">BurnP3Plus GitHub releases page</a>, then copy them to the server using `scp`.

First, on the server, create the destination directory:
```bash
mkdir -p $HOME/burnp3
```

Then, on your local machine, transfer the files:
```bash
scp -i /path/to/your-key.pem \
    /path/to/burnP3Plus-2-6-5.ssimpkg \
    /path/to/burnP3PlusFireSTARR-1-5-5.ssimpkg \
    ubuntu@<server-ip>:$HOME/burnp3/
```

> ***Windows users (PowerShell):** The backslash line continuation used above is bash syntax and will not work in PowerShell. Use backticks for line continuation, quote the filenames, and use the literal `/home/ubuntu` path instead of `$HOME` (which PowerShell will not expand on the remote side):*
> ```powershell
> scp -i C:\path\to\your-key.pem `
>     "C:\path\to\burnP3Plus-2-6-5.ssimpkg" `
>     "C:\path\to\burnP3PlusFireSTARR-1-5-5.ssimpkg" `
>     ubuntu@<server-ip>:/home/ubuntu/burnp3/
> ```

Replace `/path/to/your-key.pem` with your SSH key, `/path/to/` with the local directory containing the `.ssimpkg` files, and `<server-ip>` with your server's IP address or hostname.

Then, back on the server, install from the local package files:
```bash
# Run this on the SERVER
ssimpm --finstall="$HOME/burnp3/burnP3Plus-2-6-5.ssimpkg"
ssimpm --finstall="$HOME/burnp3/burnP3PlusFireSTARR-1-5-5.ssimpkg"
ssimpm --list --installed
```

<br>

<p id="step3"> <h2> <b>Step 3: Running BurnP3+ from the SyncroSim console</b> </h2> </p>

With SyncroSim and **BurnP3+** installed, you can run any **BurnP3+** *library* entirely from the command line. This is the approach you would use in a batch script, cron job, or HPC job submission. The full SyncroSim console reference is available at <a href="https://docs.syncrosim.com/reference/console_core.html" target="_blank">docs.syncrosim.com/reference/console_core.html</a>.

A SyncroSim *library* (`.ssim` file) is the top-level container for a modeling project. Inside a *library*, you have one or more *projects*, and within each *project*, one or more *scenarios*. A *scenario* defines all the model inputs and configuration for a single run. When running from the console, you reference *scenarios* by their **scenario ID** — an integer assigned when the *scenario* is created. To list the *scenarios* available in a *library*:

```bash
ssim --lib=/path/to/burnp3.ssim --list --scenarios
```

<br>

<p id="runcontrol"> <h3> Configuring run control and multiprocessing </h3> </p>

Before running a *scenario*, configure how many fire iterations to run and how many CPU cores to use. In SyncroSim, these settings live in *datasheets* — named tables that hold model configuration. You can import *datasheet* values from CSV files using the console.

Create a `Run_Control.csv` with your iteration settings:

```bash
cat > $HOME/burnp3/Run_Control.csv << 'EOF'
MinimumIteration,MaximumIteration,MinimumTimestep,MaximumTimestep
1,10000,1,1
EOF
```

Create a `Multiprocessing.csv` to enable parallel processing:

```bash
cat > $HOME/burnp3/Multiprocessing.csv << 'EOF'
EnableMultiprocessing,MaximumJobs,EnableMultiScenario,EnableCopyExternalFiles
Yes,8,,
EOF
```

Then import them into your *scenario* before running:

```bash
SSIMLIB=/path/to/your/burnp3.ssim

ssim --import --lib=$SSIMLIB --sheet=burnP3Plus_RunControl \
     --sid=1 --file=$HOME/burnp3/Run_Control.csv

ssim --import --lib=$SSIMLIB --sheet=core_Multiprocessing \
     --sid=1 --file=$HOME/burnp3/Multiprocessing.csv
```

Set `MaximumJobs` to match the number of CPU cores you want to use. On an HPC cluster, this should match the number of cores allocated to your job (e.g., `$SLURM_CPUS_PER_TASK`).

<br>

<p id="runscenario"> <h3> Running a scenario </h3> </p>

```bash
# Activate the GDAL environment first
conda activate gdal-mono
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}

# Run scenario with ID 1 in your library
ssim --lib=$SSIMLIB --run --sid=1
```

The table below summarizes the most useful console flags. For a complete reference, see <a href="https://docs.syncrosim.com/reference/console_core.html" target="_blank">docs.syncrosim.com/reference/console_core.html</a>.

| Flag | Description |
|---|---|
| `--lib=<path>` | Path to the `.ssim` *library* file |
| `--run` | Execute a model run |
| `--sid=<id>` | *Scenario* ID to run |
| `--pid=<id>` | *Project* ID (useful for project-level operations) |
| `--list` | List *scenarios* or *projects* in the *library* |
| `--export` | Export data from a *scenario* |
| `--import` | Import data into a *scenario* |
| `--sheet=<name>` | *Datasheet* name (used with `--import` / `--export`) |
| `--file=<path>` | CSV file path (used with `--import` / `--export`) |
| `--trx=<name>` | Run a specific transformer by name |
| `--inplace` | Write results back to the parent *scenario* |
| `--verbose` | Stream log output to the console during a run |

<br>

<p id="transformers"> <h3> Running individual transformers </h3> </p>

**BurnP3+** runs a pipeline of processing steps called **transformers**. Normally, running a *scenario* executes all transformers in sequence automatically. However, you can also run each transformer individually — this is useful for debugging, restarting a failed run mid-pipeline, or inspecting intermediate outputs.

A full **BurnP3+** run consists of four stages:

- **Stage 1 — Generate Ignitions**: Determines where fires start based on your ignition probability inputs
- **Stage 2 — Generate Burning Conditions**: Assigns weather streams to each fire iteration
- **Stage 3 — Fire Growth (FireSTARR)**: Simulates fire spread across the landscape for each iteration
- **Stage 4 — Burn Probability**: Aggregates fire perimeters across iterations to produce the final probability map

```bash
SSIMLIB=/path/to/your/burnp3.ssim

# Stage 1 — Generate ignition locations
ssim --lib=$SSIMLIB --run --sid=1 \
     --trx=burnP3Plus_generateIgnitions --inplace --verbose

# Stage 2 — Generate burning conditions (weather)
ssim --lib=$SSIMLIB --run --sid=1 \
     --trx=burnP3Plus_generateBurningConditions --inplace --verbose

# Stage 3 — Run fire growth (FireSTARR)
ssim --lib=$SSIMLIB --run --sid=1 \
     --trx=burnP3PlusFireSTARR_fireGrowthFireSTARR --inplace --verbose

# Stage 4 — Compute burn probability
ssim --lib=$SSIMLIB --run --sid=1 \
     --trx=burnP3Plus_burnProbability --inplace
```

> **`--inplace`** writes results back into the parent *scenario* rather than creating a new result *scenario*. Use this when running transformers individually to ensure results accumulate correctly.

> **`--verbose`** streams the transformer's log output to the console as it runs, which makes it easier to follow progress and diagnose errors.

<br>

<p id="slurm"> <h3> Example SLURM job script </h3> </p>

If you are running **BurnP3+** on an HPC cluster running SLURM, a minimal job script looks like this:

```bash
#!/bin/bash
#SBATCH --job-name=burnp3_run
#SBATCH --cpus-per-task=16
#SBATCH --mem=64G
#SBATCH --time=12:00:00
#SBATCH --output=burnp3_%j.out
#SBATCH --error=burnp3_%j.err

# Load user environment
source ~/.bashrc
conda activate gdal-mono
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}
export PROJ_LIB=/usr/share/proj

SSIMLIB=$HOME/projects/burnp3/my_project.ssim

# Import multiprocessing config to use all allocated cores
cat > /tmp/mp.csv << EOF
EnableMultiprocessing,MaximumJobs,EnableMultiScenario,EnableCopyExternalFiles
Yes,$SLURM_CPUS_PER_TASK,,
EOF

ssim --import --lib=$SSIMLIB --sheet=core_Multiprocessing \
     --sid=1 --file='/tmp/mp.csv'

# Run BurnP3+
ssim --lib=$SSIMLIB --run --sid=1

echo "BurnP3+ run complete."
```

> **Note:** Replace `$HOME/projects/` with the appropriate path for your cluster. Many HPC systems provide a `$WORK` or `$SCRATCH`-equivalent variable for project storage — check your cluster's documentation for the recommended location for large data files.

Submit with:

```bash
sbatch run_burnp3.sh
```

<br>

<p id="step4"> <h2> <b>Step 4: Troubleshooting</b> </h2> </p>

**GDAL load failures**

*Symptom:* SyncroSim errors on startup or when opening a spatial *library*, with messages like `Unable to load DLL 'gdal_csharp'` or `GDAL not found`.

*Fix:* The most common cause is `LD_LIBRARY_PATH` not being set. Make sure you have activated the Conda environment and exported the path:

```bash
conda activate gdal-mono
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}
```

Also verify that the `.dll` files were copied into your SyncroSim directory during setup:

```bash
ls $HOME/syncrosim/*_csharp.dll
```

If the files are missing, re-run the copy step from the [GDAL setup section](#gdal) above.

**Mono version issues**

*Symptom:* SyncroSim crashes on launch, or you see cryptic .NET runtime errors.

*Fix:* Ensure you have a recent version of Mono installed (6.x or later). Run `mono --version` to check. If you installed Mono from your distribution's default package manager rather than the official Mono repository, you may have an older version — follow the [Mono install instructions](#mono) above to install from the official source.

**Package version mismatch errors**

*Symptom:* After installing **BurnP3+** and FireSTARR, SyncroSim reports a version mismatch or a *package* fails to load.

*Fix:* **BurnP3+** and FireSTARR must be installed as compatible versions. Check the <a href="https://github.com/ApexRMS/burnP3Plus/releases" target="_blank">BurnP3+ releases page</a> to confirm which FireSTARR version is required for your **BurnP3+** release. Uninstall and reinstall the mismatched *package*:

```bash
ssimpm --uninstall=burnP3PlusFireSTARR
ssimpm --install=burnP3PlusFireSTARR --version=<correct_version>
```

**SQLite crash on library open**  
*Symptom:* SyncroSim crashes with a `SIGSEGV` and a managed stacktrace pointing to `Mono.Data.Sqlite.UnsafeNativeMethods:sqlite3_open_v2` when trying to open a `.ssim` library file.

*Fix:* The conda-forge version of `libsqlite3` copied from the gdal-mono environment is incompatible with Mono's SQLite bindings. Remove it and let Mono fall back to the system version:
```bash
rm $HOME/syncrosim/libsqlite3.so*
```

**R package load failures (`terra`, `sf`, or others)**

*Symptom:* A transformer fails with an error like:
```
unable to load shared object '.../terra/libs/terra.so':
  /usr/lib/x86_64-linux-gnu/libspatialite.so.8: undefined symbol: freexl_get_worksheets_count
```

*Fix:* This is a known incompatibility on Ubuntu 24.04 between pre-built R package binaries and the system `libspatialite`/`libfreexl` versions. First ensure the correct system libraries are installed. Note that the package name for `libspatialite` varies by Ubuntu version:
```bash
# Ubuntu 24.04
sudo apt-get install -y libspatialite8t64 libfreexl1

# Ubuntu 20.04 / 22.04
sudo apt-get install -y libspatialite7 libfreexl1

sudo ldconfig
```

Then reinstall the affected R packages from source so they compile against the correct libraries:
```bash
Rscript -e "install.packages(c('terra', 'sf'), type='source', repos='https://cloud.r-project.org')"
```

If other packages show the same error, reinstall them from source using the same approach.

<br>

*For more on SyncroSim, visit <a href="https://syncrosim.com" target="_blank">syncrosim.com</a>. **BurnP3+** package documentation is available at <a href="https://burnp3.github.io/BurnP3Plus" target="_blank">apexrms.github.io/burnP3Plus</a>. The full SyncroSim console reference can be found at <a href="https://docs.syncrosim.com/reference/console_core.html" target="_blank">docs.syncrosim.com/reference/console_core.html</a>.*
