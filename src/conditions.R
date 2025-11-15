# Setup ----
Sys.unsetenv("PROJ_LIB")
library(rsyncrosim)

# Find location of shared function definitions and source
getSharedDefinitionsPath <- function() {
  sharedDefinitionsPath <- paste0(ssimEnvironment()$PackageDirectory, "/shared.R")
  return(sharedDefinitionsPath)
}
source(getSharedDefinitionsPath())

## Connect to SyncroSim ----

# Load relevant datasheets
DeterministicIgnitionLocation <- datasheet(myScenario, "burnP3Plus_DeterministicIgnitionLocation", optional = T, returnInvisible = T) %>% unique
DeterministicBurnCondition <- datasheet(myScenario, "burnP3Plus_DeterministicBurnCondition", optional = T, returnInvisible = T) %>% unique
FireZoneTable <- datasheet(myScenario, "burnP3Plus_FireZone")
WeatherZoneTable <- datasheet(myScenario, "burnP3Plus_WeatherZone")
DistributionValue <- datasheet(myScenario, "burnP3Plus_DistributionValue", optional = T, lookupsAsFactors = F)
SeasonTable <- datasheet(myScenario, "burnP3Plus_Season", returnInvisible = T) %>% dplyr::filter(is.na(IsAuto))
FireDurationTable <- datasheet(myScenario, "burnP3Plus_FireDuration", optional = T, lookupsAsFactors = F, returnInvisible = T)
HoursBurningTable <- datasheet(myScenario, "burnP3Plus_HoursPerDayBurning", optional = T, lookupsAsFactors = F, returnInvisible = T)
WeatherStream <- datasheet(myScenario, "burnP3Plus_WeatherStream", optional = T, lookupsAsFactors = F)
WeatherOptions <- datasheet(myScenario, "burnP3Plus_WeatherOption")

# Import relevant rasters, allowing for missing values
fuelsRaster <- loadSpatial$fuels()
fireZoneRaster <- loadSpatial$firezone()
weatherZoneRaster <- loadSpatial$weatherzone()

## Parse and validate datasheets ----
validateAndParseData$Season()
validateAndParseData$Zones()
validateAndParseData$DeterminsiticIgnitions()
validateAndParseData$BurnConditionSampling()

## Function Definitions ----

# Define function to sample days burning and hours per day burning given season and fire zone
sampleFireDuration <- function(season, firezone, data){
  # Determine fire duration distribution type to use
  # This is a function of season and firezone
  filteredFireDurationTable <- FireDurationTable %>%
    dplyr::filter(
      Season == season | is.na(Season) | Season == "All" | season == "All",
      FireZone == firezone | is.na(FireZone))

  fireDurationDistributionName <- filteredFireDurationTable %>%
    pull(DistributionType) %>%
    {if(length(.) == 0) {stop("No spread event days distribution set for the \"", season, "\" Season and the \"", firezone, "\" Fire Zone. Please check the Spread Event Days table for missing combinations of Season and Fire Zone.")} else .} %>%
    {if(length(.) > 1 & !all(is.na(.))) {updateRunLog("Multiple fire duration distributions applicable for one or more combinations of season and fire zone. Using first applicable distribution.", type = "warning"); .[1]} else .}

  # Determine hours burning per day distribution type to use
  # This is a function of season only
  filteredHoursBurningTable <- HoursBurningTable %>%
    dplyr::filter(Season == season | is.na(Season) | Season == "All" | season == "All")

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
    fireDurationDistribution <- DistributionValue %>% dplyr::filter(Name == fireDurationDistributionName)
    
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
          hoursBurningDistribution <- DistributionValue %>% dplyr::filter(Name == hoursBurningDistributionName)
          
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
    dplyr::filter(
      Season == season | is.na(Season) | Season == "All" | season == "All",
      WeatherZone == weatherzone | is.na(WeatherZone)) %>%
    dplyr::select(-Season, -WeatherZone) %>%
    dplyr::arrange(Order)

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
DeterministicIgnitionLocation <- DeterministicIgnitionLocation %>%
  joinZoneByLatLong(
    fireZoneRaster = fireZoneRaster,
    weatherZoneRaster = weatherZoneRaster,
    sampleMissing = T) %>%
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
  dplyr::select(-Order) %>% 
  as.data.frame()

# Save Output
saveDatasheet(myScenario, DeterministicBurnConditions, "burnP3Plus_DeterministicBurnCondition", append = F)

# Wrapup the SyncroSim progress bar
progressBar("end")
updateRunLog("Finished sampling burn conditions in ", updateBreakpoint(), "\n\n")
