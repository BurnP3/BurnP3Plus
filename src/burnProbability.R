# Setup ----
if (.Platform$OS.type == "windows") Sys.unsetenv("PROJ_LIB")
library(rsyncrosim)

# Find location of shared function definitions and source
getSharedDefinitionsPath <- function() {
  sharedDefinitionsPath <- paste0(ssimEnvironment()$PackageDirectory, "/shared.R")
  return(sharedDefinitionsPath)
}
Sys.setenv("MALLOC_CONF" = "dirty_decay_ms:0,muzzy_decay_ms:0") # Disable jemalloc decay to free up memory immediately (Arrow 24.+. Must be done before loading Arrow) 
source(getSharedDefinitionsPath())

## Connect to SyncroSim ----

# Load relevant datasheets
SeasonTable <- datasheet(myScenario, "burnP3Plus_Season", lookupsAsFactors = F, optional = T, includeKey = T, returnInvisible = T)
DeterministicIgnitionLocation <- datasheet(myScenario, "burnP3Plus_DeterministicIgnitionLocation", lookupsAsFactors = F, optional = T, returnInvisible = T) %>% unique
DeterministicBurnCondition <- datasheet(myScenario, "burnP3Plus_DeterministicBurnCondition", lookupsAsFactors = F, optional = T, returnInvisible = T) %>% unique
FBPVariableTable <- datasheet(myScenario, "burnP3Plus_FBPOutputVariable", lookupsAsFactors = F, optional = T, returnInvisible = T)
FBPStatisticTable <- datasheet(myScenario, "burnP3Plus_FBPOutputStatistic", lookupsAsFactors = F, optional = T, returnInvisible = T)
OutputOptions <- datasheet(myScenario, "burnP3Plus_OutputOption", returnInvisible = T, optional = T)
OutputOptionsSpatial <- datasheet(myScenario, "burnP3Plus_OutputOptionSpatial", returnInvisible = T, optional = T) %>% mutate(BurnPerimeter = as.character(BurnPerimeter))
OutputOptionFBPSpatial <- datasheet(myScenario, "burnP3Plus_OutputOptionFBPSpatial", optional = T, returnInvisible = T) %>% mutate(Variable = as.character(Variable))
OutputFireStatistic <- datasheet(myScenario, "burnP3Plus_OutputFireStatistic", returnInvisible = T, optional = T) %>% arrange(Iteration, FireID)
OutputRawTabular <- datasheet(myScenario, "burnP3Plus_OutputRawTabular", optional = T, returnInvisible = T)
OutputFirePerimeter <- datasheet(myScenario, "burnP3Plus_OutputFirePerimeter", returnInvisible = T, optional = T)

## Handle empty values ----
validateAndParseData$DeterminsiticIgnitions()
validateAndParseData$DeterminsiticBurnConditions()
validateAndParseData$OutputOptions()
validateAndParseData$FBPOutputOptions()

## Setup files and folders ----

generateSharedTempFilePaths("summary")

fbpIndividualDir <- generateTempSubDir("fbpIndividual")
allPerimDir      <- generateTempSubDir("allPerim")
burnMapDir       <- generateTempSubDir("burnMap")

# Generate filename prefixes for potential outputs
burnCountFilePrefix               <- file.path(gridOutputFolder, "burnCount")
burnProbabilityFilePrefix         <- file.path(gridOutputFolder, "burnProbability")
relativeBurnProbabilityFilePrefix <- file.path(gridOutputFolder, "relativeBurnProbability")
fbpSummaryFilePrefix              <- file.path(gridOutputFolder, "fbpSummary")

## Function definitions ----

### Update functions ----
# Function to reassign Iterations and FireIDs from resampling
updateResampledFireIDs <- function(data, firesToReplace) {
  data %>%
    left_join(firesToReplace) %>%
    mutate(
      Iteration = coalesce(NewIteration, Iteration),
      FireID    = coalesce(NewFireID, FireID)) %>%
    dplyr::select(-NewIteration, -NewFireID) %>%
    arrange(Iteration, FireID) %>%
    return()
}

# Function to reassign Iterations and FireIDs from resampling
# - Also is responsible for repartitioning the raw tabular parquet file spatially for memory-safe analysis
updateResampledFireIDsParquet <- function(input_parquet_path, firesToReplace, firesToSummarize, output_parquet_path) {
  if (!is.character(input_parquet_path) | !all(file.exists(input_parquet_path)))
    stop("Received incorrect data type while trying to reassign extra fires in raw tabular output from resampling.")

  batches <- split(input_parquet_path, ceiling(seq_along(input_parquet_path) / 50L))
  temp_dirs <- file.path(
    dirname(output_parquet_path),
    paste0(".tmp_", basename(output_parquet_path), "_", seq_along(batches)))
  on.exit(unlink(temp_dirs, recursive = TRUE), add = TRUE)

  # Phase 1: process each batch of 50 input files and write to a dedicated temp directory.
  # Capping open_dataset() at 50 files per call stays below Linux's default FD limit of 1024.
  for (batch_idx in seq_along(batches)) {
    batches[[batch_idx]] %>%
      open_dataset() %>%
      left_join(firesToReplace) %>%
      mutate(
          Iteration = coalesce(NewIteration, Iteration),
          FireID    = coalesce(NewFireID, FireID)) %>%
      dplyr::select(-NewIteration, -NewFireID) %>%
      inner_join(firesToSummarize) %>%
      dplyr::filter(!is.na(CellID)) %>%
      mutate(
        BatchID = as.integer((Iteration - 1) %/% iterations_per_batch),
        TileID  = as.integer((CellID - 1) %/% cells_per_tile),
        CellID  = as.integer(CellID)) %>%
      write_dataset(
        path = temp_dirs[[batch_idx]],
        format = "parquet",
        partitioning = c("TileID", "BatchID"),
        max_open_files = 100L,
        existing_data_behavior = "overwrite")
    gc()
  }

  # Phase 2: consolidate into exactly one parquet file per TileID/BatchID partition.
  # Iterates over each partition directory, opening at most N_batches (~21) files per call.
  # One file per partition is required by savePartitionedParquetToSyncroSim: it renames every
  # file in a partition directory to the same target name, so multiple files cause silent data
  # loss through overwriting.
  if (dir.exists(output_parquet_path)) unlink(output_parquet_path, recursive = TRUE)

  all_partition_dirs <- temp_dirs %>%
    map(~ list.files(.x, pattern = "\\.parquet$", recursive = TRUE, full.names = FALSE)) %>%
    unlist() %>%
    dirname() %>%
    unique()

  for (part_dir in all_partition_dirs) {
    batch_files <- temp_dirs %>%
      map(~ {
        pdir <- file.path(.x, part_dir)
        if (dir.exists(pdir)) list.files(pdir, pattern = "\\.parquet$", full.names = TRUE)
        else character(0)
      }) %>%
      unlist()

    if (length(batch_files) == 0) next

    out_dir <- file.path(output_parquet_path, part_dir)
    dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

    open_dataset(batch_files) %>%
      collect() %>%
      write_parquet(file.path(out_dir, "part-0.parquet"))
    gc()
  }
}

# Function to quickly identify unique parition IDs by name
# - Assumes values are integers
getPartitionLevels <- function(dataset_path, key) {
  list.files(dataset_path, full.names = T, recursive = T) %>%
    str_extract(str_c(key, "=", "\\d+")) %>%
    str_extract("\\d+") %>%
    as.integer() %>%
    unique %>%
    sort()
}

### Summary functions ----

# Taken from Brett's helper package
# - Consider importing package instead
mean_bp_classification <- function(input, output_filename){
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
    terra::mask(input)
  
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

# Function to convert and write a tabular spatial dataset to tif
# - Expects a CellID and Value column to decide what values (Value) to write where (CellID)
# - A raster template is also required to define resolution, crs, etc
# - CellIDs are 1-indexed, row-major as is the default for R matrices. This is not the default in Python and most other languages!
writeTabularToSpatial <- function(tabularInput, outputFileName, template, datatype = "FLT4S") {
  # Corece into spatial
  spatialOutput <- rast(template)
  names(spatialOutput) <- outputFileName %>% basename %>% tools::file_path_sans_ext()
  tabularInput <- tabularInput %>% filter(!is.na(CellID))
  spatialOutput[tabularInput$CellID] <- tabularInput$Value

  # Save to disk
  spatialOutput %>%
    terra::writeRaster(
      filename = outputFileName,
      overwrite = T,
      filetype = "GTiff",
      datatype = datatype,
      gdal = c("COMPRESS=LZW",
               "TFW=YES"),
      NAflag = -9999)

  # Increment progress bar if present
  progressBar()
  gc()
}

# Function to apply a summary funciton to tabular FBP data and write to a tif file
# - Note that FBP summaries are calculated per fire. Iteration membership is not considered in any way, unlike for burn map summaries
summarizeFBPFromTabular <- function(data, data_path, component, statistic, statisticDisplayName, outputFilePrefix, tempfilePath, template) {
  # Generate file name from the FBP componenet name and summary statistic
  outputFileName <- str_c(outputFilePrefix, "-", component, "-", statistic, ".tif")

  # Get vectory of unique tile IDs
  tileIDs <- getPartitionLevels(data_path, key = "TileID")

  # Prep for subtiling if necessary
  subtileTempfilePath <- str_c(tempfilePath, "-subtiles")

  # Reset temp file path
  unlink(tempfilePath, recursive = T)

  # TODO: maybe iterate over batches of iterations too?
  for(tileID in tileIDs) {
    # Build a query for just the cells in this tile
    query <- data %>%
      filter(TileID == tileID) %>%
      group_by(TileID, CellID)

    # Add the summary to the query
    if(statistic == "Average") {
      query <- query %>%
        summarize(Value = mean(Value, na.rm = T))
    } else if(statistic == "Minimum") {
      query <- query %>%
        summarize(Value = min(Value, na.rm = T))
    } else if(statistic == "Maximum") {
      query <- query %>%
        summarize(Value = max(Value, na.rm = T))
    } else if(statistic == "Median") {
      # Clear out past subtile temp path
      unlink(subtileTempfilePath, recursive = T)

      # Add subtile index
      
      query <- query %>%
        mutate(SubtileID = as.integer(((CellID) - (TileID * cells_per_tile) - 1) %/% cells_per_subtile))
      
      # Iterate over subtiles calculating summary
      for (subtileID in (seq(subtiles_per_tile) - 1)) {
        query %>%
          dplyr::filter(SubtileID == subtileID) %>%
          group_by(TileID, SubtileID, CellID) %>%
          summarize(Value = median(Value, na.rm = T)) %>%
          write_dataset(
            path = subtileTempfilePath,
            format = "parquet",
            existing_data_behavior = "delete_matching")
      }

      # Update query to point to subtile summaries, grouped by Tile ID
      # - This will be reset for each tile after writing out a tile
      query <- open_dataset(subtileTempfilePath, partitioning = c("TileID", "SubtileID")) %>%
        select(-SubtileID) %>%
        group_by(TileID)
    } else if (str_detect(statistic, "Percentile")) {
      # Clear out past subtile temp path
      unlink(subtileTempfilePath, recursive = T)

      # Identify quantile to calculate
      quantile_prob <- head(componentOutputOptions[[statistic]] / 100, 1)

      # Add subtile index
      query <- query %>%
        mutate(SubtileID = as.integer(((CellID) - (TileID * cells_per_tile) - 1) %/% cells_per_subtile))
      
      # Iterate over subtiles calculating summary
      for (subtileID in (seq(subtiles_per_tile) - 1)) {
        query %>%
          filter(SubtileID == subtileID) %>%
          group_by(TileID, SubtileID, CellID) %>%
        summarize(Value = quantile(Value, probs = quantile_prob, na.rm = T)) %>%
          write_dataset(
            path = subtileTempfilePath,
            format = "parquet",
            existing_data_behavior = "delete_matching")
      }

      # Update query to point to subtile summaries, grouped by Tile ID
      # - This will be reset for each tile after writing out a tile
      query <- open_dataset(subtileTempfilePath, partitioning = c("TileID", "SubtileID")) %>%
        select(-SubtileID) %>%
        group_by(TileID)
    } else {
      updateRunLog("Skipping unknown summary statistic \"", statistic, "\"", type = "warning")
      return(tibble())
    }
    
    # Evaluate the query and write the summarized tile
    query %>%
      write_dataset(
        path = tempfilePath,
        format = "parquet",
        existing_data_behavior = "delete_matching")
    
    # Increment progress bar if present
    progressBar()
  }

  # Write values to spatial
  writeTabularToSpatial(
    tabularInput = open_dataset(tempfilePath) %>% collect(),
    outputFileName = outputFileName,
    template = template,
    datatype = "FLT4S")

  # Reset temp file paths
  unlink(tempfilePath, recursive = T)
  unlink(subtileTempfilePath, recursive = T)

  # Return records of where the files are for import into SyncroSim
  return(
    tibble(
      Summary = statisticDisplayName,
      Iteration = 0,
      Timestep = 0,
      FileName = outputFileName))
}

# Function to generate clean file names that include the season
# - season IDs are used since season names might include invalid characters for file names
generateSeasonalOutputFileName <- function(season, outputFilePrefix) {
  str_c(
    outputFilePrefix,
    "-sn",
    lookup(season, SeasonTable$Name, SeasonTable$SeasonId), ".tif")
}

# Backend for generating maps for a single fire from tabular data
generatePerFireMap <- function(iteration, fireid, data, outputFilePrefix, template) {
  # Generate file name based on iteration and fire id
  outputFileName <- str_c(outputFilePrefix, "it", iteration, "-fid", fireid, ".tif")

  # Filter and select data as needed
  tabularData <- data %>%
    dplyr::filter(
      Iteration == iteration,
      FireID == fireid) %>%
    dplyr::select(CellID, Value) %>%
    collect()

  # Write values to spatial
  writeTabularToSpatial(
    tabularInput = tabularData,
    outputFileName = outputFileName,
    template = template)
  
  # Return file name and location
  return(
    tibble(
      Iteration = iteration,
      Timestep = fireid,
      FireID = fireid,
      FileName = outputFileName))
}

# Wrapper for `generatePerFireMap` for generating the AllPerim maps
generatePerFireBurnMap <- function(Iteration, FireID, Season, data, outputFilePrefix, template) {
  tabularData <- data %>%
    mutate(Value = 1)
  
  return(
    generatePerFireMap(
      iteration = Iteration,
      fireid = FireID,
      data = tabularData,
      outputFilePrefix = str_c(outputFilePrefix, "/"),
      template = template))
}

# Wrapper for `generatePerFireMap` for generating per-fire FBP maps
generatePerFireFBPMap <- function(Iteration, FireID, Season, data, outputFilePrefix, template) {
  return(
    generatePerFireMap(
      iteration = Iteration,
      fireid = FireID,
      data = data,
      outputFilePrefix = outputFilePrefix,
      template = template))
}

# Function to generate a single per-iteration burn maps from tabular data
generateBurnMap <- function(iteration, data, season, outputFilePrefix, template) {
  # Generate file name based on iteration and season
  outputFileName <- generateSeasonalOutputFileName(season, str_c(outputFilePrefix, "/it", iteration))

  # Filter data and add a value column for writing to spatial
  burnMapData <- data %>%
    dplyr::filter(Iteration == iteration) %>%
    mutate(Value = 1) %>%
    collect()

  # Output file to disk
  writeTabularToSpatial(
    tabularInput = burnMapData,
    outputFileName = outputFileName,
    template = template,
    datatype = "INT2S")
  
  # Return a table row for import back to SyncroSim
  return(
    tibble(
      Iteration = iteration,
      Timestep = 0,
      Season = season,
      FileName = outputFileName))
}

# Wrapper around `generateBurnMap` to generate all per-iteration burn maps for a single season 
generateBurnMaps <- function(season, data, outputFilePrefix, template) {
  summarizedTabular <- data %>%
    # Filter by season if not "All"
    filter(Season == season | season == "All") %>%
    # Group by cell data and iteration
    group_by(Iteration, CellID) %>%
    # Use summarize to drop multiple burns of the same cell within an iteration
    summarize()
  
  # Safer implementation of seq to handle case where no burn maps should be produced
  iterations <- rlang::seq2(1, MaximumIteration)
  
  # Generate a map per iteration and record where the files were written
  OutputBurnMap <- map_dfr(
    iterations, 
    generateBurnMap,
    data = summarizedTabular,
    season = season,
    outputFilePrefix = outputFilePrefix,
    template = template)

  # Return table specifying where outputs written for import into SyncroSim
  return(OutputBurnMap)
}

# Function to generate burn count maps from tabular data
# - These maps are used in turn to produce burn probability and relative burn probability maps
# - Data is also filtered by season, but the "All" season is also accepted to not filter the data
summarizeBurnCountFromTabular <- function(season, data, data_path, outputFilePrefix, tempfilePath, template) {
  # Generate output file name
  outputFileName <- generateSeasonalOutputFileName(season, outputFilePrefix)

  batchedTempfilePath <- str_c(tempfilePath, "-batched")

  # Get vectory of unique tile and batch IDs
  tileIDs <- getPartitionLevels(rawTablePath, key = "TileID")
  batchIDs <- getPartitionLevels(rawTablePath, key = "BatchID")

  # Reset temp file path
  unlink(tempfilePath, recursive = T)
  unlink(batchedTempfilePath, recursive = T)

  # Add progress bar with steps per tile plus one for writing to tif
  progressBar("begin", totalSteps = 2 * length(tileIDs) + 1)
  progressBar(type = "message", message = str_c("Summarizing raw burn data for season: ", season))

  # Calculate burn count for each tile and batch
  for(tileID in tileIDs) {
    for(batchID in batchIDs) {
      # Calculate burn count for this tile and batch, save to a unique partition of temp parquet file
      data %>%
        dplyr::filter(TileID == tileID, BatchID == batchID) %>%
        dplyr::filter(Season == season | season == "All") %>%
        group_by(TileID, BatchID, CellID) %>%
        summarize(Value = n_distinct(Iteration)) %>%
        write_dataset(
          path = batchedTempfilePath,
          format = "parquet",
          existing_data_behavior = "delete_matching")
    
      progressBar()
    }
  }

  # Combine burn count summaries from all batches
  # - This works since no iterations are shared across batches
  # - Although slower, helps limit memory use for runs with very large counts of iterations
  temp_parquet <- open_dataset(batchedTempfilePath, partitioning = c("TileID", "BatchID"))
  for(tileID in tileIDs) {
    # Calculate burn count for this tile, save to a unique partition of temp parquet file
    temp_parquet %>%
      dplyr::filter(TileID == tileID) %>%
      group_by(TileID, CellID) %>%
      summarize(Value = sum(Value)) %>%
      write_dataset(
        path = tempfilePath,
        format = "parquet",
        existing_data_behavior = "delete_matching")
   
    progressBar()
  }

  # Write burn count map for this season to spatial
  writeTabularToSpatial(
    tabularInput = open_dataset(tempfilePath) %>% collect(),
    outputFileName = outputFileName,
    template = template,
    datatype = "INT2S")
  
  rm(temp_parquet)
  unlink(tempfilePath, recursive = T)
  unlink(batchedTempfilePath, recursive = T)

  return(outputFileName)
}

# Function to calculate burn probability using the corresponding burn count map
summarizeBurnProbability <- function(season, burnCountFileName, outputFilePrefix) {
  # Generate output file name
  outputFileName <- generateSeasonalOutputFileName(season, outputFilePrefix)

  # Calculate burn probability and write to file
  burnCountFileName %>%
    rast() %>%
    `/`(as.double(max(MaximumIteration - length(incompleteIterations), 1))) %>%
    terra::writeRaster(
      filename = outputFileName,
      overwrite = T,
      filetype = "GTiff",
      datatype = "FLT4S",
      gdal = c("COMPRESS=LZW",
               "TFW=YES"),
      NAflag = -9999)

  # Increment progress bar if present
  progressBar()

  return(outputFileName)
}

# Function to calculate relative burn probability using the corresponding burn probability map
# - Essentially a wrapper around `mean_bp_classification`
summarizeRelativeBurnProbability <- function(season, burnProbabilityFileName, outputFilePrefix) {
  # Generate output file name
  outputFileName <- generateSeasonalOutputFileName(season, outputFilePrefix)

  # Calculate relative burn probability and write to file
  burnProbabilityFileName %>%
    rast() %>%
    mean_bp_classification(output_filename = outputFileName)

  # Increment progress bar if present
  progressBar()

  return(outputFileName)
}

# Extract relevant parameters ----

# Identify total number of iterations
# - Note that run control might be out of date after a merge
MaximumIteration <- OutputFireStatistic %>%
  pull(Iteration) %>%
  max

# Load a spatial template to determine a tiling schema
# - also set the background to 0 where the fuels map is defined
templateRaster <- rast(datasheet(myScenario, "burnP3Plus_LandscapeRasters")[["FuelGridFileName"]]) %>%
  classify(matrix(c(-Inf, Inf, 0), nrow = 1))

updateRunLog("Finished preparing inputs in ", updateBreakpoint())

# Reassign extra fires if needed ----
# - Requires a minimum fire size greater than zero and sampled extra fires

# Default values for fires to include / replace if resampling doesn't wind up being needed
incompleteIterations <- integer(0)
firesToReplace <- data.table(
  Iteration = integer(0),
  FireID = integer(0),
  NewIteration = integer(0),
  NewFireID = integer(0))
firesToSummarize <- OutputFireStatistic %>%
  dplyr::filter(Iteration > 0) %>%
  select(Iteration, FireID, Season) %>%
  mutate(across(-Season, as.integer)) %>%
  as.data.table()

# Identify how many fires are missing for each iteration
missingFiresByIteration <- OutputFireStatistic %>%
  # Extra ignitions need not be above minimum fire size
  filter(Iteration > 0) %>%
  # Some iterations (especially after a merge) might already have been resampled 
  # - further resampling is only required if there are more discarded fires than reassigned
  group_by(Iteration) %>%
  summarize(
    requiredFires = sum(str_detect(ResampleStatus, "Discarded")) - sum(str_detect(ResampleStatus, "Reassigned")))
    
# Decide if any resampling is required
requiresResample <- missingFiresByIteration %>%
  mutate(requiresResample = requiredFires > 0) %>%
  pull(requiresResample) %>%
  any
  
# Identify the proportion of fires above the Minimum Fire Size for reporting
proportionKept <- sum(OutputFireStatistic$ResampleStatus != "Discarded") / nrow(OutputFireStatistic)

if(requiresResample) {
  progressBar(type = "message", message = "Resampling fires...")

  # Identify fires available for reassignement
  validExtraFires <- OutputFireStatistic %>%
    filter(ResampleStatus == "Extra" | ResampleStatus == "Not Used") %>%
    transmute(
      Iteration = Iteration,
      FireID = FireID,
      UniqueID = row_number())
  
  # Identify new fire IDs required to replace discarded fires
  requiredFires <- missingFiresByIteration %>%
    filter(requiredFires > 0) %>%
    # Join table of missing fires to Output Fire Statistic to calculate new Fire IDs
    left_join(OutputFireStatistic) %>%
    dplyr::reframe(
      NewFireID = seq(requiredFires[1]) + max(FireID),
      .by = "Iteration") %>%
    rename(NewIteration = Iteration) %>%
    mutate(UniqueID = row_number())

  # Sequentially re-assign extra fires to new required IDs 
  firesToReplace <- inner_join(validExtraFires, requiredFires, by = "UniqueID", relationship = "one-to-one") %>%
    dplyr::select(-UniqueID) %>%
    mutate(across(everything(), as.integer)) %>%
    as.data.table()

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
        (ResampleStatus == "Extra" | ResampleStatus == "Not Used") & Iteration != 0  ~ "Reassigned",
        TRUE ~ ResampleStatus))

  saveDatasheet(
    myScenario,
    OutputFireStatistic,
    "burnP3Plus_OutputFireStatistic",
    append = FALSE)

  # Update fires to include in summaries accordingly
  firesToSummarize <- OutputFireStatistic %>%
    dplyr::filter(
      ResampleStatus %in% c("Kept", "Reassigned"), # Discards unused extra fires and fire below minimum fire size
      !Iteration %in% incompleteIterations) %>%    # Discards fires from incomplete iterations
    select(Iteration, FireID, Season) %>%
    mutate(across(-Season, as.integer)) %>%
    as.data.table()

  # Report iterations that did not meet ignition targets
  if(length(incompleteIterations) > 0) {
    numMissingFires <- nrow(requiredFires) - nrow(validExtraFires)
    updateRunLog("Could not sample enough fires above the specified minimum fire size for ", length(incompleteIterations), " iterations.",
                 "\nPlease see the Fire Statistics table for details on specific iterations, fires, and burn conditions. Incomplete iterations will not be included in summary burn maps.\n",
                 "\nGiven the proportion of all fires burned above the minimum fire size, sampling an addditional ", ceiling(numMissingFires / proportionKept * 1.1), " extra fires is expected to produce enough fires to complete these iterations (with a 10% safety factor).",
                 "\nPlease adjust your safety factor as desired, sample these extra fires, merge the outputs with these burn outputs, and run the summarize transformer again to complete these iterations.\n", type = "warning") 
  }

  if(nrow(firesToReplace) > 0) {
    ## Update Deterministic Input tables ----
    DeterministicIgnitionLocation <- updateResampledFireIDs(DeterministicIgnitionLocation, firesToReplace)
    saveDatasheet(myScenario, DeterministicIgnitionLocation, "burnP3Plus_DeterministicIgnitionLocation", append = F)

    DeterministicBurnCondition <- updateResampledFireIDs(DeterministicBurnCondition, firesToReplace)
    saveDatasheet(myScenario, DeterministicBurnCondition, "burnP3Plus_DeterministicBurnCondition", append = F)
  }
}

# Report burn stats ----
updateRunLog("\nBurn Summary:\n", 
               nrow(OutputFireStatistic), " fires burned. \n",
               sum(OutputFireStatistic$ResampleStatus == "Discarded"), " fires discarded due to being below the specified Minimum Fire Size.\n",
               round(proportionKept * 100, 0), "% of all simulated fires were above the minimum fire size.\n",
               round(sum(OutputFireStatistic$ResampleStatus == "Not Used") / max(1, nrow(OutputFireStatistic %>% filter(Iteration == 0))) * 100, 0), "% of extra simulated fires not used because target ignition counts were already met.\n")

updateRunLog("Finished summarizing burn status and resampling fires in ", updateBreakpoint())

# Vector outputs ----
# Consolidate fire perimeter geopackages if necessary
if (saveBurnPerimeters & !isDatasheetEmpty(OutputFirePerimeter)) {
  progressBar(type = "message", message = "Consolidating vector outputs...")

  # Append geopackages one by one to new geopackage path
  # - also reassign fire ids and iterations if extra fires were resampled
  for (f in OutputFirePerimeter$FileName) {
    # There are situations where both daily and final perimeters could exist in the same package. Handle those cases here.
    layer_names <- st_layers(f)$name

    for(layer in layer_names) {
      st_read(f, layer = layer, quiet = T) %>%
        {if(nrow(firesToReplace) > 0) updateResampledFireIDs(., firesToReplace) else .} %>%
        st_write(
          dsn = geopackage_path,
          layer = layer,
          quiet = TRUE,
          append = TRUE)
    }
  }

  OutputFirePerimeter <-
    tibble(
      FileName = geopackage_path %>% normalizePath(mustWork = F),
      Description = getPerimeterType(geopackage_path)) %>%
    as.data.frame()

  saveDatasheet(myScenario, OutputFirePerimeter, "burnP3Plus_OutputFirePerimeter", append = FALSE)

  updateRunLog("Finished processing vector outputs in ", updateBreakpoint())
}

rm(OutputFireStatistic, DeterministicIgnitionLocation, DeterministicBurnCondition)
gc()

# Raster outputs ----

if (saveBurnMaps | saveFBPMaps | requiresResample) {
  # Set up parameters for tiling / subtiling
  iterations_per_batch <- 5000L
  tile_size <- 256L
  cells_per_tile <- as.integer(ncol(templateRaster) * tile_size)
  cells_per_subtile <- 250000L
  subtiles_per_tile <- as.integer(ceiling(cells_per_tile / cells_per_subtile))

  ## Repartition output raw tabular for memory-safe spatial analysis
  # - Resample and filter too if required
  updateResampledFireIDsParquet(
    input_parquet_path = OutputRawTabular$FileName,
    firesToReplace = firesToReplace,
    firesToSummarize = firesToSummarize,
    output_parquet_path = rawTablePath)
  savePartitionedParquetToSyncroSim(rawTablePath)

  # Identify which seasons to generate outputs for
  if (saveSeasonalBurnMaps) {
    seasonValues <- SeasonTable %>%
      pull(Name) %>%
      unique
  } else {
     seasonValues <- "All"
  }

  # Load data by reference
  tabularBurnData <- arrow::open_dataset(
    sources = rawTablePath,
    partitioning = c("TileID", "BatchID"))
}

## Generate burn maps per fire ----
if (OutputOptionsSpatial$AllPerim) {
  progressBar("begin", totalSteps = nrow(firesToSummarize))
  progressBar(type = "message", message = "Writing per-fire burn maps...")

  # Write outputs per iteration to file and get a table of the file paths
  OutputAllPerim <- pmap_dfr(
    firesToSummarize,
    generatePerFireBurnMap,
    data = tabularBurnData,
    outputFilePrefix = allPerimDir,
    template = templateRaster)

  # Save to SyncroSim
  if (!isDatasheetEmpty(OutputAllPerim))
    saveDatasheet(
      myScenario,
      OutputAllPerim,
      "burnP3Plus_OutputAllPerim",
      append = F)

  updateRunLog("Finished writing per-fire burn maps in ", updateBreakpoint())
  progressBar("end")
}

## Generate burn maps per iteration ----
if(OutputOptionsSpatial$BurnMap | OutputOptionsSpatial$SeasonalBurnMap) {
  # Only save seasonal summaries if requested
  # - Note that this behaviours is different for other summaries where fewer outputs are created for large runs. See below for details
  seasonsToRun <- seasonValues
  if (!OutputOptionsSpatial$SeasonalBurnMap)
    seasonsToRun <- "All"

  progressBar("begin", totalSteps = MaximumIteration * length(seasonsToRun))
  progressBar(type = "message", message = "Writing per-iteration burn maps...")
  
  # Write outputs per iteration to file and get a table of the file paths
  OutputBurnMap <- map_dfr(
    seasonsToRun,
    generateBurnMaps,
    data = tabularBurnData,
    outputFilePrefix = burnMapDir,
    template = templateRaster)

  # Save to SyncroSim
  if (!isDatasheetEmpty(OutputBurnMap))
    saveDatasheet(
      myScenario,
      OutputBurnMap,
      "burnP3Plus_OutputBurnMap",
      append = F)

  updateRunLog("Finished writing per-iteration burn maps in ", updateBreakpoint())
  progressBar("end")
}

## Generate burn summaries ----
if (saveBurnMaps) {
  # Generate burn counts for every season that is required
  burnCountFileNames <- map_chr(
    seasonValues,
    summarizeBurnCountFromTabular,
    data = tabularBurnData,
    data_path = rawTablePath,
    outputFilePrefix = burnCountFilePrefix,
    tempfilePath = rawTableTempPath,
    template = templateRaster)
  gc()

  progressBar("begin", totalSteps = summaryBurnMapCount * length(seasonValues))
  progressBar(type = "message", message = "Building burn summary maps...")

  # Save back to SyncroSim if requested
  if(OutputOptionsSpatial$BurnCount | OutputOptionsSpatial$SeasonalBurnCount)
    saveDatasheet(
      myScenario,
      tibble(
        Iteration = 0,
        Timestep = 0,
        FileName = burnCountFileNames %>% normalizePath(),
        Season = seasonValues) %>%
        as.data.frame(),
      "burnP3Plus_OutputBurnCount",
      append = F)

  # Calculate and save burn probability if requested by user
  if(OutputOptionsSpatial$BurnProbability         | OutputOptionsSpatial$SeasonalBurnProbability |
     OutputOptionsSpatial$RelativeBurnProbability | OutputOptionsSpatial$SeasonalRelativeBurnProbability) {
    
    # Generate file names for the burn probability rasters
    burnProbabilityFileNames <- map2_chr(
      .x = seasonValues,
      .y = burnCountFileNames,
      .f = summarizeBurnProbability,
      outputFilePrefix = burnProbabilityFilePrefix)

    # Save back to SyncroSim if requested
    if(OutputOptionsSpatial$BurnProbability | OutputOptionsSpatial$SeasonalBurnProbability)
      saveDatasheet(
        myScenario,
        tibble(
          Iteration = 0,
          Timestep = 0,
          FileName = burnProbabilityFileNames %>% normalizePath(),
          Season = seasonValues) %>%
          as.data.frame(),
        "burnP3Plus_OutputBurnProbability",
        append = F)
    
    if(OutputOptionsSpatial$RelativeBurnProbability | OutputOptionsSpatial$SeasonalRelativeBurnProbability) {

      # Generate file names for the relative burn probability rasters
      relativeBurnProbabilityFileNames <- map2_chr(
        .x = seasonValues,
        .y = burnProbabilityFileNames,
        .f = summarizeRelativeBurnProbability,
        outputFilePrefix = relativeBurnProbabilityFilePrefix)

      saveDatasheet(
        myScenario,
        tibble(
          Iteration = 0,
          Timestep = 0,
          FileName = relativeBurnProbabilityFileNames %>% normalizePath(),
          Season = seasonValues) %>%
          as.data.frame(),
        "burnP3Plus_OutputRelativeBurnProbability",
        append = F)

    }
  }
  # Wrap up SyncroSim progress bar
  progressBar("end")
  updateRunLog("Finished building burn summary maps in ", updateBreakpoint())
}

# Save FBP Summary Maps
if (saveFBPMaps) {
  # Decide which burn components and fires are available and needed ---
  outputComponentsToKeep <- outputComponentsToKeepDisplayName %>%
    lookup(FBPVariableTable$DisplayName, FBPVariableTable$Name)
  
  # Coerce to data.frame before extracting colnames to avoid bug in conda with extracting colnames
  # - Subset the data.table from open_dataset to limit memory use when extracting colnames
  fbpTableColumns <- open_dataset(rawTablePath) %>%
    head(0) %>%
    collect() %>%
    names()
   
  # Prep some information for more informative progress bars
  total_outputs <- OutputOptionFBPSpatial %>%
    dplyr::select(-any_of(c("Variable", "Individual"))) %>% 
    map(as.logical) %>%
    unlist() %>%
    sum(na.rm = T)
  current_output <- 1
  num_tiles <- length(getPartitionLevels(rawTablePath, key = "TileID"))

  progressBar(type = "message", message = "Summarizing FBP Outputs...")

  # Iterate over FBP variables to keep
  for (component in outputComponentsToKeep) {

    # Skip if there are no outputs for the component
    if (!component %in% fbpTableColumns)
      next

    # Load relevant data for the current FBP variable as data.table
    # - Don't collect query now as per-fire maps will need to query further
    fbpTabularData <- arrow::open_dataset(rawTablePath) %>%
      dplyr::select(all_of(c("TileID", "BatchID", "Iteration", "FireID", "CellID", "Value" = component)))
    
    # Pull out the relevant row of the FBP output options table to identify which summaries to keep for this variable
    componentOutputOptions <- OutputOptionFBPSpatial %>%
      dplyr::filter(Variable == lookup(component, FBPVariableTable$Name, FBPVariableTable$DisplayName)) %>%
      as.list()

    # Save individual maps if requested
    if (!is.na(componentOutputOptions$Individual) & componentOutputOptions$Individual) {
      progressBar("begin", totalSteps = nrow(firesToSummarize))
      progressBar(type = "message", message = str_c("Writing per-fire ", lookup(component, FBPVariableTable$Name, FBPVariableTable$DisplayName), " maps..."))

      OutputFBPIndividual <- pmap_dfr(
        firesToSummarize,
        generatePerFireFBPMap,
        data = fbpTabularData,
        outputFilePrefix = str_c(fbpIndividualDir, "/", component, "-"),
        template = templateRaster)

      if (!isDatasheetEmpty(OutputFBPIndividual))
        saveDatasheet(myScenario, OutputFBPIndividual, str_c("burnP3Plus_Output", component, "Map"), append = FALSE)
      rm(OutputFBPIndividual)

      progressBar("end")
    }

    # Iteration and FireID indices are no longer needed
    fbpTabularData <- fbpTabularData %>%
      dplyr::select(-Iteration, -FireID)

    # Initialize a table to hold the generated outputs
    OutputFBPSummary <- data.frame()

    # Iterate over summary statistics
    for (statisticDisplayName in FBPStatisticTable$Name) {
      statistic <- statisticDisplayName %>% str_replace(" ", "") # Percentile1, Percentile2, and Percentile3 all have spaces in their display names, but not in keys

      # Skip if this statistic is not requested for this FBP variable
      if (is.na(componentOutputOptions[statistic]) | !as.logical(componentOutputOptions[[statistic]]))
        next

      # Add progress bar with steps per tile plus one for writing to tif
      progressBar("begin", totalSteps = num_tiles + 1)
      progressBar(type = "message", message = str_c("Calculating FBP Summary ", current_output, " of ", total_outputs, " - ", statisticDisplayName, str_replace_all(component, "([A-Z])"," \\1")))

      # Calculate summary map and write to disk
      OutputFBPSummary <- bind_rows(
        OutputFBPSummary,
        summarizeFBPFromTabular(
          data = fbpTabularData,
          data_path = rawTablePath,
          component = component,
          statistic = statistic,
          statisticDisplayName = statisticDisplayName,
          outputFilePrefix = fbpSummaryFilePrefix,
          tempfilePath = rawTableTempPath,
          template = templateRaster))
      gc()
      
      # Update index of burn summary progress bar messages
      progressBar("end")
      current_output <- current_output + 1
    }

    # Save summary outputs for this FBP variable
    if(!isDatasheetEmpty(OutputFBPSummary))
      saveDatasheet(myScenario, OutputFBPSummary, str_c("burnP3Plus_Output", component, "SummaryMap"), append = FALSE)
  }

  updateRunLog("Finished summarizing and writing FBP outputs in ", updateBreakpoint(), "\n\n")
}
