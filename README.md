
<!-- README.md is generated from README.Rmd. Please edit that file -->
harpIO
======

harpIO provides a set of read and write functions for the harp ecosystem.

The package is currently under development, but the aim is to provide functions to read grib1, grib2, FA, NetCDF and vfld files from weather forecast / climate models; station observations from vobs files, radar / satellite observations from HDF5 files and in house databases at selected meteorological institutes. Further functions will interpolate gridded forecast fields to weather station locations which will in turn be written to portable sqlite database files.

Installation:
-------------

``` r
#>install.packages("devtools")
devtools::install_github("andrew-MET/harpIO")
```

If you wish to read data from netcdf files and don't already have the system libraries installed, you will need to install them:

``` bash
sudo apt-get install libnetcdf-dev netcdf-bin libudunits2-dev
```

Additionally, for reading from grib and FA files, the R packages Rgrib2, Rfa and meteogrid are needed - these are not publically available, but are available on demand. For interpolating data from NetCDF files, the miIO package is needed, which can be obtained from MET Norway.

Examples
--------

To run these examples, you should have access to vfld and vobs files - replace all paths with your own paths and `start_date`, `end_date` etc. to fit your data. Note also that to read vfld files from multiple forecast models (or experiments), the data are expected to be in their own directory for each forecast model underneath a common directory . i.e `/path/to/vfld/data/model1`, `/path/to/vfld/data/model2/` etc.

To start, load the harpIO package and set up the paths and dates etc. Here we assume the forecast models are called model1, model2 and model3. To begin with a test will be done for two forecasts - one for 00 UTC on 30 May 2017, and then for the same time the next day.

``` r
library(harpIO)
vfld_path          <- "/path/to/vfld/data"
first_forecast     <- 2017053000
last_forecast      <- 2017053100
forecast_models    <- c("model1", "model2", "model3")
forecast_frequency <- "1d"
```

In this case, model1 has 5 members (0-4), and model2 and model3 have 8 members (0-7). We will ask for lead times 0 - 36 hours every 3 hours and use `read_eps_interpolate()` to read in the data setting `return_data = TRUE` so that we can inspect the data. We set `parameter = NULL` to read all parameters from the vfld files. Note that when more than one `eps_model` is asked for, the number of members must be specified for each model in a list, even if each model has the same number of members.

To run this example on ecgate you can set `vfld_path <- "/scratch/ms/no/fa1m/vfld"`

``` r
forecast_members    <- list(model1 = seq(0, 4), model2 = seq(0, 7), model3 = seq(0, 7))
forecast_lead_times <- seq(0, 36, 3)

forecast_data <- read_eps_interpolate(
  start_date  = first_forecast,
  end_date    = last_forecast,
  eps_model   = forecast_models,
  parameter   = NULL, 
  lead_time   = forecast_lead_times,
  members_in  = forecast_members,
  by          = forecast_frequency,
  file_path   = vfld_path, 
  return_data = TRUE
)
```

The model data are interpolated to station locations that are supplied with harpIO, which can be seen in the variable `station_list`.

``` r
head(forecast_data, n = 10)
#> # A tibble: 10 x 18
#>    eps_model sub_model fcdate lead_time member members_out validdate   SID
#>    <chr>     <chr>      <dbl>     <dbl> <chr>  <chr>           <dbl> <dbl>
#>  1 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1001
#>  2 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1010
#>  3 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1014
#>  4 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1015
#>  5 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1018
#>  6 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1023
#>  7 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1025
#>  8 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1026
#>  9 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1027
#> 10 model1    model1    1.50e9         0 mbr000 mbr000         1.50e9  1033
#> # ... with 10 more variables: lat <dbl>, lon <dbl>, model_elevation <dbl>,
#> #   lat.temp <dbl>, lon.temp <dbl>, model_elevation.temp <dbl>,
#> #   elev <dbl>, name <chr>, parameter <chr>, forecast <dbl>
```

To write out the data to sqlite files, set `sqlite_path = /path/to/output` where /path/to/output is the directory you want to which you want to write the sqlite files. It is also a good idea to set `return_data = FALSE` when reading a large amount of data, although this is the default behaviour.
