library(rsyncrosim)
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(terra))

# Setup ----
progressBar(type = "message", message = "Preparing inputs...")

# Initialize first breakpoint for timing code
currentBreakPoint <- proc.time()

## Connect to SyncroSim ----

myScenario <- scenario()

# Load Run Controls and identify iterations to run
RunControl <- datasheet(myScenario, "burnP3Plus_RunControl")

# Load remaining datasheets
FuelTypeTable <- datasheet(myScenario, "burnP3Plus_FuelType")
FireZoneTable <- datasheet(myScenario, "burnP3Plus_FireZone")
DistributionType <- datasheet(myScenario, "burnP3Plus_Distribution", lookupsAsFactors = F)
DistributionValue <- datasheet(myScenario, "burnP3Plus_DistributionValue", optional = T, lookupsAsFactors = F)
SeasonTable <- datasheet(myScenario, "burnP3Plus_Season")
CauseTable  <- datasheet(myScenario, "burnP3Plus_Cause")

# Load relevant ignition datasheets
IgnitionsPerIteration <- datasheet(myScenario, "burnP3Plus_IgnitionsPerIteration", optional = T, lookupsAsFactors = F)
ResampleOption <- datasheet(myScenario, "burnP3Plus_FireResampleOption", optional = T)
ProbabilisticIgnitionLocation <- datasheet(myScenario, "burnP3Plus_ProbabilisticIgnitionLocation", optional = T, lookupsAsFactors = F)
IgnitionRestriction <- datasheet(myScenario, "burnP3Plus_IgnitionRestriction", optional = T, lookupsAsFactors = F)
IgnitionDistribution <- datasheet(myScenario, "burnP3Plus_IgnitionDistribution", optional = T, lookupsAsFactors = F)

# Import relevant rasters, allowing for missing values
fuelsRaster <- rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["FuelGridFileName"]])
fireZoneRaster <- tryCatch(
  rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["FireZoneGridFileName"]]),
  error = function(e) NULL)

## Handle empty values ----
if(nrow(FuelTypeTable) == 0) {
  updateRunLog("No fuel table found! Using default Canadian Forest Service fuel codes.", type = "warning")
  FuelTypeTable <- read_csv(file.path(ssimEnvironment()$PackageDirectory, "Default Fuel Types.csv"))
  saveDatasheet(myScenario, FuelTypeTable, "burnP3Plus_FuelType")
}

if(nrow(RunControl) == 0) {
  updateRunLog("No iteration count provided, defaulting to 1 iteration.", type = "warning")
  RunControl[1,] <- c(1,1,0,0)
  saveDatasheet(myScenario, RunControl, "burnP3Plus_RunControl")
}

if(nrow(IgnitionsPerIteration) == 0) {
  updateRunLog("No Ignitions per Iteration values found. Defaulting to 1 ignition per iteration.", type = "info")
  IgnitionsPerIteration[1,"Mean"] <- 1
  saveDatasheet(myScenario, IgnitionsPerIteration, "burnP3Plus_IgnitionsPerIteration")
}

if(nrow(ResampleOption) == 0) {
  ResampleOption[1,] <- c(0,0)
  saveDatasheet(myScenario, ResampleOption, "burnP3Plus_FireResampleOption")
}

## Check raster inputs for consistency ----

# Ensure fuels crs can be converted to Lat / Long
tryCatch(fuelsRaster %>% project("+proj=longlat"), error = function(e) stop("Error parsing provided Fuels map. Cannot calculate Latitude and Longitude from provided Fuels map, please check CRS."))

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

## Parse distributions ----

# Decide if sampling based on a distribution
byDistribution <- any(!is.na(IgnitionsPerIteration$DistributionType))

# If so, ensure only one distribution is specified
if(byDistribution & nrow(IgnitionsPerIteration) > 1)
  stop("If sampling Ignitions per Iteration from a distribution, only one record is accepted.\nTo modify a user-defined distribution, please edit the 'Distributions' datasheet \nunder the 'Advanced' tab in the scenario properties.")

# Identify the name and type of distribution
distributionName <- IgnitionsPerIteration$DistributionType
isAuto <- DistributionType %>% filter(Name == distributionName) %>% pull(IsAuto) %>% replace_na(0) %>% `==`(-1) 
distributionData <- DistributionValue %>% filter(Name == distributionName)

if(byDistribution) {
  # If using a built-in distribution, ensure Mean and SD are provided
  if(isAuto)
    if(is.na(IgnitionsPerIteration$Mean) | is.na(IgnitionsPerIteration$DistributionSD))
      stop("Please specify a Mean and SD to use this built-in distribution to sample Ignitions per Iteration")
  
  # If using a user-defined distribution, ensure there is a corresponding definition and warn user about unrespected fields
  if(!isAuto) {
    if(nrow(distributionData) == 0)
      stop("No distribution definition found for the user-defined distribution in Ignitions per Iteration.\nTo modify a user-defined distribution, please edit the 'Distributions' datasheet \nunder the 'Advanced' tab in the scenario properties.")
    
    if(!is.na(IgnitionsPerIteration$Mean) | !is.na(IgnitionsPerIteration$DistributionSD))
       updateRunLog("Found Mean or SD values for a user-defined distribution in Ignitions per Iteration.\nThese values will not be respected during sampling. To modify a user-defined distribution, \nplease edit the 'Distributions' datasheet under the 'Advanced' tab in the scenario properties.", type = "warning")
  }
}
## Extract relevant parameters ----
iterations <- seq(RunControl$MinimumIteration, RunControl$MaximumIteration)
numIterations <- length(iterations)
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
    
    # Start by finding the relevant probabilistic ignition grid
    filter(Cause %in% c(cause, NA), Season %in% c(season, NA)) %>%
    pull(IgnitionGridFileName) %>%
    
    # Warn if multiple probabilistic ignition grids are specified
    {if(length(.) > 1) {updateRunLog("Multiple probabilistic ignition grids specified for some combinations of season and cause. Using first applicable grid.", type = "warning"); .[1]} else .} %>%
    
    # Use a uniform probability map if there is no valid grid
    {if(length(.) > 0) rast(.) else rast(fuelsRaster, vals = 1)} %>% 
    
    # Check the probability map for consistency
    checkSpatialInput("Probabilistic Ignition Location", checkProjection = F) %>%
    
    # Mask by the restrited fuels grid and firezone raster if present and firezone is not empty
    {if(!is.null(fireZoneRaster) & firezone != "") mask(., fireZoneRaster, maskvalue = firezoneID, inverse = T) else .} %>%
    mask(fuelsRaster, maskvalue = restrictedFuelIDs)
  
  # Sample cells from probability map
  cells <- sample(ncell(maskedProbability), nrow(data), replace = T, prob = replace_na(maskedProbability[], 0)) 
  longlat <- as.points(fuelsRaster)[cells] %>%
    project("+proj=longlat") %>%
    crds
  
  # Update SyncroSim progress bar
  progressBar()
  # Convert cells to row/col, format, and return
  return(
    tibble(
      Iteration = data$Iteration,
      FireID = data$FireID,
      Latitude = longlat[, "y"],
      Longitude = longlat[, "x"],
      Season = season,
      Cause = cause))
}

updateRunLog("Finished preparing inputs in ", updateBreakpoint())
  
# Sample number of ignitions per iteration ----
progressBar(type = "message", message = "Sampling iterations...")

# If no distribution is specified
if(is.na(distributionName)) {
  numIgnitions <- sample(IgnitionsPerIteration$Mean, numIterations, replace = T)
  
# If a normal distribution is requested
} else if (distributionName == "Normal") {
  numIgnitions <- sampleNorm(IgnitionsPerIteration, numIterations)
  
# If a gamma distribution is requested
} else if (distributionName == "Gamma") {
  numIgnitions <- sampleGamma(IgnitionsPerIteration, numIterations)
  
# Otherwise sample from a user distribution
} else {
  ignitionCountDistribution <- DistributionValue %>% filter(Name == distributionName)
  numIgnitions <- sample(ignitionCountDistribution$Value, numIterations, replace = T, prob = ignitionCountDistribution$RelativeFrequency)
}
  
saveDatasheet(myScenario, data.frame(Iteration = iterations, Ignitions = numIgnitions), "burnP3Plus_DeterministicIgnitionCount", append = T)

# Add extra ignitions to each iteration if requested
numIgnitions <- ceiling(numIgnitions * (1 + proportionExtraIgnitions))

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
updateRunLog("Finished sampling ignitions in ", updateBreakpoint(), "\n\n")