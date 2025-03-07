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

checkPackageVersion("rsyncrosim", "2.0.0")
checkPackageVersion("tidyverse",  "2.0.0")
checkPackageVersion("dplyr",      "1.1.2")
checkPackageVersion("codetools",  "0.2.19")
checkPackageVersion("terra",      "1.5.21")
checkPackageVersion("sf",         "1.0.7")

# Setup ----
progressBar(type = "message", message = "Preparing inputs...")

# Initialize first breakpoint for timing code
currentBreakPoint <- proc.time()

## Connect to SyncroSim ----
myScenario <- scenario()

# Load remaining datasheets
DeterministicIgnitionLocation <- datasheet(myScenario, "burnP3Plus_DeterministicIgnitionLocation", optional = T, returnInvisible = T) %>% unique
DeterministicBurnCondition <- datasheet(myScenario, "burnP3Plus_DeterministicBurnCondition", optional = T, returnInvisible = T) %>% unique
FuelTypeTable <- datasheet(myScenario, "burnP3Plus_FuelType")
FireZoneTable <- datasheet(myScenario, "burnP3Plus_FireZone")
WeatherZoneTable <- datasheet(myScenario, "burnP3Plus_WeatherZone")
DistributionValue <- datasheet(myScenario, "burnP3Plus_DistributionValue", optional = T, lookupsAsFactors = F)
SeasonTable <- datasheet(myScenario, "burnP3Plus_Season", returnInvisible = T) %>% filter(is.na(IsAuto))

# Load weather and burn condition table
FireDurationTable <- datasheet(myScenario, "burnP3Plus_FireDuration", optional = T, lookupsAsFactors = F, returnInvisible = T)
HoursBurningTable <- datasheet(myScenario, "burnP3Plus_HoursPerDayBurning", optional = T, lookupsAsFactors = F, returnInvisible = T)
WeatherStream <- datasheet(myScenario, "burnP3Plus_WeatherStream", optional = T, lookupsAsFactors = F)
WeatherOptions <- datasheet(myScenario, "burnP3Plus_WeatherOption")

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

# Import relevant rasters, allowing for missing values
fuelsRaster <- rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["FuelGridFileName"]])
fireZoneRaster <- tryCatch(
  rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["FireZoneGridFileName"]]),
  error = function(e) NULL)
weatherZoneRaster <- tryCatch(
  rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["WeatherZoneGridFileName"]]),
  error = function(e) NULL)

## Handle empty values ----
if(isDatasheetEmpty(WeatherStream)) {
  stop("Error: Please provide weather stream data to sample burning conditions.")
}

if(isDatasheetEmpty(FireDurationTable)) {
  updateRunLog("No fire duration distribution provided, defaulting to 1 day fires.", type = "warning")
  FireDurationTable[1,"Mean"] <- 1
  saveDatasheet(myScenario, FireDurationTable, "burnP3Plus_FireDuration")
}

if(isDatasheetEmpty(HoursBurningTable)) {
  updateRunLog("No hours burning per day distribution provided, defaulting to 4 hours of burning per burn day.", type = "warning")
  HoursBurningTable[1, "Season"] <- "All"
  HoursBurningTable[1,"Mean"] <- 4
  saveDatasheet(myScenario, HoursBurningTable, "burnP3Plus_HoursPerDayBurning")
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

if (!isDatasheetEmpty(DeterministicBurnCondition)) {
  updateRunLog("Values in Deterministic Burn Conditions datasheet are overwritten.", type = "warning")
}

if(isDatasheetEmpty(FireZoneTable))
  FireZoneTable <- data.frame(Name = "", ID = 0)
if(isDatasheetEmpty(WeatherZoneTable))
  WeatherZoneTable <- data.frame(Name = "", ID = 0)

# Fill missing season values

# Define function to fill missing season values and optionally save changes back to library
fill_season <- function(datasheet, datasheet_name = "", update_library = F) {
  datasheet <- datasheet %>%
    mutate(
      Season = if(!exists("Season", where = .)) NA_character_ else as.character(Season),
      Season = replace_na(Season, "All"))

  if (update_library)
    saveDatasheet(myScenario, datasheet, datasheet_name)

  return(datasheet)
}

DeterministicIgnitionLocation <- fill_season(DeterministicIgnitionLocation, "burnP3Plus_DeterministicIgnitionLocation", TRUE)
FireDurationTable <- fill_season(FireDurationTable, "burnP3Plus_FireDuration", TRUE)
HoursBurningTable <- fill_season(HoursBurningTable, "burnP3Plus_HoursPerDayBurning", TRUE)
WeatherStream <- fill_season(WeatherStream, "burnP3Plus_WeatherStream", TRUE)

## Check raster inputs for consistency ----

test.point <- vect(xyFromCell(fuelsRaster,1), crs = crs(fuelsRaster))
# Ensure fuels crs can be converted to Lat / Long
if(test.point %>% is.lonlat){stop("Incorrect coordinate system. Projected coordinate system required, please reproject your grids.")}
tryCatch(test.point %>% project("epsg:4326"), error = function(e) stop("Error parsing provided Fuels map. Cannot calculate Latitude and Longitude from provided Fuels map, please check CRS."))

# Define function to check input raster for consistency
checkSpatialInput <- function(x, name, checkProjection = T, warnOnly = F) {
  # Only check if not null
  if(!is.null(x)) {
    # Ensure comparable number of rows and cols in all spatial inputs
    if(nrow(fuelsRaster) != nrow(x) | ncol(fuelsRaster) != ncol(x))
      if(warnOnly) {
        updateRunLog("Number of rows and columns in ", name, " map do not match Fuels map. Please check that the extent and resolution of these maps match.", type = "warning")
        invisible(NULL) # Return null silently to mimic behaviour of missing input
      } else
        stop("Number of rows and columns in ", name, " map do not match Fuels map. Please check that the extent and resolution of these maps match.")

    # Info if CRS is not matching
    if(checkProjection)
      if(crs(x) != crs(fuelsRaster))
        updateRunLog("Projection of ", name, " map does not match Fuels map. Please check that the CRS of these maps match.", type = "info")
  }

  # Silently return for clean pipelining
  invisible(x)
}

# Check optional inputs
if (!is.null(fireZoneRaster)) checkSpatialInput(fireZoneRaster, "Fire Zone")
if (!is.null(weatherZoneRaster)) checkSpatialInput(weatherZoneRaster, "Weather Zone")

## Function Definitions ----

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

# Define function to facilitate recoding a vector using a look-up table
lookup <- function(x, old, new){
  dplyr::recode(x, !!!set_names(new, old))
}

# Function to find the number of unique values in a column of a data.frame
uni <- function(df, colName) {
  return(df[colName] %>% unique %>% nrow)
}

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

# Define function to sample days burning and hours per day burning given season and fire zone
sampleFireDuration <- function(season, firezone, data){
  # Determine fire duration distribution type to use
  # This is a function of season and firezone
  filteredFireDurationTable <- FireDurationTable %>%
    filter(
      Season == season | is.na(Season) | Season == "All",
      FireZone == firezone | is.na(FireZone))

  fireDurationDistributionName <- filteredFireDurationTable %>%
    pull(DistributionType) %>%
    {if(length(.) == 0) {stop("No spread event days distribution set for the \"", season, "\" Season and the \"", firezone, "\" Fire Zone. Please check the Spread Event Days table for missing combinations of Season and Fire Zone.")} else .} %>%
    {if(length(.) > 1 & !all(is.na(.))) {updateRunLog("Multiple fire duration distributions applicable for one or more combinations of season and fire zone. Using first applicable distribution.", type = "warning"); .[1]} else .}

  # Determine hours burning per day distribution type to use
  # This is a function of season only
  if (season %in% HoursBurningTable$Season){
    filteredHoursBurningTable <- HoursBurningTable %>%
      filter(Season == season)
  } else {
    filteredHoursBurningTable <- HoursBurningTable %>%
      filter(Season == "All" | is.na(Season))
  }

  hoursBurningDistributionName <- filteredHoursBurningTable %>%
    pull(DistributionType) %>%
    {if(length(.) == 0) {stop("No daily burning hours distribution set for the \"", season, "\" Season and the \"", firezone, "\" Fire Zone. Please check the Daily Burning Hours table for missing combinations of Season and Fire Zone.")} else .} %>%
    {if(length(.) > 1 & !all(is.na(.))) {updateRunLog("Multiple hours burning distributions applicable for one or more seasons. Using first applicable distribution.", type = "warning"); .[1]} else .}

  # Sample fire durations

  # If no distribution is specified
  if(is.na(fireDurationDistributionName)) {
    fireDurations <- sample(rep(filteredFireDurationTable$Mean, 2), nrow(data), replace = T)

    # If sampling form a normal distribution
  } else if (fireDurationDistributionName == "Normal") {
    fireDurations <- sampleNorm(filteredFireDurationTable, nrow(data))

    # If sampling form a gamma distribution
  } else if (fireDurationDistributionName == "Gamma") {
    fireDurations <- sampleGamma(filteredFireDurationTable, nrow(data))

    # Otherwise sample from a user defined distribution
  } else {
    fireDurationDistribution <- DistributionValue %>% filter(Name == fireDurationDistributionName)
    
    if (nrow(fireDurationDistribution) == 1) {
      fireDurations <- rep(fireDurationDistribution$Value, nrow(data))
    } else {
      fireDurations <- sample(fireDurationDistribution$Value, nrow(data), replace = T, prob = fireDurationDistribution$RelativeFrequency)
    }
  }

  # Update SyncroSim progress bar
  progressBar()

  # Add a record for each burning day, sample the number of hours burning for each
  # Finally add season and fire zone back to the dataframe and return
  fireDurations %>%
    imap_dfr(
      ~ data %>%
        slice(.y) %>%
        expand_grid(BurnDay = seq(.x))) %>%
    mutate(
      HoursBurning =
        # If no distribution is provided
        if (is.na(hoursBurningDistributionName)) {
          sample(rep(filteredHoursBurningTable$Mean, 2), nrow(.), replace = T)

          # If sampling from a normal distribution
        } else if (hoursBurningDistributionName == "Normal") {
          sampleNorm(filteredHoursBurningTable, nrow(.))

          # If sampling from a gamma distribution
        } else if (hoursBurningDistributionName == "Gamma") {
          sampleGamma(filteredHoursBurningTable, nrow(.))

          # Otherwise sample from a user defined distribution
        } else {
          hoursBurningDistribution <- DistributionValue %>% filter(Name == hoursBurningDistributionName)
          
          if (nrow(hoursBurningDistribution) == 1) {
            rep(hoursBurningDistribution$Value, nrow(.))
          } else {
            sample(hoursBurningDistribution$Value, nrow(.), replace= T, prob = hoursBurningDistribution$RelativeFrequency)
          }
        },
      firezone = firezone,
      season = season) %>%
    return
}

# Define function to sample weather stream given season and weatherzone
sampleWeather <- function(season, weatherzone, data) {
  
  # Filter weather by season and weather zone
  localWeather <- WeatherStream %>%
    filter(
      Season == season | is.na(Season) | Season == "All",
      WeatherZone == weatherzone | is.na(WeatherZone)) %>%
    dplyr::select(-Season, -WeatherZone)

  if (nrow(localWeather) == 0)
    stop("Could not find any daily weather records for the Season \"", season, "\" and Weather Zone \"", weatherzone, "\". Please add daily weather records as needed or check ignition distribution if this combination is invalid.")

  # Sample rows of the weather stream randomly
  weatherIndex <- sample(nrow(localWeather), nrow(data), replace = T)

  # If sampling sequentially, modify the sampled weather stream accordingly
  if(WeatherOptions$SampleSequentially)
    weatherIndex <- data$BurnDay %>%
    imap_int(
      function(burnDay, position, weatherIndex)
        as.integer(weatherIndex[position - (burnDay - 1)] + (burnDay - 1)) %>% min(nrow(localWeather)),
      weatherIndex)

  # Update SyncroSim progress bar
  progressBar()

  # Convert weather indices to weather data and return
  data %>%
    dplyr::select(Iteration, FireID, BurnDay, HoursBurning) %>%
    bind_cols(localWeather %>% slice(weatherIndex)) %>%
    return
}

# Determine Fire Zone and Weather Zone for each ignition ----
DeterministicIgnitionLocation$cell <- cellFromXY(
  fuelsRaster,
  xy = data.frame(
    long=DeterministicIgnitionLocation$Longitude,
    lat=DeterministicIgnitionLocation$Latitude) %>% 
      st_as_sf(crs = "EPSG:4326",
      coords = c("long","lat")) %>%
      st_transform(crs = crs(fuelsRaster)) %>%
      st_coordinates)

if (!is.null(weatherZoneRaster)){
  DeterministicIgnitionLocation <- DeterministicIgnitionLocation %>%
    mutate(
      weatherzoneID = weatherZoneRaster[][cell],
      WeatherZone = lookup(weatherzoneID, WeatherZoneTable$ID, WeatherZoneTable$Name)
    ) %>%
    dplyr::select(-weatherzoneID)
} else{
  numIgnitions <- nrow(DeterministicIgnitionLocation)
  weatherZoneSamples <- sample(WeatherZoneTable$Name, numIgnitions, replace = T)
  DeterministicIgnitionLocation$WeatherZone <- weatherZoneSamples
}

if (!is.null(fireZoneRaster)){
  DeterministicIgnitionLocation <- DeterministicIgnitionLocation %>%
    mutate(
      firezoneID = fireZoneRaster[][cell],
      FireZone = lookup(firezoneID, FireZoneTable$ID, FireZoneTable$Name)
    ) %>%
    dplyr::select(-firezoneID)
} else{
  numIgnitions <- nrow(DeterministicIgnitionLocation)
  fireZoneSamples <- sample(FireZoneTable$Name, numIgnitions, replace = T)
  DeterministicIgnitionLocation$FireZone <- fireZoneSamples
}

# Clean up
DeterministicIgnitionLocation <- DeterministicIgnitionLocation %>%
  dplyr::select(-cell)

updateRunLog("Finished preparing inputs in ", updateBreakpoint())

# Initialize the SyncroSim progress bar
# - Fire duration must be sampled for every combination of season and firezone
# - Weather must be sampled for every combination of season and weatherzone
# - This block finds the maximum number of possible combinations of season and firezone / weatherzone
nsteps <- DeterministicIgnitionLocation %>%
  {uni(., "Season") * (uni(., "FireZone") + uni(., "WeatherZone"))}
progressBar("begin", totalSteps = nsteps)

progressBar(type = "message", message = "Sampling burning conditions...")

# Sample burn conditions ----
DeterministicBurnConditions <- DeterministicIgnitionLocation %>%
  # Rename some variables to avoid collisions when filtering other tables
  rename(season = Season, firezone = FireZone, weatherzone = WeatherZone) %>%

  # Group by season and fire zone to sample fire duration and hours burning
  group_by(season, firezone) %>%
  nest %>%
  pmap_dfr(sampleFireDuration) %>%

  # Group season and weather zone to sample weather
  group_by(season, weatherzone) %>%
  nest %>%
  pmap_dfr(sampleWeather) %>%

  # Clean up
  arrange(Iteration, FireID, BurnDay) %>%
  fill_season() %>%
  as.data.frame()

# Save Output
saveDatasheet(myScenario, DeterministicBurnConditions, "burnP3Plus_DeterministicBurnCondition", append = F)

# Wrapup the SyncroSim progress bar
progressBar("end")
updateRunLog("Finished sampling burn conditions in ", updateBreakpoint(), "\n\n")
