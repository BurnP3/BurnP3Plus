# Clean global environment variables
native_proj_lib <- Sys.getenv("PROJ_LIB")
Sys.unsetenv("PROJ_LIB")
options(scipen = 999)

# Check and load packages ----
library(rsyncrosim)
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))

checkPackageVersion <- function(packageString, minimumVersion){
  result <- compareVersion(as.character(packageVersion(packageString)), minimumVersion)
  if (result < 0) {
    updateRunLog("The R package ", packageString, " (", 
         as.character(packageVersion(packageString)), 
         ") does not meet the minimum requirements (", minimumVersion, 
         ") for this version of BurnP3+. Please upgrade this package if the scenario fails to run.", 
         type = "warning")
  } else if (result > 0) {
    updateRunLog("Using a newer version of ", packageString, " (", 
                 as.character(packageVersion(packageString)), 
                 ") than BurnP3+ was built against (", 
                 minimumVersion, ").", type = "info")
  }
}

checkPackageVersion("rsyncrosim", "2.1.0")
checkPackageVersion("tidyverse",  "2.0.0")
checkPackageVersion("dplyr",      "1.1.2")
checkPackageVersion("codetools",  "0.2.19")
checkPackageVersion("data.table", "1.14.8")
checkPackageVersion("terra",      "1.5.21")
checkPackageVersion("sf",         "1.0.7")

# Setup ----
progressBar(type = "message", message = "Preparing inputs...")
terraOptions(memmax = 2)

# Initialize first breakpoint for timing code
currentBreakPoint <- proc.time()

## Connect to SyncroSim ----

myScenario <- scenario()

# Load relevant datasheets
SeasonTable <- datasheet(myScenario, "burnP3Plus_Season", lookupsAsFactors = F, optional = T, includeKey = T, returnInvisible = T)
RunControl <- datasheet(myScenario, "burnP3Plus_RunControl", returnInvisible = T)
DeterministicIgnitionLocation <- datasheet(myScenario, "burnP3Plus_DeterministicIgnitionLocation", lookupsAsFactors = F, optional = T, returnInvisible = T) %>% unique
DeterministicBurnCondition <- datasheet(myScenario, "burnP3Plus_DeterministicBurnCondition", lookupsAsFactors = F, optional = T, returnInvisible = T) %>% unique
FBPVariableTable <- datasheet(myScenario, "burnP3Plus_FBPOutputVariable", lookupsAsFactors = F, optional = T, returnInvisible = T)
FBPStatisticTable <- datasheet(myScenario, "burnP3Plus_FBPOutputStatistic", lookupsAsFactors = F, optional = T, returnInvisible = T)
AllPerim <- datasheet(myScenario, "burnP3Plus_OutputAllPerim", returnInvisible = T)
OutputBurnMap <- datasheet(myScenario, "burnP3Plus_OutputBurnMap", returnInvisible = T)
OutputOptionsSpatial <- datasheet(myScenario, "burnP3Plus_OutputOptionSpatial", returnInvisible = T, optional = T) %>% mutate(BurnPerimeter = as.character(BurnPerimeter))
OutputOptionFBPSpatial <- datasheet(myScenario, "burnP3Plus_OutputOptionFBPSpatial", optional = T, returnInvisible = T) %>% mutate(Variable = as.character(Variable))
OutputFireStatistic <- datasheet(myScenario, "burnP3Plus_OutputFireStatistic", returnInvisible = T, optional = T) %>% arrange(Iteration, FireID)
OutputFirePerimeter <- datasheet(myScenario, "burnP3Plus_OutputFirePerimeter", returnInvisible = T, optional = T)

# Create function to test if datasheets are empty
isDatasheetEmpty <- function(ds){
  if (nrow(ds) == 0) {
    return(TRUE)
  }
  if (all(is.na(ds))) {
    return(TRUE)
  }
  return(FALSE)
}

## Handle empty values ----
if(isDatasheetEmpty(OutputOptionsSpatial)) {
  updateRunLog("No spatial output options chosen. Defaulting to keeping all spatial outputs and final burn perimeters.", type = "info")
  OutputOptionsSpatial[1,] <- rep(TRUE, length(OutputOptionsSpatial[1,]))
  OutputOptionsSpatial$BurnPerimeter <- "Final"
  saveDatasheet(myScenario, OutputOptionsSpatial, "burnP3Plus_OutputOptionSpatial")
} else if (any(is.na(OutputOptionsSpatial))) {
  updateRunLog("Missing one or more spatial output options. Defaulting to keeping unspecified spatial outputs.", type = "info")
  OutputOptionsSpatial <- OutputOptionsSpatial %>%
    replace(is.na(.), TRUE)
  OutputOptionsSpatial$BurnPerimeter <- replace(OutputOptionsSpatial$BurnPerimeter, OutputOptionsSpatial$BurnPerimeter == TRUE, "Final")
  saveDatasheet(myScenario, OutputOptionsSpatial, "burnP3Plus_OutputOptionSpatial")
}

if (!isDatasheetEmpty(OutputOptionFBPSpatial)) {
  # Fill missing values for all but Percentile outputs, which are left as NA to indicate non-use
  OutputOptionFBPSpatial <- OutputOptionFBPSpatial %>%
    mutate(across(
      any_of(c("Average", "Minimum", "Maximum", "Median", "Individual")),
      \(x) replace_na(x, FALSE)))
  
  saveDatasheet(myScenario, OutputOptionFBPSpatial, "burnP3Plus_OutputOptionFBPSpatial")

  # Parse table to determine which outputs should be generated
  outputComponentsToKeepDisplayName <- OutputOptionFBPSpatial %>%
    dplyr::filter(any(Average, Minimum, Maximum, Median, Individual, as.logical(c(Percentile1, Percentile2, Percentile3)))) %>%
    pull(Variable)
} else {
  # Set flags to not save FBP outputs
  outputComponentsToKeepDisplayName <- character(0)
}

## Parse multiprocessing options ----
# num_cores <- 1
# MultiProcessing <- datasheet(myScenario, "core_Multiprocessing")
# if (MultiProcessing$EnableMultiprocessing)
#   num_cores <- MultiProcessing$MaximumJobs
  
## Setup files and folders ----

# Create temp folder, ensure it is empty
tempDir <- ssimEnvironment()$TempDirectory %>%
  str_replace_all("\\\\", "/") %>%
  file.path("summary")
allPerimDir <- file.path(tempDir, "allPerim")
burnMapDir <- file.path(tempDir, "burnMap")

# Create path for geopackage for storing vector outputs
geopackage_path <- file.path(tempDir, "burn-perimeters.gpkg")
# Note geopackage recommends `_` for word separation in table, feature, etc names
geopackage_layer_name <-
  str_c(
    str_to_lower(OutputOptionsSpatial$BurnPerimeter),
    "_burn_perimeters"
  )

unlink(tempDir, recursive = T, force = T)
dir.create(tempDir, showWarnings = F)

# Generate filename prefixes for potential outputs
burnCountFilePrefix <- file.path(tempDir, "burnCount")
burnProbabilityFilePrefix <- file.path(tempDir, "burnProbability")
relativeBurnProbabilityFilePrefix <- file.path(tempDir, "relativeBurnProbability")
fbpSummaryFilePrefix <- file.path(tempDir, "fbpSummary")

## Function definitions ----

### Convenience and conversion functions ----

# Function to time code by returning a clean string of time since this function was last called
updateBreakpoint <- function() {
  # Calculate time since last breakpoint
  newBreakPoint <- proc.time()
  elapsed <- (newBreakPoint - currentBreakPoint)['elapsed']
  
  # Update current breakpoint
  currentBreakPoint <<- newBreakPoint
  
  # Return cleaned elapsed time
  if (elapsed < 60) {
    return(str_c(round(elapsed), " seconds"))
  } else if (elapsed < 60^2) {
    return(str_c(round(elapsed / 60, 1), " minutes"))
  } else
    return(str_c(round(elapsed / 60 / 60, 1), " hours"))
}

# Define a function to facilitate recoding values using a lookup table
lookup <- function(x, old, new) dplyr::recode(x, !!!set_names(new, old))

# Function to move a folder while minimizing temporary space on disk
# - Not currently set up for recursive folders
dir.move <- function(source, target) {
  # Ensure traget exists
  dir.create(target, showWarnings = F)

  # Move files one at a time
  for(f in list.files(source, full.names = T)) {
    file.copy(f, file.path(target, basename(f)))
    unlink(f, force = T)
  }
}

### Update functions ----
# Function to reassign Iterations and FireIDs from resampling
updateResampledFireIDs <- function(data, firesToReplace) {
  data %>%
    left_join(firesToReplace) %>%
    mutate(
      Iteration = if_else(!is.na(NewIteration), NewIteration, Iteration),
      FireID    = if_else(!is.na(NewFireID), NewFireID, FireID)) %>%
    dplyr::select(-NewIteration, -NewFireID) %>%
    arrange(Iteration, FireID)
}

# Function to add reassigned extra fires to existing burn maps
updateBurnMap <- function(NewIteration, data, OutputBurnMap, AllPerim, DeterministicIgnitionLocation) {
  # Initialize a temp file name
  tempFilename <- file.path(burnMapDir, "temp.tif")

  # Consider only burn maps for this iteration (up to one per season)
  OutputBurnMap <- OutputBurnMap %>%
    filter(Iteration == NewIteration)
  
  # Join season info to the individual burn maps of extra fires
  AllPerim <- AllPerim %>%
    filter(Iteration == 0) %>%
    left_join(DeterministicIgnitionLocation, by = c("Iteration", "FireID"))

  # Update burn maps one season at a time
  for(thisSeason in OutputBurnMap$Season) {
    # Load relevant burn map
    currentBurnMapFilename <- OutputBurnMap %>% filter(Season == thisSeason) %>% pull(FileName)

    if(length(currentBurnMapFilename) > 1) 
      stop("Found multiple burn maps for the ", thisSeason, " Season, iteration ", NewIteration, ".")

    burnMap <- tryCatch(
      rast(currentBurnMapFilename),
      error = function(e) stop("Could not find the ", thisSeason, " Season burn map for iteration ", NewIteration, " while reassigning extra fires to incomplete iterations."))
  
    # Iterate over extra fires
    for(extraIgnitionID in data$FireID) {
      # Only add relevant maps for this season
      if(thisSeason == "All" | lookup(extraIgnitionID, AllPerim$FireID, AllPerim$Season) == thisSeason) {

        # Load and add in the current extra fire to burn map
        additionalBurn <- tryCatch(
          rast(AllPerim %>% filter(FireID == extraIgnitionID) %>% pull(FileName)),
          error = function(e) stop("Could not find individual burn map for extra fire ", extraIgnitionID, " while reassigning extra fires to incomplete iterations."))
  
        burnMap <- burnMap + additionalBurn
      }
    }

    # Binarize accumulator to burn or not
    burnMap[burnMap != 0] <- 1

    # Write to temp file and overwrite old burn map
    terra::writeRaster(x = burnMap,
                       filename = currentBurnMapFilename,
                       overwrite = T,
                       filetype = "GTiff",
                       datatype = "INT2S",
                       gdal = c("COMPRESS=LZW",
                                "TFW=YES"),
                       NAflag = -9999)

    file.copy(tempFilename, currentBurnMapFilename, overwrite = T)
    unlink(tempFilename, force = T)
  }

}

### Summary functions ----

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

saveBurnPerimeters <- OutputOptionsSpatial$BurnPerimeter != "No"

# Set a flag to decide whether or not to handle secondary outputs
saveFBPMaps <- length(outputComponentsToKeepDisplayName) > 0

# Reassign extra fires if needed ----
# - Requires a minimum fire size greater than zero and sampled extra fires

# Placeholder for list of iterations that did not meet ignition targets
incompleteIterations <- integer(0)
firesToReplace <- data.frame()

# Decide if any resampling is required
requiresResample <- OutputFireStatistic %>%
  filter(Iteration > 0) %>%
  pull(ResampleStatus) %>%
  str_detect("Discarded") %>%
  any

if(requiresResample) {
  # Identify fires available for reassignement
  validExtraFires <- OutputFireStatistic %>%
    filter(ResampleStatus == "Extra") %>%
    transmute(
      Iteration = Iteration,
      FireID = FireID,
      UniqueID = row_number())
  
  # Identify new fire IDs required to replace discarded fires
  requiredFires <- OutputFireStatistic %>%
    group_by(Iteration) %>%
    mutate(TargetIgnitions = max(FireID)) %>%
    filter(
      Iteration > 0,
      ResampleStatus == "Discarded") %>%
    mutate(NewFireID = TargetIgnitions + row_number()) %>%
    ungroup() %>%
    transmute(
      NewIteration = Iteration,
      NewFireID    = NewFireID,
      UniqueID     = row_number())

  # Sequentially re-assign extra fires to new required IDs 
  firesToReplace <- inner_join(validExtraFires, requiredFires, by = "UniqueID", relationship = "one-to-one") %>%
    dplyr::select(-UniqueID)

  # Identify any iterations that could not meet targets after reassignment
  incompleteIterations <- anti_join(requiredFires, validExtraFires, by = "UniqueID") %>%
    pull(NewIteration) %>%
    unique

  # Update output fire statistics table
  OutputFireStatistic <- OutputFireStatistic %>%
    mutate(OriginalFireID = if_else(ResampleStatus == "Extra", FireID, NA)) %>%
    updateResampledFireIDs(firesToReplace) %>%
    mutate(
      OriginalFireID = if_else(Iteration == 0, NA, OriginalFireID), # Extra fires that are not resampled don't require original fire id values
      ResampleStatus = case_when(
        ResampleStatus == "Extra" & Iteration == 0 ~ "Not Used",
        ResampleStatus == "Extra" & Iteration != 0  ~ "Reassigned",
        TRUE ~ ResampleStatus))

  saveDatasheet(
    myScenario,
    OutputFireStatistic,
    "burnP3Plus_OutputFireStatistic",
    append = FALSE)

  # Report iterations that did not meet ignition targets
  if(length(incompleteIterations) > 0)
    updateRunLog("Could not sample enough fires above the specified minimum fire size for ", length(incompleteIterations), " iterations.",
                 "\nPlease increase the 'Proportion of Extra Ignition to Sample' in the Fire Resampling Options or decrease the 'Minimum Fire Size'.",
                 "\nPlease see the Fire Statistics table for details on specific iterations, fires, and burn conditions. Incomplete iterations will not be included in summary burn maps\n", type = "warning") 

  ## Update burn maps if any extra fires were reassigned ----
  if(nrow(firesToReplace) > 0 & saveBurnMaps) {
    # Move burn maps to temp folder
    OutputBurnMap %>%
      pull(FileName) %>%
      head(1) %>%
      dirname %>%
      dir.move(burnMapDir)

    OutputBurnMap <- OutputBurnMap %>% mutate(FileName = file.path(burnMapDir,  basename(FileName)))

    # Group replacements by iteration and update burn maps in place accordingly
    firesToReplace %>%
      group_by(NewIteration) %>%
      nest() %>%
      pwalk(updateBurnMap, OutputBurnMap = OutputBurnMap, AllPerim = AllPerim, DeterministicIgnitionLocation = DeterministicIgnitionLocation)

    # Save back to SyncroSim
    saveDatasheet(myScenario, OutputBurnMap, "burnP3Plus_OutputBurnMap", append = F)

    ## Update All Perim maps to match new assignments ----
    if (OutputOptionsSpatial$AllPerim) {
      AllPerim <- updateResampledFireIDs(AllPerim, firesToReplace) %>%
        mutate(Timestep = FireID) # Used for plotting Individual Burn Perims in SSim UI
      saveDatasheet(myScenario, AllPerim, "burnP3Plus_OutputAllPerim")
    } else { # Otherwise remove any records and maps to avoid confusion
      rsyncrosim::delete(myScenario, datasheet = "burnP3Plus_OutputAllPerim", force = T)
    }

    # Note that Burn Perimeters and Individual FBP Maps are reassigned in their respective sections below
  }

  if(nrow(firesToReplace) > 0 ) {
    ## Update Deterministic Input tables ----
    DeterministicIgnitionLocation <- updateResampledFireIDs(DeterministicIgnitionLocation, firesToReplace)
    saveDatasheet(myScenario, DeterministicIgnitionLocation, "burnP3Plus_DeterministicIgnitionLocation")

    DeterministicBurnCondition <- updateResampledFireIDs(DeterministicBurnCondition, firesToReplace)
    saveDatasheet(myScenario, DeterministicBurnCondition, "burnP3Plus_DeterministicBurnCondition")
  }
}

# Report burn stats ----
updateRunLog("\nBurn Summary:\n", 
               nrow(OutputFireStatistic), " fires burned. \n",
               sum(OutputFireStatistic$ResampleStatus == "Discarded"), " fires discarded due to insufficient burn area.\n",
               round(sum(OutputFireStatistic$ResampleStatus != "Discarded") / nrow(OutputFireStatistic) * 100, 0), "% of simulated fires were above the minimum fire size.\n",
               round(sum(OutputFireStatistic$ResampleStatus == "Not Used") / max(1, nrow(OutputFireStatistic %>% filter(Iteration == 0))) * 100, 0), "% of extra simulated fires not used because target ignition counts were already met.\n")


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

  # Start by setting up an empty template
  emptyTemplate <- NULL
  if(!isDatasheetEmpty(OutputBurnMap))
    emptyTemplate <- OutputBurnMap %>%
      pull(FileName) %>%
      pluck(1) %>%
      {tryCatch(rast(.) %>% rast(vals = 0), error = function(e) NULL)}

  # Load in burn maps by season and replace any empty sets with a zero raster
  burnMapRasters <- 
    map(seasonValues, function(thisSeason) {
      # Read in burn maps per season as raster stack
      tryCatch(
        OutputBurnMap %>%
          filter(
            Season == thisSeason,
            !Iteration %in% incompleteIterations) %>% # Filter out any iterations that did not meet their ignition targets after reassignment
          pull(FileName) %>%
          rast,
        error = function(e) emptyTemplate) # If no valid maps are found for a given season for the entire run
    }) %>%
    set_names(seasonValues) %>%
    discard(is.null)
  
  # Check that there are outputs to summarize
  if(length(burnMapRasters) > 0) {
    
    # Initialize the SyncroSim progress bar
    progressBar("begin", totalSteps = length(burnMapRasters))
    progressBar(type = "message", message = "Summarizing fires...")
    
    # Setup counter
    burnCountRasters <- rast(burnMapRasters[[1]][[1]], vals = 0) %>%
      list() %>%
      rep(length(seasonValues)) %>%
      set_names(names(burnMapRasters))
    
    # Sum layers by season
    # - note the use of `terraOptions` above to set max memory use
    for(thisSeason in names(burnCountRasters)) {
      for(thisLayer in seq(nlyr(burnMapRasters[[thisSeason]]))) {
        progressBar()
        burnCountRasters[[thisSeason]] <- burnCountRasters[[thisSeason]] + burnMapRasters[[thisSeason]][[thisLayer]]
        # Update progress bar
      }
    }
    
    # Reclassify NaN to NA for consistency with other layers
    burnCountRasters <- burnCountRasters %>%
      map(classify, rcl = matrix(c(NaN, NA), ncol = 2)) 

    # Write out all relevant burn count rasters
    progressBar(type = "message", message = "Writing spatial outputs...")

    # Build up burn count raster file names
    burnCountFilenames <- names(burnCountRasters) %>%
      map_chr(function(seasonName) str_c(burnCountFilePrefix, "-sn", lookup(seasonName, SeasonTable$Name, SeasonTable$SeasonId), ".tif")) %>%
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
          Iteration = 0,
          Timestep = 0,
          FileName = burnCountFilenames,
          Season = str_extract(FileName, "\\d+.tif") %>% str_sub(end = -5) %>% as.integer()) %>%
          mutate(
            Season = lookup(Season, SeasonTable$SeasonId, SeasonTable$Name)) %>%
          as.data.frame(),
        "burnP3Plus_OutputBurnCount")
    
    # Calculate and save burn probability if requested by user
    if(OutputOptionsSpatial$BurnProbability         | OutputOptionsSpatial$SeasonalBurnProbability |
       OutputOptionsSpatial$RelativeBurnProbability | OutputOptionsSpatial$SeasonalRelativeBurnProbability) {

      burnProbabilityRasters <- burnCountRasters %>%
        map(function(burnCountRaster) (burnCountRaster / max(RunControl$MaximumIteration - length(incompleteIterations), 1))) %>%
        set_names(names(burnCountRasters))

      # Discard seasonal probabilities if not requested
      if(!OutputOptionsSpatial$SeasonalBurnProbability & !OutputOptionsSpatial$SeasonalRelativeBurnProbability)
        burnProbabilityRasters <- burnProbabilityRasters %>%
          keep_at("All")

      # Build up probabilty raster file names
      burnProbabilityFilenames <- names(burnProbabilityRasters) %>%
        map_chr(function(seasonName) str_c(burnProbabilityFilePrefix, "-sn", lookup(seasonName, SeasonTable$Name, SeasonTable$SeasonId), ".tif")) %>%
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
            Iteration = 0,
            Timestep = 0,
            FileName = burnProbabilityFilenames,
            Season = str_extract(FileName, "\\d+.tif") %>% str_sub(end = -5) %>% as.integer()) %>%
            mutate(
              Season = lookup(Season, SeasonTable$SeasonId, SeasonTable$Name)) %>%
            as.data.frame(),
          "burnP3Plus_OutputBurnProbability")
      
      if(OutputOptionsSpatial$RelativeBurnProbability | OutputOptionsSpatial$SeasonalRelativeBurnProbability) {
        # Discard seasonal files if not requested
        if(!OutputOptionsSpatial$SeasonalRelativeBurnProbability)
          burnProbabilityFilenames <- burnProbabilityFilenames %>%
            keep_at("All")

        # Build up relative probabilty raster file names
        relativeBurnProbabilityFilenames <- names(burnProbabilityFilenames) %>%
          map_chr(function(seasonName) str_c(relativeBurnProbabilityFilePrefix, "-sn", lookup(seasonName, SeasonTable$Name, SeasonTable$SeasonId), ".tif")) %>%
          set_names(names(burnProbabilityFilenames))

        # Calculate relative burn probabilities
        pwalk(list(burnProbabilityFilename = burnProbabilityFilenames, relativeBurnProbabilityFilename = relativeBurnProbabilityFilenames, seasonName = names(burnProbabilityFilenames)),
          function(burnProbabilityFilename, relativeBurnProbabilityFilename, seasonName) {
            mean_bp_classification(input = burnProbabilityFilename, output_filename = relativeBurnProbabilityFilename, seasonName = seasonName)
          })

        saveDatasheet(
          myScenario,
          tibble(
            Iteration = 0,
            Timestep = 0,
            FileName = relativeBurnProbabilityFilenames,
            Season = str_extract(FileName, "\\d+.tif") %>% str_sub(end = -5) %>% as.integer()) %>%
            mutate(
              Season = lookup(Season, SeasonTable$SeasonId, SeasonTable$Name)) %>%
            as.data.frame(),
          "burnP3Plus_OutputRelativeBurnProbability")
      }
    }
  }
}

# Consolidate fire perimeter geopackages if necessary
if (saveBurnPerimeters) {
  # Append geopackages one by one to new geopackage path
  # - layer name is used on read to ensure all inputs are the same variable type (final or daily) as expected in output
  # - also reassign fire ids and iterations if extra fires were resampled
  for (f in OutputFirePerimeter$FileName) {
    st_read(f, layer = geopackage_layer_name, quiet = T) %>%
      {if(nrow(firesToReplace) > 0) updateResampledFireIDs(., firesToReplace) else .} %>%
      st_write(
        dsn = geopackage_path,
        layer = geopackage_layer_name,
        quiet = TRUE,
        append = TRUE)
  }

  OutputFirePerimeter <-
    tibble(
      FileName = geopackage_path %>% normalizePath(mustWork = F),
      Description = 
        str_c(
          OutputOptionsSpatial$BurnPerimeter,
          " burn perimeters")
    ) %>%
    as.data.frame()

  saveDatasheet(myScenario, OutputFirePerimeter, "burnP3Plus_OutputFirePerimeter", append = FALSE)
}

# Wrap up SyncroSim progress bar
progressBar("end")
updateRunLog("Finished summarizing burn probability in ", updateBreakpoint(), "\n\n")

# Save FBP Summary Maps
if (saveFBPMaps) {
  progressBar("begin", totalSteps = OutputOptionFBPSpatial %>% dplyr::select(-Variable, -Individual) %>% as.matrix %>% as.logical %>% sum(na.rm = T))
  progressBar(type = "message", message = "Summarizing FBP Outputs...")

  # Decide which burn components to keep
  outputComponentsToKeep <- outputComponentsToKeepDisplayName %>%
    lookup(FBPVariableTable$DisplayName, FBPVariableTable$Name)
  
  # Iterate over FBP variables to keep
  for (component in outputComponentsToKeep) {
    # Connect to per-fire raw outputs for this variable
    componentDatasheet <- datasheet(myScenario, str_c("burnP3Plus_Output", component, "Map"))

    # Reassign iteration and fire IDs from resampling if needed
    if(nrow(firesToReplace) > 0) {
      componentDatasheet <- updateResampledFireIDs(componentDatasheet, firesToReplace)
    } 
      
    # Load stack of relevant FBP rasters
    fbpStack <- componentDatasheet %>%
      left_join(OutputFireStatistic %>% dplyr::select(Iteration, FireID, ResampleStatus), by = c("Iteration", "FireID")) %>%
      dplyr::filter(
        ResampleStatus %in% c("Kept", "Reassigned"), # Discards unused extra fires and fire below minimum fire size
        !Iteration %in% incompleteIterations) %>%    # Discards fires from incomplete iterations
      pull(FileName) %>%
      rast()
    
    # Pull out the relevant row of the FBP output options table to identify which summaries to keep for this variable
    componentOutputOptions <- OutputOptionFBPSpatial %>%
      dplyr::filter(Variable == lookup(component, FBPVariableTable$Name, FBPVariableTable$DisplayName)) %>%
      as.list()

    # Initialize a table to hold the generated outputs
    OutputFBPSummary <- data.frame()
    
    # Iterate over summary statistics
    for (statistic_display_name in FBPStatisticTable$Name) {
      statistic <- statistic_display_name %>% str_replace(" ", "") # Percentile1, Percentile2, and Percentile3 all have spaces in their display names, but not in keys

      # Skip if this statistic is not requested for this FBP variable
      if (is.na(componentOutputOptions[statistic]) | !as.logical(componentOutputOptions[[statistic]]))
        next
      
      # Apply the statistic to the corresponding FBP raster stack and save to disk
      fbpSummaryMap <- NA
      if(statistic == "Average") {

        fbpSummaryMap <- rast(fbpStack[[1]], vals = NA_real_)
        for(thisLayer in seq(nlyr(fbpStack))) {
          fbpSummaryMap <- sum(fbpSummaryMap, fbpStack[[thisLayer]], na.rm = T)
        }
        fbpSummaryMap <- fbpSummaryMap / nlyr(fbpStack)

      } else if(statistic == "Minimum") {

        fbpSummaryMap <- rast(fbpStack[[1]], vals = NA_real_)
        for(thisLayer in seq(nlyr(fbpStack))) {
          fbpSummaryMap <- min(fbpSummaryMap, fbpStack[[thisLayer]], na.rm = T)
        }

      } else if(statistic == "Maximum") {

        fbpSummaryMap <- rast(fbpStack[[1]], vals = NA_real_)
        for(thisLayer in seq(nlyr(fbpStack))) {
          fbpSummaryMap <- max(fbpSummaryMap, fbpStack[[thisLayer]], na.rm = T)
        }

      } else {
        updateRunLog("Skipping unknown summary statistic \"", statistic, "\"", type = "warning")
      }

      # If a summary map was created
      if("SpatRaster" %in% class(fbpSummaryMap)) {
        # Generate file name and datasheet entry
        fbpSummaryFileName <- str_c(fbpSummaryFilePrefix, "-", component, "-", statistic, ".tif")
        OutputFBPSummary <- rbind(
          OutputFBPSummary,
          data.frame(
            Summary = statistic_display_name,
            Iteration = 0,
            Timestep = 0,
            FileName = fbpSummaryFileName))

        # Save summary map
        terra::writeRaster(
          x = fbpSummaryMap,
          filename = fbpSummaryFileName,
          overwrite = T,
          filetype = "GTiff",
          gdal = c("COMPRESS=LZW",
                   "TFW=YES"),
          NAflag = -9999)
      }
      
      progressBar()
    }

    # Save summary outputs for this FBP variable
    saveDatasheet(myScenario, OutputFBPSummary, str_c("burnP3Plus_Output", component, "SummaryMap"), append = FALSE)

    # Clear out raw FBP maps if not needed
    if(is.na(componentOutputOptions$Individual) | !componentOutputOptions$Individual) {
      rsyncrosim::delete(myScenario, datasheet = str_c("burnP3Plus_Output", component, "Map"), force = T)
      
    # Otherwise save any updated iteration / fire id reassignments from resampling back to the library
    } else {
      saveDatasheet(myScenario, componentDatasheet, str_c("burnP3Plus_Output", component, "Map"))
    }
  }

  updateRunLog("Finished summarizing FBP outputs in ", updateBreakpoint(), "\n\n")
  progressBar("end")
}

updateRunLog("Run Context: ", as.character(datasheet(myScenario, "core_Multiprocessing")$EnableMultiprocessing), "\n\n")