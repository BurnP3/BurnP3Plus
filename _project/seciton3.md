---
layout: default
section: 3
title: FireSTARR
permalink: reference/fire-starr
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
            <a href="#heading01"> &emsp;&emsp;&emsp;FireSTARR Crosswalk</a>
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

# **BurnP3+ FireSTARR**

In SyncroSim Studio, the following *project datasheets* can be accessed by right-clicking on **Definitions** in the Explorer, selecting **Open** from the context menu, and navigating to the **BurnP3+ FireSTARR** tab.

<br>

<p id="heading01"> <h2><b>FireSTARR Crosswalk</b></h2> </p>

**Datasheet internal name:** burnP3PlusFireSTARR_FuelCodeCrosswalk

The **FireSTARR Crosswalk** datasheet can be found under the **BurnP3+ FireSTARR** tab and contains information about the fuel types associated with the study area. The Fuel Types in the Crosswalk must match the Names of the fuel types in the BurnP3+ \| <a href="burn-p3-plus#heading01">Fuel Types</a> datasheet. The fuel Crosswalk links the pre-defined BurnP3+ \| <a href="burn-p3-plus#heading01">Fuel Types</a> Names to the fuels in the FireSTARR fire growth model.

*Note: The FireSTARR Crosswalk is identical to the Prometheus Crosswalk. As a result, data can be exported and imported between the two datasheets without any modifications.*


### **Fuel Type**

**Column internal name:** FuelType

Defines a name for the fuel type. The name of the fuel type is selected from a dropdown menu, the values of which are populated from the BurnP3+ \| <a href="burn-p3-plus#heading01">Fuel Types</a> datasheet. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: List Item 


### **FireSTARR Fuel Code**

**Column internal name:** Code

Defines the FBP fuel type code. The fuel type code is selected from the available FBP fuel type codes in Canada. For example, “D-1/D-2” corresponds to Aspen [Fuel Type](#fuel-type). 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: List Item

<br>