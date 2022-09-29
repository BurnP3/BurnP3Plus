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
RunControl <- datasheet(myScenario, "burnP3Plus_RunControl")
OutputOptionsSpatial <- datasheet(myScenario, "burnP3Plus_OutputOptionSpatial")

## Setup files and folders ----

# Create temp folder, ensure it is empty
tempDir <- ssimEnvironment()$TempDirectory %>%
  str_replace_all("\\\\", "/") %>%
  file.path("summary")
unlink(tempDir, recursive = T, force = T)
dir.create(tempDir, showWarnings = F)

# Generate filenames for potential outputs
burnCountFile <- file.path(tempDir, "burnCount.tif")
burnProbabilityFile <- file.path(tempDir, "burnProbability.tif")
relativeBurnProbabilityFile <- file.path(tempDir, "relativeBurnProbability.tif")

## Handle empty values ----
if(nrow(OutputOptionsSpatial) == 0) {
  updateRunLog("No spatial output options chosen. Defaulting to keeping all spatial outputs.", type = "info")
  OutputOptionsSpatial[1,] <- rep(TRUE, length(OutputOptionsSpatial[1,]))
  saveDatasheet(myScenario, OutputOptionsSpatial, "burnP3Plus_OutputOptionSpatial")
}
  

## Function definitions ----

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
mean_bp_classification <- function(input,output_filename){
  
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

# Summarize fires ----

if(OutputOptionsSpatial$BurnCount | OutputOptionsSpatial$BurnProbability | OutputOptionsSpatial$RelativeBurnProbability) {
  # Calculate burn count
  burnMapRaster <- 
    # Read in burn maps as raster stack
    tryCatch(
      datasheet(myScenario, "burnP3Plus_OutputBurnMap")[["FileName"]] %>%
        {file.path(ssimEnvironment()$OutputDirectory, str_c("Scenario-", ssimEnvironment()$ScenarioId), "burnP3Plus_OutputBurnMap", basename(.))} %>%
        rast,
      error = function(e) NULL)
  
  # Check that there are outputs to summarize
  if(!is.null(burnMapRaster)) {
    
    # Initialize the SyncroSim progress bar
    progressBar("begin", totalSteps = nlyr(burnMapRaster))
    progressBar(type = "message", message = "Summarizing fires...")
    
    # Setup counter
    burnCountRaster <- sum(burnMapRaster)
    
    progressBar(type = "message", message = "Writing spatial outputs...")
    terra::writeRaster(burnCountRaster, 
                       burnCountFile, 
                       wopt = list(filetype = "GTiff",
                                   datatype = "INT4S",
                                   gdal = c("COMPRESS=DEFLATE","ZLEVEL=9","PREDICTOR=2")), 
                       NAflag = -9999, overwrite = T)
    
    # Save burn count if requested by user
    if(OutputOptionsSpatial$BurnCount)
      saveDatasheet(
        myScenario,
        data.frame(Iteration = 1, Timestep = 0, FileName = burnCountFile),
        "burnP3Plus_OutputBurnCount")
    
    # Calculate and save burn probability if requested by user
    if(OutputOptionsSpatial$BurnProbability | OutputOptionsSpatial$RelativeBurnProbability){
      burnProbabilityRaster <-
        (burnCountRaster / RunControl$MaximumIteration) %>%
        terra::writeRaster(filename = burnProbabilityFile,
                           wopt = list(filetype = "GTiff",
                                       gdal = c("COMPRESS=DEFLATE","ZLEVEL=9","PREDICTOR=2")),
                           NAflag = -9999, 
                           overwrite = T)
      
      if(OutputOptionsSpatial$BurnProbability)
        saveDatasheet(
          myScenario,
          data.frame(Iteration = 1, Timestep = 0, FileName = burnProbabilityFile),
          "burnP3Plus_OutputBurnProbability")
      
      if(OutputOptionsSpatial$RelativeBurnProbability) {
        mean_bp_classification(input = burnProbabilityFile, output_filename = relativeBurnProbabilityFile)
        saveDatasheet(
          myScenario,
          data.frame(Iteration = 1, Timestep = 0, FileName = relativeBurnProbabilityFile),
          "burnP3Plus_OutputRelativeBurnProbability")
      }
    }
  }
}

# Wrap up SyncroSim progress bar
progressBar("end")
updateRunLog("Finished summarizing burn probability in ", updateBreakpoint(), "\n\n")