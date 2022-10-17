---
layout: default
title: Home
description: "Landing page for the Package"
permalink: /
---

# **BurnP3+** SyncroSim Package
<img align="right" style="padding: 13px" width="180" src="assets/images/logo/burnP3Plus-sticker.png">
[![GitHub release](https://img.shields.io/github/v/release/BurnP3/BurnP3Plus.svg?style=for-the-badge&color=d68a06)](https://GitHub.com/BurnP3/BurnP3Plus/releases/)    <a href="https://github.com/BurnP3/BurnP3Plus"><img align="middle" style="padding: 1px" width="30" src="assets/images/logo/github-trans2.png"> <br>

### **BurnP3+** is an open-source [SyncroSim](https://syncrosim.com/){:target="_blank"} base package for running spatially-explicit fire growth models to explore fire risk and susceptibility across a landscape. **BurnP3+** is funded, developed and maintained by the [Canadian Forest Service](https://www.nrcan.gc.ca/our-natural-resources/forests-forestry/the-canadian-forest-service/about-canadian-forest-service/17545){:target="_blank"}. <br>

<br>

## Background
**BurnP3+** was designed to update and replace [Burn-P3](https://firegrowthmodel.ca/pages/burnp3_overview_e.html){:target="_blank"}, a Windows based software application originally developed in 2005 by the Canadian Forest Service ([Parisien *et al.* 2005](https://cfs.nrcan.gc.ca/publications?id=25627){:target="_blank"}). Burn-P3 (probability, prediction, and planning) allows users to produce estimates of wildfire susceptibility and risk across a landscape. Using a Monte Carlo simulation modelling approach, Burn-P3 combines stochastic draws of fire ignition, weather, and other burning conditions with a deterministic fire growth model. The resulting output is a burn probability map. Alternative scenarios can be contrasted to evaluate the response or sensitivity of burn probability to change in variables or conditions of interest, such as climate or alternative land management practices. <br>

**BurnP3+** was developed to improve scalability to larger landscapes and number of scenarios, allow for cross-compatibility among platforms (Widows and Linux) and interfaces (Graphical, command line, R and Python), and increase flexibility in model structure through the implementation of modules. With these enhancements, **BurnP3+** extends the success of Burn-P3 as a decision-support tool in land management and a framework for scientific inquiry ([Parisien *et al.* 2019](https://www.fs.usda.gov/research/treesearch/60727){:target="_blank"}). <br>

Burn-P3 utilized a single deterministic fire grow model called [Prometheus](https://firegrowthmodel.ca/pages/prometheus_overview_e.html){:target="_blank"}. **BurnP3+** now provides two options of fire growth models, available as add-on packages: [BurnP3+Cell2Fire](https://github.com/BurnP3/BurnP3PlusCell2Fire){:target="_blank"} enables users to grow fires with [Cell2Fire](https://github.com/cell2fire/Cell2Fire){:target="_blank"}; and [BurnP3+Prometheus](https://github.com/BurnP3/BurnP3PlusPrometheus){:target="_blank"} enables users to grow fires with [Prometheus](https://firegrowthmodel.ca/pages/prometheus_overview_e.html){:target="_blank"}. The Canadian Forest Service plans to develop additional fire growth add-on packages for **BurnP3+**. Alternatively, users also have the option to develop their own fire growth models and add-on packages. <br>

**BurnP3+** users can load model inputs, export model outputs and view spatial and graphical result summaries via various SyncroSim interfaces, including the Windows Graphical User Interface, the [rsyncrosim](https://syncrosim.github.io/rsyncrosim/){:target="_blank"} package for [R](https://www.r-project.org/){:target="_blank"} and the [pysyncrosim](https://pysyncrosim.readthedocs.io/en/latest/index.html){:target="_blank"} package for [Python](https://www.python.org/){:target="_blank"}. <br>

<br>

## Requirements

The **BurnP3+ SyncroSim Package** requires the SyncroSim software, [version 2.4.5](https://syncrosim.com/download/){:target="_blank"} or higher. <br>

If using the Cell2Fire fire growth model, you will also need to install the [BurnP3+Cell2Fire](https://github.com/BurnP3/BurnP3PlusCell2Fire){:target="_blank"} add-on package. <br>

If using the Prometheus fire growth model, you will need to install both [Prometheus](https://firegrowthmodel.ca/pages/prometheus_software_e.html){:target="_blank"} (version 2021.12.03) and the [BurnP3+Prometheus](https://github.com/BurnP3/BurnP3PlusPrometheus){:target="_blank"} add-on package. <br>

> Instructions for installing the above requirements for **BurnP3+** are provided on the [Getting Started](https://burnp3.github.io/BurnP3Plus/getting_started.html) page. <br>

<br>

## Getting Started

For a guided tutorial on **BurnP3+**, including installation, set up, model run, and output visualization, see [Getting Started](https://burnp3.github.io/BurnP3Plus/getting_started.html). <br>

<br>

## Key Links

Browse source code for **BurnP3+** at
[http://github.com/BurnP3/BurnP3Plus/](http://github.com/BurnP3/BurnP3Plus/){:target="_blank"}. <br>
Report a bug with **BurnP3+** at
[http://github.com/BurnP3/BurnP3Plus/issues](http://github.com/BurnP3/BurnP3Plus/issues){:target="_blank"}. <br>
+Cell2Fire add-on package for **BurnP3+** at [https://github.com/BurnP3/BurnP3PlusCell2Fire](https://github.com/BurnP3/BurnP3PlusCell2Fire){:target="_blank"}. <br>
Prometheus add-on package for **BurnP3+** at [https://github.com/BurnP3/BurnP3PlusCell2Fire](https://github.com/BurnP3/BurnP3PlusCell2Fire){:target="_blank"}. <br>
Burn-P3 software at [https://firegrowthmodel.ca/pages/burnp3_overview_e.html](https://firegrowthmodel.ca/pages/burnp3_overview_e.html){:target="_blank"}. <br>
Burn-P3 documentation at [https://cfs.nrcan.gc.ca/publications?id=25627](https://cfs.nrcan.gc.ca/publications?id=25627){:target="_blank"}. <br>

<br>

## Developers

Chris Stockdale (Author)
<br>
Shreeram Senthivasan (Author) <a href="https://orcid.org/0000-0002-7118-9547" target="_blank"><img align="middle" style="padding: 0.5px" width="17" src="assets/images/ORCID.png"></a>
<br>
Brett Moore (Author, Maintainer) <a href="https://orcid.org/0000-0002-9456-8435" target="_blank"><img align="middle" style="padding: 0.5px" width="17" src="assets/images/ORCID.png"></a>
<br>
Colin Daniel (Author) <a href="https://orcid.org/0000-0001-7367-2041" target="_blank"><img align="middle" style="padding: 0.5px" width="17" src="assets/images/ORCID.png"></a>
<br>
Katie Birchard (Author)
<br>
Peter Englefield (Author)
<br>
Quinn Barber (Author) <a href="https://orcid.org/0000-0003-0318-9446" target="_blank"><img align="middle" style="padding: 0.5px" width="17" src="assets/images/ORCID.png"></a>
<br>
Denys Yemshanov (Author) <a href="https://orcid.org/0000-0002-6992-9614" target="_blank"><img align="middle" style="padding: 0.5px" width="17" src="assets/images/ORCID.png"></a>
<br>
Leonardo Frid (Author) <a href="https://orcid.org/0000-0002-5489-2337" target="_blank"><img align="middle" style="padding: 0.5px" width="17" src="assets/images/ORCID.png"></a>
<br>
