library(rsyncrosim)
library(tidyverse)
library(raster)
library(terra)

# Setup ----
progressBar(type = "message", message = "Preparing inputs...")

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
  updateRunLog("No spatial output options chosen. Defaulting to keeping all spatial outputs.")
  OutputOptionsSpatial[1,] <- rep(TRUE, length(OutputOptionsSpatial[1,]))
  saveDatasheet(myScenario, OutputOptionsSpatial, "burnP3Plus_OutputOptionSpatial")
}
  

## Function definitions ----

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

# Summarize fires ----

if(OutputOptionsSpatial$BurnCount | OutputOptionsSpatial$BurnProbability | OutputOptionsSpatial$RelativeBurnProbability) {
  # Calculate burn count
  burnMapRaster <- 
    # Read in burn maps as raster stack
    tryCatch(datasheetRaster(myScenario, "burnP3Plus_OutputBurnMap", "FileName"),
             error = function(e) NULL)
  
  # Check that there are outputs to summarize
  if(!is.null(burnMapRaster)) {
    
    # Initialize the SyncroSim progress bar
    progressBar("begin", totalSteps = nlayers(burnMapRaster))
    progressBar(type = "message", message = "Summarizing fires...")
    
    # Setup counter
    burnCountRaster <- raster(subset(burnMapRaster, 1)) %>%
      raster::setValues(rep(0, ncell(burnMapRaster)))
    
    for(i in seq(nlayers(burnMapRaster))) {
      # Update progress bar
      progressBar()
      
      # Binarize and add another burn map to burn counter
      burnCountRaster <<- subset(burnMapRaster, i) %>%
        min(1) %>%
        `+`(burnCountRaster)
    }
    
    progressBar(type = "message", message = "Writing spatial outputs...")
    raster::writeRaster(burnCountRaster, burnCountFile, datatype = "INT4S", NAflag = -9999, overwrite = T)
    
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
        raster::writeRaster(burnProbabilityFile, datatype = "FLT8S", NAflag = -9999, overwrite = T)
      
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