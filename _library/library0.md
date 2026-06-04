---
layout: default
section: 0
title: Batch Burns
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

# **Batch Burns**

**Datasheet internal name:** burnP3Plus_BatchOption

The **Batch Burns** node is a *library datasheet*.

In SyncroSim Studio, it can be accessed by right-clicking on the **BurnP3+** library name in the *explorer* panel (top-left), selecting **Open** from the context menu, navigating to the *BurnP3+ tab* to open **Batch Burns** window.

<br>


### **Batch Size (ignitions)**

**Column internal name:** BatchSize

This option is used by **BurnP3+** to determine how many fires should be run at a time (per job) by the model. Note that the number of fires being run per job is unrelated to the number of fires per iteration; it is simply for computing efficiency. Larger batch sizes allow the models to run more efficiently, but smaller batch sizes help limit the size of temporary files on disk. 

&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Data Type*: Integer
<br>
&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; *Default*: 250


<br>