#' Title
#'
#' @param file_name
#' @param parameter
#' @param lead_time
#' @param members
#' @param stations
#' @param is_ensemble
#'
#' @return
#' @export
#'
#' @examples
read_netcdf_interpolate <- function(
  file_name,
  parameter   = NULL,
  lead_time   = NA_real_,
  members     = NA_character_,
  stations    = NULL,
  is_ensemble = FALSE
) {

  empty_data <- tibble::tibble(
    SID             = NA_real_,
    lat             = NA_real_,
    lon             = NA_real_,
    model_elevation = NA_real_,
    member          = members,
    lead_time       = lead_time
  )

  if (!file.exists(file_name)) {
    warning("File not found: ", file_name, call. = FALSE, immediate. = TRUE)
    return(empty_data)
  }

  if (is_ensemble) {
    members   <- readr::parse_number(unique(members))
  }
  lead_time <- unique(lead_time)

  if (is.null(stations)) {
    warning("No stations specified for interpolating to. Default station list used.", call. = FALSE)
    stations <- station_list
  }

  message("Reading:", file_name)

  # Need to get the model elevation before anything else
  if (is_ensemble) {
    prm_nc <- list(model_elevation = list(name = "surface_geopotential", mbr = 0))
  } else {
    prm_nc <- list(model_elevation = list(name = "surface_geopotential"))
  }
  model_elevation <- miIO::miReadNetCDFinterpolation(
    file_name,
    sites = as.data.frame(stations),
    prm   = prm_nc,
    lt    = 0
  ) %>%
    dplyr::rename(
      SID             = .data$SITE,
      lead_time       = .data$LT
    )

  if (is_ensemble) {
    model_elevation <- dplyr::rename(model_elevation, model_elevation = .data$model_elevation.0)
  }

  model_elevation <- model_elevation %>%
    dplyr::mutate(model_elevation = .data$model_elevation / 9.80665) %>%
    dplyr::select(-dplyr::contains("TIME")) %>%
    tidyr::drop_na()

  stations <- dplyr::inner_join(
    stations,
    model_elevation,
    by = "SID"
  )

  if (nrow(stations) < 1) {
    stop("No stations found inside model domain.", call. = FALSE)
  }

  # function to read the data
  get_netcdf_data <- function(.param, .file, .sites, .lead_time, .member, .is_ensemble) {

    nc_prm <- list()
    if (is_ensemble) {
      nc_prm[[.param]] <- list(name = get_netcdf_param_MET(.param), mbr = .member)
    } else {
      nc_prm[[.param]] <- list(name = get_netcdf_param_MET(.param))
    }

    netcdf_data <- miIO::miReadNetCDFinterpolation(
      .file,
      sites = as.data.frame(.sites),
      lt    = .lead_time * 3600,
      prm   = nc_prm
    ) %>%
      dplyr::rename(
        SID       = .data$SITE,
        lead_time = .data$LT
      ) %>%
      dplyr::select(-dplyr::starts_with("TIME")) %>%
      tibble::as_tibble()

    if (.is_ensemble) {

      netcdf_data <- netcdf_data %>%
        tidyr::gather(
          dplyr::contains(.param),
          key   = "member",
          value = !!rlang::sym(.param)
        ) %>%
        tidyr::separate(.data$member, c("param", "member"), "\\.") %>%
        dplyr::mutate(member = paste0("mbr", formatC(as.numeric(.data$member), width = 3, flag = "0"))) %>%
        dplyr::select(-.data$param)

    }

    netcdf_data

  }

  netcdf_data <- purrr::map(
    parameter,
    get_netcdf_data,
    file_name,
    stations,
    lead_time,
    members,
    is_ensemble
  )

  if (is_ensemble) {
    join_cols <- c("SID", "lead_time", "member")
  } else {
    join_cols <- c("SID", "lead_time")
  }

  if (length(netcdf_data) > 1) {
    netcdf_data <- purrr::reduce(netcdf_data, dplyr::inner_join, by = join_cols)
  } else {
    netcdf_data <- netcdf_data[[1]]
  }

  dplyr::inner_join(
    stations,
    netcdf_data,
    by = "SID"
  ) %>%
    dplyr::select(-.data$elev, -.data$name)

}