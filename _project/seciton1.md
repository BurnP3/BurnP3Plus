---
layout: default
section: 1
title: BurnP3+
permalink: reference/burn-p3-plus
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
            <a href="#heading01"> &emsp;&emsp;&emsp;Fuel Types</a>
            <a href="#heading02"> &emsp;&emsp;&emsp;Seasons</a>
            <a href="#heading03"> &emsp;&emsp;&emsp;Causes</a>
            <a href="#heading04"> &emsp;&emsp;&emsp;Fire Zones</a>
            <a href="#heading05"> &emsp;&emsp;&emsp;Weather Zones</a>
            <a href="#heading06"> &emsp;&emsp;&emsp;Distributions</a>
        {% endif %}
    {% endfor %}
    <li>Scenario</li>
    {% for section in site.scenarios %}
        {% if section.section != page.section %}
            <a href="{{site.baseurl}}{{ section.url }}"> &emsp;{{ section.title }} </a>
        {% else %}
            <a class="selected" href="{{site.baseurl}}{{ section.url }}"> &emsp;{{ section.title }} </a>
        {% endif %}
    {% endfor %}
</div>

# **BurnP3+**

In SyncroSim Studio, the following *project datasheets* can be accessed by right-clicking on **Definitions** in the Explorer, selecting **Open** from the context menu, and navigating to the **BurnP3+** tab.

<br>

# **Fuels**

The **Fuels** node contains the **Fuel Types** datasheet.

<p id="heading01"> <h2><b>Fuel Types</b></h2> </p>

**Datasheet internal name:** burnP3Plus_FuelType

The **Fuel Types** datasheet can be found under the **Fuels** node and contains information about the fuel types associated with the study area.

The fuel definitions are free-form but must later be connected (i.e., using a crosswalk) to the modeled fuels defined in the various deterministic fire growth models. Currently, all the fire growth models available for BurnP3+ use the Fuel types classified in the Canadian Fire Behaviour Prediction (FBP) System. The FBP System is a subsystem of the Canadian Forest Fire Danger Rating System (CFFDRS) and produces quantitative fire behaviour outputs <a href="https://ostrnrcan-dostrncan.canada.ca/entities/publication/18cdf7dd-2488-4df4-8cc7-62fb1eebf9ed" target="_blank">Parisien et al., 2005</a>. 

For more information on the Canadian Fire Behaviour Prediction (FBP) System fuel type descriptions, visit this <a href="https://cwfis.cfs.nrcan.gc.ca/background/fueltypes/c1" target="_blank">link</a>.


### **Name**

**Column internal name:** Name

Defines a name for the fuel type. E.g., “Boreal Spruce”. Fuel Names are defined by the user (i.e., free-form) and must match the name(s) of the Fuel Type(s) in the fuel Crosswalk (e.g., <a href="fire-starr#heading01">FireSTARR Crosswalk</a>).

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String


### **ID**

**Column internal name:** ID

Defines a numerical ID for the fuel type. The numerical IDs specified in this datasheet should match the values in the scenario-scoped <a href="#heading01">Fuel Type</a> raster.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer


### **Description**

**Column internal name:** Description

*Optional*. Provides a description of the fuel type.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String


### **Color**

**Column internal name:** Color

*Optional*. Defines a color for each fuel type to be used when visualizing the fuel types in the SyncroSim Map Viewer. If defining the color programmatically from R or Python, the color is determined using hex color codes (e.g., “#1473c8”).

*Note: automatic color legends are not yet available.*

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

<br>

# **Advanced**

The **Advanced** node groups the following project datasheets:
* Seasons
* Causes
*	Fire Zones
*	Weather Zones
*	Distributions


<p id="heading02"> <h2><b>Seasons</b></h2> </p>

**Datasheet internal name:** burnP3Plus_Season

The Seasons datasheet is used for determining which seasons to include in the analysis. Seasons denote any way of temporal partitioning of the data to account for fuel changes (green-up, grass-curing) or weather conditions. Seasons *do not* directly affect fire behaviour; instead, they are assigned to cell values in the corresponding maps, and are used to spatially stratify ignition sampling distributions, weather streams, etc. 


### **Name**

**Column internal name:** Name

Provides a name for the season. E.g., “Spring”.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String


### **Median Julian Day**

**Column internal name:** JulianDay

Provides a number between 1 and 364 for the median Julian day of the year for a Season. All fires sampled under a Season are burned on this day of the year. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: 182
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer


### **Description**

**Column internal name:** Description

*Optional*. Provides a description of the season.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

<br>

<p id="heading03"> <h2><b>Causes</b></h2> </p>

**Datasheet internal name:** burnP3Plus_Cause

The Causes datasheet is used to set specific fire causes in the analysis. Specifying fire Causes may also be used to sample from different Ignition Location probabilities, restrict different ignition Fuels, etc. 

### **Name**

**Column internal name:** Name

Provides a name for the fire cause. E.g., “Human” or “Lightning”.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

### **Description**

**Column internal name:** Description

*Optional*. Provides a description of the fire cause.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

<br>

<p id="heading04"> <h2><b>Fire Zones</b></h2> </p>

**Datasheet internal name:** burnP3Plus_FireZone

The Fire Zones datasheet is used to set fire zones in the analysis. Fire zones *do not* directly affect fire behaviour; instead, they are assigned to cell values in the corresponding maps, and are used to spatially stratify ignition sampling distributions, weather streams, etc. 


### **Name**

**Column internal name:** Name

Provides a name for the fire zone. E.g., “Englemann Spruce Subalpine Fir”.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String


### **ID**

**Column internal name:** ID

Provides a numerical ID for the fire zone. IDs must match the fire zone raster.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer


### **Description**

**Column internal name:** Description

*Optional*. Provides a description of the fire zone.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String


### **Color**

**Column internal name:** Color

*Optional*. Defines a color for each fire zone to be used when visualizing the fire zones in the SyncroSim Map Viewer. If defining the color programmatically from R or Python, the color is determined using hex color codes (e.g., “#1473c8”).

*Note: automatic color legends are not yet available.*

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

<br>

<p id="heading05"> <h2><b>Weather Zones</b></h2> </p>

**Datasheet internal name:** burnP3Plus_WeatherZone

The Weather Zones datasheet is used to set weather zones in the analysis. Once fire ignition location is determined, weather zones are used to ensure the weather draw only occurs from the appropriate zone. Weather zones *do not* directly affect fire behaviour; instead, they are assigned to cell values in the corresponding maps, and are used to spatially stratify ignition sampling distributions, weather streams, etc.


### **Name**

**Column internal name:** Name

Provides a name for the weather zone. E.g., “Englemann Spruce Subalpine Fir”.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String


### **ID**

**Column internal name:** ID

Provides a numerical ID for the weather zone. IDs must match the weather zone raster.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer


### **Description**

**Column internal name:** Description

*Optional*. Provides a description of the weather zone.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String


### **Color**

**Column internal name:**  Color

*Optional*. Defines a color for each weather zone to be used when visualizing the weather zones in the SyncroSim Map Viewer. If defining the color programmatically from R or Python, the color is determined using hex color codes (e.g., “#1473c8”).

*Note: automatic color legends are not yet available.*

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

<br>

<p id="heading06"> <h2><b>Distributions</b></h2> </p>

**Datasheet internal name:** burnP3Plus_Distribution

The **Distributions** datasheet is used to define distributions in the analysis. Further information on the distribution(s) defined in this datasheet is input in the <a href="burn-p3-plus-scenario#heading21">scenario Distributions datasheet</a>.


### **Name**

**Column internal name:** Name

Provides a name for a custom sampling distribution. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String


### **Description**

**Column internal name:** Description

*Optional*. Provides a description of the sampling distribution. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: String

<br>