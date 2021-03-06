#--------------------------------------------------------------------------------------
# CCSRA2D__Grid_Data.R  
#
#   Extracts CCSRA data from 2D prediction grids dervived by Mike Jacox's for 31-yr 
#   reanalysis files (for 1991-2010) and the NRT (2011-2015) .nc files:
#
#    'curl','sst', 'ssh', 'sss', 'ild', 'su', 'sv', 'sustr', 'svstr' 
#
#    Modified by Karin Forney & Elizabeth Becker from the CalCOFI_CCSRA_Grid_Data.R to obtain  
#    CCSRA data for 2D prediction grids (vs. 3D)                 12/19/2016
#
#    Modified by Sam Woodman to redo EAB models with a 3x3km grid. Dec 2018
#    For others to run, will need to change 'user' object, maybe file paths, and 
#    'startgrid' and 'endgrid' object values right above first for() loop.
#    Also may need to run install.packages command (right above library() calls)
#
#--------------------------------------------------------------------------------------
# Clear workspace 
#
rm(list = ls())
source("Funcs_WEAR.R")

# #-------------------------------SET UP FUNCTIONS---------------------------------------
# # Function to check for libararies
# #
# is.installed <- function(x){
#   is.element(x, installed.packages()[,1])
# } 
# #--------------------------------------------------------------------------------------
# #
# # If needed install and load ncdf4 packages
# 
# if (!is.installed("ncdf4")){
#   install.packages("ncdf4")
# }

### Run install.packages() below when running this code for the first time
# install.packages(c("ncdf4", "dplyr", "purrr", "lubridate", "sf"))
library(ncdf4)
library(dplyr)
library(purrr)
library(lubridate)
library(sf)


#-------------------------------END OF FUNCTIONS---------------------------------------
#
# Open .nc file for 2011-2015 CCSRA-NRT data and read in non-changing values
# Notes re NRT predictors:  
#  SST: should be similar between the two datasets.
#  SD(SST): should be the same.
#  Salinity: will be different ? there was not very much data available to use for 
#     the near-real-time assimilation.  (KAF: maybe use Aviso for salinity for post 
#     2010 modeling).
#  SSH and SD(SSH): a calibration factor could be applied to the near-real-time data 
#     to match it to the historical reanalysis dataset (Chris offered to provide a 
#     calibration factor for our use).
#  MLD/ILD:  should be fine since largely based on the temperature signal.
#  PEA:  could be different.
#
# -----------------------------------------------------------------------------


# TODO by user (general): 
#   1) Check file paths
#   2) Update 'nc.pathNRT.post' object
#   3) Update 'grid.dates' object, and 'startgrid' and 'endgrid' as necessary


#------------------------------------------------------------------------------
# Set path for nc files, input grids and output files based on who 
# is running code (change user initials, all CAPS)

## User path descriptions
# grid.path:  Folder with 'gridfile' object ('Grid_Nonrectangle_3km_WEAR.csv') 
#   and 'Grid_CCSRA_na_WEAR.csv'
# nc.path31:  Folder with 31-yr reanalysis nc files
# nc.pathNRT: Folder with NRT nc files
# out.path:   Folder to which to write csv files with extracted data

# Automatically detect computer info and set file paths accordingly
source("User_script_local.R", local = TRUE, echo = FALSE)
if (user == "KAF") {  
  grid.path <- 'C:/KAF/PROJECTS/SERDP-CCmodels/CCE1991-2014/'
  nc.path31 <- 'C:/KAF/PROJECTS/SERDP-CCmodels/CCE1991-2014/wcra31_daily/' 
  nc.pathNRT <- 'C:/KAF/PROJECTS/SERDP-CCmodels/CCE1991-2014/wcnrt_daily/'
  out.path <- 'C:/KAF/PROJECTS/SERDP-CCmodels/CCE1991-2014/CCSRA_pred_grids/'
  
} else if (user == "EAB") {
  nc.path31 <- 'C:/Users/EABECKER/Documents/HabModels_CCE_1991_2014/Grid_data/wcra31_daily/' 
  nc.pathNRT <- 'C:/Users/EABECKER/Documents/HabModels_CCE_1991_2014/Grid_data/wcnrt_daily/'
  grid.path <- 'C:/Users/EABECKER/Documents/HabModels_CCE_2013/Datasets/EAB_CCE/CCE_Grid_Pred_Data/'
  out.path <- 'C:/Users/EABECKER/Documents/HabModels_CCE_1991_2014/Grid_data/CalCOFI/CCSRA_pred_grids/'
  
} else if (user == "SMW") {
  nc.path31 <- '../whale-model-prep_data/CCSRA_nc/' #TODO fix
  nc.pathNRT <- '../whale-model-prep_data/CCSRA_nc/CCSRA_NRT2018-2019_daily_2D_Jacox/'    
  grid.path <- '../whale-model-prep_data/Grid/'
  out.path <- '../whale-model-prep_data/Grid/Grid_CCSRA/'
  
} else {
  stop("Invalid value supplied for 'user' object")
}


# nc.pathNRT.post is the last half of nc file name, aka the part of the file 
#   name with the dates in the nc file. Changes 
# Note: this variable is not used if pre-2011 (aka using reanalysis data)
nc.pathNRT.post <- '_daily_20180801_20190815.nc'
# nc.pathNRT.post <- '_daily_20170420_20180731.nc'
# nc.pathNRT.post <- '_daily_20110102_20170419.nc'



# ---------------------------------------------------------------------------
# Set Predictor variable names, and set up array with cruise dates which grid files 
#  will be extracted from the nc files.
ssh.calib <- 0.154     # calibration to add to ccsNRT to make consistent with ccsra31 
Predictors <- c('sst', 'ssh', 'ild')
# grid.dates <- seq(as.Date("2005-01-01"), as.Date("2017-12-31"), by = 2)
grid.dates <- seq(as.Date("2018-08-01"), as.Date("2019-08-15"), by = 2)
# write.csv(grid.dates, "Grid.dates.csv")  # save dates for reference


# Open grid pixel file and initialize variables
gridfile <- 'Grid_Nonrectangle_3km_WEAR.csv'
grid.pixelfile <- paste0(grid.path, gridfile)
grid.pixels    <- read.csv(grid.pixelfile, header = TRUE)[, c("lat", "lon180")]
names(grid.pixels) <- c('lat', 'lon')

num.pixels     <- nrow(grid.pixels)
gridlon        <- grid.pixels$lon  # For ROMS data, use -longitudes (not 360)
gridlat        <- grid.pixels$lat

# Objects used within for() loops
# Need to change 'grid.rad.half' depending on grid resolution (currently for 3km grid)
# grid.rad.half <- 0.027 / 2 #Not needed for 'ccsra' smartcheck
# nc.file.date <- as.Date("2017-04-20") # Date at which NRT nc files are split


#----------------------------------------------------------
temp <- read.csv(paste0(grid.path, "Grid_CCSRA_na_WEAR.csv"))
ccsra.na.idx <- as.logical(temp$na_flag); rm(temp) #Is TRUE if value is NA


#----------------------------------------------------------
t1 <- Sys.time()
# 30 Nov: 4.81 min for 2 days (2005 Jan 1, 3)
# 21.6 hours for 1401-2000


#----------------------------------------------------------
# Loop through each daily grid file to be created 
# To run in smaller batches, specify start and end of grid date indices, e.g.
#   grid.dates[1100]: "2011-01-08"
#   grid.dates[2250]: "2017-04-26"

startgrid <- 1
endgrid   <- length(grid.dates)

for(g in startgrid:endgrid) {
  ### Get year, month, day details for this grid file
  grid.data <- grid.pixels
  grid.date <- grid.dates[g]
  print(paste(g, grid.date, sep = ": "))
  
  grid.year  <- lubridate::year(grid.date)  #as.numeric(strftime(grid.dates[g],"%Y"))
  grid.month <- lubridate::month(grid.date) #as.numeric(strftime(grid.dates[g],"%m"))
  grid.day   <- lubridate::day(grid.date)   #as.numeric(strftime(grid.dates[g],"%d"))
  grid.ymd <- paste(
    grid.year, sprintf("%02d", grid.month), sprintf("%02d", grid.day), 
    sep = '-'
  )
  
  ### Now get one predictor at a time from the .nc files
  for(p in Predictors) {
    calib.val <- ifelse(p == "ssh" && grid.year >= 2011, ssh.calib, 0)
    
    # Open either ccsra31 or appropriate (pre/post 2017-04-20) NRT nc file
    nc.file <- ifelse(
      grid.year < 2011, 
      paste0(nc.path31, 'wcra31_', p, '_daily_1991_2010.nc'), 
      paste0(nc.pathNRT, 'wcnrt_', p, nc.pathNRT.post)
    )
    stopifnot(file.exists(nc.file))
    
    # Get nc file data
    nc.data <- nc_open(nc.file)
    
    ROMSlat   <- ncvar_get(nc.data, 'lat')[1, ]
    ROMSlon   <- ncvar_get(nc.data, 'lon')[, 1]
    ROMSnrows <- length(ROMSlon)
    ROMSncols <- length(ROMSlat)
    
    ## Find index in the ROMS file for the date of this grid file 
    ROMS.year  <- ncvar_get(nc.data, 'year')
    ROMS.month <- ncvar_get(nc.data, 'month')
    ROMS.day   <- ncvar_get(nc.data, 'day')
    day.index <- which(
      (ROMS.year == grid.year) & (ROMS.month == grid.month) & (ROMS.day == grid.day)
    )
    
    # Check that info for that days exists in the nc file
    if (length(day.index) == 0) {
      warning("No nc file data for ", grid.ymd, " for predictor ", p)
      
      grid.data$temp1 <- NA
      grid.data$temp2 <- NA
      names(grid.data) <- c(
        head(names(grid.data), -2), c(paste0(p, '.mean'), paste0(p, '.SD'))
      )
      
    } else {
      # nc_extract() is in 'Funcs_WEAR.R'
      # Don't need to do smartcheck because 0.1 deg res of CCSRA nc is too big
      # Original for() loop code is at bottom of file
      grid.data <- nc_extract(
        grid.data, nc.data, ROMSlon, ROMSlat, ROMSnrows, ROMSncols,
        day.index, var.name = p, calib = calib.val, sd.radius = 1, 
        smartcheck = TRUE, grid.rad.half = grid.rad.half, 
        na.idx = ccsra.na.idx, s.type.flag = "ccsra"
      )
    }
    
    nc_close(nc.data)
    
  } # p loop (Predictors) 
  
  grid.datafile <- paste0(out.path, 'WEAR_CCSRA_3km_', grid.ymd, '.csv')
  write.table(grid.data, grid.datafile, sep = "," , col.names = TRUE, row.names = FALSE)
  rm(grid.data, grid.datafile)
  
}  # g loop (grids)

Sys.time() - t1


#-------------------------------------------------------------------------------------
# For spot-checking, extract one day's complete SST grid (26 June 2014)
#
# testSST<-ncvar_get(nc.data,p,start=c(1,1,day.index),
#                    count=c(ROMSnrows,ROMSncols,1),verbose=FALSE)
# rownames(testSST) <-ROMSlon
# colnames(testSST) <-ROMSlat
# write.csv(testSST,"SST26Jun2014.csv")

#-------------------------------------------------------------------------------------
