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
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

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


# ghana_in_ssa_map <- ggplot() +
#   geom_sf(data = africa_boundary, fill = "grey90", color = "grey70", size = 0.2) +
#   # geom_sf(data = ghana_boundary, fill = "lightcoral", color = "grey20", size = 0.3) +
#   geom_sf(data = study_box_wgs84, fill = NA, color = "red", size = 1) +  # Highlight study area
#   labs(title = "") +
#   theme_void() +
#   theme(
#     plot.title = element_text(hjust = 0.5, size = 10, face = "bold")
#   )

study_area_WestAfrica <- ggplot() +
  geom_sf(data = west_africa, fill = "grey90", color = "grey70", size = 0.2) +
  geom_sf(data = ghana_boundary, fill = "grey80", color = "grey40", size = 0.3) +  # Show Ghana for context
  geom_sf(data = study_box_wgs84, fill = NA, color = "red", linewidth = 1) +  # Study area box
  labs(title = "") +
  theme_void() +
  theme(
    plot.title = element_text(hjust = 0.5, size = 10, face = "bold")
  )
print(study_area_WestAfrica)

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

print(sample_map)

# inset_map <- ggplot() +
#   geom_sf(data = districts, fill = "grey95", color = "grey60", size = 0.2) +
#   geom_sf(data = all_dist, fill = "red", color = "black", size = 0.3) +
#   ggtitle("Sampled Districts \n within Ghana") +
#   theme_void() +
#   theme(
#     plot.title = element_text(hjust = 0.5, size = 8, face = "bold"),
#     plot.margin = margin(0.0, 0.0, 0.0, 0.0)
#   )

# # Add white background and border to inset box
# inset_with_box <- ggdraw() +
#   draw_plot(
#     ggplot() + theme_void() +
#       theme(panel.background = element_rect(fill = "white", color = "black")),
#     x = 0, y = 0, width = 0.9, height = 1.1
#   ) +
#   draw_plot(inset_map, x = 0.05, y = 0.05, width = 0.875, height = 1.075)


# ghana_map_ssa <- ggplot() +
#   geom_sf(data = africa_boundary, fill = "grey90", color = "grey60", size = 0.2) +  # SSA background
#   geom_sf(data = ghana_boundary, fill = "red", color = "black", size = 0.45) +
#   theme_void()     # Ghana in red
  # geom_sf(data = rivers_utm, color = "blue", size = 0.2) +                          # Rivers
# labs(title = expression(bold("A.") ~ "Sample Point Distribution within Ghana")) +  theme_void() +
#   theme(
#     plot.title = element_text(hjust = 0.5, size = 10, face = "bold")
#   )

upper_panel <- study_area_WestAfrica + sample_map +
  plot_layout(widths = c(1.5, 3)) +
  plot_annotation(
    title = expression(bold("A.") ~ "Study Area Overview and Sampling Locations in Western North Ghana")
  )
if (dev.cur() == 1) windows(width = 8, height = 4)  # Only opens if no device active
print(upper_panel)

# # Extract legend from sample_map
# sample_map_legend <- cowplot::get_legend(sample_map)

# # Remove legend from sample_map
# sample_map_no_legend <- sample_map +
#   theme(legend.position = "none",
#         plot.margin = margin(0, -10, 0, 0))
# study_area_WestAfrica_minimal <- study_area_WestAfrica +
#   theme(plot.margin = margin(0, 0, 0, -10))

# # Layout: (West Africa / legend) | sample_map
# upper_panel <- (study_area_WestAfrica / wrap_elements(sample_map_legend) +
#                   plot_layout(heights = c(1, 3))) |
#                sample_map_no_legend +
#                plot_layout(widths = c(2.5, 1))

# upper_panel <- upper_panel +
#   plot_annotation(
#     title = expression(bold("A.") ~ "Study Area Overview and Sampling Locations in Western North Ghana")
#   )
# upper_panel <- upper_panel & theme(plot.margin = margin(0, 0, 0, 0))

# print(upper_panel)


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
print(main_map)
# ## Repeat for IQR
# main_map_IQR <- ggplot() +
#   geom_sf(data = wboundary_utm, fill = "grey75", color = "black", size = 0.6) +
#   geom_sf(data = all_dist, fill = NA, color = "black", size = 0.6) +
#   geom_sf(data = grid_summary, aes(fill = Mn_IQR ), color = alpha("white", 0.3), size = 0.05) +
#   # geom_sf(data = points_sf_utm, shape = 21, fill = "black", color = "white", size = 2, alpha = 0.85) +
#   # geom_sf(data = rivers_utm, color = "blue", size = 0.4) +
#   scale_fill_distiller(
#     name = "Mn IQR\n(1km grid)",
#     palette = "YlOrRd",
#     direction = 1,
#     na.value = "transparent"
#   ) +
#   labs(
#     title = expression(bold("C.") ~ "Inter-Quartile Range"),
#     x = "Longitude", y = "Latitude"
#   ) +
#   theme_minimal() +
#   theme(
#     legend.position = c(0.01, 0.05),         # x, y (0 = left/bottom, 1 = right/top)
#     legend.justification = c(0, 0),         # anchor point for the legend box
#     legend.background = element_rect(fill = "white", color = NA),
#     legend.box.background = element_rect(color = "black"),
#     legend.text = element_text(size = 7),    # smaller legend labels
#     legend.title = element_text(size = 8, face = "bold")  # optional: smaller bold title
#   ) +
#   coord_sf(
#     xlim = c(bbox_expanded["xmin"], bbox_expanded["xmax"]),
#     ylim = c(bbox_expanded["ymin"], bbox_expanded["ymax"]),
#     expand = FALSE
#   )


# Final map with inset placed in lower-right
# ## Median Plot
# final_plot <- ggdraw() +
#   draw_plot(main_map)
# # +
#   draw_plot(inset_with_box, x = 0.8, y = 0.1, width = 0.2, height = 0.2)

# if (dev.cur() == 1) windows(width = 14, height = 8)  # Only opens if no device active
# print(final_plot)
# ggsave("../Output/Figures/Mn_MEDIAN_Distribution_Grid_Map.pdf",
#        plot = final_plot,
#        width = 10, height = 8)


# ## IQR Plot
# final_plot_IQR <- ggdraw() +
#   draw_plot(main_map_IQR)
  # draw_plot(inset_with_box, x = 0.8, y = 0.1, width = 0.2, height = 0.2)

# if (dev.cur() == 1) windows(width = 14, height = 8)  # Only opens if no device active
# print(final_plot_IQR)
# ggsave("../Output/Figures/Mn_IQR_Distribution_Grid_Map.pdf",
#        plot = final_plot,
#        width = 10, height = 8)

## Put those two together:
# main_map_with_inset <- ggdraw() +
#   draw_plot(main_map)

# main_map_IQR_with_inset <- ggdraw() +
#   draw_plot(main_map_IQR)
#   # draw_plot(inset_with_box, x = 0.81, y = 0.225, width = 0.2, height = 0.18)
# print(main_map_IQR_with_inset)

# final_side_by_side <- plot_grid(
#   main_map_with_inset + theme(plot.margin = margin(0, 0, 0, 0)),
#   main_map_IQR_with_inset + theme(plot.margin = margin(0, 0, 0, 0)),
#   ncol = 2
# )
# print(final_side_by_side)
upper_panel_wrapped <- wrap_elements(full = upper_panel)
upper_panel_wrapped <- upper_panel_wrapped & theme(plot.margin = margin(0, 0, 0, 0))

  # combined_plot <- (plot_spacer() + upper_panel_wrapped + plot_spacer() + plot_layout(widths = c(1, 6, 1))) /
  #                  final_side_by_side +
  #                  plot_layout(heights = c(0.75, 1))

design <- "
AAAA
BBB#
"
combined_plot <- upper_panel_wrapped + main_map +
  plot_layout(design = design, heights = c(1, 1))

 print(combined_plot)
ggsave("../Output/Figures/Mn_IQR_and_Median_Grid_Map_Africa.svg",
       plot = combined_plot,
       width = 8, height = 8)



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
