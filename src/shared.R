# Initial setup ----
progressBar(type = "message", message = "Preparing inputs...")

# Clean up environment variables and global options before loading packages
Sys.unsetenv("PROJ_LIB")
options(scipen = 999)

# Initialize first breakpoint for timing code
currentBreakPoint <- proc.time()

# Load packages
library(rsyncrosim)
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(lubridate))
suppressPackageStartupMessages(library(terra))
suppressPackageStartupMessages(library(sf))
suppressPackageStartupMessages(library(data.table))
suppressPackageStartupMessages(library(arrow))

# Function for validating package versions against what is expected
checkPackageVersion <- function(packageString, minimumVersion){
  result <- compareVersion(as.character(packageVersion(packageString)), minimumVersion)
  if (result < 0) {
    stop("The R package ", packageString, " (", as.character(packageVersion(packageString)), ") does not meet the minimum requirements (", minimumVersion, ") for this version of BurnP3+ FireSTARR. Please upgrade this package and rerun this scenario.", type = "warning")
  } else if (result > 0) {
    updateRunLog("Using a newer version of ", packageString, " (", as.character(packageVersion(packageString)), ") than BurnP3+ FireSTARR was built against (", minimumVersion, ").", type = "info")
  }
}

# Check pacakge versions against those expected
checkPackageVersion("rsyncrosim", "2.1.0")
checkPackageVersion("tidyverse",  "2.0.0")
checkPackageVersion("terra",      "1.5.21")
checkPackageVersion("sf",         "1.0.7")
checkPackageVersion("dplyr",      "1.1.2")
checkPackageVersion("codetools",  "0.2.19")
checkPackageVersion("data.table", "1.14.8")
checkPackageVersion("arrow",      "14.0.1")

# Shared Convenience Functions ----

## General convenience functions ----
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

# Function to find the number of unique values in a column of a data.frame
uni <- function(df, colName) {
  return(df[colName] %>% unique %>% nrow)
}

# A slower but memory safe implementation of unique for spatRasters
# - Only called once per job for validation, so speed is not too important
uniqueOnDisk <- function(input_layer) {
  # The blocks function is not available in the conda version of terra, so we access block info by opening and closing write connnection
  temp <- rast(input_layer)
  blockInfo <- writeStart(temp, filename = "")
  invisible(writeStop(temp))
  rm(temp)
  v <- integer()

  for (i in seq_along(blockInfo$row) ) {
    # read values appears to leak memory until the file is closed, so we start and stop frequently to reduce memory overhead
    readStart(input_layer)

    # Read values and bind an appropriante number of NA columns to either side
    v <- unique(c(v, readValues(input_layer, row = blockInfo$row[i], nrows = blockInfo$nrows[i])))

    readStop(input_layer)
    # Although garbage collection every block is slow, it help reduce memory overhead
    gc()
  }

  return(purrr::discard(v, is.na))
}

# Function to delete files in file
resetFolder <- function(path) {
  list.files(path, full.names = T) %>%
    unlink(recursive = T, force = T)
  invisible()
}

## BurnP3+ specific convenience functions ----
# Function to get median julian day from season
# - 2001 is default to avoid leap years
getSeasonMedianDate <- function(season, year = 2001) {
  # Extract Julian day
  julian_day <- SeasonTable %>%
    dplyr::filter(Name == season) %>%
    pull(JulianDay)

  # Create date object
  d <- lubridate::ymd(20010101)

  # Set julian day and year
  lubridate::yday(d) <- julian_day
  lubridate::year(d) <- year

  return(d)
}

# Function to determine which fires should be kept after resampling
getResampleStatus <- function(burnSummary) {
  burnSummary %>%
    mutate(
      ResampleStatus = case_when(
        Area < minimumFireSize ~ "Discarded",
        Iteration == 0         ~ "Extra",
        TRUE                   ~ "Kept"
      )) %>%
    return()
}

# Function for preparing input data for iterating over primary burn loop
# - ignitionLocation will be structured differently based on the fire growth model, but should be joinable to the burn condition by iteration and fire id
generateFireGrowthInputs <- function(firesToBurn, DeterministicBurnCondition, ignitionLocation) {
  firesToBurn %>%

    left_join(DeterministicBurnCondition, by = c("Iteration", "FireID")) %>%

    # Group by iteration and fire ID for the `growFire()` function
    nest(.by = c(Iteration, FireID)) %>%

    # Add ignition location information
    left_join(ignitionLocation, c("Iteration", "FireID")) %>%

    # Assign batch IDs
    # - Identify the hours burned in each fire
    # - Scale by average hours burned in each fire
    # - Scaling by the number of fires per batch gives a "weight" to each fire as a proportion of an average batch
    # - Floor of the cumulative sum is used to group consecutive fires loosely into even sized batches
    mutate(
      BatchID = map_int(data, function(data)
        data %>%
          pull(HoursBurning) %>%
          sum()),
      BatchID = floor(cumsum(BatchID / mean(BatchID) / batchSize)) + 1)
}

# Function to append weather and fire zone data to a dataset by Latitude and Longitude
# - Handles missing weather and fire zone tables
# - note that it also adds a column of cell IDs called "cell"
joinZoneByLatLong <- function(data, fireZoneRaster, weatherZoneRaster, sampleMissing = F) {
  data$cell <- cellFromXY(
    fuelsRaster,
    xy = data.frame(long=data$Longitude,
                    lat=data$Latitude) %>%
        st_as_sf(crs = "EPSG:4326",
                coords = c("long","lat")) %>%
        st_transform(crs = crs(fuelsRaster)) %>%
        st_coordinates)

  # Add firezone and weatherzone info if present 
  if (!is.null(weatherZoneRaster)){
    data <- data %>%
      mutate(
        weatherzoneID = unlist(extract(weatherZoneRaster, cell)),
        WeatherZone = lookup(weatherzoneID, WeatherZoneTable$ID, WeatherZoneTable$Name)
      ) %>%
      dplyr::select(-weatherzoneID)
  } else{
    data$WeatherZone <- WeatherZoneTable$Name
    if (sampleMissing)
      data$WeatherZone <- sample(WeatherZoneTable$Name, nrow(data), replace = T)
  }

  if (!is.null(fireZoneRaster)){
    data <- data %>%
      mutate(
        firezoneID = unlist(extract(fireZoneRaster, cell)),
        FireZone = lookup(firezoneID, FireZoneTable$ID, FireZoneTable$Name)
      ) %>%
      dplyr::select(-firezoneID)
  } else{
    data$FireZone <- FireZoneTable$Name
    if (sampleMissing)
      data$FireZone <- sample(FireZoneTable$Name, nrow(data), replace = T)
  }

  return(data)
}

# Function to add extra information to fire statistics table based on cell locations, etc.
augmentOutputFireStatistic <- function(OutputFireStatistic, firesToBurn, DeterministicBurnCondition) {
  # Load necessary rasters and lookup tables
  fireZoneRaster <- loadSpatial$firezone()
  weatherZoneRaster <- loadSpatial$weatherzone()
    
  OutputFireStatistic <- firesToBurn %>%

    # Start by summarizing burn conditions
    left_join(DeterministicBurnCondition, by = c("Iteration", "FireID")) %>%
  
    # Summarize burn conditions by fire
    group_by(Iteration, FireID) %>%
    summarize(
      FireDuration = max(BurnDay),
      HoursBurning = sum(HoursBurning),
      .groups = "drop") %>%
  
    # Join ignition location and fire statistics
    left_join(DeterministicIgnitionLocation, by = c("Iteration", "FireID")) %>%
    right_join(OutputFireStatistic, by = c("Iteration", "FireID"))

  # Determine Fire and Weather Zones if the rasters are present, as well as
  # fuel type of ignition location
  OutputFireStatistic <- OutputFireStatistic %>%
    joinZoneByLatLong(
      fireZoneRaster = fireZoneRaster,
      weatherZoneRaster = weatherZoneRaster,
      sampleMissing = F) %>%
    mutate(
      fueltypeID = unlist(extract(fuelsRaster, cell)),
      FuelType = lookup(fueltypeID, FuelType$ID, FuelType$Name),
      Timestep = 0) %>%

      # Clean up for saving
      dplyr::select(Iteration, Timestep, FireID, Latitude, Longitude, Season,
                    Cause, FireZone, WeatherZone, FuelType, FireDuration,
                    HoursBurning, Area, ResampleStatus)
}

consolidateTabularOutputs <- function() {
  if(saveBurnMaps & file.exists(rawTableTempPath)) {
    progressBar(type = "message", message = "Writing spatial burn outputs...")

    rawTableTempPath %>%
      arrow::open_dataset(format = "arrow") %>%
      dplyr::select(-BatchID) %>%
      arrange(Iteration, FireID, CellID) %>%
      arrow::write_parquet(rawTablePath)

    OutputRawTabular <- data.frame(
      FileName = rawTablePath %>% normalizePath(mustWork = F),
      Description =
        str_c(
          "Raw tabular outputs", 
          ifelse(runContext$isParallel, str_c(" - Job ", runContext$jobIndex), "")))

      saveDatasheet(myScenario, OutputRawTabular, str_c("burnP3Plus_OutputRawTabular"))

    updateRunLog("Finished writing burn outputs in ", updateBreakpoint())
  }
}

consolidateVectorOutputs <- function() {
  if (OutputOptionsSpatial$BurnPerimeter == "No" | !file.exists(geopackage_path))
    return(invisible())

  # Define empty geom to fill missing perimeters
  empty_geom <- fuelsRaster %>%
    ext() %>%
    as.polygons() %>%
    erase(.,.) %>%
    st_as_sf() %>%
    st_set_crs(crs(fuelsRaster)) %>%
    st_cast("MULTIPOLYGON")

  # Identify perimeters present in geopackage
  perimeters_present <- st_read(geopackage_path, geopackage_layer_name) %>%
    dplyr::select(any_of(c("Iteration", "FireID", "BurnDay")))

  # Identify fires that are needed
  perimeters_required <- OutputFireStatistic %>%
    filter(ResampleStatus == "Kept" | ResampleStatus == "Extra") %>%
    dplyr::select(Iteration, FireID) %>%
    left_join(DeterministicBurnCondition, by = c("Iteration", "FireID")) %>%
    dplyr::select(Iteration, FireID, BurnDay) %>%
    {if(OutputOptionsSpatial$BurnPerimeter != "Daily") dplyr::filter(., BurnDay == max(BurnDay), .by = c("Iteration", "FireID")) else .}

  # Identify missing perimeters
  perimeters_missing <- anti_join(perimeters_required, perimeters_present)

  # Fill missing periemeters with empty geom
  perimeters_missing %>%
    pwalk(
      function(Iteration, FireID, BurnDay) {
        empty_geom %>%
          mutate(
            Iteration = Iteration,
            FireID = FireID,
            BurnDay = BurnDay,
            geometry = geometry,
            .keep = "none") %>%
          {if (OutputOptionsSpatial$BurnPerimeter != "Daily") dplyr::select(., -BurnDay) else .} %>%
          st_write(
            dsn = geopackage_path,
            layer = geopackage_layer_name,
            quiet = TRUE,
            append = TRUE)
      })

  progressBar(type = "message", message = "Saving burn perimeters...")
  
  OutputFirePerimeter <-
    tibble(
      FileName = geopackage_path %>% normalizePath(),
      Description = getPerimeterType(geopackage_path)) %>%
    as.data.frame()
  
  if(file.exists(geopackage_path))
    saveDatasheet(myScenario, OutputFirePerimeter, "burnP3Plus_OutputFirePerimeter")
  
  updateRunLog("Finished collecting burn perimeters in ", updateBreakpoint())
}

# Function to identify perimeter types (final, daily, mixed) present in a geopackage and return a description
getPerimeterType <- function(geopackage_path) {
  # A suffix to the description is added based on the current job number
  jobSuffix <- ifelse(runContext$isParallel, str_c(" - Job ", runContext$jobIndex), "")

  # Extract layer names
  perimeterTypesPresent <- st_layers(geopackage_path)$name

  # Handle empty geopackages, but should not happen
  if (length(perimeterTypesPresent) == 0) {
    updateRunLog("No fire perimeter layers found!", type = "warning")
    return("")
  }
  
  # Include a warning for mixed perimeter types.
  if (length(perimeterTypesPresent) > 1) {
    updateRunLog("Found a mix of burn perimeter output types! Both will be retained in separate layers.", type = "warning")
    return(str_c("Mixed burn perimeters", jobSuffix))
  }

  # Handle base cases
  if (str_detect(perimeterTypesPresent, "final"))
    return(str_c("Final burn perimeters", jobSuffix))

  if (str_detect(perimeterTypesPresent, "daily"))
    return(str_c("Daily burn perimeters", jobSuffix))
  
  # If a single unknown layer is present, this is an error
  stop("Found unexpected layer names in the Fire Perimeters geopackage")
}

## Functions for sampling fire growth inputs ----
# Function to parse a table defining a normal distribution and sample accordingly
sampleNorm <- function(df, numSamples, defaultMean = 1, defaultSD = 0, defaultMin = 1, defaultMax = Inf) {

  distributionMean <- ifelse(is.na(df$Mean),            defaultMean, df$Mean)
  distributionSD   <- ifelse(is.na(df$DistributionSD),  defaultSD,   df$DistributionSD)
  distributionMin  <- ifelse(is.na(df$DistributionMin), defaultMin,  df$DistributionMin)
  distributionMax  <- ifelse(is.na(df$DistributionMax), defaultMax,  df$DistributionMax)

  rnorm(numSamples, distributionMean, distributionSD) %>%
    round(0) %>%
    pmax(distributionMin) %>%
    pmin(distributionMax) %>%
    return
}

# Function to parse a table defining a gamma distribution and sample accordingly
sampleGamma <- function(df, numSamples, defaultMean = 1, defaultSD = 1, defaultMin = 1, defaultMax = Inf) {

  distributionMean <- ifelse(is.na(df$Mean),            defaultMean, df$Mean)
  distributionSD   <- ifelse(is.na(df$DistributionSD),  defaultSD,   df$DistributionSD)
  distributionMin  <- ifelse(is.na(df$DistributionMin), defaultMin,  df$DistributionMin)
  distributionMax  <- ifelse(is.na(df$DistributionMax), defaultMax,  df$DistributionMax)

  # Calculate shape and rate from mean and sd
  # - Derivation from: https://math.stackexchange.com/questions/1810257/gamma-functions-mean-and-standard-deviation-through-shape-and-rate
  shape <- (distributionMean / distributionSD)^2
  rate  <- distributionMean / (distributionSD^2)

  rgamma(numSamples, shape = shape, rate = rate) %>%
    round(0) %>%
    pmax(distributionMin) %>%
    pmin(distributionMax) %>%
    return
}


## Functions for handling multiprocessing ----
# Function to allocate fires to jobs by expected run time
# - This function uses the number of hours burning of each fire to estimate run time and allocate jobs accordingly
# - Future work could also consider wind speed, curing, green up, FFMC, DMC, DC
splitFiresByJob <- function() {
  DeterministicBurnCondition %>%

    # Identify how many days and hours each fire consists of as an estimate of simulation time
    group_by(Iteration, FireID) %>%
    summarize(HoursBurning = sum(HoursBurning), .groups = "drop") %>%

    # Split fires into approximately equal total hours burning
    mutate(JobIndex = (floor(cumsum(HoursBurning) / sum(HoursBurning) * runContext$numJobs) + 1) %>% pmin(runContext$numJobs)) %>%
    dplyr::filter(JobIndex == runContext$jobIndex) %>%
    dplyr::select(Iteration, FireID)
}

# Define function to determine if the current job is multiprocessed
getRunContext <- function() {
  libraryPath <- ssimEnvironment()$LibraryFilePath %>% normalizePath()
  libraryName <- libraryPath %>% basename %>% {tools::file_path_sans_ext(.)}

  # Libraries are identified as remote if the path includes the Parallel folder and library follows the Job-<jobid> naming convention
  isParallel <- libraryPath %>%
    str_split("/|(\\\\)") %>%
    pluck(1) %>%
    str_detect("MultiProc") %>%
    any %>%
    `&`(str_detect(libraryName, "Job-\\d"))

  # Return if false
  if (!isParallel)
    return(list(isParallel = F, numJobs = 1, jobIndex = 1))

  # Otherwise parse number of jobs and current job index
  numJobs <- libraryPath %>%
    dirname() %>%
    list.files("Job-\\d+.ssim.temp") %>%
    length()
  jobIndex <- str_extract(libraryName, "\\d+") %>% as.integer()

  return(list(isParallel = T, numJobs = numJobs, jobIndex = jobIndex))
}

## Functions for loading and validating spatial layers ----

# Define function to check input raster for consistency
checkSpatialInput <- function(x, name, checkProjection = T, warnOnly = F) {
  # Only check if not null
  if (!is.null(x)) {
    # Ensure comparable number of rows and cols in all spatial inputs
    if (nrow(fuelsRaster) != nrow(x) | ncol(fuelsRaster) != ncol(x)) {
      if (warnOnly) {
        updateRunLog("Number of rows and columns in the ", name, " map do not match Fuels map. Please check that the extent and resolution of these maps match.", type = "warning")
        # Unlike with the resolution check below, you can't use this map if rows and cols don't match
        invisible(NULL)
      } else {
        stop("Number of rows and columns in the ", name, " map do not match Fuels map. Please check that the extent and resolution of these maps match.")
      }
    }

    # Ensure resolution matches for all spatial inputs
    if (any(res(fuelsRaster) != res(x))) {
      if (warnOnly) {
        updateRunLog("The resolution of the ", name, " map do not match Fuels map. Please check that the extent and resolution of these maps match.", type = "warning")
      } else {
        stop("The resolution of the ", name, " map do not match Fuels map. Please check that the extent and resolution of these maps match.")
      }
    }

    # Info if CRS is not matching
    if (checkProjection) {
      if (crs(x) != crs(fuelsRaster)) {
        updateRunLog("Projection of the ", name, " map does not match Fuels map. Please check that the CRS of these maps match.", type = "info")
      }
    }
  }

  # Silently return for clean pipelining
  invisible(x)
}

# Function to override (not reproject!) the crs quietly and returns the object (for piping)
# - some fire models override but CRS in outputs without reprojecting (e.g. FireSTARR)
# - this is used to deal with that quietly within pipes
set_crs <- function(x, template_crs) {
  crs(x) <- template_crs
  return(x)
}

# Store functions for loading spatial data as a list so it can be dropped from memory once it is not needed
# - Note that datasheetRaster is avoided as it requires rgdal
# - Under conda, this causes Prometheus to point to the wrong version of GDAL
loadSpatial <- list(

  fuels = function() {
    # Load fuels
    fuelsRaster <- rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["FuelGridFileName"]])

    # Make sure fuels layers have perfectly square pixels
    if (res(fuelsRaster)[1] != res(fuelsRaster)[2])
      stop("The fuels raster cells are not square. Please check the resolutions and projections of all spatial inputs.")

    # Ensure fuels crs can be converted to Lat / Long
    test.point <- vect(xyFromCell(fuelsRaster,1), crs = crs(fuelsRaster))
    if(test.point %>% is.lonlat){stop("Incorrect coordinate system. Projected coordinate system required, please reproject your grids.")}
    tryCatch(test.point %>% terra::project("epsg:4326"), error = function(e) stop("Error parsing provided Fuels map. Cannot calculate Latitude and Longitude from provided Fuels map, please check CRS."))

    return(fuelsRaster)
  },

  elevation = function() {
    # Load elevation raster if present
    # - technically optional but really not
    elevationRaster <- tryCatch(
      rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["ElevationGridFileName"]]),
      error = function(e) NULL)

    # Check for consistency with fuels raster
    checkSpatialInput(elevationRaster, "Elevation")

    return(elevationRaster)
  },

  firezone = function() {
    tryCatch(
      rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["FireZoneGridFileName"]]),
      error = function(e) NULL) %>%
      checkSpatialInput("Fire Zone", warnOnly = T)
  },

  weatherzone = function() {
    tryCatch(
      rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["WeatherZoneGridFileName"]]),
      error = function(e) NULL) %>%
      checkSpatialInput("Weather Zone", warnOnly = T)
  }
)

## Functions for setting up temp files and folders ----

# Function to build transformer-specific temp directory
generateTempDir <- function(folderName) {
  tempDir <- ssimEnvironment()$TempDirectory %>%
    str_replace_all("\\\\", "/") %>%
    file.path(str_c(folderName, "/"))
  unlink(tempDir, recursive = T, force = T)
  dir.create(tempDir, showWarnings = F)
  return(tempDir)
}

# Function to build transformer-specific temp directory
generateTempSubDir <- function(folderName) {
  tempSubDir <- file.path(tempDir, folderName)
  unlink(tempSubDir, recursive = T, force = T)
  dir.create(tempSubDir, showWarnings = F)
  return(tempSubDir)
}

# Function to setup all the common temp directories, subdirectories, and temp file paths
generateSharedTempFilePaths <- function(transformerName) {
  tempDir <<- generateTempDir(transformerName)

  # Create folders for various outputs
  ignitionFolder      <<- generateTempSubDir("ignitions")
  weatherFolder       <<- generateTempSubDir("weathers")
  gridOutputFolder    <<- generateTempSubDir("outputs")
  shapeOutputFolder   <<- generateTempSubDir("shapes")
  tabularOutputFolder <<- generateTempSubDir("tabular")

  # Create path for geopackage for storing vector outputs
  # - Having a unique name for each job (if multiprocessed) helps organize things during merge
  geopackage_path <<- 
    str_c(
      "burn-perimeters",
      ifelse(runContext$isParallel, str_c("-", runContext$jobIndex), "")) %>%
    str_c(".gpkg") %>%
    file.path(shapeOutputFolder, .)

  # Note geopackage recommends `_` for word separation in table, feature, etc names
  geopackage_layer_name <<-
    str_c(
      str_to_lower(if(exists("OutputOptionsSpatial")) OutputOptionsSpatial$BurnPerimeter else "mixed"),
      "_burn_perimeters"
    )

  # Create path for parquet files to hold tabular data
  rawTableTempPath <<- 
    str_c(
      "raw-tabular",
      ifelse(runContext$isParallel, str_c("-", runContext$jobIndex), "")) %>%
    file.path(tabularOutputFolder, .)
  rawTablePath <<- str_c(rawTableTempPath, ".parquet")
}

## Functions for parsing data sheets and handling different missing and invalid inputs ----

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

# Define function to fill missing season values and save changes back to library
fill_season <- function(datasheet, datasheet_name = "", update_library = F) {
  datasheet <- datasheet %>%
    mutate(
      Season = if(!exists("Season", where = .)) NA_character_ else as.character(Season),
      Season = replace_na(Season, "All"))

  if (update_library)
    saveDatasheet(myScenario, datasheet, datasheet_name)

  return(datasheet)
}

# Store functions for handling missing data as a list so it can be dropped from memory once it is not needed
validateAndParseData <- list(
  FuelType = function(crosswalk = NA) {
    # Make sure fuel definitions exist
    if(isDatasheetEmpty(FuelType)) {
      stop("No Fuel Definitions found! Pelase check the fuel definitions in your SyncroSim project.")
    }
    
    # Make sure all fuel types have at least a name and id associated
    if(any(is.na(FuelType$Name))){
      stop("One or more Fuel Type definitions are missing Names. Please check your Fuel Type table.")
    }
  
    if(any(is.na(FuelType$ID))){
      stop("One or more Fuel Type definitions are missing IDs. Please check your Fuel Type table.")
    }
    
    # Make sure all fuels in the fuels map are defined
    fuelsPresent <- uniqueOnDisk(fuelsRaster)
    if(length(setdiff(fuelsPresent, FuelType$ID)) > 0) {
      FuelType <- bind_rows(
        FuelType,
        tibble(ID = setdiff(fuelsPresent, FuelType$ID)))
      saveDatasheet(myScenario, FuelTypeCrosswalk, crosswalk)
      stop("Found fuel values in the fuel map that are not defined in the Fuel Type definitions. Missing records have been added to the Fuel Type table, please name these fuel types.")
    }
    
    # Make sure fuel crosswalk definitions exist and is fully populated, if relevant
    if (!is.na(crosswalk)) {
      # Check for missing fuel type records
      if (isDatasheetEmpty(FuelTypeCrosswalk) | length(setdiff(FuelType$Name, FuelTypeCrosswalk$FuelType)) > 0) {
        # Fill in missing fuel types
        FuelTypeCrosswalk <- bind_rows(
          FuelTypeCrosswalk,
          tibble(FuelType = setdiff(FuelType$Name, FuelTypeCrosswalk$FuelType)))
        saveDatasheet(myScenario, FuelTypeCrosswalk, crosswalk)
        stop("Missing one or more Fuel Type definitions in the Fuel Code Crosswalk for this fire growth model. Missing records have been added to the Fuel Code Crosswalk table, please associate these rows with their corresponding Fuel Code.")
      }
  
      # Check for missing codes
      if(any(is.na(FuelTypeCrosswalk$Code))){
        stop("Missing one or more Fuel Type codes in the Fuel Code Crosswalk for this fire growth model. Please associate all Fuel Types to their corresponding Fuel Codes in the Fuel Code Crosswalk for this fire growth model.")
      }
    
      # Finally, if everything is good, join the fuel type definitions and crosswalk
      FuelType <<- FuelType %>%
        left_join(FuelTypeCrosswalk, by = c("Name" = "FuelType"))
      
    }
  },

  Season = function() {
    if(isDatasheetEmpty(SeasonTable))
      SeasonTable <<- data.frame(Name = "All")
  },

  Cause = function() {
    if(isDatasheetEmpty(CauseTable))
      CauseTable <<- data.frame(Name = "")
  },

  Zones = function() {
    if(isDatasheetEmpty(FireZoneTable))
      FireZoneTable <<- data.frame(Name = "", ID = 0)
    if(isDatasheetEmpty(WeatherZoneTable))
      WeatherZoneTable <<- data.frame(Name = "", ID = 0)
  },

  RunControl = function() {
    if(isDatasheetEmpty(RunControl)) {
      updateRunLog("No iteration count provided, defaulting to 1 iteration.", type = "warning")
      RunControl[1,] <<- c(1,1,0,0)
      saveDatasheet(myScenario, RunControl, "burnP3Plus_RunControl")
    }
  },
  
  IgnitionSampling = function() {
    if(isDatasheetEmpty(IgnitionsPerIteration)) {
      updateRunLog("No Ignitions per Iteration values found. Defaulting to 1 ignition per iteration.", type = "info")
      IgnitionsPerIteration[1,"Mean"] <<- 1
      saveDatasheet(myScenario, IgnitionsPerIteration, "burnP3Plus_IgnitionsPerIteration")
    }

    if(any(is.na(ProbabilisticIgnitionLocation$IgnitionGridFileName))) {
      stop("Not all Probabilistic Ignition Grids specified in the Ignition Location datasheet.")
    }

    # Check for ignition count distribution
    for (i in 1:nrow(IgnitionsPerIteration)){
      distName <<- IgnitionsPerIteration$DistributionType[i]
      if (is.na(distName) | distName == "Gamma" | distName == "Normal") next
      distValues <<- DistributionValue %>% filter(Name == distName)
      if (nrow(distValues) == 0){
        stop(paste0("No values found in Distribution datasheet for Ignition Count distribution: ", distName))
      }
    }

    # Check if values in Deterministic Ignition Locations is empty
    if (!isDatasheetEmpty(DeterministicIgnitionLocation)) {
      updateRunLog("Values in Deterministic Ignition Location datasheet are overwritten.", type = "warning")
    }

    # If the ignition distribution table is used but one or more season, cause, or firezone are defined but not explicitly listed,
    # these values will be randomly assigned to each ignition with equal probability. Warn users if this behaviour is used.
    if (!isDatasheetEmpty(IgnitionDistribution)) {
      if (
        (!all(SeasonTable$Name == "All")  & any(is.na(IgnitionDistribution$Season))) |
        (!all(CauseTable$Name == "")      & any(is.na(IgnitionDistribution$Cause))) |
        (!all(FireZoneTable$Name == "")   & any(is.na(IgnitionDistribution$FireZone))))
          updateRunLog("One or more of Season, Cause, and Fire Zone are defined at the project scope but not completely described by the Ignition Distribution table. Unspecified values will be drawn randomly where appropriate.", type = "warning")
    }

    # Fill in missing season values
    ProbabilisticIgnitionLocation <<- fill_season(ProbabilisticIgnitionLocation, "burnP3Plus_ProbabilisticIgnitionLocation", TRUE)
    IgnitionRestriction <<- fill_season(IgnitionRestriction, "burnP3Plus_IgnitionRestriction", TRUE)
    IgnitionDistribution <<- fill_season(IgnitionDistribution, "burnP3Plus_IgnitionDistribution", TRUE)

    # Decide if sampling based on a distribution
    byDistribution <- any(!is.na(IgnitionsPerIteration$DistributionType))

    # If so, ensure only one distribution is specified
    if(byDistribution & nrow(IgnitionsPerIteration) > 1)
      stop("If sampling Ignitions per Iteration from a distribution, only one record is accepted.\nTo modify a user-defined distribution, please edit the 'Distributions' datasheet \nunder the 'Advanced' tab in the scenario properties.")

    # Identify the name and type of distribution
    # - Only distributionName is required after validation, rest can stay in this scope
    distributionName <<- IgnitionsPerIteration$DistributionType
    isAuto <- DistributionType %>% filter(Name == distributionName) %>% pull(IsAuto) %>% replace_na(0) %>% `==`(-1)
    distributionData <- DistributionValue %>% filter(Name == distributionName)

    if(byDistribution) {
      # If using a built-in distribution, ensure Mean and SD are provided
      if(isAuto)
        if(is.na(IgnitionsPerIteration$Mean) | is.na(IgnitionsPerIteration$DistributionSD))
          stop("Please specify a Mean and SD to use this built-in distribution to sample Ignitions per Iteration")

      # If using a user-defined distribution, ensure there is a corresponding definition and warn user about unrespected fields
      if(!isAuto) {
        if(isDatasheetEmpty(distributionData))
          stop("No distribution definition found for the user-defined distribution in Ignitions per Iteration.\nTo modify a user-defined distribution, please edit the 'Distributions' datasheet \nunder the 'Advanced' tab in the scenario properties.")

        if(!is.na(IgnitionsPerIteration$Mean) | !is.na(IgnitionsPerIteration$DistributionSD))
           updateRunLog("Found Mean or SD values for a user-defined distribution in Ignitions per Iteration.\nThese values will not be respected during sampling. To modify a user-defined distribution, \nplease edit the 'Distributions' datasheet under the 'Advanced' tab in the scenario properties.", type = "warning")
      }
    }
  },

  BurnConditionSampling = function() {
    if(isDatasheetEmpty(WeatherStream)) {
      stop("Error: Please provide weather stream data to sample burning conditions.")
    }

    if(isDatasheetEmpty(FireDurationTable)) {
      updateRunLog("No fire duration distribution provided, defaulting to 1 day fires.", type = "warning")
      FireDurationTable[1,"Mean"] <<- 1
      saveDatasheet(myScenario, FireDurationTable, "burnP3Plus_FireDuration")
    }

    if(isDatasheetEmpty(HoursBurningTable)) {
      updateRunLog("No hours burning per day distribution provided, defaulting to 4 hours of burning per burn day.", type = "warning")
      HoursBurningTable[1, "Season"] <<- "All"
      HoursBurningTable[1,"Mean"] <<- 4
      saveDatasheet(myScenario, HoursBurningTable, "burnP3Plus_HoursPerDayBurning")
    }

    if(isDatasheetEmpty(WeatherOptions)) {
      updateRunLog("No weather sampling options chosen, defaulting to sampling daily weather stream sequentially.", type = "info")
      WeatherOptions$SampleSequentially <<- TRUE
      saveDatasheet(myScenario, WeatherOptions, "burnP3Plus_WeatherOption")
    }

    # Make sure order is fully populated if sampling sequentially
    if(WeatherOptions$SampleSequentially & any(is.na(WeatherStream$Order))) {
      stop("Weather can't be sample sequentially if the weather stream is not sorted using the Order column. Please update the weather stream to include this variable or update the Weather Sampling Options to not sample sequentially.")
    }

    if (!isDatasheetEmpty(DeterministicBurnCondition)) {
      updateRunLog("Values in Deterministic Burn Conditions datasheet are overwritten.", type = "warning")
    }

    # Check to ensure that distributions specified actually exist
    # Spread Event Days
    for (i in 1:nrow(FireDurationTable)){
      distName <- FireDurationTable$DistributionType[i]
      if (is.na(distName) | distName == "Gamma" | distName == "Normal") next
      distValues <- DistributionValue %>% filter(Name == distName)
      if (nrow(distValues) == 0){
        stop(paste0("No values found in Distribution datasheet for Spread Event Days distribution: ", distName))
      }
    }

    # Daily Burning Hours
    for (i in 1:nrow(HoursBurningTable)){
      distName <- HoursBurningTable$DistributionType[i]
      if (is.na(distName) | distName == "Gamma" | distName == "Normal") next
      distValues <- DistributionValue %>% filter(Name == distName)
      if (nrow(distValues) == 0){
        stop(paste0("No values found in Distribution datasheet for Daily Burning Hours distribution: ", distName))
      }
    }

    # Fill missing seasons
    FireDurationTable <<- fill_season(FireDurationTable, "burnP3Plus_FireDuration", TRUE)
    HoursBurningTable <<- fill_season(HoursBurningTable, "burnP3Plus_HoursPerDayBurning", TRUE)
    WeatherStream <<- fill_season(WeatherStream, "burnP3Plus_WeatherStream", TRUE)

  },
  
  DeterminsiticIgnitions = function() {
    if(isDatasheetEmpty(DeterministicIgnitionLocation)) {
      stop("No Deterministic Ignition Location data found. Please ensure you have sampled ignitions prior to running the fire growth transformer.")
    }
    DeterministicIgnitionLocation <<- fill_season(DeterministicIgnitionLocation, "burnP3Plus_DeterministicIgnitionLocation", update_library = TRUE)
  },
  
  DeterminsiticBurnConditions = function() {
    if(isDatasheetEmpty(DeterministicBurnCondition)) {
      stop("No Deterministic Burn Condition data found. Please ensure you have sampled burning conditions prior to running the fire growth transformer.")
    }
  },
  
  OutputOptions = function() {
    if(isDatasheetEmpty(OutputOptions)) {
      updateRunLog("No tabular output options chosen. Defaulting to keeping all tabular outputs.", type = "info")
      OutputOptions[1,] <<- rep(TRUE, length(OutputOptions[1,]))
      saveDatasheet(myScenario, OutputOptions, "burnP3Plus_OutputOption")
    } else if (any(is.na(OutputOptions))) {
      updateRunLog("Missing one or more tabular output options. Defaulting to keeping unspecified tabular outputs.", type = "info")
      OutputOptions <<- OutputOptions %>%
        replace(is.na(.), TRUE)
      saveDatasheet(myScenario, OutputOptions, "burnP3Plus_OutputOption")
    }
  
    if(isDatasheetEmpty(OutputOptionsSpatial)) {
      updateRunLog("No spatial output options chosen. Defaulting to keeping all summary burn maps and final burn perimeters.", type = "info")
  
      # Start by enabling all outputs
      OutputOptionsSpatial[1,] <<- rep(TRUE, length(OutputOptionsSpatial[1,]))
      # Specify final burn perimeters as opposed to daily
      OutputOptionsSpatial$BurnPerimeter <<- "Final"
      # Disable per-iteration and per-fire outputs
      # - These can be regenerated later from the raw tabular outputs by rerunning the summary transformer
      OutputOptionsSpatial$BurnMap <<- FALSE
      OutputOptionsSpatial$SeasonalBurnMap <<- FALSE
      OutputOptionsSpatial$AllPerim <<- FALSE
  
      # Save back to SyncroSim
      saveDatasheet(myScenario, OutputOptionsSpatial, "burnP3Plus_OutputOptionSpatial")
    } else if (any(is.na(OutputOptionsSpatial))) {
      updateRunLog("Missing one or more spatial output options. Defaulting to keeping unspecified summary spatial outputs.", type = "info")
  
      OutputOptionsSpatial <<- OutputOptionsSpatial %>%
        # Enable any missing summary maps
        mutate(across(contains(c("Probability", "Count")),
          ~ replace_na(.x, TRUE))) %>%
        # Explicitly disable missing per-fire and per-iteration map options
        # - These can be regenerated later from the raw tabular outputs by rerunning the summary transformer
        mutate(across(contains(c("Map", "AllPerim")),
          ~ replace_na(.x, FALSE))) %>%
        # Specify final burn perimeters as opposed to daily if missing
        mutate(across("BurnPerimeter",
          ~ replace_na(.x, "Final")))
  
      # Save back to SyncroSim
      saveDatasheet(myScenario, OutputOptionsSpatial, "burnP3Plus_OutputOptionSpatial")
    }

    # Burn maps must be kept to generate summarized maps later, this boolean summarizes
    # whether or not burn maps are needed
    saveBurnMaps <<- any(OutputOptionsSpatial$BurnMap, OutputOptionsSpatial$SeasonalBurnMap,
                        OutputOptionsSpatial$BurnProbability, OutputOptionsSpatial$SeasonalBurnProbability,
                        OutputOptionsSpatial$RelativeBurnProbability, OutputOptionsSpatial$SeasonalRelativeBurnProbability,
                        OutputOptionsSpatial$BurnCount, OutputOptionsSpatial$SeasonalBurnCount,
                        OutputOptionsSpatial$AllPerim, OutputOptionsSpatial$BurnPerimeter != "No")
    
    # Decide whether or not to save outputs seasonally
    saveSeasonalBurnMaps <<- any(OutputOptionsSpatial$SeasonalBurnMap,
                                OutputOptionsSpatial$SeasonalBurnProbability,
                                OutputOptionsSpatial$SeasonalRelativeBurnProbability,
                                OutputOptionsSpatial$SeasonalBurnCount)

    # Decide whether or not to save spatial summary outputs
    # Set a flag to decide whether or not to handle secondary outputs
    saveBurnMaps <<- any(OutputOptionsSpatial$BurnCount, OutputOptionsSpatial$SeasonalBurnCount,
                        OutputOptionsSpatial$BurnProbability, OutputOptionsSpatial$SeasonalBurnProbability,
                        OutputOptionsSpatial$RelativeBurnProbability, OutputOptionsSpatial$SeasonalRelativeBurnProbability)
    
    summaryBurnMapCount <<- case_when(
      OutputOptionsSpatial$RelativeBurnProbability | OutputOptionsSpatial$SeasonalRelativeBurnProbability ~ 3,
      OutputOptionsSpatial$BurnProbability         | OutputOptionsSpatial$SeasonalBurnProbability         ~ 2,
      OutputOptionsSpatial$BurnCount               | OutputOptionsSpatial$SeasonalBurnCount               ~ 1,
      TRUE                                                                                                ~ 0)
    
    # Decide whether or not to save seasonal spatial summary outputs
    saveSeasonalBurnMaps <<- any(OutputOptionsSpatial$SeasonalBurnProbability,
                                OutputOptionsSpatial$SeasonalRelativeBurnProbability,
                                OutputOptionsSpatial$SeasonalBurnCount)
    
    saveBurnPerimeters <<- OutputOptionsSpatial$BurnPerimeter != "No"
  },
  
  FBPOutputOptions = function() {
    if (!isDatasheetEmpty(OutputOptionFBPSpatial)) {
      # Fill missing values for all but Percentile outputs, which are left as NA to indicate non-use
      OutputOptionFBPSpatial <<- OutputOptionFBPSpatial %>%
        mutate(across(
          any_of(c("Average", "Minimum", "Maximum", "Median", "Individual")),
          \(x) replace_na(x, FALSE)))
  
      saveDatasheet(myScenario, OutputOptionFBPSpatial, "burnP3Plus_OutputOptionFBPSpatial")
  
      # Parse table to determine which outputs should be generated
      outputComponentsToKeepDisplayName <<- OutputOptionFBPSpatial %>%
        dplyr::filter(any(Average, Minimum, Maximum, Median, Individual, as.logical(c(Percentile1, Percentile2, Percentile3)))) %>%
        pull(Variable)

      # Convert from display name from UI to internal component names
      outputComponentsToKeep <<- outputComponentsToKeepDisplayName %>%
        lookup(FBPVariableTable$DisplayName, FBPVariableTable$Name)
      
      saveFBPMaps <<- length(outputComponentsToKeepDisplayName) > 0
      if (saveFBPMaps)
        saveBurnMaps <<- TRUE
    } else {
      # Set flags to not save FBP outputs
      outputComponentsToKeepDisplayName <<- character(0)
      saveFBPMaps <<- FALSE
    }
  
  },
  
  BatchOptions = function() {
    if(isDatasheetEmpty(BatchOption)) {
      updateRunLog("No batch size chosen. Defaulting to batches of 50 fires.", type = "info")
      BatchOption[1,] <<- c(50)
      saveDatasheet(myScenario, BatchOption, "burnP3Plus_BatchOption")
    }
    batchSize <<- BatchOption$BatchSize
  },
  
  ResampleOptions = function() {
    if(isDatasheetEmpty(ResampleOption)) {
      updateRunLog("No Minimum Fire Size chosen.\nDefaulting to a Minimum Fire Size of 0ha and with no extra fires. \nPlease see the Fire Resampling Options table for more details.", type = "info")
      ResampleOption[1,] <<- c(0,0)
      saveDatasheet(myScenario, ResampleOption, "burnP3Plus_FireResampleOption")
    }
    minimumFireSize <<- ResampleOption$MinimumFireSize
  },
  
  FireGrowthOptions = function() {
    if (isDatasheetEmpty(GreenUp)) {
      GreenUp[1, ] <<- c(NA, TRUE)
      saveDatasheet(myScenario, GreenUp, "burnP3Plus_GreenUp")
    } else if (is.character(GreenUp$GreenUp))
      GreenUp$GreenUp <<- GreenUp$GreenUp != "No"

    GreenUp <<- fill_season(GreenUp, "burnP3Plus_GreenUp", update_library = TRUE)
  
    if (isDatasheetEmpty(Curing)) {
      Curing[1, ] <<- c(NA, 75L)
      saveDatasheet(myScenario, Curing, "burnP3Plus_Curing")
    }

    Curing <<- fill_season(Curing, "burnP3Plus_Curing", update_library = TRUE)
    
    # Note: FuelLoad is currently disabled
    setFuelLoad <<- FALSE # Fuel load is never used
    # FuelLoad <<- fill_season(FuelLoad, "burnP3Plus_FuelLoad", TRUE) # Currently not supported by FireSTARR
  },
  
  WindGrids = function() {
    useWindGrid <<- !isDatasheetEmpty(WindGrid)

    # TODO: validate all spatial layers against fuels
  })
  
# Extract SyncroSim session info ----
# Connect to current scenario
myScenario <- scenario()

# Determine if jobs are being multiprocessed
runContext <- getRunContext()

# Set max terra mem use for parallel runs
# - note: not repsected by the conda version of terra
if (runContext$isParallel)
  terraOptions(memmax = 0.5)
