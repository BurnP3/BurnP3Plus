# Setup ----
Sys.unsetenv("PROJ_LIB")
library(rsyncrosim)

# Testing:
options(pillar.print_min = 50)

# Find location of shared function definitions and source
getSharedDefinitionsPath <- function() {
  sharedDefinitionsPath <- paste0(ssimEnvironment()$PackageDirectory, "/shared.R")
  return(sharedDefinitionsPath)
}
source(getSharedDefinitionsPath())

generateSharedTempFilePaths("merge-burns")

# Function definitions ----

# Function to clean up data after loading
cleanMergedDatasheets <- function(mergedData) {
  mergedData %>%
    as_tibble %>%
    # Drop unneeded scenario info
    dplyr::select(-any_of(c(
      "ProjectId",
      "ScenarioName",
      "ParentId",
      "ParentName",
      "Timestep"))) %>%
    # Drop duplicate data from within a scenario
    unique 
}

# Function to update merged spreadsheets
mergeDatasheets <- function(scenariosToMerge, datasheetName, crosswalk) {
  mergedData <- scenariosToMerge %>%
    # Load data using map since datasheet sometimes fails when given a list of scenarios directly
    map_dfr(
      datasheet,
      datasheetName,
      optional = T,
      returnInvisible = T,
      returnScenarioInfo = T) %>%
    # Clean up unneeded columns, etc
    cleanMergedDatasheets() %>%
    # Identify the new iteration and fire id post merge
    left_join(
      crosswalk,
      by = c("ScenarioId", "Iteration", "FireID")) %>%
    mutate(Iteration = NewIteration, FireID = NewFireID) %>%
    # Clean up
    dplyr::select(-ScenarioId, -NewIteration, -NewFireID) %>%
    arrange(Iteration, FireID) %>%
    as.data.frame()

  # Save back to SyncroSim
  saveDatasheet(myScenario, mergedData, datasheetName)

  return(mergedData)
}

# Function to crosswalk and merge fire perimeter geopackages
mergeFirePerimeters <- function(ScenarioId, FileName, crosswalk, geopackage_path) {
  # Get layers present (in case there are multiple)
  layer_names <- st_layers(FileName)$name

  for(layer in layer_names) {
    # Read in the layer
    st_read(FileName, layer = layer, quiet = T) %>%
      # Use the crosswalk to update Iteration and FireID
      mutate(ScenarioId = ScenarioId) %>%
      left_join(
        crosswalk,
        by = c("ScenarioId", "Iteration", "FireID")) %>%
      mutate(
        Iteration = NewIteration,
        FireID = NewFireID) %>%
      dplyr::select(-ScenarioId, -NewIteration, -NewFireID) %>%
      # Append to output folder
      st_write(
        dsn = geopackage_path,
        layer = layer,
        quiet = TRUE,
        append = TRUE)
  }
}

# Function to crosswalk and merge fire perimeter geopackages
mergeRawTabular <- function(ScenarioId, BatchID, FileName, crosswalk, rawTableTempPath) {
  # Read in the layer
  arrow::open_dataset(FileName) %>%
    # Use the crosswalk to update Iteration and FireID
    mutate(
      ScenarioId = ScenarioId,
      BatchID = BatchID) %>%
    left_join(
      crosswalk,
      by = c("ScenarioId", "Iteration", "FireID")) %>%
    mutate(
      Iteration = as.integer(NewIteration),
      FireID = as.integer(NewFireID)) %>%
    dplyr::select(-ScenarioId, -NewIteration, -NewFireID) %>%
    # Append to temp file using BatchID to avoid overwriting past data
    arrow::write_dataset(
      path = rawTableTempPath,
      format = "arrow",
      partitioning = "BatchID",
      existing_data_behavior = "delete_matching")
    
  # Finally return a single row of the raw tabular output to track which FBP variables were included
  arrow::open_dataset(FileName)[1,] %>%
    dplyr::select(-Iteration, -FireID, -CellID) %>%
    as_tibble() %>%
    mutate(across(everything(), ~ TRUE)) %>%
    mutate(ScenarioId = ScenarioId) %>%
    return()
}

identifyIncompleteFBPRecords <- function(fbpColumnSummary) {
  scenariosMissingRecords <- fbpColumnSummary %>%
    dplyr::filter(if_any(everything(), is.na)) %>%
    pull(ScenarioId) %>%
    unique

  componentsMissingRecords <- fbpColumnSummary %>%
    dplyr::select(dplyr::where(~any(is.na(.)))) %>%
    colnames

  if (length(scenariosMissingRecords) > 0)
    updateRunLog(
      "The following scenarios: ",
      str_c(scenariosMissingRecords, collapse = " "),
      " are each missing one or more of the following FBP outputs: ",
      str_c(componentsMissingRecords, collapse = " "),
      " which are present in other scenarios in the merge. ",
      "Please be aware that summaries of these metrics will be accordingly incomplete.",
      type = "warning")
}

## Prepare for merge ----

# Identify scenarios to merge
myLibrary <- ssimLibrary(myScenario)
allScenarios <- scenario(myLibrary, summary = T) %>%
  dplyr::select(ScenarioId, ParentId, IsResult)
scenariosToMerge <- myScenario %>%
  # Find parent of the current scenario
  parentId %>%
  scenario(myLibrary, scenario = .) %>%
  # Find dependencies of the parent (sorted by scenario ID)
  dependency %>%
  pull(ScenarioId) %>%
  sort() %>%
  map(function(sid) {
    scnInfo <- allScenarios %>%
      dplyr::filter(ScenarioId == sid)

    # TODO: filter out failed runs
    # If this is a result scenario, there's nothing to do
    if (scnInfo$IsResult == "Yes")
      return(sid)
    
    # If not, find all child scenarios
    allScenarios %>%
      dplyr::filter(ParentId == sid) %>%
      pull(ScenarioId) %>%
      return()
    }) %>%
  as_vector() %>%
  # Convert to a list of scenarios
  scenario(myLibrary, scenario = .)

updateRunLog("Merging ", length(scenariosToMerge), " scenarios.", type = "status")
progressBar(message = str_c("Merging ", length(scenariosToMerge), " scenarios..."), type = "message")

# Build crosswalk for fires after merge ----
# Start by finding iterations and fire ids in each scenario
firesByScenario <- 
  map_dfr(
    scenariosToMerge,
    datasheet,
    "burnP3Plus_DeterministicIgnitionLocation",
    returnScenarioInfo = T,
    returnInvisible = T) %>%
  cleanMergedDatasheets() %>%
  arrange(ScenarioId, Iteration, FireID) %>%
  dplyr::select(ScenarioId, Iteration, FireID)

# Build a cross walk to assign new iterations and fire ids to avoid conflicts
fireCrosswalk <- bind_rows(
  # Extra ignitions will remain as extras and just be assigned a new fire id in sequential order
  firesByScenario %>% 
    dplyr::filter(Iteration == 0) %>%
    mutate(
      NewIteration = 0,
      NewFireID = row_number()),
  # Regular ignitions will maintain their current fire id but iterations will be updated to avoid duplicates
  firesByScenario %>%
    dplyr::filter(Iteration != 0) %>%
    # Summarize is used to get back a single row for each iteration so we can count how many unique iterations are present
    summarize(.by = c("ScenarioId", "Iteration")) %>%
    mutate(NewIteration = row_number()) %>%
    # We join this back to the fires by scenario table to get back the fire id information we dropped in the summarize
    left_join(
      firesByScenario,
      by = c("ScenarioId", "Iteration")) %>%
    mutate(NewFireID = FireID)) %>%
  mutate(across(everything(), as.integer))

# Update tabular datasheets ----
# Some data to update is just stored directly in datasheets, these can be merged by applying the crosswalk

# Deterministic Ignition Locations
mergeDatasheets(
  scenariosToMerge,
  "burnP3Plus_DeterministicIgnitionLocation",
  fireCrosswalk)

# Deterministic Burn Conditions
mergeDatasheets(
  scenariosToMerge,
  "burnP3Plus_DeterministicBurnCondition",
  fireCrosswalk)

# Output Fire Statistics
mergeDatasheets(
  scenariosToMerge,
  "burnP3Plus_OutputFireStatistic",
  fireCrosswalk)

# Update external file datasheets ----
# Some data are stored in external files that need to be loaded and merged

# Burn perimeters ----

# Pick where to store merged fire perimeters and reset the file
# Crosswalk and merge geopackages
scenariosToMerge %>%
  # Read in data 
  map_dfr(
    datasheet,
    "burnP3Plus_OutputFirePerimeter",
    optional = T,
    returnInvisible = T,
    returnScenarioInfo = T) %>%
  # Clean up
  cleanMergedDatasheets() %>%
  dplyr::select(ScenarioId, FileName) %>%
  # Crosswalk fire indies
  pwalk(mergeFirePerimeters, crosswalk = fireCrosswalk, geopackage_path = geopackage_path)

# Validate perimeter type and use to determine Description of output
OutputFirePerimeter <-
  tibble(
    FileName = geopackage_path %>% normalizePath(mustWork = F),
    Description = getPerimeterType(geopackage_path)) %>%
  as.data.frame()

saveDatasheet(myScenario, OutputFirePerimeter, "burnP3Plus_OutputFirePerimeter", append = FALSE)

# Raw tabular outputs ----

# Pick where to store merged fire perimeters and reset the file
scenariosToMerge %>%
  # Read in data
  map_dfr(
    datasheet,
    "burnP3Plus_OutputRawTabular",
    optional = T,
    returnInvisible = T,
    returnScenarioInfo = T) %>%
  # Clean up
  cleanMergedDatasheets() %>%
  dplyr::select(ScenarioId, FileName) %>%
  mutate(BatchID = row_number()) %>%
  # Crosswalk
  pmap_dfr(mergeRawTabular, crosswalk = fireCrosswalk, rawTableTempPath = rawTableTempPath) %>%
  identifyIncompleteFBPRecords()

# Combine the partitioned temporary raw output to final and save back to SyncroSim using the consolidate tabular function
saveBurnMaps <- T
consolidateTabularOutputs()
