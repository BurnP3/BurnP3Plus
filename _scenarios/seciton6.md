---
layout: default
section: 6
title: Prometheus
permalink: reference/prometheus-scenario
---

<!--- Sidebar Navigation Menu --->
<div class="sidenav">
    <li>Library</li>
    {% for section in site.library %}
        {% if section.section != page.section %}
            <a href="{{site.baseurl}}{{ section.url }}"> &emsp;{{ section.title }} </a>
        {% else %}
            <a class="selected" href="{{site.baseurl}}{{ section.url }}"> &emsp;{{ section.title }} </a>
        {% endif %}
    {% endfor %}
    <li>Project</li>
    {% for section in site.project %}
        {% if section.section != page.section %}
            <a href="{{site.baseurl}}{{ section.url }}"> &emsp;{{ section.title }} </a>
        {% else %}
            <a class="selected" href="{{site.baseurl}}{{ section.url }}"> &emsp;{{ section.title }} </a>
        {% endif %}
    {% endfor %}
    <li>Scenario</li>
    {% for section in site.scenarios %}
        {% if section.section != page.section %}
            <a href="{{site.baseurl}}{{ section.url }}"> &emsp;{{ section.title }} </a>
        {% else %}
            <a class="selected" href="{{site.baseurl}}{{ section.url }}"> &emsp;{{ section.title }} </a>
            <a href="#heading01"> &emsp;&emsp;&emsp;Fire Behaviour Prediction (FBP) System Spatial Outputs</a>
        {% endif %}
    {% endfor %}
</div>

# **BurnP3+ Prometheus**

<br>

<p id="heading01"> <h2><b>Fire Behaviour Prediction (FBP) System Spatial Outputs</b></h2> </p>

**Datasheet internal name:** burnP3PlusPrometheus_OutputOptionSpatial

The FBP Outputs datasheet can be found under the **BurnP3+ Prometheus** tab within the **Prometheus** node and provides specifications on the spatial output maps.

### **Rate of Spread Map**

**Column internal name:** RateofSpread

Describes the predicted speed (m/min) of fire as it initially passes through the cell. The Rate of Spread (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">ROS</a>) metric is based on the Fuel Type, Initial Spread Index (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">ISI</a>),  Buildup Index (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">BUI</a>), and other fuel-specific parameters (i.e., leafless or green in deciduous trees, crown base height in coniferous trees, and percent curing in grasses). 

If set to *Yes* a fire rate of spread map will be created, and if set to *No* a fire rate of spread map will not be created.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: No
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

### **Fire Intensity Map**

**Column internal name:** FireIntensity

Describes the predicted intensity (energy output in kW/m) of the fire as it initially passes through the cell. The Fire Intensity (FI) metric is based on the Rate of Spread (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">ROS</a>), and the Total Fuel Consumption (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">TFC</a>). 

If set to *Yes* a fire intensity map will be created, and if set to *No* a fire intensity map will not be created.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: No
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

### **Spread Direction Map**

**Column internal name:** SpreadDirection

Describes the predicted direction of fire spread.

If set to *Yes* a fire spread direction map will be created, and if set to *No* a fire spread direction map will not be created.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: No
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

### **Surface Fuel Consumption Map**

**Column internal name:** SurfaceFuelConsumption

Describes the predicted amount (kg/m2) of fuel consumed by the fire on the surface of the forest floor.

If set to *Yes* a surface fuel consumption map will be created, and if set to *No* a surface fuel consumption map will not be created.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: No
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

### **Crown Fraction Burned Map**

**Column internal name:** CrownFractionBurned

Describes the predicted fraction (%) of tree crowns burned by the fire. The Crown Fraction Burned (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">CFB</a>) is based on the Buildup Index (BUI), foliar moisture content, surface fuel consumption, and Rate of Spread (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">ROS</a>). 

If set to *Yes* a crown fraction burned map will be created, and if set to *No* a crown fraction burned map will not be created.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: No
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

### **Crown Fraction Consumed Map**

**Column internal name:** CrownFractionConsumed

Describes the predicted fraction (%) of tree crowns consumed by the fire. 

If set to *Yes* a crown fraction consumed map will be created, and if set to *No* a crown fraction consumed map will not be created.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: No
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

### **Total Fuel Consumption Map**

**Column internal name:** TotalFuelConsumption

Describes the predicted amount (kg/m2) of fuel consumed by the fire on the forest floor and in the crown. The Total Fuel Consumption (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">TFC</a>) is based on foliar moisture content, surface fuel consumption, and Rate of Spread (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">ROS</a>). 

If set to *Yes* a total fuel consumption map will be created, and if set to *No* a total fuel consumption map will not be created.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: No
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

<br>