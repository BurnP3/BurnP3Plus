# Clean global environment variables
native_proj_lib <- Sys.getenv("PROJ_LIB")
Sys.unsetenv("PROJ_LIB")

# Check and load packages ----
library(rsyncrosim)
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(terra))

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

checkPackageVersion("rsyncrosim", "1.5.0")
checkPackageVersion("tidyverse",  "2.0.0")
checkPackageVersion("terra",      "1.5.21")
checkPackageVersion("dplyr",      "1.1.2")
checkPackageVersion("codetools",  "0.2.19")

# Setup ----
options(scipen = 100)
progressBar(type = "message", message = "Preparing inputs...")

# Initialize first breakpoint for timing code
currentBreakPoint <- proc.time()

## Connect to SyncroSim ----
myScenario <- scenario()

# Load remaining datasheets
DeterministicIgnitionLocation <- datasheet(myScenario, "burnP3Plus_DeterministicIgnitionLocation", optional = T, returnInvisible = T) %>% unique
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

# Import relevant rasters, allowing for missing values
fuelsRaster <- rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["FuelGridFileName"]])
fireZoneRaster <- tryCatch(
  rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["FireZoneGridFileName"]]),
  error = function(e) NULL)
weatherZoneRaster <- tryCatch(
  rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["WeatherZoneGridFileName"]]),
  error = function(e) NULL)

## Handle empty values ----
if(nrow(WeatherStream) == 0) {
  stop("Error: Please provide weather stream data to sample burning conditions.")
}

if(nrow(FireDurationTable) == 0) {
  updateRunLog("No fire duration distribution provided, defaulting to 1 day fires.", type = "warning")
  FireDurationTable[1,"Mean"] <- 1
  saveDatasheet(myScenario, FireDurationTable, "burnP3Plus_FireDuration")
}

if(nrow(HoursBurningTable) == 0) {
  updateRunLog("No hours burning per day distribution provided, defaulting to 4 hours of burning per burn day.", type = "warning")
  HoursBurningTable[1,"Mean"] <- 4
  saveDatasheet(myScenario, HoursBurningTable, "burnP3Plus_HoursPerDayBurning")
}

# If HoursBurningTable set to "All", then all seasons in the SeasonTable
# not specified in the HoursBurningTable should also have that value
if (!"All" %in% HoursBurningTable$Season && !is.na(HoursBurningTable$Season[1])){
  HoursBurningTable <- HoursBurningTable %>%
    add_row(Season = c("All"), Mean = c(4))
}

for (s in SeasonTable$Name){
  
  if (!s %in% HoursBurningTable$Season){
    msg <- paste0("No hours burning per day distribution provided for season ", s, 
                  ". Defaulting to either 'All' or 4 hours of burning per burn day.")
    updateRunLog(msg, type = "info")
    newRow <- HoursBurningTable[HoursBurningTable$Season == "All", ]
    newRow$Season <- s
    HoursBurningTable <- HoursBurningTable %>%
      add_row(newRow)
  }
}

if(nrow(FireZoneTable) == 0)
  FireZoneTable <- data.frame(Name = "", ID = 0)
if(nrow(WeatherZoneTable) == 0)
  WeatherZoneTable <- data.frame(Name = "", ID = 0)

## Check raster inputs for consistency ----

# Ensure fuels crs can be converted to Lat / Long
if(fuelsRaster %>% is.lonlat){stop("Incorrect coordinate system. Projected coordinate system required, please reproject your grids.")}
tryCatch(fuelsRaster %>% project("EPSG:4326"), error = function(e) stop("Error parsing provided Fuels map. Cannot calculate Latitude and Longitude from provided Fuels map, please check CRS."))

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
checkSpatialInput(fireZoneRaster, "Fire Zone")
checkSpatialInput(weatherZoneRaster, "Weather Zone")

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

# Function to convert from latlong to cell index
cellFromLatLong <- function(x, lat, long) {
  # Convert list of lat and long to SpatVector, reproject to source crs
  points <- matrix(c(long, lat), ncol = 2) %>%
    vect(crs = "EPSG:4326") %>%
    project(x)
  
  # Get vector of cell ID's from points
  return(cells(x, points)[, "cell"])
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
    filter(Season == season | is.na(Season), FireZone == firezone | is.na(FireZone))
  
  fireDurationDistributionName <- filteredFireDurationTable %>%
    pull(DistributionType)
  
  # Determine hours burning per day distribution type to use
  # This is a function of season only
  filteredHoursBurningTable <- HoursBurningTable %>%
    filter(Season == season | is.na(Season))
  
  hoursBurningDistributionName <- filteredHoursBurningTable %>%
    pull(DistributionType)
  
  # Sample fire durations
  
  # If no distribution is specified
  if(is.na(fireDurationDistributionName)) {
    fireDurations <- rep(filteredFireDurationTable$Mean, nrow(data))
    
  # If sampling form a normal distribution
  } else if (fireDurationDistributionName == "Normal") {
    fireDurations <- sampleNorm(filteredFireDurationTable, nrow(data))
    
  # If sampling form a gamma distribution
  } else if (fireDurationDistributionName == "Gamma") {
    fireDurations <- sampleGamma(filteredFireDurationTable, nrow(data))
    
  # Otherwise sample from a user defined distribution
  } else {
    fireDurationDistribution <- DistributionValue %>% filter(Name == fireDurationDistributionName)
    fireDurations <- sample(fireDurationDistribution$Value, nrow(data), replace = T, prob = fireDurationDistribution$RelativeFrequency)
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
          rep(filteredHoursBurningTable$Mean, nrow(.))
        
        # If sampling from a normal distribution
        } else if (hoursBurningDistributionName == "Normal") {
          sampleNorm(filteredHoursBurningTable, nrow(.))
          
        # If sampling from a gamma distribution
        } else if (hoursBurningDistributionName == "Gamma") {
          sampleGamma(filteredHoursBurningTable, nrow(.))
        
        # Otherwise sample from a user defined distribution
        } else {
          hoursBurningDistribution <- DistributionValue %>% filter(Name == hoursBurningDistributionName)
          sample(hoursBurningDistribution$Value, nrow(.), replace= T, prob = hoursBurningDistribution$RelativeFrequency)
        },
      firezone = firezone,
      season = season) %>%
    return
}

# Define function to sample weather stream given season and weatherzone
sampleWeather <- function(season, weatherzone, data) {
  # Filter weather by season and weather zone
  localWeather <- WeatherStream %>%
    filter(Season == season | is.na(Season), WeatherZone == weatherzone | is.na(WeatherZone)) %>%
    dplyr::select(-Season, -WeatherZone)
  
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
DeterministicIgnitionLocation$cell <- cellFromLatLong(
  fuelsRaster, 
  DeterministicIgnitionLocation$Latitude, 
  DeterministicIgnitionLocation$Longitude)

if (!is.null(weatherZoneRaster)){
  DeterministicIgnitionLocation <- DeterministicIgnitionLocation %>%
    mutate(
      weatherzoneID = weatherZoneRaster[][cell],
      WeatherZone = lookup(weatherzoneID, WeatherZoneTable$ID, WeatherZoneTable$Name)
    ) %>%
    dplyr::select(-weatherzoneID)
} else{
  DeterministicIgnitionLocation$WeatherZone = WeatherZoneTable$Name
}

if (!is.null(fireZoneRaster)){
  DeterministicIgnitionLocation <- DeterministicIgnitionLocation %>%
    mutate(
      firezoneID = fireZoneRaster[][cell],
      FireZone = lookup(firezoneID, FireZoneTable$ID, FireZoneTable$Name)
    ) %>%
    dplyr::select(-firezoneID)
} else{
  DeterministicIgnitionLocation$FireZone = FireZoneTable$Name
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
  as.data.frame()

# Save Output
saveDatasheet(myScenario, DeterministicBurnConditions, "burnP3Plus_DeterministicBurnCondition", append = T)

# Wrapup the SyncroSim progress bar
progressBar("end")
updateRunLog("Finished sampling burn conditions in ", updateBreakpoint(), "\n\n")
