# make a hex logo
library(devtools)
library(gdalraster)
library(ggplot2)
library(magick)
library(shadowtext)
load_all()

# ----- make raster ------

esri_sat <- "<GDAL_WMS><Service name=\"TMS\"><ServerUrl>http://services.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/${z}/${y}/${x}</ServerUrl></Service><DataWindow><UpperLeftX>-20037508.34</UpperLeftX><UpperLeftY>20037508.34</UpperLeftY><LowerRightX>20037508.34</LowerRightX><LowerRightY>-20037508.34</LowerRightY><TileLevel>17</TileLevel><TileCountX>1</TileCountX><TileCountY>1</TileCountY><YOrigin>top</YOrigin></DataWindow><Projection>EPSG:900913</Projection><BlockSizeX>256</BlockSizeX><BlockSizeY>256</BlockSizeY><BandsCount>3</BandsCount><MaxConnections>10</MaxConnections><Cache /></GDAL_WMS>"

ds <- new(GDALRaster, esri_sat)
tras <- fs::file_temp(ext = "tif")
wds <- gdalraster::warp(
  ds,
  dst_filename = tras,
  t_srs = "EPSG:4326",
  cl_arg = c("-tr", "0.1", "0.1")
)

vrtility::plot_raster_src(tras, c(1, 2, 3))
# ----------------------------------------

# ------ make a5 grid ------

resolution <- 3

origin <- a5_lonlat_to_cell(0, 0, resolution = resolution)

disk <- a5_spherical_cap(origin, radius = 1e7) |>
  a5_uncompact(resolution = resolution)


ts <- fs::file_temp(ext = "fgb")
a5sf <- tibble::tibble(
  cell_id = as.character(disk),
  geometry = a5R::a5_cell_to_boundary(disk)
) |>
  sf::st_as_sf(crs = 4326) |>
  sf::st_write(ts, delete_dsn = TRUE)


# ----- zonal stats -----
ao <- fs::file_temp(ext = "parquet")
args <- list(
  input = tras,
  zones = ts,
  output = ao,
  format = "PARQUET",
  stat = "mean",
  overwrite = TRUE,
  "include-field" = "cell_id"
)

alg <- gdalraster::gdal_run("raster zonal-stats", args)
alg$release()

aodf <- arrow::read_parquet(ao)

# ----- make plot -----
sf_wc <- sf::st_as_sf(dplyr::left_join(aodf, a5sf, by = "cell_id")) |>
  tidyr::drop_na() |>
  dplyr::mutate(
    rgbhex = {
      hsv_mat <- rgb2hsv(
        mean_band_1,
        mean_band_2,
        mean_band_3,
        maxColorValue = 255
      )
      hsv(hsv_mat[1, ], pmin(hsv_mat[2, ] * 0.45, 1), hsv_mat[3, ])
    }
  ) |>
  sf::st_transform(crs = "+proj=ortho")


ggp <- ggplot(sf_wc) +
  geom_sf(aes(fill = rgbhex), colour = "#74ac9071") +
  scale_fill_identity() +
  annotate(
    "text",
    x = 0,
    y = 0,
    label = "a5R",
    size = 20,
    colour = "#ffffffff",
    fontface = "bold",
    family = "Manjari Thin"
  ) +
  theme_void() +
  theme(
    legend.position = "none",
    plot.margin = margin(40, 40, 40, 40)
  )
ggp
tf <- fs::file_temp(ext = "png")


ggsave(tf, width = 100, height = 100, units = "mm", dpi = 300)

cropcircles::crop_hex(
  tf,
  to = "man/figures/a5Rhex.png",
  border_size = 10,
  border_colour = "#74ac90ff",
  bg_fill = "#000000ff"
)
