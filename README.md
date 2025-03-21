# **BurnP3+**

**BurnP3+** is an open-source [SyncroSim](http://www.syncrosim.com) package for running spatially-explicit fire growth models to explore fire risk and susceptibility across a landscape. 

* See the [Home page](https://burnp3.github.io/BurnP3Plus/) for an overview of **BurnP3+**
* See the [Getting Started](https://burnp3.github.io/BurnP3Plus/getting_started.html) page to get up and running quickly

**BurnP3+** is funded, developed and maintained by the [Canadian Forest Service](https://www.nrcan.gc.ca/our-natural-resources/forests-forestry/the-canadian-forest-service/about-canadian-forest-service/17545).

## Installing a BP3+ package from folder

Follow the instructions below to install the latest BurnP3Plus code from this GitHub repository as a package in SyncroSim Studio.

1. Clone the **BurnP3Plus** repository 

    - The BurnP3Plus repository can be cloned using both the command prompt and desktop. For detailed instructions, see the official GitHub guide here: <a href = "https://docs.github.com/en/repositories/creating-and-managing-repositories/cloning-a-repository#cloning-a-repository" target = "_blank">Cloning a repository</a>.

    - Cloning the repository will create a folder named **BurnP3Plus** in your current directory containing all repository files.

    ![Repository folder location.](./Figures/repo-folder-location.png)

<br>

2. Install the **BurnP3Plus** package from folder in SyncroSim Studio 

    - Open <a href = "https://syncrosim.com/download/" target = "_blank">SyncroSim Studio</a>.

    -  Navigate to **File > Local Packages**. 

    ![File > Local packages.](./Figures/file-local-packages.png)

    - Click **Install from Folder...**.

    ![Local packages window.](./Figures/local-packages-window.png)

    - Select the **src** subfolder from within the cloned **BurnP3Plus** repository and click **OK**. 

    ![Browse for folder.](./Figures/browse-for-folder.png)

    - The **burnP3Plus** package should now appear in the **Local Packages** list.

    ![Installed burnP3Plus package.](./Figures/burnP3Plus-package.png)

<br>

> _**NOTE**: If you modify the package version number in the src/package.xml file of the folder, or you pull a more recent version of the package folder from the GitHub repository, you may run into an error when you try to open your BurnP3+ library. See <a href = "https://community.syncrosim.com/forums/topic/syncrosim-package-version-mismatch/" target = "_blank">this forum post</a> for more information on how to handle this error._

<br>