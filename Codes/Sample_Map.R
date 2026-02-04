##------------------------
## LOAD PACKAGES
##------------------------

# List of required packages
packages <- c(
  "svglite",         # for saving svg plots
  "dplyr",
  "sf",
  "ggplot2",
  "igraph",
  "FNN",
  "sfnetworks",
  "geosphere",       # for distance calculations
  "ggspatial",       # optional for basemap or scalebar/compass
  "cowplot",         # for inset plotting
  "viridis",         # colors
  "scico",           # more color palettes
  "rnaturalearth",
  "rnaturalearthdata",
  "patchwork",
  "rstudioapi"      # to set working directory to source file location
)

# Install if missing, then load all
invisible(lapply(packages, function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}))


## Do NOT CHANGE -- R SCRIPT IS SAVED WITH THE SAME FOLDER AS THE MASTER DO FILE
if (requireNamespace("rstudioapi", quietly = TRUE) && rstudioapi::isAvailable()) {
  setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
} else {
  args <- commandArgs(trailingOnly = FALSE)
  file_arg <- args[grep("--file=", args)]
  if (length(file_arg) > 0) {
    setwd(dirname(normalizePath(sub("--file=", "", file_arg))))
  }
}

##------------------------
## INPUT DATA
##------------------------

##Get the sample coordinates
data <- read.csv("../Output/Feed_into_GEE_Test_Results_with_GPS.csv")

##Get the Dustrict Boundaries
boundary <- st_read(dsn="../Original Data/Spatial/dhsboundaries/shps", layer="sdr_subnational_boundaries") # nolint
wboundary <- boundary[boundary$REGNAME == "Western" | boundary$REGNAME == "Western North"
                      | boundary$REGNAME == "Ashanti" | boundary$REGNAME == "Ahafo" |
                        boundary$REGNAME == "Central" | boundary$REGNAME == "Bono", ]
wboundary_utm <- st_transform(wboundary, crs = 32630)

districts <- st_read(dsn="../Original Data/Spatial/districts_archub", layer="9c121d63-5e62-4264-bb0e-6b7204bb60ee202045-1-3k41f2.tl238")
st_bbox(boundary)
st_bbox(districts)
target_crs <- st_crs(boundary)
districts <- st_transform(districts, crs = target_crs)
st_bbox(districts)

all_dist <- districts[districts$DISTRICT == "SEFWI-WIAWSO" |
                        districts$DISTRICT ==  "BIBIANI-ANHWIASO-BEKWAI MUNICIPAL" |
                        districts$DISTRICT ==  "SEFWI AKONTOMBRA" |
                        districts$DISTRICT ==  "JUABOSO", ]

# Full African continent (countries)
africa_boundary <- ne_countries(continent = "Africa", returnclass = "sf")
west_africa <- ne_countries(continent = "Africa", returnclass = "sf") %>%
  filter(subregion == "Western Africa")


# Ghana boundary only
ghana_boundary <- ne_countries(country = "Ghana", returnclass = "sf")


##Get the River lines from GEE
rivers <- st_read(dsn = "../Original Data/Spatial/GEE_HydroShed_River",
                  layer = "HydroSHEDS_rivers_buffer")
rivers_utm <- st_transform(rivers, crs = 32630)

# Crop rivers to Ghana extent for clarity
ghana_boundary_proj <- st_transform(ghana_boundary, crs = st_crs(rivers_utm))
rivers_in_ghana <- st_intersection(rivers_utm, st_buffer(ghana_boundary_proj, 50000))  # optional buffer

##------------------------
## FURTHER PROCESSING
##------------------------

## Process the sampling Coordinates
data_clean <- data %>%
  filter(!is.na(GPS_lat), !is.na(GPS_long), !is.na(Mn))

points_sf <- st_as_sf(data_clean, coords = c("GPS_long", "GPS_lat"), crs = 4326)

# Project to UTM or metric CRS for accurate distance in meters
points_sf_utm <- st_transform(points_sf, crs = 32630) # UTM zone appropriate for Ghana

# Replace 0 with the LOD/sqrt(2)
points_sf_utm$Mn_LODsq2 <- points_sf_utm$Mn
points_sf_utm$Mn_LODsq2[points_sf_utm$Batch == 1 & points_sf_utm$Mn == 0] <- 2.953 / sqrt(2)
points_sf_utm$Mn_LODsq2[points_sf_utm$Batch == 2 & points_sf_utm$Mn == 0] <- 3.282 / sqrt(2)
points_sf_utm$log_Mn_LODsq2 <- log(points_sf_utm$Mn_LODsq2)

# Create sample type category
points_sf_utm$sample_type <- case_when(
  points_sf_utm$river_sample_yn == 1 ~ "River",
  points_sf_utm$school_sample_yn == 1 ~ "School",
  points_sf_utm$hh_sample_yn == 1 ~ "Household",
  points_sf_utm$vendor_sachet_yn == 1 ~ "Vendor",
)
points_sf_utm$sample_type <- factor(points_sf_utm$sample_type,
                                     levels = c("Household", "School", "River", "Vendor"))

# Create grid over the expanded bbox (10 km buffer)
grid <- st_make_grid(points_sf_utm, cellsize = 5000, square = FALSE)  # 1km x 2km cells (to match the IQR&Median Resolution)
grid_sf <- st_sf(grid_id = 1:length(grid), geometry = grid)
joined <- st_join(points_sf_utm, grid_sf)
# Compute median Mn MEDIAN and IQR per grid cell
grid_summary_values <- joined %>%
  st_drop_geometry() %>%
  group_by(grid_id) %>%
  summarise(
    Mn_median = median(Mn_LODsq2, na.rm = TRUE),
    Mn_IQR = IQR(Mn_LODsq2, na.rm = TRUE)
  )
grid_summary <- left_join(grid_sf, grid_summary_values, by = "grid_id")
grid_summary$Mn_median_log <- log(grid_summary$Mn_median)
grid_summary$Mn_IQR_log <- log(grid_summary$Mn_IQR)



##------------------------
## MAKE THE MAP
##------------------------
# Create study area box (expand bbox by 50km instead of st_buffer to keep sharp corners)
study_bbox <- st_bbox(points_sf_utm)
study_bbox_expanded <- study_bbox
study_bbox_expanded["xmin"] <- study_bbox["xmin"] - 50000
study_bbox_expanded["xmax"] <- study_bbox["xmax"] + 50000
study_bbox_expanded["ymin"] <- study_bbox["ymin"] - 50000
study_bbox_expanded["ymax"] <- study_bbox["ymax"] + 50000
study_box_expanded <- st_as_sfc(study_bbox_expanded, crs = st_crs(points_sf_utm))
study_box_wgs84 <- study_box_expanded %>%
  st_segmentize(dfMaxLength = 1000) %>%  # densify edges to prevent curving after transform
  st_transform(crs = 4326)  # transform to match Africa map


# Expand the bounding box by 5 km (5,000 meters) in each direction
bbox_pts <- st_bbox(points_sf_utm)
bbox_expanded <- bbox_pts
bbox_expanded["xmin"] <- bbox_pts["xmin"] - 5000 #<- Within 5km box *upper lower right left
bbox_expanded["xmax"] <- bbox_pts["xmax"] + 5000
bbox_expanded["ymin"] <- bbox_pts["ymin"] - 5000
bbox_expanded["ymax"] <- bbox_pts["ymax"] + 5000


study_area_WestAfrica <- ggplot() +
  geom_sf(data = west_africa, fill = "grey90", color = "grey70", size = 0.2) +
  geom_sf(data = ghana_boundary, fill = "grey80", color = "grey40", size = 0.3) +  # Show Ghana for context
  geom_sf(data = study_box_wgs84, fill = NA, color = "red", linewidth = 1) +  # Study area box
  labs(title = "") +
  theme_void() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 10, face = "bold")
  )
# print(study_area_WestAfrica)

study_box_proj <- st_transform(study_box_expanded, crs = st_crs(rivers_utm))
rivers_crop <- st_intersection(rivers_utm, study_box_proj)
sample_map <- ggplot() +
  # Rivers
  geom_sf(data = rivers_crop, aes(color = "Rivers"), linewidth = 0.3, alpha = 0.4) +

  # District boundaries
  geom_sf(data = all_dist, aes(color = "District Boundaries"), fill = NA, linewidth = 0.55) +

  # Sample points by type - map both shape and color
  geom_sf(data = points_sf_utm, aes(shape = sample_type, color = sample_type),
          size = 2, alpha = 0.7) +

  # Region boundary
  geom_sf(data = wboundary_utm, color = "black", fill = NA, linewidth = 0.55) +

  # Shape scale for sample types (including Vendor)
  scale_shape_manual(
    name = "Sample Type",
    values = c("Household" = 16, "School" = 17, "River" = 15, "Vendor" = 18),  # 18 = diamond
     guide = "none"
  ) +

 # Combined color scale for everything
  scale_color_manual(
    name = "Legend",
    values = c(
      "Household" = "red", "School" = "darkgreen", "River" = "blue", "Vendor" = "purple",
      "Rivers" = "blue", "District Boundaries" = "black"
    ),
    guide = guide_legend(
      override.aes = list(
        linetype = c(0, 0, 0, 0, 1, 1),
        shape = c(16, 17, 15, 18, NA, NA),
        linewidth = c(NA, NA, NA, NA, 0.5, 0.75)
      )
    )
  ) +

  theme_minimal() +
  theme(
    panel.grid.major = element_blank(),
    panel.background = element_rect(fill = "white"),
    plot.title = element_text(hjust = 0.5, size = 10, face = "bold"),
    legend.position = "right",
    legend.title = element_text(size = 9, face = "bold"),
    legend.text = element_text(size = 8),
    legend.key.height = unit(1.1, "lines"),
    legend.spacing.y = unit(0.6, "lines")
  ) +

  coord_sf(
    xlim = c(study_bbox["xmin"] - 10000, study_bbox["xmax"] + 10000),
    ylim = c(study_bbox["ymin"] - 10000, study_bbox["ymax"] + 10000),
    expand = FALSE
  )

# print(sample_map)


upper_panel <- study_area_WestAfrica + sample_map +
  plot_layout(widths = c(1.5, 3)) +
  plot_annotation(
    title = expression(bold("A.") ~ "Study Area Overview and Sampling Locations in Western North Ghana")
  )



# Plot the Mn concentration using ggplot2 - Individual HH points colored by Mn level
main_map <- ggplot() +
  geom_sf(data = wboundary_utm, fill = "grey90", color = "black", size = 0.6) +
  geom_sf(data = all_dist, fill = NA, color = "black", size = 0.6) +
  # Individual points colored by Mn concentration with transparency for overlap
  geom_sf(data = points_sf_utm, aes(fill = Mn_LODsq2),
          shape = 21, color = "white", size = 4, alpha = 0.57, stroke = 0.3) +
  # Blue circle outline for river samples
  geom_sf(data = points_sf_utm[points_sf_utm$sample_type == "River", ],
          shape = 21, fill = NA, color = "blue", size = 4, stroke = 1,  alpha = 0.4) +
  scale_fill_distiller(
    name = expression("Mn(" * mu * "g/L)"),
    palette = "YlOrRd",
    direction = 1,
    trans = "log",
    na.value = "grey50",
    labels = scales::label_number(accuracy = 1)
  ) +
  labs(
    title = expression(bold("B.") ~ "Mn Levels at Sample Points (" * mu * "g/L)"),
    x = "Longitude", y = "Latitude"
  ) +
  theme_minimal() +
  theme(
    legend.position = c(0.01, 0.05),         # x, y (0 = left/bottom, 1 = right/top)
    legend.justification = c(0, 0),         # anchor point for the legend box
    legend.background = element_rect(fill = "white", color = NA),
    legend.box.background = element_rect(color = "black"),
    legend.text = element_text(size = 7),    # smaller legend labels
    legend.title = element_text(size = 8, face = "bold")  # optional: smaller bold title
  ) +
  coord_sf(
    xlim = c(bbox_expanded["xmin"], bbox_expanded["xmax"]), #<- +/- 10km
    ylim = c(bbox_expanded["ymin"], bbox_expanded["ymax"]), #<- +/- 10km
    expand = FALSE
  )
# print(main_map)

upper_panel_wrapped <- wrap_elements(full = upper_panel)
upper_panel_wrapped <- upper_panel_wrapped & theme(plot.margin = margin(0, 0, 0, 0))

design <- "
AAAA
BBB#
"
combined_plot <- upper_panel_wrapped + main_map +
  plot_layout(design = design, heights = c(1, 1))

#  print(combined_plot)
ggsave("../Output/Figures/Mn_IQR_and_Median_Grid_Map_Africa.svg",
       plot = combined_plot,
       width = 8, height = 8)
