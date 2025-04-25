---
layout: default
section: 2
title: Cell2Fire
permalink: reference/cell2-fire
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
            <a href="#heading01"> &emsp;&emsp;&emsp;Cell2Fire Crosswalk</a>
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

# **BurnP3+ Cell2Fire**

In SyncroSim Studio, the following *project datasheets* can be accessed by right-clicking on **Definitions** in the Explorer, selecting **Open** from the context menu, and navigating to the **BurnP3+ Cell2Fire** tab.

<br>

<p id="heading01"> <h2><b>Cell2Fire Crosswalk</b></h2> </p>

**Datasheet internal name:** burnP3PlusCell2Fire_FuelCodeCrosswalk

The **Cell2Fire Crosswalk** datasheet can be found under the **BurnP3+ Cell2Fire** tab and contains information about the fuel types associated with the study area. The Fuel Types in the Crosswalk must match the Names of the fuel types in the BurnP3+ \| <a href="burn-p3-plus#heading01">Fuel Types</a> datasheet. The fuel Crosswalk links the pre-defined BurnP3+ \| <a href="burn-p3-plus#heading01">Fuel Types</a> Names to the built-in fuels in the Cell2Fire fire growth model.


### **Fuel Type**

**Column internal name:** FuelType

Defines a name for the fuel type. The name of the fuel type is selected from a dropdown menu, the values of which are populated from the BurnP3+ \| <a href="burn-p3-plus#heading01">Fuel Types</a> datasheet. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: List Item


### **Cell2Fire Fuel Code**

**Column internal name:** Code

Defines the FBP fuel type code. The fuel type code is selected from the available FBP fuel type codes in Canada. For example, “C-2” corresponds to the Boreal Spruce [Fuel Type](#fuel-type).  

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: List Item


### **Percent Conifer**

**Column internal name:** PercentConifer

Defines the percentage of conifer fuels within a mixedwood fuel type. This is used to control the split of conifer fuels for Boreal Mixedwood – Leafless (M-1), and Boreal Mixedwood – Green (M-2).

Coniferous fuels (e.g., pine, spruce, etc.) tend to have greater flammability and intensity compared to deciduous trees due to their resin content, as well as increased likelihood of fire spread due to highly connected needle foliage and canopy structures.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer


### **Percent Dead Fir**

**Column internal name:** PercentDeadFir

Defines the percentage of dead fir fuels within a fuel type. This is used to control the split of conifer fuels for Dead Balsam Fir Mixedwood – Leafless (M-3), and Dead Balsam Fir Mixedwood – Green (M-4).

Due to extremely low moisture content in dead fir trees, these fuels can experience increased flammability. Additionally, highly connected horizontal and vertical dead fir fuels allow for greater fire spread throughout a forest stand.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer


### **Grass Fuel Loading**

**Column internal name:** GrassFuelLoading

Defines the grass fuel load within a fuel type.

This metric represents the amount of fine grass fuels available to burn, and affects fire intensity and fuel consumption rates. Greater grass fuel loads are associated with increased intensity and fuel consumption rates (and vice-versa). 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Double


### **Grass Curing**

**Column internal name:** GrassCuring

Defines the grass curing within a fuel type.

This metric represents the percent of dead, dry grass available to burn, and affects fire intensity and rate of spread.

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer

<br>