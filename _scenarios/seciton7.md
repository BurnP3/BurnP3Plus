---
layout: default
section: 7
title: FireSTARR
permalink: reference/fire-star-scenario
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
            <a href="#heading01"> &emsp;&emsp;&emsp;Fire Behaviour Prediction (FBP) Outputs</a>
            <a href="#heading02"> &emsp;&emsp;&emsp;Output Rate of Spread Map</a>
            <a href="#heading03"> &emsp;&emsp;&emsp;Output Fire Intensity Map</a>
            <a href="#heading04"> &emsp;&emsp;&emsp;Output Spread Direction Map</a>
        {% endif %}
    {% endfor %}
</div>

# **BurnP3+ FireSTARR**

<br>

<p id="heading01"> <h2><b>Fire Behaviour Prediction (FBP) Outputs</b></h2> </p>

**Datasheet internal name:** burnP3PlusFireSTARR_OutputOptionSpatial

The **FBP Outputs** datasheet can be found under the **BurnP3+ FireSTARR** tab within the **Output Options** node and provides specifications on the spatial output maps.

### **Rate of Spread Map**

**Column internal name:** RateofSpread

Describes the predicted speed (m/min) of fire as it initially passes through the cell. The Rate of Spread (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">ROS</a>) metric is based on the Fuel Type, Initial Spread Index (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">ISI</a>),  Buildup Index (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">BUI</a>), and other fuel-specific parameters (i.e., leafless or green in deciduous trees, crown base height in coniferous trees, and percent curing in grasses). 

If set to *Yes* a fire rate of spread map will be created, and if set to *No* a fire rate of spread map will not be created.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

### **Fire Intensity Map**

**Column internal name:** FireIntensity

Describes the predicted intensity (energy output in kW/m) of the fire as it initially passes through the cell. The Fire Intensity (FI) metric is based on the Rate of Spread (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">ROS</a>), and the Total Fuel Consumption (<a href="https://cwfis.cfs.nrcan.gc.ca/background/summary/fbp" target="_blank">TFC</a>).

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

### **Spread Direction Map**

**Column internal name:** SpreadDirection

Describes the predicted direction of fire spread.

If set to *Yes* a fire spread direction map will be created, and if set to *No* a fire spread direction map will not be created. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Boolean

<br>

<p id="heading02"> <h2><b>Output Rate of Spread Map</b></h2> </p>

**Datasheet internal name:** burnP3PlusFireSTARR_OutputRateOfSpreadMap

### **Iteration**

**Column internal name:** Iteration

Specifies the map’s iteration.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

### **Timestep**

**Column internal name:** Timestep

Specifies the map’s timestep.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

### **FireID**

**Column internal name:** FireID

Specifies the map’s ID.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

### **FileName**

**Column internal name:** FileName

Specifies the map’s file name.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

### **Band**

**Column internal name:** Band

Specifies the map’s band.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

<br>

<p id="heading03"> <h2><b>Output Fire Intensity Map</b></h2> </p>

**Datasheet internal name:** burnP3PlusFireSTARR_OutputFireIntensityMap

### **Iteration**

**Column internal name:** Iteration

Specifies the map’s iteration.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

### **Timestep**

**Column internal name:** Timestep

Specifies the map’s timestep.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

### **FireID**

**Column internal name:** FireID

Specifies the map’s ID.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

### **FileName**

**Column internal name:** FileName

Specifies the map’s file name.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

### **Band**

**Column internal name:** Band

Specifies the map’s band.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

<br>

<p id="heading04"> <h2><b>Output Spread Direction Map</b></h2> </p>

**Datasheet internal name:** burnP3PlusFireSTARR_OutputSpreadDirectionMap

### **Iteration**

**Column internal name:** Iteration

Specifies the map’s iteration.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

### **Timestep**

**Column internal name:** Timestep

Specifies the map’s timestep.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

### **FireID**

**Column internal name:** FireID

Specifies the map’s ID.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

### **FileName**

**Column internal name:** FileName

Specifies the map’s file name.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

### **Band**

**Column internal name:** Band

Specifies the map’s band.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

<br>
