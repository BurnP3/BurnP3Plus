---
layout: default
title: Tutorials
permalink: /tutorials
description: "List of tutorials for BurnP3+ SyncroSim"
---

# Configuring models in **BurnP3+**

This video tutorial covers how to use the **BurnP3+** SyncroSim package to configure a wildfire probability model. 

To follow along, this tutorial requires:
* the SyncroSim software, version 3.0.9;
* the **BurnP3+** SyncroSim package; and
* the **BurnP3+Prometheus** SyncroSim package

Download the latest version of SyncroSim [here](https://syncrosim.com/download/){:target="_blank"} and follow the installation prompts.

To install the **BurnP3+** and **BurnP3+Prometheus** SyncroSim packages, open SyncroSim Studio (**Start > SyncroSim Studio**) and select **File > Local Packages...**.

<img align="middle" style="padding: 3px" width="600" src="./assets/images/BurnP3Plus-screenshot-0.png">

Click on the **Install from Server...** button.

<img align="middle" style="padding: 3px" width="600" src="./assets/images/BurnP3Plus-screenshot-1.png">

Mark the checkbox beside **burnP3Plus**, and click **OK**. Repeat this process for **burnP3PlusPrometheus**. For more details on installing **BurnP3+** packages, please see the [Getting Started](https://burnp3.github.io/BurnP3Plus/getting_started.html) page.

<img align="middle" style="padding: 3px" width="600" src="./assets/images/BurnP3Plus-screenshot-2-2.png">

For this tutorial, we will use with a pre-built example library using the **BurnP3+** and **BurnP3+Prometheus** packages. This example uses the Glacier National Park landscape in British Columbia, Canada to demonstrate the basics of running **BurnP3+** using the **Prometheus** fire growth model.

To open the **Glacier National Park Example** template library in SyncroSim Studio:

1. Navigate to the Glacier National Park Example template library on [SyncroSim Cloud](https://cloud.syncrosim.com/) by selecting **Explore** from the top menu, searching for a library with the name “*Glacier National Park Example*”, and clicking on the library name.

    <img align="middle" style="padding: 3px" width="600" src="./assets/images/BurnP3Plus-screenshot-2.7.png">

2. Click on the **Download** icon to download the library file, called “*Glacier National Park Example.ssimbak*”.

    <img align="middle" style="padding: 3px" width="600" src="./assets/images/BurnP3Plus-screenshot-2.8.png">

3. Start **SyncroSim Studio** by searching for it using the **Windows** toolbar and under the **File** menu, select **Open**.

    <img align="middle" style="padding: 3px" width="600" src="./assets/images/BurnP3Plus-screenshot-2.6.png">

4. From the File Browser, navigate to the recently downloaded “*Glacier National Park Example.ssimbak*” and select this file to open.

5. When prompted, you can accept the default **File name** and **Folder**, or optionally use **Browse...** to choose a new file name and folder. Click **OK**.

The new **Glacier National Park Example** *library* will be created and loaded into the **Library Explorer** window in SyncroSim Studio.

<img align="middle" style="padding: 3px" width="600" src="./assets/images/BurnP3Plus-screenshot-4.1.png">

Now you are all set to follow along with the tutorial. This video will provide:

* An introduction to **BurnP3+** in SyncroSim
* An overview of the structure of **BurnP3+**
* Instructions on how to sample from distributions in **BurnP3+** 
* Options for how to configure the fire growth model
* Instructions on how to run **BurnP3+** and vizualize outputs

> **Note:** Please note that the demonstration video below was recorded using SyncroSim version 2.4, and BurnP3+ version 1.0. 

<iframe width="600" height="378" src="https://www.youtube.com/embed/iDaHoUEM3Rw" title="YouTube video player" frameborder="0" allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" allowfullscreen></iframe>
