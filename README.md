# Burn-P3+

Burn-P3+ is a [SyncroSim](http://www.syncrosim.com) package that facilitates sampling spatially-explicit fire growth models to explore fire risk across a landscape. The package uses user-provided maps and rules to sample the ignitions and burn conditions that will be used as inputs for the external fire growth models. These fire growth models are provided as add-on packages to Burn-P3+. Two example fire growth model add-ons that wrap [Prometheus](https://github.com/BurnP3/BurnP3PlusPrometheus) and [Cell2Fire](https://github.com/BurnP3/BurnP3PlusCell2Fire) are provided, but developers can also [create their own](https://docs.syncrosim.com/how_to_guides/package_create_overview.html) add-on packages to provide additional fire growth models. The outputs of these models collected across realizations can then be summarized and visualized within SyncroSim or exported to plain text tabular formats and GDAL-compliant geospatial formats for more complex analyses using other tools.

## Getting Started

### Installation

The burnP3 package can be [built](https://docs.syncrosim.com/how_to_guides/package_create_bundle.html#step-2---bundle-the-package) and [installed](https://docs.syncrosim.com/how_to_guides/package_manager.html#2-installing-from-a-package-file) from file like any other package using the [SyncroSim Package Manager](https://docs.syncrosim.com/how_to_guides/package_manager.html). However, some external fire growth models have other external dependencies. 

### Running an Example

This package comes with a template library with data from Glacier National Park. Both the Promtheus and Cell2Fire add-on packages are required if you would like to run all the included scenarios.