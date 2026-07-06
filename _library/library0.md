---
layout: default
section: 0
title: BurnP3+
permalink: reference/batch-burns
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
        {% endif %}
    {% endfor %}
</div>

# **BurnP3+**

In SyncroSim Studio, the following *library datasheet* can be accessed by right-clicking on the library name in the Explorer, selecting **Open** from the context menu, and navigating to the **BurnP3+** tab to open the **Batch Burns** datasheet.

<br>

## **Batch Burns**

**Datasheet internal name:** burnP3Plus_BatchOption


### **Batch Size (ignitions)**

**Column internal name:** BatchSize

This option is used by **BurnP3+** to determine how many fires should be run at a time (per job) by the model. Note that the number of fires being run per job is unrelated to the number of fires per iteration; it is simply for computing efficiency. Larger batch sizes allow the models to run more efficiently, but smaller batch sizes help limit the size of temporary files on disk. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: 250


<br>