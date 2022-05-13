library(rsyncrosim)
library(tidyverse)
library(raster)

# Setup ----

## Connect to SyncroSim ----

myScenario <- scenario()

# Load Run Controls and identify iterations to run
RunControl <- datasheet(myScenario, "burnP3Plus_RunControl")
iterations <- seq(RunControl$MinimumIteration, RunControl$MaximumIteration)

# Load remaining datasheets
FuelTypeTable <- datasheet(myScenario, "burnP3Plus_FuelType")
FireZoneTable <- datasheet(myScenario, "burnP3Plus_FireZone")
DistributionValue <- datasheet(myScenario, "burnP3Plus_DistributionValue")
SeasonTable <- datasheet(myScenario, "burnP3Plus_Season")
CauseTable  <- datasheet(myScenario, "burnP3Plus_Cause")

# Load relevant ignition datasheets
IgnitionsPerIteration <- datasheet(myScenario, "burnP3Plus_IgnitionsPerIteration", optional = T)
ResampleOption <- datasheet(myScenario, "burnP3Plus_FireResampleOption", optional = T)
ProbabilisticIgnitionLocation <- datasheet(myScenario, "burnP3Plus_ProbabilisticIgnitionLocation", optional = T)
IgnitionRestriction <- datasheet(myScenario, "burnP3Plus_IgnitionRestriction", optional = T)
IgnitionDistribution <- datasheet(myScenario, "burnP3Plus_IgnitionDistribution")

# Import relevant rasters, allowing for missing values
fuelsRaster <- datasheetRaster(myScenario, "burnP3Plus_LandscapeRasters", "FuelGridFileName")
fireZoneRaster <- tryCatch(
  datasheetRaster(myScenario, "burnP3Plus_LandscapeRasters", "FireZoneGridFileName"),
  error = function(e) NULL)

## Extract relevant parameters ----
numIterations <- length(iterations)
distributionName <- IgnitionsPerIteration$DistributionType
proportionExtraIgnitions <- 0
if (length(ResampleOption$ProportionExtraIgnition) > 0)
  proportionExtraIgnitions <- ResampleOption$ProportionExtraIgnition

## Handle empty tables ----
if(nrow(FireZoneTable) == 0)
  FireZoneTable <- data.frame(Name = "", ID = 0)
if(nrow(CauseTable) == 0)
  CauseTable <- data.frame(Name = "")
if(nrow(SeasonTable) == 0)
  SeasonTable <- data.frame(Name = "")

## Function Definitions ----

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

# Define function to sample locations given season, cause, and fire zone
sampleLocations <- function(season, cause, firezone, data) {
  # Convert firezone to ID value
  firezoneID <- FireZoneTable %>% filter(Name == firezone) %>% pull(ID)
  
  # Determine the restricted fuel types for the given season, cause, firezone
  restrictedFuels <- IgnitionRestriction %>%
    filter(Season == season | is.na(Season), Cause == cause | is.na(Cause), FireZone == firezone | is.na(FireZone)) %>%
    pull(FuelType)
  
  # Convert restricted fuels list to IDs, add NA as restricted fuel
  restrictedFuelIDs <- FuelTypeTable %>%
    filter(Name %in% restrictedFuels) %>%
    pull(ID) %>%
    c(NA)
  
  # Mask the probabilistic ignition location map to only the current fire zone
  # and fuels that are not restricted
  maskedProbability <- ProbabilisticIgnitionLocation %>%
    
    # Start by finding the relevant probabilist ignition grid
    filter(Cause == cause) %>%
    pull(IgnitionGridFileName) %>%
    {if(length(.) > 0) raster(.) else raster(fuelsRaster) %>% raster::setValues(1)} %>% # Use a uniform probability map if there is no valid grid
    
    # Mask by the restrited fuels grid and firezone raster if present
    {if(!is.null(fireZoneRaster)) mask(., fireZoneRaster, maskvalue = firezoneID, inverse = T) else .} %>%
    mask(fuelsRaster, maskvalue = restrictedFuelIDs)
  
  # Sample cells from probability map
  cells <- sample(ncell(maskedProbability), nrow(data), replace = T, prob = replace_na(maskedProbability[], 0)) 
  
  # Update SyncroSim progress bar
  progressBar()
  
  # Convert cells to row/col, format, and return
  return(
    tibble(
      Iteration = data$Iteration,
      FireID = data$FireID,
      X = colFromCell(maskedProbability, cells),
      Y = rowFromCell(maskedProbability, cells),
      Season = season,
      Cause = cause))
}

# Sample number of ignitions per iteration ----
ignitionCountDistribution <- DistributionValue %>% filter(Name == distributionName)

# Sample from a discrete distribution is specified
if(nrow(ignitionCountDistribution) > 0) {
  numIgnitions <- sample(ignitionCountDistribution$Value, numIterations, replace = T, prob = ignitionCountDistribution$RelativeFrequency)

# Otherwise sample from a normal distribution using default values for Mean and SD if not provided
} else
  numIgnitions <- sampleNorm(IgnitionsPerIteration, numIterations)
  
saveDatasheet(myScenario, data.frame(Iteration = iterations, Ignitions = numIgnitions), "burnP3Plus_DeterministicIgnitionCount", append = T)

# Add extra ignitions to each iteration if requested
numIgnitions <- ceiling(numIgnitions * (1 + proportionExtraIgnitions))

# Initialize the SyncroSim progress bar
progressBar("begin", totalSteps = nrow(IgnitionDistribution))

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
  { if(nrow(IgnitionDistribution) > 0) {
      mutate(.,
        situation = sample(nrow(IgnitionDistribution), nrow(.), replace = T, prob = IgnitionDistribution$RelativeLikelihood),
        season = IgnitionDistribution$Season[situation],
        cause = IgnitionDistribution$Cause[situation],
        firezone = IgnitionDistribution$FireZone[situation]) %>%
      dplyr::select(-situation)
    
  # If the Ignition Distribution table is not present, choose these values randomly 
    } else
      mutate(.,
        season =   sample(SeasonTable$Name,   nrow(.), replace = T),
        cause =    sample(CauseTable$Name,    nrow(.), replace = T),
        firezone = sample(FireZoneTable$Name, nrow(.), replace = T))
  } %>%
  
  # Group the data by season, cause and firezone and send to
  # sampleLocations() to sample ignition location accordingly
  group_by(season, cause, firezone) %>%
  nest() %>%
  pmap_dfr(sampleLocations) %>%
  
  # Clean up
  arrange(Iteration, FireID) %>%
  as.data.frame

# Return output
saveDatasheet(myScenario, DeterminisiticIgnitionLocation, "burnP3Plus_DeterministicIgnitionLocation", append = T)

# Wrapup the SyncroSim progress bar
progressBar("end")