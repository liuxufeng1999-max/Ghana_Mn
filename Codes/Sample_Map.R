##------------------------
## LOAD PACKAGES
##------------------------

library(dplyr)
library(sf)
library(ggplot2)
library(igraph)
library(FNN)
library(sfnetworks)
library(geosphere)  # for distance calculations
library(ggspatial)  # optional for basemap or scalebar
library(cowplot)  # for inset plotting
library(ggspatial)  # optional scalebar/compass
library(viridis) #<-- Colors
library(scico) #<-- more color plates
# library(rgee)
library(rnaturalearth)
library(rnaturalearthdata)
library(patchwork)

## Do NOT CHANGE -- R SCRIPT IS SAVED WITH THE SAME FOLDER AS THE MASTER DO FILE 
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

##------------------------
## INPUT DATA
##------------------------

##Get the sample coordinates
data <- read.csv("../Output/Feed_into_GEE_Test_Results_with_GPS.csv")

##Get the Dustrict Boundaries 
boundary <- st_read(dsn="../Original Data/Spatial/dhsboundaries/shps", layer="sdr_subnational_boundaries") 
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

# Compute spatial median Mn in a 2 km radius for each point
median_Mn_1km <- sapply(1:nrow(points_sf_utm), function(i) {
  distances <- st_distance(points_sf_utm[i, ], points_sf_utm)
  nearby <- which(as.numeric(distances) <= 2000)  # within 2 km
  median(points_sf_utm$Mn[nearby], na.rm = TRUE)
})
points_sf_utm$Mn_median_1km <- median_Mn_1km

# Compute spatial IQR Mn in a 2 km radius for each point
iqr_Mn_1km <- sapply(1:nrow(points_sf_utm), function(i) {
  distances <- st_distance(points_sf_utm[i, ], points_sf_utm)
  nearby <- which(as.numeric(distances) <= 2000)  # within 2 km
  IQR(points_sf_utm$Mn[nearby], na.rm = TRUE)
})
points_sf_utm$Mn_IQR_1km <- iqr_Mn_1km

##Next, I want to create a grid-style plot (so a smoothed geo-spatial spread)

# Create grid over the expanded bbox (10 km buffer)
grid <- st_make_grid(points_sf_utm, cellsize = 2000, square = FALSE)  # 2km x 2km cells (to match the IQR&Median Resolution)
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
# Buffer around sample points (e.g. 50km box) for SSA inset
study_bbox <- st_bbox(points_sf_utm)
study_box <- st_as_sfc(st_bbox(study_bbox), crs = st_crs(points_sf_utm))
study_box_expanded <- st_buffer(study_box, dist = 50000)  # 50 km buffer
study_box_wgs84 <- st_transform(study_box_expanded, crs = 4326)  # transform to match Africa map

ghana_in_ssa_map <- ggplot() +
  geom_sf(data = africa_boundary, fill = "grey90", color = "grey70", size = 0.2) +
  # geom_sf(data = ghana_boundary, fill = "lightcoral", color = "grey20", size = 0.3) +
  geom_sf(data = study_box_wgs84, fill = NA, color = "red", size = 1) +  # Highlight study area
  labs(title = "") +
  theme_void() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 10, face = "bold")
  )

study_box_proj <- st_transform(study_box_expanded, crs = st_crs(rivers_utm))
rivers_crop <- st_intersection(rivers_utm, study_box_proj)
sample_map <- ggplot() +
  # Rivers
  geom_sf(data = rivers_crop, aes(color = "Rivers"), size = 0.3, show.legend = "line") +
  
  # Sample points (just red dots)
  geom_sf(data = points_sf_utm, aes(color = "Sample Points"), size = 0.6, alpha = 0.85, show.legend = "point") +
  
  # District boundaries
  geom_sf(data = all_dist, aes(color = "District Boundaries"), fill = NA, size = 0.4, show.legend = "line") +
  
  # Region boundary (shown but not in legend)
  geom_sf(data = wboundary_utm, color = "grey50", fill = NA, size = 0.4) +
  
  labs(title = "Sample Points & Rivers in Western North",
       color = "Features") +  # Unified legend title
  
  # Manual colors for all features under 'color' aesthetic
  scale_color_manual(
    values = c(
      "Sample Points" = "red",
      "Rivers" = "blue",
      "District Boundaries" = "black"
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
    legend.key.height = unit(1.1, "lines"),  # Control spacing between legend rows
    legend.spacing.y = unit(0.6, "lines")
  ) +
  
  coord_sf(
    xlim = c(study_bbox["xmin"], study_bbox["xmax"]),
    ylim = c(study_bbox["ymin"], study_bbox["ymax"]),
    expand = FALSE
  )


upper_panel <- ghana_in_ssa_map + sample_map +
  plot_layout(widths = c(0.8, 1.6))  # Adjust these ratios as needed
print(upper_panel)


# Expand the bounding box by 10 km (10,000 meters) in each direction
bbox_pts <- st_bbox(points_sf_utm)
bbox_expanded <- bbox_pts
bbox_expanded["xmin"] <- bbox_pts["xmin"] - 10000 #<- Within 10km box *upper lower right left
bbox_expanded["xmax"] <- bbox_pts["xmax"] + 10000
bbox_expanded["ymin"] <- bbox_pts["ymin"] - 10000
bbox_expanded["ymax"] <- bbox_pts["ymax"] + 10000

inset_map <- ggplot() +
  geom_sf(data = districts, fill = "grey95", color = "grey60", size = 0.2) +
  geom_sf(data = all_dist, fill = "red", color = "black", size = 0.3) +
  ggtitle("Sampled Districts \n within Ghana") +
  theme_void() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 8, face = "bold"),
    plot.margin = margin(0.0, 0.0, 0.0, 0.0)
  )

# Add white background and border to inset box
inset_with_box <- ggdraw() +
  draw_plot(
    ggplot() + theme_void() +
      theme(panel.background = element_rect(fill = "white", color = "black")),
    x = 0, y = 0, width = 0.9, height = 1.1
  ) +
  draw_plot(inset_map, x = 0.05, y = 0.05, width = 0.875, height = 1.075)


ghana_map_ssa <- ggplot() +
  geom_sf(data = africa_boundary, fill = "grey90", color = "grey60", size = 0.2) +  # SSA background
  geom_sf(data = ghana_boundary, fill = "red", color = "black", size = 0.3) +       # Ghana in red
  # geom_sf(data = rivers_utm, color = "blue", size = 0.2) +                          # Rivers
  labs(title = "Sample Point Distribution within Ghana") +
  theme_void() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 10, face = "bold")
  )




# Plot the Mn concentration using ggplot2
main_map <- ggplot() +
  geom_sf(data = wboundary_utm, fill = "grey90", color = "black", size = 0.6) +
  geom_sf(data = all_dist, fill = NA, color = "black", size = 0.6) +
  geom_sf(data = grid_summary, aes(fill = Mn_median_log), color = "white", size = 0.1) + 
  geom_sf(data = points_sf_utm, shape = 21, fill = "black", color = "white", size = 2, alpha = 0.85) +
  # geom_sf(data = rivers_utm, color = "blue", size = 0.4) +
  scale_fill_distiller(
    name = "log(Mn Median)\n(1km grid)",
    palette = "YlOrRd",
    direction = 1,
    na.value = "transparent"
  ) + 
  labs(
    title = "A. Log(Mn Median)",
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

## Repeat for IQR 
main_map_IQR <- ggplot() +
  geom_sf(data = wboundary_utm, fill = "grey90", color = "black", size = 0.6) +
  geom_sf(data = all_dist, fill = NA, color = "black", size = 0.6) +
  geom_sf(data = grid_summary, aes(fill = Mn_IQR_log ), color = "white", size = 0.1) + 
  geom_sf(data = points_sf_utm, shape = 21, fill = "black", color = "white", size = 2, alpha = 0.85) +
  geom_sf(data = rivers_utm, color = "blue", size = 0.4) +
  scale_fill_distiller(
    name = "log(Mn IQR)\n(1km grid)",
    palette = "YlOrRd",
    direction = 1,
    na.value = "transparent"
  ) + 
  labs(
    title = "B. Log(Mn IQR)",
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
    xlim = c(bbox_expanded["xmin"], bbox_expanded["xmax"]),
    ylim = c(bbox_expanded["ymin"], bbox_expanded["ymax"]),
    expand = FALSE
  )


# Final map with inset placed in lower-right
## Median Plot
final_plot <- ggdraw() +
  draw_plot(main_map) 
+
  draw_plot(inset_with_box, x = 0.8, y = 0.1, width = 0.2, height = 0.2)

# if (dev.cur() == 1) windows(width = 14, height = 8)  # Only opens if no device active
# print(final_plot)
# ggsave("../Output/Figures/Mn_MEDIAN_Distribution_Grid_Map.pdf", 
#        plot = final_plot, 
#        width = 10, height = 8)


## IQR Plot
final_plot_IQR <- ggdraw() +
  draw_plot(main_map_IQR) +
  draw_plot(inset_with_box, x = 0.8, y = 0.1, width = 0.2, height = 0.2)

# if (dev.cur() == 1) windows(width = 14, height = 8)  # Only opens if no device active
# print(final_plot_IQR)
# ggsave("../Output/Figures/Mn_IQR_Distribution_Grid_Map.pdf", 
#        plot = final_plot, 
#        width = 10, height = 8)

## Put those two together: 
main_map_with_inset <- ggdraw() +
  draw_plot(main_map) 

main_map_IQR_with_inset <- ggdraw() +
  draw_plot(main_map_IQR) +
  draw_plot(inset_with_box, x = 0.81, y = 0.225, width = 0.2, height = 0.18)

final_side_by_side <- plot_grid(
  main_map_with_inset,
  main_map_IQR_with_inset,
  ncol = 2
)

if (dev.cur() == 1) windows(width = 14, height = 8)  # Only opens if no device active
print(final_side_by_side)
ggsave("../Output/Figures/Mn_IQR_and_Median_Grid_Map.pdf",
       plot = final_side_by_side,
       width = 14, height = 8)

STOP HERE 
##------------------------
## WHETHER DOWNSTREAM SAMPLE HAS HIGHER MN CONCENTRAITON 
##------------------------
rivers_split <- rivers_local %>%
  st_cast("MULTILINESTRING", warn = FALSE) %>%
  st_cast("LINESTRING", warn = FALSE)
river_coords_list <- st_coordinates(rivers_split)
river_coords_df <- as.data.frame(river_coords_list)
river_coords_df$node <- paste(river_coords_df$X, river_coords_df$Y, sep = ",")
river_coords_df$group <- river_coords_df$L1

rivers_net <- as_sfnetwork(rivers_split, directed = TRUE)

# Get node coordinates
node_coords <- st_coordinates(activate(rivers_net, "nodes"))

# Match samples to nearest river node
point_coords <- st_coordinates(nonsachetpoints_sf_utm)
nn_indices <- get.knnx(node_coords[, 1:2], point_coords, k = 1)$nn.index
nonsachetpoints_sf_utm$nearest_node_id <- nn_indices

# Create igraph from sfnetwork
g <- as.igraph(rivers_net)

# Count how many sample nodes can reach each node
nonsachetpoints_sf_utm$n_upstream <- sapply(1:nrow(nonsachetpoints_sf_utm), function(i) {
  this_node <- nonsachetpoints_sf_utm$nearest_node_id[i]
  others <- nonsachetpoints_sf_utm$nearest_node_id[-i]
  paths <- suppressWarnings(shortest_paths(g, from = others, to = this_node, output = "vpath"))
  sum(sapply(paths$vpath, length) > 0)
})

ggplot(nonsachetpoints_sf_utm, aes(x = n_upstream, y = Mn_LODsq2)) +
  geom_point() +
  geom_smooth(method = "lm") +
  labs(
    x = "Number of Upstream Sample Points",
    y = "Local Mn Concentration",
    title = "Does Upstream Activity Influence Mn Levels?"
  )




# Build edges by walking along each linestring
edges <- river_coords_df %>%
  group_by(group) %>%
  mutate(
    point_order = row_number(),
    from = lag(node),
    to = node
  ) %>%
  filter(!is.na(from)) %>%
  select(from, to)

plot(rivers_split, col = "blue")
plot(st_geometry(nonsachetpoints_sf_utm), col = "black", add = TRUE)
rivers_net <- as_sfnetwork(rivers_local, directed = TRUE)

# Simplify and clean (optional but recommended)
rivers_net <- st_transform(rivers_net, 32630) %>%
  convert(to_spatial_subdivision) %>%
  convert(to_undirected)

# Use node coordinates from the network
node_coords <- st_coordinates(activate(rivers_net, "nodes"))
node_points <- st_as_sf(node_coords, coords = c("X", "Y"), crs = st_crs(points_sf_utm))
plot(st_geometry(node_points), col = "red", pch = 16, add = TRUE)

# Ensure point_coords is numeric matrix (already should be from st_coordinates)
point_matrix <- as.matrix(point_coords)

# Then use get.knnx
nn_indices <- get.knnx(node_matrix, point_matrix, k = 1)$nn.index
nonsachetpoints_sf_utm$nearest_node <- st_nearest_feature(nonsachetpoints_sf_utm, activate(rivers_net, "nodes"))

# Convert edges to igraph object
g <- igraph::graph_from_data_frame(edges, directed = TRUE)

point_coords <- st_coordinates(nonsachetpoints_sf_utm)
river_nodes <- unique(c(edges$from, edges$to))
node_coords <- do.call(rbind, strsplit(river_nodes, ","))
node_coords <- as.data.frame(node_coords)
colnames(node_coords) <- c("X", "Y")
node_coords$node <- river_nodes

# Function to find nearest river node
find_nearest_node <- function(x, y) {
  dists <- (as.numeric(node_coords$X) - x)^2 + (as.numeric(node_coords$Y) - y)^2
  node_coords$node[which.min(dists)]
}

nonsachetpoints_sf_utm$nearest_node <- apply(point_coords, 1, function(coord) {
  find_nearest_node(coord[1], coord[2])
})

nonsachetpoints_sf_utm$n_upstream <- sapply(1:nrow(nonsachetpoints_sf_utm), function(i) {
  this_node <- nonsachetpoints_sf_utm$nearest_node[i]
  others <- nonsachetpoints_sf_utm$nearest_node[-i]
  
  reachable <- suppressWarnings(shortest_paths(g, from = others, to = this_node, output = "vpath"))
  
  # Count how many of those can reach the current point
  sum(sapply(reachable$vpath, length) > 0)
})

ggplot(nonsachetpoints_sf_utm, aes(x = n_upstream, y = Mn_LODsq2)) +
  geom_point() +
  geom_smooth(method = "lm") +
  labs(
    x = "Number of Upstream Sample Points",
    y = "Local Mn Concentration",
    title = "Does Upstream Activity Influence Mn Levels?"
  )

p <- ggplot(nonsachetpoints_sf_utm, aes(x = n_upstream, y = Mn_LODsq2)) +
  geom_point() +
  geom_smooth(method = "lm") +
  labs(
    x = "Number of Upstream Sample Points",
    y = "Local Mn Concentration",
    title = "Does Upstream Activity Influence Mn Levels?"
  )

print(p)  # This ensures the plot is shown in script execution

ggplot(nonsachetpoints_sf_utm, aes(x = downstream_status, y = Mn_LODsq2)) +
  geom_point() +
  geom_smooth(method = "lm") +
  labs(
    x = "Is Downstream (1 = Yes)",
    y = "Local Mn Concentration",
    title = "Relationship Between Downstream Status and Mn Levels"
  )

  # 
  # # Shpefile with only the districts in the western region
  # allwest <- districts[districts$REGION == "WESTERN NORTH" | 
  #                        districts$REGION == "WESTERN" |
  #                        districts$REGION == "ASHANTI" |
  #                        districts$REGION == "AHAFO" |
  #                        districts$REGION == "CENTRAL" |
  #                        districts$REGION == "BONO" , ]
  # 
  # # 2 districts of interest 
  # sw_dist <- districts[districts$DISTRICT == "SEFWI-WIAWSO" , ]
  # sba_dist <- districts[districts$DISTRICT == "BIBIANI-ANHWIASO-BEKWAI MUNICIPAL" , ]
  # sa_dist <- districts[districts$DISTRICT == "SEFWI AKONTOMBRA"  , ]
  # j_dist <- districts[districts$DISTRICT == "JUABOSO"  , ]
  # 
  # # the 4 districts that harry sent ot anne

  # 
  # aowin_dist <- districts[districts$DISTRICT == "AOWIN" , ]
  