---
layout: default
title: Reference
description: "Reference guide for the BurnP3+ package"
permalink: /reference
---

# Reference guide for the **BurnP3+** SyncroSim *Package*

In SyncroSim, all inputs and outputs associated with a model are stored in a single file (with the extension .ssim), referred to as a SyncroSim *Library*. The inputs and outputs contained within a SyncroSim *Library* are organized into *Datafeeds* (or tabs in the SyncroSim UI). Each *Datafeed* can be made up of one or more tables of data, called *Datasheets*. Each *Datasheet* is associated with one of three scopes: *Library*, *Project* or *Scenario*. See the [SyncroSim documentation](https://docs.syncrosim.com/how_to_guides/library_overview.html) for more details.

**BurnP3+** has a *Library*, a *Project* and multiple *Scenario* scoped *Datasheets*. Within this Reference guide, you will find details on the function of each field within **BurnP3+** *Datasheets*. For details on *Datasheets* not covered in this reference guide, see the [SyncroSim Core Datasheets Overview](https://docs.syncrosim.com/reference/ds_overview.html). 

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