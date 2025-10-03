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
RunControl <- datasheet(myScenario, "burnP3Plus_RunControl", returnInvisible = T)
FuelType <- datasheet(myScenario, "burnP3Plus_FuelType")
FireZoneTable <- datasheet(myScenario, "burnP3Plus_FireZone")
WeatherZoneTable <- datasheet(myScenario, "burnP3Plus_FireZone")
DistributionType <- datasheet(myScenario, "burnP3Plus_Distribution", lookupsAsFactors = F, returnInvisible = T)
DistributionValue <- datasheet(myScenario, "burnP3Plus_DistributionValue", optional = T, lookupsAsFactors = F)
SeasonTable <- datasheet(myScenario, "burnP3Plus_Season", returnInvisible = T) %>% filter(is.na(IsAuto))
CauseTable  <- datasheet(myScenario, "burnP3Plus_Cause")
IgnitionsPerIteration <- datasheet(myScenario, "burnP3Plus_IgnitionsPerIteration", optional = T, lookupsAsFactors = F, returnInvisible = T)
ResampleOption <- datasheet(myScenario, "burnP3Plus_FireResampleOption", optional = T) %>% dplyr::select(-starts_with("Scenario"))
ProbabilisticIgnitionLocation <- datasheet(myScenario, "burnP3Plus_ProbabilisticIgnitionLocation", optional = T, lookupsAsFactors = F, returnInvisible = T)
IgnitionRestriction <- datasheet(myScenario, "burnP3Plus_IgnitionRestriction", optional = T, lookupsAsFactors = F, returnInvisible = T)
IgnitionDistribution <- datasheet(myScenario, "burnP3Plus_IgnitionDistribution", optional = T, lookupsAsFactors = F, returnInvisible = T)
DeterministicIgnitionLocation <- datasheet(myScenario, "burnP3Plus_DeterministicIgnitionLocation", optional = T, returnInvisible = T) %>% unique

# Import relevant rasters, allowing for missing values
fuelsRaster <- loadSpatial$fuels()
fireZoneRaster <- loadSpatial$firezone()

## Parse and validate datasheets ----
validateAndParseData$FuelType()
validateAndParseData$Season()
validateAndParseData$Cause()
validateAndParseData$Zones()
validateAndParseData$RunControl()
validateAndParseData$ResampleOptions()
validateAndParseData$IgnitionSampling()


## Parse distributions ----

## Extract relevant parameters ----
iterations <- seq(RunControl$MinimumIteration, RunControl$MaximumIteration)
numIterations <- length(iterations)
proportionExtraIgnitions <- 0
if (!is.na(ResampleOption$ProportionExtraIgnition))
  proportionExtraIgnitions <- ResampleOption$ProportionExtraIgnition

## Function Definitions ----

# Define function to sample locations given season, cause, and fire zone
sampleLocations <- function(season, cause, firezone, data) {
  # Convert firezone to ID value
  firezoneID <- FireZoneTable %>% filter(Name == firezone) %>% pull(ID)

  # Determine the restricted fuel types for the given season, cause, firezone
  restrictedFuels <- IgnitionRestriction %>%
    filter(
      Season == season | is.na(Season) | Season == "All",
      Cause == cause | is.na(Cause),
      FireZone == firezone | is.na(FireZone)) %>%
    pull(FuelType)

  # Convert restricted fuels list to IDs, add NA as restricted fuel
  restrictedFuelIDs <- FuelType %>%
    filter(Name %in% restrictedFuels) %>%
    pull(ID) %>%
    c(NA)

  # Mask the probabilistic ignition location map to only the current fire zone
  # and fuels that are not restricted
  maskedProbability <- ProbabilisticIgnitionLocation %>%

    # Start by finding the relevant probabilistic ignition grid
    filter(Cause %in% c(cause, NA), Season %in% c(season, NA, "All")) %>%
    pull(IgnitionGridFileName) %>%

    # Warn if multiple probabilistic ignition grids are specified
    {if(length(.) > 1) {updateRunLog("Multiple probabilistic ignition grids specified for some combinations of season and cause. Using first applicable grid.", type = "warning"); .[1]} else .} %>%

    # Use a uniform probability map if there is no valid grid
    {if(length(.) > 0) rast(.) else rast(fuelsRaster, vals = 1)} %>%

    # Check the probability map for consistency
    checkSpatialInput("Probabilistic Ignition Location", checkProjection = F) %>%

    # Mask by the restrited fuels grid and firezone raster if present and firezone is not empty
    {if(!(is.null(fireZoneRaster) | is.na(firezone) | firezone == "")) mask(., fireZoneRaster, maskvalue = firezoneID, inverse = T) else .} %>%
    mask(fuelsRaster, maskvalue = restrictedFuelIDs)

  # Sample cells from probability map
  cells <- sample(ncell(maskedProbability), nrow(data), replace = T, prob = replace_na(maskedProbability[], 0))
  longlat <- xyFromCell(fuelsRaster,cells)%>%
    data.frame %>%
    st_as_sf(coords=c("x","y"), crs=st_crs(fuelsRaster)) %>%
    st_transform("EPSG:4326") %>%
    st_coordinates

  # Update SyncroSim progress bar
  progressBar()
  # Convert cells to row/col, format, and return
  return(
    tibble(
      Iteration = data$Iteration,
      FireID = data$FireID,
      Latitude = longlat[, "Y"],
      Longitude = longlat[, "X"],
      Season = season,
      Cause = cause))
}

updateRunLog("Finished preparing inputs in ", updateBreakpoint())

# Sample number of ignitions per iteration ----
progressBar(type = "message", message = "Sampling iterations...")

# If no distribution is specified
if(is.na(distributionName)) {
  numIgnitions <- sample(rep(IgnitionsPerIteration$Mean, 2), numIterations, replace = T)

# If a normal distribution is requested
} else if (distributionName == "Normal") {
  numIgnitions <- sampleNorm(IgnitionsPerIteration, numIterations)

# If a gamma distribution is requested
} else if (distributionName == "Gamma") {
  numIgnitions <- sampleGamma(IgnitionsPerIteration, numIterations)

# Otherwise sample from a user distribution
} else {
  ignitionCountDistribution <- DistributionValue %>% filter(Name == distributionName)
  
  if (nrow(ignitionCountDistribution) == 1) {
    numIgnitions <- rep(IgnitionsPerIteration$Value, numIterations)
  } else {
    numIgnitions <- sample(ignitionCountDistribution$Value, numIterations, replace = T, prob = ignitionCountDistribution$RelativeFrequency)
  }
}

# Prepend extra ignitions for resampling to vector of ignition counts if requested (to be assigned to iteration 0)
numIgnitions <- numIgnitions %>%
  sum %>%
  prod(proportionExtraIgnitions) %>%
  ceiling %>%
  c(numIgnitions)

# Update iterations and numIterations
# - Note: assumes this transformer remains single-threaded
iterations <- c(0, iterations)
numIterations <- numIterations + 1

# Initialize the SyncroSim progress bar
progressBar("begin", totalSteps = nrow(IgnitionDistribution))
progressBar(type = "message", message = "Sampling iterations...")

# Build table of ignitions ----
DeterminisiticIgnitionLocation <-
  # Create a row for each ignition in each iteration
  map2_dfr(
    numIgnitions,
    iterations,
    ~ if(.x > 0)
      tibble(
        Iteration = .y,
        FireID = seq(.x))) %>%

  # Sample rows from the Ignition Distribution table to assign
  # a season, cause, and firezone to each ignition if the table is present
  # - "All" season is explicitly set to NA to be resampled from defined seasons if possible
  { if(!isDatasheetEmpty(IgnitionDistribution)) {
      mutate(.,
        situation = sample(nrow(IgnitionDistribution), nrow(.), replace = T, prob = IgnitionDistribution$RelativeLikelihood),
        season = IgnitionDistribution$Season[situation] %>% na_if("All"),
        cause = IgnitionDistribution$Cause[situation],
        firezone = IgnitionDistribution$FireZone[situation]) %>%
      dplyr::select(-situation)

  # If the Ignition Distribution table is not present, set these values as empty strings to be filled in the next step
    } else
      mutate(.,
        season =   NA_character_,
        cause =    NA_character_,
        firezone = NA_character_)
  } %>%

  # If any season, cause, or firezones values are blank, replace with a random sample from the appropriate table of definitions, 
  # - Note that values could be NA or "", so we first standardize all to NA then correct
  mutate(.,
     season =   na_if(as.character(season), ""),
     firezone = na_if(as.character(firezone), ""),
     cause =    na_if(as.character(cause), ""),
     season =   coalesce(season,   sample(SeasonTable$Name,   length(season),   replace = T)),
     cause =    coalesce(cause,    sample(CauseTable$Name,    length(cause),    replace = T)),
     firezone = coalesce(firezone, sample(FireZoneTable$Name, length(firezone), replace = T))) %>%

  # Group the data by season, cause and firezone and send to
  # sampleLocations() to sample ignition location accordingly
  group_by(season, cause, firezone) %>%
  nest() %>%
  pmap_dfr(sampleLocations) %>%

  # Clean up
  arrange(Iteration, FireID) %>%
  fill_season() %>%
  as.data.frame

# Return output
saveDatasheet(myScenario, DeterminisiticIgnitionLocation, "burnP3Plus_DeterministicIgnitionLocation", append = F)

# Wrapup the SyncroSim progress bar
progressBar("end")
updateRunLog("Finished sampling ignitions in ", updateBreakpoint(), "\n\n")
