---
layout: default
title: Getting started
---

# Getting started with **BurnP3+**

### Here we provide a guided tutorial on **BurnP3+**, an open-source package for running spatially-explicit fire growth models to explore fire risk and susceptibility across a landscape. 

**BurnP3+** extends [Burn-P3](https://firegrowthmodel.ca/pages/burnp3_overview_e.html){:target="_blank"} ([Parisien *et al.* 2005](https://cfs.nrcan.gc.ca/publications?id=25627){:target="_blank"}) by enhancing scalability, cross-compatibility, and flexibility (visit our [Home page](http://burnp3.github.io/BurnP3Plus/) for more background information). The **BurnP3+** package is built for [SyncroSim](https://syncrosim.com/){:target="_blank"}, yet familiarity with SyncroSim is not required to get started with **BurnP3+**. Throughout the Quickstart tutorial, terminology associated with SyncroSim will be italicized, and whenever possible, links will be provided to the SyncroSim [online documentation](https://docs.syncrosim.com/index.html){:target="_blank"}. For more on SyncroSim, please refer to the SyncroSim [Overview](https://docs.syncrosim.com/getting_started/overview.html){:target="_blank"} and [Quickstart tutorial](https://docs.syncrosim.com/getting_started/quickstart.html){:target="_blank"}.

<br>

## **BurnP3+** Quickstart Tutorial

This Quickstart tutorial will introduce you to the basics of working with **BurnP3+** in SyncroSim Studio. The steps include:

1. <a href="#step1"> Installing the <b>BurnP3+</b> package </a>
2. <a href="#step2"> Creating a new <b>BurnP3+</b> <i>library</i> </a>
3. <a href="#step3"> Configuring the <b>BurnP3+</b> <i>library</i> to: </a>
* <a href="#stage1"> Sample ignitions </a>
* <a href="#stage2"> Sample burn conditions </a>
* <a href="#stage3"> Grow fires </a>
* <a href="#stage4"> Summarize burn probability </a>
4. <a href="#step4"> Running the model </a>
5. <a href="#step5"> Analyzing the model results </a>

<br>

<p id="step1"> <h2> <b>Step 1: Installing the BurnP3+ package</b> </h2> </p>

Running **BurnP3+** requires that the SyncroSim software be installed on your computer (version 3.0.9). Download the latest version of SyncroSim [here](https://syncrosim.com/studio-download/){:target="_blank"} and follow the installation prompts. 

In this Quickstart tutorial, you will run the **BurnP3+** and [BurnP3+Cell2Fire](https://github.com/BurnP3/BurnP3PlusCell2Fire){:target="_blank"} [SyncroSim *packages*](https://docs.syncrosim.com/how_to_guides/package_overview.html){:target="_blank"}. The **BurnP3+Cell2Fire** package uses the [Cell2Fire](https://doi.org/10.3389/ffgc.2021.692706){:target="_blank"} fire growth model.

> An additional package to **BurnP3+** is also available: [BurnP3+Prometheus](https://github.com/BurnP3/BurnP3PlusPrometheus/releases/){:target="_blank"}. Unlike the Cell2Fire fire growth model that is raster-based, Prometheus is vector-based and capable of executing fine-scale simulations. This degree of accuracy, however, is more computationally demanding in terms of memory use. Moreover, running a BurnP3+Prometheus model requires the installation of [Prometheus 2021.12.03](https://firegrowthmodel.ca/pages/prometheus_software_e.html){:target="_blank"}.

To install the **BurnP3+** and **BurnP3+Cell2Fire** packages, open SyncroSim Studio (**Start > SyncroSim Studio**) and select **File > Local Packages...**. 

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-0.png">

Click on the **Install from Server...** button.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-1.png">

Select the checkbox beside the **burnP3Plus** package from the list, and click **OK**.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-2.png">

If you do not have Miniconda installed in your computer, a dialog box will open asking if you would like to install [Miniconda](https://docs.conda.io/en/latest/miniconda.html){:target="_blank"}. Click **Yes**. Once Miniconda is done installing, a dialog box will open asking if you would like to create a new conda environment. Click **Yes**.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-2.1.png">

> **Miniconda** is an installer for [conda](https://docs.conda.io/projects/conda/en/latest/){:target="_blank"}, a package environment management system that installs any required packages and their dependencies. By default, [**BurnP3+** runs conda](https://docs.syncrosim.com/how_to_guides/package_conda.html){:target="_blank"} to install, create, save, and load the required environment for running **BurnP3+**. The **BurnP3+** environment includes the R software environment and associated packages.

The pop-up window will close after the conda environment is created, and a checkmark will appear in the Conda checkbox beside the package description. 

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-2.2.png">

Next, click on the **Install from Server...** button again to open the packages repository. Select the **burnP3PlusCell2Fire** package from the list and click **OK**.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-2.3.png">

<br>

<p id="step2"> <h2> <b>Step 2: Opening a BurnP3+ library</b> </h2> </p>

Having installed **BurnP3+** and **burnP3PlusCell2Fire**, you are now ready to create your first SyncroSim [*library*](https://docs.syncrosim.com/getting_started/overview.html#libraries){:target="_blank"}. A library is a file (with extension .ssim) that stores all the data and configurations associated with your model. 

We will start with a pre-built example library using the **BurnP3+** and **BurnP3+Cell2Fire** packages. This example uses a synthetic landscape to demonstrate the basics of running **BurnP3+** using the **Cell2Fire** fire growth model.

To open the **Cell2Fire** template library in SyncroSim Studio:

1. Navigate to the Cell2Fire template library on [SyncroSim Cloud](https://cloud.syncrosim.com/){:target="_blank"} by selecting **Explore** from the top menu, searching for a library with the name “*Cell2Fire Example*”, and clicking on the library name.

    <img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-2.4.png">

2.	Click on the **Download** icon to download the library file, called “*Cell2Fire-Example.ssimbak*”.

    <img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-2.5.png">

3.	Start **SyncroSim Studio** by searching for it using the **Windows** toolbar and under the **File** menu, select **Open**.

    <img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-2.6.png">

4.	From the File Browser, navigate to the recently downloaded “*Cell2Fire-Example.ssimbak*” and select this file to open.

5.	When prompted, you can accept the default **File name** and **Folder**, or optionally use **Browse...** to choose a different file name and folder. Click **OK**.

The new **Cell2Fire Example** *library* will be created and loaded into the **Library Explorer** window in SyncroSim Studio.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-4.png">

The **Cell2Fire Example** library contains a [*project*](https://docs.syncrosim.com/how_to_guides/library_overview.html){:target="_blank"} named **Definitions**, with one [*scenario*](https://docs.syncrosim.com/getting_started/overview.html#scenarios){:target="_blank"} named **Baseline Burning Hours**.

<br>

<p id="step3"> <h2> <b>Step 3: Configuring the BurnP3+ library</b> </h2> </p>

This Quickstart tutorial demonstrates the Cell2Fire fire growth model, which has already been added as a package in this template library.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-5.png">

This information can be found by selecting **File > Library Datafeeds** and navigating to the **General** tab. Under **Packages**, you'll find that the **burnP3PlusCell2Fire** package has been added.

Next, in the **Library Explorer** window, double click on **Definitions**. Definitions are [*project datafeeds*](https://docs.syncrosim.com/how_to_guides/library_overview.html){:target="_blank"} containing data shared across all scenarios for a project. 

Navigate to the **BurnP3+** tab, under the **Fuels** tab, click **Fuel Types**. Here, you will find a **Name** list for each of the fuel types present in the fuel grid, which the model requires as input. This example library already contains a fuel grid with two fuel types: **Boreal Spruce** and **Lodgepole Pine Slash**. Note that these names are free-form and can be arbitrary. Each **Name** is associated with an **ID** that must correspond to the labels given to each fuel type in the fuel grid loaded for each scenario. 

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-6.png">

Next, under the **BurnP3+Cell2Fire** tab, click on **Cell2Fire Crosswalk**. Here, each fuel type listed under the **Fuel Types** tab needs to be linked to one of the fuel codes recognized by Cell2Fire. In the case of these two fuel types, Cell2Fire recognizes the Canadian Forest Service Fuel Codes [C2](https://cwfis.cfs.nrcan.gc.ca/background/fueltypes/c2){:target="_blank"} and [S1](https://cwfis.cfs.nrcan.gc.ca/background/fueltypes/c2){:target="_blank"}.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-7.png">

Lastly, in the **Library Explorer** window, you will see one scenario named **Baseline Burning Hours**. Model inputs in SyncroSim are organized into scenarios. Each scenario is associated with [*scenario datafeeds*](https://docs.syncrosim.com/how_to_guides/library_overview.html){:target="_blank"} containing data that are specified for each scenario.

To view the model inputs for the scenario, double-click on **Baseline Burning Hours**. 

In the **General** tab, the **Pipeline** [*datasheet*](https://docs.syncrosim.com/how_to_guides/properties_overview.html){:target="_blank"} allows users to select the stages to include in the model run and their order. A full run of **BurnP3+** consists of four stages:

-	**Stage 1: Sample Ignitions**: Sample the number and locations of ignitions for each simulated burn season, or iteration;
-	**Stage 2: Sample Burning Conditions**: Sample the burning conditions for each ignitions, which depend on when and where the ignitions occurred;
-	**Stage 3: Grow Fires with Cell2Fire**: Simulate each fire deterministically using a fire growth model; and
-	**Stage 4: Summarize Burn Probability**: Summarise the outputs of the fire growth model to calculate burn probability and other burn metrics.

In this example, we will run the full pipeline.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-8.png">

In the **BurnP3+** tab, **Run Control** allows users to specify the number of iterations or Monte Carlo realizations to run. In this example, each scenario will run for **100 iterations**. Each iteration represents a stochastic simulation of a single fire season. Typically, **BurnP3+** should be run for tens of thousands of iterations.

The **Landscape Maps** contains the pre-loaded raster files for **Fuel** and **Elevation** (although this is an optional input).

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-9.png">

<img align="middle" style="padding: 3px" width="525" src="assets/images/BurnP3Plus-screenshot-10.png">

Raster files for **Fire Zone** and **Weather Zone** are optional and will not be considered in this Quickstart tutorial. These raster files allow end users to stratify the landscape and define different statistical distributions for model inputs and summarize model outputs according to these zones. For example, daily weather may vary according to **Weather Zone**.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-extra1.png">

The following four tabs contain the rules for stages 1 to 4. 

<p id="stage1"> <h3> <b><i>Stage 1: Sample Ignitions</i></b> </h3> </p>

Expand the **Sample Ignitions** node. The **Ignition Count** *datasheet* defines the number of fires that should be ignited every iteration within a season. For the purposes of this Quickstart tutorial, **Ignition Count** was set to **1**.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-11.png">

<p id="stage2"> <h3> <b><i>Stage 2: Sample Burning Conditions</i></b> </h3> </p>

Navigate to the next node, **Sample Burning Conditions**. The **Spread Event Days** datasheet specifies the number of days uncontrolled fires are actively burning and spreading in a season. Similarly, for the purposes of this Quickstart tutorial, **Spread Event Days** was set to **1**.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-11.1.png">

The **Daily Burning Hours** datasheet defines the number of hours fires are actively burning per day. For the **Baseline Burning Hours** *cenario, **Daily Burning Hours** was set to **4** for all **Seasons**.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-12.png">

The **Daily Weather** datasheet specifies weather variables for the landscape of interest. Each row corresponds to one day of weather data. The required variables are: temperature, relative humidity, wind speed, wind direction, precipitation, fine fuel moisture code, duff moisture code, drought code, initial spread index, buildup index, and fire weather index.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-13.png">

<p id="stage3"> <h3> <b><i>Stage 3: Grow Fires with Cell2Fire</i></b> </h3> </p>

Under the **Fire Growth Model Options** tab, all settings are optional. However, as advanced features, they will not be covered in this Quickstart tutorial. By leaving the **Fire Growth Model Options** empty, **BurnP3+** will use the default values.

<p id="stage4"> <h3> <b><i>Stage 4: Summarize Burn Probability</i></b> </h3> </p>

Finally, the **Output Options** node specifies which outputs will be generated after running the scenario. The **Tabular** output option is set to **Yes**. However, in this example, there is no seasonal stratification; therefore the seasonal maps in the **Spatial** node are set to **No**. Additionally, the **Burn Perimeters** are also set to **No** because this option is not provided by Cell2Fire.

> **Note:** If all rows in the **Spatial Output Options** datafeed are left blank, **BurnP3+** will default to generating all spatial outputs. However, if only some rows are set to return spatial outputs, the model will only return outputs for the specified rows. 

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-14.png">

Close the window for the **Baseline Burning Hours** scenario. 

Next, you will create a new scenario to compare the effects of **Daily Burning Hours** on fire risk. While you could create a new empty scenario, instead you will copy, paste, and modify the existing scenario to save time and reuse the model inputs. To do so, in the **Library Explorer** window, right-click on the current scenario (**Baseline Burning Hours**), and select **Copy** and **Paste** from the context menu.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-15.png">

Rename the *scenario* by right clicking the newly created scenario, selecting **Rename…** from the context menu, and typing **Extended Burning Hours**. Next, double click on the **Extended Burning Hours** scenario and navigate to the **Sample Burning Conditions** tab. Here, you will modify the input **Daily Burning Hours** from **4** to **6**.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-16.png">

<br>

<p id="step4"> <h2> <b>Step 4: Running the Model</b> </h2> </p>

After reviewing the model inputs and creating a new scenario, you are now ready to run the model. 

**Multiprocessing** is enabled to run 6 jobs in parallel. You can adjust the number of multiprocessing jobs according to the specifications of your computer. A good rule of thumb to follow is number of logical cores minus 1.

Next, right-click on the **Baseline Burning Hours** scenario, and from the context menu select **Run**. If prompted to save your project, click **Yes**.

<img align="middle" style="padding: 3px" width="500" src="assets/images/BurnP3Plus-screenshot-17.png">

A **Run Monitor** window will appear, indicating the **Status** of the scenario as **Running**. At the bottom of the SyncroSim Studio window, an orange progress bar will provide further information during each stage of the pipeline. 

When the run has completed you will see the **Status** of **Done** in the **Run Monitor**. If an error or warning has been issued, click on the **Run Log** link to see a report of problems. Make any required changes to your scenario and re-run it.

Running a model in SyncroSim produces a [*results scenario*](https://docs.syncrosim.com/how_to_guides/modelrun_overview.html#results-scenarios){:target="_blank"}, which contain the input datasheets associated with the *parent scenario*, as well as output datasheets for the scenario run. Each results scenario inherits the parent scenario’s name and receives a unique ID.

<img align="middle" style="padding: 3px" width="400" src="assets/images/BurnP3Plus-screenshot-18.png">

Repeat the same process to run the **Extended Burning Hours** *scenario*.

<br>

<p id="step5"> <h2> <b>Step 5: Analyzing the Model Results</b> </h2> </p>

To view the tabular results from each of your runs, double-click on one of your results scenarios and navigate to the last tab, **Output Fire Statistics**. Here, you can view the results and have the option to export the data by right-clicking anywhere on the spreadsheet, and selecting **Export All** from the context menu.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-19.png">

Next, move to the results panel at the bottom left of SyncroSim Studio. Under the **Charts** tab, double-click on **Burn Area by Fuel Type** to see the tabular results for area burned. 

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-20.png">

Next, navigate to the **Maps** tab and double-click on **Burn Probability Maps**.

<img align="middle" style="padding: 3px" width="600" src="assets/images/BurnP3Plus-screenshot-21.1.png">

Lastly, under the **Maps** tab you can also find the **Input Maps** for fuel type and elevation.

<img align="middle" style="padding: 3px" width="350" src="assets/images/BurnP3Plus-screenshot-22.png">

> **Note:** Map legends can be customized by double-clicking on the bins. You can also add and remove a result scenario being charted or mapped by selecting a result scenario in the **Library Explorer** and then choosing either **Add to Results** or **Remove from Results** from the context menu. Scenarios with results currently selected for analysis have a red checkmark and are bolded in the **Library Explorer**.
