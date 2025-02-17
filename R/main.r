################################################################################
#                 Map rivers with sf and ggplot2 in R
#                 Milos Popovic
#                 2022/03/27

# HACKING to do for Aus rivers ####-------------------------------------------------------

################################################################################
#windowsFonts(georg = windowsFont('Georgia'))

# libraries we need
libs <- c("httr", "tidyverse", "sf")

# install missing libraries
installed_libs <- libs %in% rownames(installed.packages())
if (any(installed_libs == F)) {
  install.packages(libs[!installed_libs])
}

# load libraries
invisible(lapply(libs, library, character.only = T))
library(here)
library(tictoc)

# 1. GET RIVERS DATA
#---------

# get_data <- function(url, res, filenames) {
# 
#   url <- "https://m201.syncusercontent1.com/mfs-60:cb0f370cfc9aad110e47af0c14c6d6a0=============================/p/HydroRIVERS_v10_eu_shp.zip?allowdd=0&datakey=ge8BrffNb5ff90cF/3Dr8CGlfSRTS2g+I3poOJEOpd65Nwv0agBsI6yzqEFKLIDb/9iORBIKcrW+jONfWXU+Dm2WNnWn2KcP3R2WQMtiHUpSXuIg9e3gkGUd+nMSCIDRVvkSLQfFifZAeYjNKnNMSWPKn5mJIC/0RZ3kWGVVfDgZRYHLVgMMtxn+47XRsMbvz2WOE8R8J4n0RB7xVI5tlpmFR8Bv3nZB0HYc43cdyYSW5DqyKGji5CkoYTBNzE/jow5oBri2TOZWNxWVV9ET/9/udwd8KuOH++GoRzpgVJZ5WH1LgW7IBaHnDPTHdYENxRe/4JNlXanhauLfqOMNMQ&engine=ln-1.11.18&errurl=GLK4RA2KpWnRCSNSKOrDC8T6XxhjDIuUGGVvUo/zJAGGma48px5C67R8o6en+Qmegmceb/EJkpCEYm4SRBZDNMs+CgNFjFgEYdN4byFeygcAnvSAclpxktxsJc18rczzZtNuL4oyVr7SxjPeDdyHsveNgnibmLp1UWA45i5K12NRlbfK55BDYGOrwLu2RRJUm4AWUNeYpo4f8yqZ8zxQGUuLcKGx68bKP5I7ri8Lf8nkGsxRvT/axtcNmUiaZ706TofwP6mkzzaDZs+xin46q3P//GOuLornz7vN+q/d89qYsgpm5KsqyqEV+DePj2K6/vMDT4BLYWtxLeY1ESZgyg==&header1=Q29udGVudC1UeXBlOiBhcHBsaWNhdGlvbi96aXA&header2=Q29udGVudC1EaXNwb3NpdGlvbjogYXR0YWNobWVudDsgZmlsZW5hbWU9Ikh5ZHJvUklWRVJTX3YxMF9ldV9zaHAuemlwIjtmaWxlbmFtZSo9VVRGLTgnJ0h5ZHJvUklWRVJTX3YxMF9ldV9zaHAuemlwOw&ipaddress=1398165091&linkcachekey=89159c590&linkoid=51000013&mode=101&sharelink_id=3443504720013&timestamp=1649430246943&uagent=0c3c442ba67c66fa3227e09aeb8c763c79676604&signature=1cdeb688c90dc709eb9e652f6ccaf3beaa64197c&cachekey=60:cb0f370cfc9aad110e47af0c14c6d6a0============================="
#   res <- GET(url,
#              write_disk("eu_rivers.zip"),
#              progress())
#   unzip("eu_rivers.zip") #unzip
#   filenames <- list.files("HydroRIVERS_v10_eu_shp", pattern="*.shp", full.names=T)
# 
#   return(filenames)
# }

# Download manually from https://www.hydrosheds.org/products/hydrorivers HydroRIVERS_v10_eu_shp.zip
# or use wget in terminal for eurpoe
# wget https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_eu_shp.zip
# or for aus
# wget https://data.hydrosheds.org/file/HydroRIVERS/HydroRIVERS_v10_au_shp.zip

get_data <- function(url, res, filenames) {
  # unzip("HydroRIVERS_v10_eu_shp.zip") #unzip, need once only
  # filenames <- list.files("HydroRIVERS_v10_eu_shp", pattern="*.shp", full.names=T)
  #unzip("HydroRIVERS_v10_au_shp.zip") #unzip, need once only
  filenames <- list.files("HydroRIVERS_v10_au_shp", pattern="*.shp", full.names=T)
  return(filenames)
}

tic("get_data")
get_data()
toc()
# 3.5 seconds

# 2. CREATE RIVER WIDTH
#---------

 get_rivers <- function(filenames, list_riv, au_riv) {

  filenames <- get_data()
  list_riv <- lapply(filenames, st_read)
  au_riv <- list_riv[[1]] %>% 
  st_cast("MULTILINESTRING") %>% 
  mutate(width = as.numeric(ORD_FLOW),
         width = case_when(width == 3 ~ 1,
                           width == 4 ~ 0.8,
                           width == 5 ~ 0.6,
                           width == 6 ~ 0.4,
                           width == 7 ~ 0.2,
                           width == 8 ~ 0.2,
                           width == 9 ~ 0.1,
                           width == 10 ~ 0.1,
                           TRUE ~ 0)) %>% 
  st_as_sf()
  
  au_riv$geometry <- au_riv$geometry %>%
  s2::s2_rebuild() %>%
  sf::st_as_sfc()
  
  return(au_riv)

  }

tic("get_rivers")
get_rivers()
toc()
# takes 5 minutes

# 3. MAKE BOUNDING BOX
#---------

get_bounding_box <- function(crsLONGLAT, bbox, new_prj, bb) {

  crsLONGLAT <- "+proj=longlat +datum=WGS84 +no_defs"

  bbox <- st_sfc(
  st_polygon(list(cbind(
    # c(-10.5, 48.5, 48.5, -10.5, -10.5), # x-coordinates (longitudes) of points A,B,C,D        #EU
    # c(35.000, 35.000, 69.5, 69.5, 35.000)     # y-coordinates (latitudes) of points A,B,C,D   #EU
    c(95, 179.999, 179.999, 95, 95), # x-coordinates (longitudes) of points A,B,C,D
    c(-55, -55, 21, 21, -55)     # y-coordinates (latitudes) of points A,B,C,D
    
    
    ))),
  crs = crsLONGLAT)

  new_prj <- st_transform(bbox, crs = 4087)
  bb <- st_bbox(new_prj)

  return(bb)
}

tic("get_bounding_box")
get_bounding_box()
toc()
# ~0 seconds

# 4. MAP
#---------

#map_url <- "https://raw.githubusercontent.com/milos-agathon/map-rivers-with-sf-and-ggplot2-in-R/main/R/make_map.r"
#source(map_url) # load script
source("R/make_map.r")

tic("get_river_map makes the plot")
p1 <- get_river_map()
toc()
# ~5 min

tic("save plot")
#ggsave(filename="european_rivers_new.png", width=7, height=8.5, dpi = 600, device='png', p1)
ggsave(filename="australasian_rivers_new.png", width=7, height=8.5, dpi = 600, device='png', p1)
toc()
# ~2.5 minutes
