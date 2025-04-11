---
layout: default
section: 5
title: BurnP3+
permalink: reference/burn-p3-plus-scenario
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
            <a href="#heading01"> &emsp;&emsp;&emsp;Run Control</a>
            <a href="#heading02"> &emsp;&emsp;&emsp;Landscape Maps</a>
            <a href="#heading03"> &emsp;&emsp;&emsp;Ignition Count</a>
            <a href="#heading04"> &emsp;&emsp;&emsp;Ignition Location</a>
            <a href="#heading05"> &emsp;&emsp;&emsp;Ignition Restrictions</a>
            <a href="#heading06"> &emsp;&emsp;&emsp;Ignition Distribution</a>
            <a href="#heading07"> &emsp;&emsp;&emsp;Spread Event Days</a>
            <a href="#heading08"> &emsp;&emsp;&emsp;Daily Burning Hours</a>
            <a href="#heading09"> &emsp;&emsp;&emsp;Daily Weather</a>
            <a href="#heading10"> &emsp;&emsp;&emsp;Weather Sampling Options</a>
            <a href="#heading11"> &emsp;&emsp;&emsp;Green Up</a>
            <a href="#heading12"> &emsp;&emsp;&emsp;Curing</a>
            <a href="#heading13"> &emsp;&emsp;&emsp;Grass Fuel Load</a>
            <a href="#heading14"> &emsp;&emsp;&emsp;Wind Grid</a>
            <a href="#heading15"> &emsp;&emsp;&emsp;Tabular</a>
            <a href="#heading16"> &emsp;&emsp;&emsp;Spatial</a>
            <a href="#heading17"> &emsp;&emsp;&emsp;Deterministic Ignition Count</a>
            <a href="#heading18"> &emsp;&emsp;&emsp;Deterministic Ignition Location</a>
            <a href="#heading19"> &emsp;&emsp;&emsp;Deterministic Burn Conditions</a>
            <a href="#heading20"> &emsp;&emsp;&emsp;Fire Resampling Options</a>
            <a href="#heading21"> &emsp;&emsp;&emsp;Distributions</a>
            <a href="#heading22"> &emsp;&emsp;&emsp;Output Fire Statistics Table</a>
        {% endif %}
    {% endfor %}
</div>

# **BurnP3+**



<br>

<p id="heading01"> <h2><b>Run Control</b></h2> </p>

### **Number of Iterations**

<br>

<p id="heading02"> <h2><b>Landscape Maps</b></h2> </p>

### **Fuel**

### **Elevation (Optional)**

### **Fire Zone (Optional)**

### **Weather Zone (Optional)**


<br>

<p id="heading03"> <h2><b>Ignition Count</b></h2> </p>

### **Ignition Count**

### **Ignition Count Distribution**

### **Ignition Count SD**

### **Ignition Count Min**

### **Ignition Count Max**

### **Ignition Count Distribution Examples**


<br>

<p id="heading04"> <h2><b>Ignition Location</b></h2> </p>

### **Probabilistic Ignition Grid**

### **Season**

### **Cause**


<br>

<p id="heading05"> <h2><b>Ignition Restrictions</b></h2> </p>

### **Fuel Type**

### **Season**

### **Cause**

### **Fire Zone**

### **Ignition Restrictions Examples**


<br>

<p id="heading06"> <h2><b>Ignition Distribution</b></h2> </p>

### **Relative Likelihood**

### **Season**

### **Cause**

### **Fire Zone**

### **Ignition Count Distribution Examples**


<br>

<p id="heading07"> <h2><b>Spread Event Days</b></h2> </p>

### **Season**

### **Fire Zone**

### **Fire Duration (Days)**

### **Fire Duration Distribution**

### **Fire Duration SD**

### **Fire Duration Min**

### **Fire Duration Max**

### **Fire Duration Distribution Examples**


<br>

<p id="heading08"> <h2><b>Daily Burning Hours</b></h2> </p>

### **Season**

### **Daily Burning Hours**

### **Daily Burning Hours Distribution**

### **Daily Burning Hours SD**

### **Daily Burning Hours Min**

### **Daily Burning Hours Max**

### **Daily Burning Hours Distribution Examples**


<br>

<p id="heading09"> <h2><b>Daily Weather</b></h2> </p>

### **Temperature**

### **Relative Humidity**

### **Wind Speed**

### **Wind Direction**

### **Precipitation**

### **Fine Fuel Moisture Code**

### **Duff Moisture Code**

### **Drought Code**

### **Initial Spread Index**

### **Build Up Index**

### **Fire Weather Index**

### **Season**

### **Weather Zone**


<br>

<p id="heading10"> <h2><b>Weather Sampling Options</b></h2> </p>

### **Sample Weather Sequentially**


<br>

<p id="heading11"> <h2><b>Green Up</b></h2> </p>

### **Green Up**

### **Season**


<br>

<p id="heading12"> <h2><b>Curing</b></h2> </p>

### **Curing**

### **Season**


<br>

<p id="heading13"> <h2><b>Grass Fuel Load</b></h2> </p>

### **Grass Fuel Load**

### **Season**


<br>

<p id="heading14"> <h2><b>Wind Grid</b></h2> </p>

### **Prevailing Wind Speed**

### **Wind Speed North**

### **Wind Speed North East**

### **Wind Speed East**

### **Wind Speed South East**

### **Wind Speed South**

### **Wind Speed South West**

### **Wind Speed West**

### **Wind Speed North West**

### **Wind Direction North**

### **Wind Direction North East**

### **Wind Direction East**

### **Wind Direction South East**

### **Wind Direction South**

### **Wind Direction South West**

### **Wind Direction West**

### **Wind Direction North West**


<br>

<p id="heading15"> <h2><b>Tabular</b></h2> </p>

### **Fire Statistics Table**


<br>

<p id="heading16"> <h2><b>Spatial</b></h2> </p>

### **Burn Probability Map**

### **Seasonal Burn Probability Map**

### **Relative Burn Probability Map**

### **Seasonal Relative Burn Probability Map**

### **Burn Count Map**

### **Seasonal Burn Count Map**

### **Burn Maps**

### **Seasonal Burn Maps**

### **Burn Perimeters**

### **Output Individual Burn Maps**



<br>

<p id="heading17"> <h2><b>Deterministic Ignition Count</b></h2> </p>

### **Iteration**

### **Ignitions**


<br>

<p id="heading18"> <h2><b>Deterministic Ignition Location</b></h2> </p>

### **Iteration**

### **Fire ID**

### **Latitude**

### **Longitude**

### **Season**

### **Cause**



<br>

<p id="heading19"> <h2><b>Deterministic Burn Conditions</b></h2> </p>

### **Iteration**

### **Fire ID**

### **Burn Day**

### **Hours Burning**

### **Temperature**

### **Relative Humidity**

### **Wind Speed**

### **Wind Direction**

### **Precipitation**

### **Fine Fuel Moisture Code**

### **Duff Moisture Code**

### **Drought Code**

### **Initial Spread Index**

### **Build Up Index**

### **Fire Weather Index**



<br>

<p id="heading20"> <h2><b>Fire Resampling Options</b></h2> </p>

### **Minimum Fire Size (ha)**

### **Proportion of Extra Ignitions to Sample for Replacing Fires below Minimum Size**


<br>

<p id="heading21"> <h2><b>Distributions</b></h2> </p>

### **Name**

### **Value**

### **Relative Frequency**


<br>

<p id="heading22"> <h2><b>Output Fire Statistics Table</b></h2> </p>

### **Iteration**

### **Fire ID**

### **Latitude**

### **Longitude**

### **Fuel Type**

### **Fire Duration**

### **Hours Burning**

### **Area**

### **Resample Status**

### **Season**

### **Cause**

### **Fire Zone**

### **Weather Zone**


<br>