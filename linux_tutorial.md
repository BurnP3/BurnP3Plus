---
layout: default
title: Running BurnP3+ on Linux
---

# Running **BurnP3+** on Linux

### Here we provide a complete guide to setting up and running **BurnP3+** on Linux using the SyncroSim console and the `rsyncrosim` R package — no GUI required.

**BurnP3+** is a [SyncroSim](https://syncrosim.com/){:target="_blank"} package that simulates wildfire ignition, spread, and suppression over many thousands of iterations to produce spatially explicit burn probability maps. It uses [FireSTARR](https://github.com/CWFMF/FireSTARR){:target="_blank"} (or other fire growth engines) under the hood and requires spatial inputs including weather streams, fuel grids, topography, and ignition zones. Full **BurnP3+** documentation is available at [apexrms.github.io/burnP3Plus](https://apexrms.github.io/burnP3Plus/){:target="_blank"}.

Most **BurnP3+** workflows assume you are working through the SyncroSim Studio graphical interface on Windows. However, if you are running analyses on a Linux server, a high-performance computing (HPC) cluster, or an automated pipeline, you need to work headlessly. This guide walks through everything required to get **BurnP3+** running on Linux — from a bare system all the way through a complete model run using both the SyncroSim console and the `rsyncrosim` R package. Throughout this tutorial, terminology associated with SyncroSim will be italicized, and whenever possible, links will be provided to the SyncroSim [online documentation](https://docs.syncrosim.com/index.html){:target="_blank"}.

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
4. <a href="#step4"> Running <b>BurnP3+</b> from R with <code>rsyncrosim</code> </a>
    * <a href="#rinstall"> Installing rsyncrosim </a>
    * <a href="#rconnect"> Connecting rsyncrosim to SyncroSim </a>
    * <a href="#rlibrary"> Opening or creating a <i>library</i> </a>
    * <a href="#rconfig"> Configuring a <i>scenario</i> </a>
    * <a href="#rrun"> Running a <i>scenario</i> </a>
    * <a href="#rresults"> Retrieving and visualizing results </a>
    * <a href="#rendtoend"> Complete end-to-end example </a>
5. <a href="#step5"> Tips for production workflows </a>
6. <a href="#step6"> Troubleshooting </a>

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

On Red Hat-based systems, Mono is installed via an RPM repository. Follow the official instructions for your distribution at [mono-project.com/download/stable](https://www.mono-project.com/download/stable/){:target="_blank"} — the steps vary slightly between RHEL versions.

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

Download and extract the SyncroSim Linux build. You can find the latest version number on the [SyncroSim downloads page](https://syncrosim.com/download/){:target="_blank"}:

```bash
# Download SyncroSim (adjust version as needed)
curl -fsSL "https://downloads.syncrosim.com/3-1-24/syncrosim-linux-3-1-24.zip" \
    -o /tmp/syncrosim.zip

unzip -q /tmp/syncrosim.zip -d $HOME/syncrosim
rm /tmp/syncrosim.zip

# Make the executables executable
chmod 755 $HOME/syncrosim/SyncroSim.Console.exe \
          $HOME/syncrosim/SyncroSim.PackageManager.exe
```

For convenience, create shell wrappers so you can invoke `ssim` and `ssimpm` from anywhere on the system:

```bash
sudo tee /usr/local/bin/ssim > /dev/null << 'EOF'
#!/bin/bash
mono $HOME/syncrosim/SyncroSim.Console.exe "$@"
EOF

sudo tee /usr/local/bin/ssimpm > /dev/null << 'EOF'
#!/bin/bash
mono $HOME/syncrosim/SyncroSim.PackageManager.exe "$@"
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
cp $HOME/miniconda3/envs/gdal-mono/lib/*_csharp.dll \
   $HOME/syncrosim/
```

> **What this does:** The `gdal-csharp` package provides the "glue" between SyncroSim (a .NET application) and GDAL (a C library). Copying the `.dll` files into the SyncroSim folder makes them available when SyncroSim starts up.

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

> **Tip:** Check the [ApexRMS GitHub releases page](https://github.com/ApexRMS/burnP3Plus/releases){:target="_blank"} for the current version numbers of **BurnP3+** and its compatible FireSTARR release. Always install versions that are listed as compatible with each other.

Verify the *packages* installed correctly:

```bash
ssimpm --list
```

You should see `burnP3Plus` and `burnP3PlusFireSTARR` (along with their dependencies) in the output.

**Offline / Airgapped Install**

If your server does not have internet access, download the *package* files on another machine and transfer them manually. Download the `.ssimpkg` files from the [ApexRMS GitHub releases page](https://github.com/ApexRMS/burnP3Plus/releases){:target="_blank"}, copy them to the server, then install:

```bash
mkdir -p $HOME/burnp3

# Install from local package files
ssimpm --finstall="$HOME/burnp3/burnP3Plus-2-6-5.ssimpkg"
ssimpm --finstall="$HOME/burnp3/burnP3PlusFireSTARR-1-5-5.ssimpkg"
```

<br>

<p id="step3"> <h2> <b>Step 3: Running BurnP3+ from the SyncroSim console</b> </h2> </p>

With SyncroSim and **BurnP3+** installed, you can run any **BurnP3+** *library* entirely from the command line. This is the approach you would use in a batch script, cron job, or HPC job submission. The full SyncroSim console reference is available at [docs.syncrosim.com/reference/console_core.html](https://docs.syncrosim.com/reference/console_core.html){:target="_blank"}.

A SyncroSim *library* (`.ssim` file) is the top-level container for a modeling project. Inside a *library*, you have one or more *projects*, and within each *project*, one or more *scenarios*. A *scenario* defines all the model inputs and configuration for a single run. When running from the console, you reference *scenarios* by their **scenario ID** — an integer assigned when the *scenario* is created. To list the *scenarios* available in a *library*:

```bash
ssim --lib=/path/to/burnp3.ssim --list --scenarios
```

<br>

<p id="runcontrol"> <h3> Configuring run control and multiprocessing </h3> </p>

Before running a *scenario*, configure how many fire iterations to run and how many CPU cores to use. In SyncroSim, these settings live in *datasheets* — named tables that hold model configuration. You can import *datasheet* values from CSV files using the console.

Create a `Run_Control.csv` with your iteration settings:

```
MaximumIteration,StartTimestep,EndTimestep
10000,1,1
```

Create a `Multiprocessing.csv` to enable parallel processing:

```
EnableMultiprocessing,MaximumJobs
TRUE,8
```

Then import them into your *scenario* before running:

```bash
SSIMLIB=/path/to/your/burnp3.ssim

ssim --import --lib=$SSIMLIB --sheet=burnP3Plus_RunControl \
     --sid=1 --file='Run_Control.csv'

ssim --import --lib=$SSIMLIB --sheet=core_Multiprocessing \
     --sid=1 --file='Multiprocessing.csv'
```

Set `MaximumJobs` to match the number of CPU cores you want to use. On an HPC cluster, this should match the number of cores allocated to your job (e.g., `$SLURM_CPUS_PER_TASK`).

<br>

<p id="runscenario"> <h3> Running a scenario </h3> </p>

```bash
# Activate the GDAL environment first
conda activate gdal-mono
export LD_LIBRARY_PATH=$CONDA_PREFIX/lib:${LD_LIBRARY_PATH:-}

# Run scenario with ID 1 in your library
ssim --lib=/path/to/your/burnp3.ssim --run --sid=1
```

The table below summarizes the most useful console flags. For a complete reference, see [docs.syncrosim.com/reference/console_core.html](https://docs.syncrosim.com/reference/console_core.html){:target="_blank"}.

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
EnableMultiprocessing,MaximumJobs
TRUE,$SLURM_CPUS_PER_TASK
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

<p id="step4"> <h2> <b>Step 4: Running BurnP3+ from R with rsyncrosim</b> </h2> </p>

The `rsyncrosim` package provides a full R interface to SyncroSim, letting you build *libraries*, configure *scenarios*, run models, and retrieve results — all from within an R script or RMarkdown document. This is especially powerful when you want to integrate **BurnP3+** runs into a larger analytical pipeline.

<br>

<p id="rinstall"> <h3> Installing rsyncrosim </h3> </p>

```r
install.packages("rsyncrosim",
  repos = "https://packagemanager.posit.co/cran/__linux__/jammy/latest"
)
```

<br>

<p id="rconnect"> <h3> Connecting rsyncrosim to SyncroSim </h3> </h3> </p>

```r
library(rsyncrosim)

# Point rsyncrosim at your SyncroSim installation
# (only needed if SyncroSim is not in the default location)
envPath <- "~/syncrosim"
```

> **Note:** On Linux, `rsyncrosim` will call SyncroSim via Mono under the hood. Make sure you have the `gdal-mono` Conda environment activated and `LD_LIBRARY_PATH` set in the R session before running any spatially explicit *scenarios*.

You can set these environment variables from within R before loading `rsyncrosim`:

```r
Sys.setenv(
  LD_LIBRARY_PATH = paste0(Sys.getenv("CONDA_PREFIX"), "/lib"),
  PROJ_LIB = "/usr/share/proj"
)
```

Alternatively, launch R from a shell where the `gdal-mono` environment is already activated.

<br>

<p id="rlibrary"> <h3> Opening or creating a library </h3> </p>

```r
library(rsyncrosim)

# Open an existing BurnP3+ library
myLib <- ssimLibrary(name = "/path/to/burnp3.ssim")

# Or create a new library with BurnP3+ as the base package
myLib <- ssimLibrary(
  name    = "/path/to/new_burnp3.ssim",
  package = "burnP3Plus"
)
```

To explore the *library* structure:

```r
# List projects in the library
project(myLib)

# Get the default project
myProject <- project(myLib, project = 1)

# List scenarios
scenario(myProject)
```

<br>

<p id="rconfig"> <h3> Configuring a scenario </h3> </p>

**BurnP3+** *scenarios* are configured through *datasheets* — named tables that hold model inputs. You can read and write *datasheets* using `datasheet()` and `saveDatasheet()`.

**Run Control and Multiprocessing**

Configure the number of iterations and parallel jobs through the `burnP3Plus_RunControl` and `core_Multiprocessing` *datasheets*:

```r
# Get a reference to a scenario
myScenario <- scenario(myProject, scenario = "My BurnP3 Run")

# Configure run control (number of iterations)
runControl <- datasheet(myScenario, name = "burnP3Plus_RunControl")
runControl$MaximumIteration <- 10000
runControl$StartTimestep    <- 1
runControl$EndTimestep      <- 1
saveDatasheet(myScenario, runControl, name = "burnP3Plus_RunControl")

# Configure multiprocessing (number of parallel jobs)
mp <- datasheet(myScenario, name = "core_Multiprocessing")
mp$EnableMultiprocessing <- TRUE
mp$MaximumJobs           <- 8
saveDatasheet(myScenario, mp, name = "core_Multiprocessing")
```

Set `MaximumJobs` to the number of CPU cores available on your machine or cluster node.

**Setting Spatial Inputs**

**BurnP3+** requires several spatial raster layers, managed through *datasheets*:

```r
# Read the landscape inputs datasheet
landscape <- datasheet(myScenario, name = "burnP3Plus_LandscapeRasters")

# Update raster file paths
landscape$FuelGridFilename  <- "/data/spatial/fuel_grid.tif"
landscape$ElevationFilename <- "/data/spatial/dem.tif"
landscape$SlopeFilename     <- "/data/spatial/slope.tif"
landscape$AspectFilename    <- "/data/spatial/aspect.tif"

saveDatasheet(myScenario, landscape, name = "burnP3Plus_LandscapeRasters")
```

<br>

<p id="rrun"> <h3> Running a scenario </h3> </p>

```r
# Run the scenario
resultScenario <- run(myScenario)

# Check run status
status(resultScenario)
```

Running a *scenario* produces a [*result scenario*](https://docs.syncrosim.com/how_to_guides/modelrun_overview.html#results-scenarios){:target="_blank"}, which contains the input *datasheets* associated with the parent *scenario* as well as output *datasheets* for the run. Each *result scenario* inherits the parent *scenario*'s name and receives a unique ID.

<br>

<p id="rresults"> <h3> Retrieving and visualizing results </h3> </p>

After a run completes, results are stored in *result scenarios* linked to your parent *scenario*. You can retrieve spatial outputs as raster files:

```r
library(terra)

# Get the result scenario
results <- scenario(myProject, scenario = resultScenario)

# Read burn probability output raster
burnProb <- datasheet(results, name = "burnP3Plus_OutputBurnProbability")
print(burnProb)

# Load and plot the raster
bp_rast <- rast(burnProb$Filename[1])
plot(bp_rast, main = "Burn Probability", col = hcl.colors(100, "YlOrRd", rev = TRUE))
```

<br>

<p id="rendtoend"> <h3> Complete end-to-end example </h3> </p>

The following condensed example opens a *library*, updates key inputs, runs the model, and retrieves the output burn probability map:

```r
library(rsyncrosim)
library(terra)

# Environment setup (if not already done in shell)
Sys.setenv(
  LD_LIBRARY_PATH = paste0(Sys.getenv("CONDA_PREFIX"), "/lib"),
  PROJ_LIB        = "/usr/share/proj"
)

# ── 1. Open library ──────────────────────────────────────────────────────────
myLib      <- ssimLibrary("/data/projects/burnp3.ssim")
myProject  <- project(myLib, project = 1)
myScenario <- scenario(myProject, scenario = "Baseline Fire Risk")

# ── 2. Update run control ────────────────────────────────────────────────────
rc <- datasheet(myScenario, "burnP3Plus_RunControl")
rc$MaximumIteration <- 5000
rc$StartTimestep    <- 1
rc$EndTimestep      <- 1
saveDatasheet(myScenario, rc, "burnP3Plus_RunControl")

# ── 3. Configure multiprocessing ─────────────────────────────────────────────
mp <- datasheet(myScenario, "core_Multiprocessing")
mp$EnableMultiprocessing <- TRUE
mp$MaximumJobs           <- 8
saveDatasheet(myScenario, mp, "core_Multiprocessing")

# ── 4. Update spatial inputs ─────────────────────────────────────────────────
landscape <- datasheet(myScenario, "burnP3Plus_LandscapeRasters")
landscape$FuelGridFilename  <- "/data/spatial/fbp_fuel.tif"
landscape$ElevationFilename <- "/data/spatial/dem.tif"
saveDatasheet(myScenario, landscape, "burnP3Plus_LandscapeRasters")

# ── 5. Run ───────────────────────────────────────────────────────────────────
cat("Starting BurnP3+ run...\n")
result <- run(myScenario)

# ── 6. Retrieve burn probability ─────────────────────────────────────────────
outSheets <- datasheet(result, "burnP3Plus_OutputBurnProbability")
bp <- rast(outSheets$Filename[1])

# ── 7. Plot ──────────────────────────────────────────────────────────────────
plot(bp,
     main = "Burn Probability — Baseline Scenario",
     col  = hcl.colors(100, "YlOrRd", rev = TRUE))
```

<br>

<p id="step5"> <h2> <b>Step 5: Tips for production workflows</b> </h2> </p>

**Keep your GDAL environment stable**

Avoid updating the `gdal-mono` Conda environment once it is working. Pin the `gdal-csharp` version to `1.1.1` and only update it intentionally when upgrading SyncroSim to a new major version.

**Script your library configuration**

Rather than manually creating and editing *scenarios* in a GUI, script all *scenario* creation and configuration in R. This ensures reproducibility and makes it trivial to generate *scenario* variants:

```r
# Create scenario variants programmatically
weather_scenarios <- list(
  "Normal Year"     = "weather_normal.csv",
  "Extreme Year"    = "weather_extreme.csv",
  "Historical 2023" = "weather_2023.csv"
)

for (name in names(weather_scenarios)) {
  s <- scenario(myProject, scenario = name)
  wx <- datasheet(s, "burnP3Plus_WeatherStream")
  wx <- read.csv(weather_scenarios[[name]])
  saveDatasheet(s, wx, "burnP3Plus_WeatherStream")
}
```

**Use result scenario chaining**

SyncroSim's dependency system allows *result scenarios* to feed into downstream analyses (e.g., post-processing, zonal statistics). Take advantage of this by setting `dependency` relationships between *scenarios* in `rsyncrosim`.

**Logging and monitoring on HPC**

For long HPC runs, direct SLURM output to timestamped log files and monitor progress:

```bash
#SBATCH --output=/home/$USER/logs/burnp3_%j_%x.out
```

Inside your R script, periodically write status messages:

```r
cat(sprintf("[%s] Iteration check...\n", Sys.time()))
```

**Cleaning up old result scenarios**

**BurnP3+** runs generate substantial intermediate data. Use `rsyncrosim` to programmatically delete old *result scenarios* that are no longer needed:

```r
# List all result scenarios
all_scenarios <- scenario(myProject)
result_mask   <- grepl("^Results for", all_scenarios$Name)
old_results   <- all_scenarios$ScenarioID[result_mask]

# Delete them
for (sid in old_results) {
  delete(myProject, scenario = sid, force = TRUE)
}
```

<br>

<p id="step6"> <h2> <b>Step 6: Troubleshooting</b> </h2> </p>

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

*Fix:* **BurnP3+** and FireSTARR must be installed as compatible versions. Check the [BurnP3+ releases page](https://github.com/ApexRMS/burnP3Plus/releases){:target="_blank"} to confirm which FireSTARR version is required for your **BurnP3+** release. Uninstall and reinstall the mismatched *package*:

```bash
ssimpm --uninstall=burnP3PlusFireSTARR
ssimpm --install=burnP3PlusFireSTARR --version=<correct_version>
```

<br>

*For more on SyncroSim, visit [syncrosim.com](https://syncrosim.com){:target="_blank"}. **BurnP3+** package documentation is available at [apexrms.github.io/burnP3Plus](https://apexrms.github.io/burnP3Plus/){:target="_blank"}. The full SyncroSim console reference can be found at [docs.syncrosim.com/reference/console_core.html](https://docs.syncrosim.com/reference/console_core.html){:target="_blank"}.*
