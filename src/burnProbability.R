library(rsyncrosim)
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(terra))

# Setup ----
progressBar(type = "message", message = "Preparing inputs...")

# Initialize first breakpoint for timing code
currentBreakPoint <- proc.time()

## Connect to SyncroSim ----

myScenario <- scenario()

# Load relevant datasheets
SeasonTable <- datasheet(myScenario, "burnP3Plus_Season", lookupsAsFactors = F, optional = T, includeKey = T)
RunControl <- datasheet(myScenario, "burnP3Plus_RunControl")
OutputOptionsSpatial <- datasheet(myScenario, "burnP3Plus_OutputOptionSpatial")

## Setup files and folders ----

# Create temp folder, ensure it is empty
tempDir <- ssimEnvironment()$TempDirectory %>%
  str_replace_all("\\\\", "/") %>%
  file.path("summary")
unlink(tempDir, recursive = T, force = T)
dir.create(tempDir, showWarnings = F)

# Generate filename prefixes for potential outputs
burnCountFilePrefix <- file.path(tempDir, "burnCount")
burnProbabilityFilePrefix <- file.path(tempDir, "burnProbability")
relativeBurnProbabilityFilePrefix <- file.path(tempDir, "relativeBurnProbability")

## Handle empty values ----
if(nrow(OutputOptionsSpatial) == 0) {
  updateRunLog("No spatial output options chosen. Defaulting to keeping all spatial outputs.", type = "info")
  OutputOptionsSpatial[1,] <- rep(TRUE, length(OutputOptionsSpatial[1,]))
  saveDatasheet(myScenario, OutputOptionsSpatial, "burnP3Plus_OutputOptionSpatial")
} else if (any(is.na(OutputOptionsSpatial))) {
  updateRunLog("Missing one or more spatial output options. Defaulting to keeping unspecified spatial outputs.", type = "info")
  OutputOptionsSpatial <- OutputOptionsSpatial %>%
    replace(is.na(.), TRUE)
  saveDatasheet(myScenario, OutputOptionsSpatial, "burnP3Plus_OutputOptionSpatial")
}
  

## Function definitions ----

### Convenience and conversion functions ----

# Define a function to facilitate recoding values using a lookup table
lookup <- function(x, old, new) dplyr::recode(x, !!!set_names(new, old))

### Summary functions ----

# Function to time code by returning a clean string of time since this function was last called
updateBreakpoint <- function() {
  # Calculate time since last breakpoint
  newBreakPoint <- proc.time()
  elapsed <- (newBreakPoint - currentBreakPoint)['elapsed']
  
  # Update current breakpoint
  currentBreakPoint <<- newBreakPoint
  
  # Return cleaned elapsed time
  if (elapsed < 60) {
    return(str_c(round(elapsed), "sec"))
  } else if (elapsed < 60^2) {
    return(str_c(round(elapsed / 60, 1), "min"))
  } else
    return(str_c(round(elapsed / 60 / 60, 1), "hr"))
}

# Taken from Brett's helper package
# - Consider importing package instead
mean_bp_classification <- function(input, output_filename, seasonName){
  
  if ( grepl("SpatRast", class(input)) ) { bp <- input }
  if ( grepl("character", class(input)) ) { bp <- terra::rast(input) }
  if ( !grepl("SpatRast|character", class(input)) ) { message("Reference Grid must be the directory of the raster or a raster object.") }
  
  bp[][bp[] == 0] <- NA
  mean_bp <- mean(x = bp[],
                  na.rm = T)
  mean_bp.r <- bp/mean_bp
  print(paste0("The mean burn probability is: ", round(mean_bp,4)))
  bp_vals <- terra::values(mean_bp.r)
  bp_vals[bp_vals[] < 1 & bp_vals[] > 0 & !is.na(bp_vals)] <- (1/bp_vals[bp_vals[] < 1 & bp_vals[] > 0 & !is.na(bp_vals)])*-1
  mean_bp.r <- terra::setValues(x = mean_bp.r,
                                values = bp_vals
  )
  mean_bp.r <- terra::classify(mean_bp.r,
                               rcl = matrix(ncol = 3,
                                            byrow = T,
                                            data = c(-Inf,-10,-11,10,Inf,11)
                               )
  )
  
  # Add a standardized background
  # - NA for no values in the fuel grid, 0 for never burned / non-fuel
  mean_bp.r <- terra::classify(mean_bp.r,
                               rcl = matrix(ncol = 2,
                                            byrow = T,
                                            data = c(NA, 0))) %>%
    terra::mask(burnCountRasters[[seasonName]])
  
  terra::writeRaster(x = mean_bp.r,
                     filename = output_filename,
                     overwrite = T,
                     filetype = "GTiff",
                     datatype = "INT2S",
                     gdal = c("COMPRESS=LZW",
                              "TFW=YES"),
                     NAflag = -9999
  )
}

updateRunLog("Finished preparing inputs in ", updateBreakpoint())

# Extract relevant parameters ----
# Decide whether or not to save spatial summary outputs
saveBurnMaps <- any(OutputOptionsSpatial$BurnProbability, OutputOptionsSpatial$SeasonalBurnProbability,
                    OutputOptionsSpatial$RelativeBurnProbability, OutputOptionsSpatial$SeasonalRelativeBurnProbability,
                    OutputOptionsSpatial$BurnCount, OutputOptionsSpatial$SeasonalBurnCount)

# Decide whether or not to save seasonal spatial summary outputs
saveSeasonalBurnMaps <- any(OutputOptionsSpatial$SeasonalBurnProbability,
                            OutputOptionsSpatial$SeasonalRelativeBurnProbability,
                            OutputOptionsSpatial$SeasonalBurnCount)

# Summarize fires ----

if(saveBurnMaps) {

  # Identify seasons in project (always at least includes "All")
  if(saveSeasonalBurnMaps) {
    seasonValues <- SeasonTable %>%
      pull(Name) %>%
      unique
  } else {
     seasonValues <- "All"
  }

  # Calculate burn count

  # Start by loading in burn maps by season and discarding any empty outputs
  burnMapRasters <- 
    map(seasonValues, function(thisSeason) {
      # Read in burn maps per season as raster stack
      tryCatch(
        datasheet(myScenario, "burnP3Plus_OutputBurnMap") %>%
          filter(Season == thisSeason) %>%
          pull(FileName) %>%
          {file.path(ssimEnvironment()$OutputDirectory, str_c("Scenario-", ssimEnvironment()$ScenarioId), "burnP3Plus_OutputBurnMap", basename(.))} %>%
          rast,
        error = function(e) NULL)
    }) %>%
    set_names(seasonValues) %>%
    discard(is.null)
  
  # Check that there are outputs to summarize
  if(length(burnMapRasters) > 0) {
    
    # Initialize the SyncroSim progress bar
    progressBar("begin", totalSteps = nlyr(burnMapRasters[[1]]) * length(burnMapRasters))
    progressBar(type = "message", message = "Summarizing fires...")
    
    # Setup counter
    burnCountRasters <- rast(burnMapRasters[[1]][[1]], vals = 0) %>%
      list() %>%
      rep(length(seasonValues)) %>%
      set_names(names(burnMapRasters))
    
    # Sum one layer at a time to avoid loading entire burn stack into memory with `terra::sum()`
    for(thisSeason in names(burnCountRasters)) {
      for(thisLayer in seq(nlyr(burnMapRasters[[thisSeason]]))) {
        # Update progress bar
        progressBar()

        burnCountRasters[[thisSeason]] <- burnCountRasters[[thisSeason]] + burnMapRasters[[thisSeason]][[thisLayer]]
      }
    }
    
    # Reclassify NaN to NA for consistency with other layers
    burnCountRasters <- burnCountRasters %>%
      map(classify, rcl = matrix(c(NaN, NA), ncol = 2)) 

    # Write out all relevant burn count rasters
    progressBar(type = "message", message = "Writing spatial outputs...")

    # Build up burn count raster file names
    burnCountFilenames <- names(burnCountRasters) %>%
      map_chr(function(seasonName) str_c(burnCountFilePrefix, "-sn", lookup(seasonName, SeasonTable$Name, SeasonTable$SeasonID), ".tif")) %>%
      set_names(names(burnCountRasters))

    # Write out count rasters by season
    walk2(burnCountRasters, burnCountFilenames,
      function(burnCountRaster, burnCountFilename) {
        terra::writeRaster(burnCountRaster, 
                           filename = burnCountFilename, 
                           wopt = list(filetype = "GTiff",
                                       datatype = "INT4S",
                                       gdal = c("COMPRESS=DEFLATE","ZLEVEL=9","PREDICTOR=2")), 
                           NAflag = -9999, overwrite = T)
      })
    
    # Save burn count if requested by user
    if(OutputOptionsSpatial$BurnCount)
      saveDatasheet(
        myScenario,
        tibble(
          Iteration = 1,
          Timestep = 0,
          FileName = burnCountFilenames,
          Season = str_extract(FileName, "\\d+.tif") %>% str_sub(end = -5) %>% as.integer()) %>%
          mutate(
            Season = lookup(Season, SeasonTable$SeasonID, SeasonTable$Name)) %>%
          as.data.frame(),
        "burnP3Plus_OutputBurnCount")
    
    # Calculate and save burn probability if requested by user
    if(OutputOptionsSpatial$BurnProbability         | OutputOptionsSpatial$SeasonalBurnProbability |
       OutputOptionsSpatial$RelativeBurnProbability | OutputOptionsSpatial$SeasonalRelativeBurnProbability) {

      burnProbabilityRasters <- burnCountRasters %>%
        map(function(burnCountRaster) (burnCountRaster / RunControl$MaximumIteration)) %>%
        set_names(names(burnCountRasters))

      # Discard seasonal probabilities if not requested
      if(!OutputOptionsSpatial$SeasonalBurnProbability & !OutputOptionsSpatial$SeasonalRelativeBurnProbability)
        burnProbabilityRasters <- burnProbabilityRasters %>%
          keep_at("All")

      # Build up probabilty raster file names
      burnProbabilityFilenames <- names(burnProbabilityRasters) %>%
        map_chr(function(seasonName) str_c(burnProbabilityFilePrefix, "-sn", lookup(seasonName, SeasonTable$Name, SeasonTable$SeasonID), ".tif")) %>%
        set_names(names(burnProbabilityRasters))

      # Write out probability rasters by season
      walk2(burnProbabilityRasters, burnProbabilityFilenames,
        function(burnProbabilityRaster, burnProbabilityFilename) {
          terra::writeRaster(burnProbabilityRaster,
                             filename = burnProbabilityFilename,
                             wopt = list(filetype = "GTiff",
                                         gdal = c("COMPRESS=DEFLATE","ZLEVEL=9","PREDICTOR=2")),
                             NAflag = -9999, 
                             overwrite = T)
        })
      
      if(OutputOptionsSpatial$BurnProbability)
        saveDatasheet(
          myScenario,
          tibble(
            Iteration = 1,
            Timestep = 0,
            FileName = burnProbabilityFilenames,
            Season = str_extract(FileName, "\\d+.tif") %>% str_sub(end = -5) %>% as.integer()) %>%
            mutate(
              Season = lookup(Season, SeasonTable$SeasonID, SeasonTable$Name)) %>%
            as.data.frame(),
          "burnP3Plus_OutputBurnProbability")
      
      if(OutputOptionsSpatial$RelativeBurnProbability | OutputOptionsSpatial$SeasonalRelativeBurnProbability) {
        # Discard seasonal files if not requested
        if(!OutputOptionsSpatial$SeasonalRelativeBurnProbability)
          burnProbabilityFilenames <- burnProbabilityFilenames %>%
            keep_at("All")

        # Build up relative probabilty raster file names
        relativeBurnProbabilityFilenames <- names(burnProbabilityFilenames) %>%
          map_chr(function(seasonName) str_c(relativeBurnProbabilityFilePrefix, "-sn", lookup(seasonName, SeasonTable$Name, SeasonTable$SeasonID), ".tif")) %>%
          set_names(names(burnProbabilityFilenames))

        # Calculate relative burn probabilities
        pwalk(list(burnProbabilityFilename = burnProbabilityFilenames, relativeBurnProbabilityFilename = relativeBurnProbabilityFilenames, seasonName = names(burnProbabilityFilenames)),
          function(burnProbabilityFilename, relativeBurnProbabilityFilename, seasonName) {
            mean_bp_classification(input = burnProbabilityFilename, output_filename = relativeBurnProbabilityFilename, seasonName = seasonName)
          })

        saveDatasheet(
          myScenario,
          tibble(
            Iteration = 1,
            Timestep = 0,
            FileName = relativeBurnProbabilityFilenames,
            Season = str_extract(FileName, "\\d+.tif") %>% str_sub(end = -5) %>% as.integer()) %>%
            mutate(
              Season = lookup(Season, SeasonTable$SeasonID, SeasonTable$Name)) %>%
            as.data.frame(),
          "burnP3Plus_OutputRelativeBurnProbability")
      }
    }
  }
}

# Wrap up SyncroSim progress bar
progressBar("end")
updateRunLog("Finished summarizing burn probability in ", updateBreakpoint(), "\n\n")