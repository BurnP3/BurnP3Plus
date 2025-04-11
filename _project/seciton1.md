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



<br>

<p id="heading01"> <h2><b>Fuel Types</b></h2> </p>

### **Name**

### **ID**

### **Description**

### **Color**

<br>


<p id="heading02"> <h2><b>Seasons</b></h2> </p>

### **Name**

### **Description**

### **Median Julian Day**

<br>

<p id="heading03"> <h2><b>Causes</b></h2> </p>

### **Name**

### **Description**

<br>

<p id="heading04"> <h2><b>Fire Zones</b></h2> </p>

### **Name**

### **ID**

### **Description**

### **Color**

<br>

<p id="heading05"> <h2><b>Weather Zones</b></h2> </p>

### **Name**

### **ID**

### **Description**

### **Color**

<br>

<p id="heading06"> <h2><b>Distributions</b></h2> </p>

### **Name**

### **Description**

<br>