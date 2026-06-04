---
layout: default
title: Reference
description: "Reference guide for the BurnP3+ package"
permalink: /reference
---

# Reference guide for the **BurnP3+** SyncroSim *Package*

In SyncroSim, all tabular data associated with a model are stored in a single file (with the extension *.ssim*), referred to as a SyncroSim *library*. The inputs and outputs contained within a SyncroSim *library* are organized into *datafeeds* (or tabs in SyncroSim Studio). Each *datafeed* can be made up of one or more tables of data, called *datasheets*. Each *datasheet* is associated with one of three scopes: *library*, *project* or *scenario*. See the <a href="https://docs.syncrosim.com/how_to_guides/library_overview.html" target="_blank">SyncroSim documentation</a> for more details on the various *datasheet* scopes.

**BurnP3+** has a *library*, and multiple *project*- and, *scenario*-scoped *datasheets*. The associated **BurnP3+** fire growth model packages (**BurnP3+Prometheus** and **BurnP3+FireSTARR**) also contain several *project* and *scenario*-scoped *datasheets*. Within this Reference guide, you will find details on each field within the **BurnP3+**, **BurnP3+Prometheus**, and **BurnP3+FireSTARR** datasheets. For details on *datasheets* that are package-agnostic and specific to SyncroSim, see the <a href="https://docs.syncrosim.com/reference/ds_overview.html" target="_blank">SyncroSim System Datasheets Overview</a>.

The original <a href="https://firegrowthmodel.ca/#/burnp3_documentation" target="_blank">Burn-P3 manual</a> provides useful information about how the data needs to be structured but does not contain information on *why* certain fields are used and what they mean for wildfire modelling. This reference guide supersedes the original Burn-P3 manual in terms of data structures and adds new features.

*Note: Datasheets located under a project- or scenario-scoped* **_Advanced_** *node are optional for users to fill, while all other datasheets are mandatory.*

<li class="no-bullets">Library <i>Datasheet</i>:</li>
{% for section in site.library %}
  <li> <a href="{{site.baseurl}}{{ section.url }}"> {{ section.title }}</a> </li>
{% endfor %}
<div class="spacer"></div>
<li class="no-bullets">Project <i>Datasheet</i>:</li>
{% for section in site.project %}
  <li> <a href="{{site.baseurl}}{{ section.url }}"> {{ section.title }}</a> </li>
{% endfor %}
<div class="spacer"></div>
<li class="no-bullets">Scenario <i>Datasheets</i>:</li>
{% for section in site.scenarios %}
  <li> <a href="{{site.baseurl}}{{ section.url }}"> {{ section.title }}</a> </li>
{% endfor %}