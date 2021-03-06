# Use griplots_var to plot SSH and SST for June-July, 2012-2015

###############################################################################
library(dplyr)
library(RColorBrewer)
library(sf)

source('C:/SMW/RAIMBOW/whale-model-prep/GridPlots_vars.R')

###############################################################################
# Plot SSH and SST for June-July, 2012-2015

### Practice
d <- read.csv("../whale-model-prep_data/Grid/Grid_all/WEAR_3km_2005-01-11.csv")
gridplots_vars(
  "../whale-model-prep_data/Grid/Grid_all/WEAR_3km_2005-01-13.csv", 
  plot.folder = NULL, "ild.mean"
)

### Get file names
ym.char <- unlist(lapply(2012:2015, function(i, j) paste0(i, "-0", j), j = 6:7))
files.all <- list.files("../whale-model-prep_data/Grid/Grid_all/", full.names = TRUE)
tmp <- sapply(files.all, function(x) {
  any(sapply(ym.char, function(y) grepl(y, x)))
})
files.curr <- files.all[tmp]


### Get min/max for color break points
library(parallel)
no_cores <- detectCores() - 1
cl <- makeCluster(no_cores)
tmp.all <- parLapply(cl, files.curr, read.csv) #37s
tmp.all.df <- do.call(rbind, tmp.all)
stopCluster(cl)

# tmp.all2 <- lapply(files.curr, read.csv) #80s
# tmp.all2.df <- do.call(rbind, tmp.all2)
# tmp.all.df <- NULL
# for(j in files.curr) tmp.all.df <- rbind(tmp.all.df, read.csv(j)) #160s


### Plot SST
range(tmp.all.df$sst.mean, na.rm = TRUE)
gridplots_vars(
  files.toplot = files.curr, 
  plot.folder = "../whale-model-prep_data/Grid/GridPlots_vars/SST/", 
  var.name = "sst.mean", 
  col.breaks = c(6, 10, 12, 14, 16, 18, 20, 22, 26)
)

### Plot SSH
range(tmp.all.df$ssh.mean, na.rm = TRUE)
gridplots_vars(
  files.toplot = files.curr, 
  plot.folder = "../whale-model-prep_data/Grid/GridPlots_vars/SSH/", 
  var.name = "ssh.mean", 
  col.breaks = c(-0.07, 0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6)
)

### Plot MLD (ILD)
range(tmp.all.df$ild.mean, na.rm = TRUE)
gridplots_vars(
  files.toplot = files.curr, 
  plot.folder = "../whale-model-prep_data/Grid/GridPlots_vars/ILD/", 
  var.name = "ild.mean", 
  col.breaks = c(0, 10, 20, 40, 60, 80, 100, 150, 212)
)
gridplots_vars(
  files.toplot = files.curr, 
  plot.folder = "../whale-model-prep_data/Grid/GridPlots_vars/ILD_v2/", 
  var.name = "ild.mean", 
  col.breaks = c(0, 4, 8, 12, 16, 20, 50, 150, 212)
)

### murSST
range(tmp.all.df$analysed_sst.mean, na.rm = TRUE)
gridplots_vars(
  files.toplot = files.curr, 
  plot.folder = "../whale-model-prep_data/Grid/GridPlots_vars/murSST/", 
  var.name = "analysed_sst.mean", 
  col.breaks = c(7, 10, 12, 14, 16, 18, 20, 22, 24)
)

###############################################################################
