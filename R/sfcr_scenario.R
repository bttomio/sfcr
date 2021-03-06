#' Make matrix for scenario calculations
#'
#' @param baseline a model calculated with the \code{sfcr_sim()} function
#' @param scenario a List holding the different scenarios
#' @param periods The total number of periods in the model
#'
#' @details This function generates the base matrix that is going to be
#' modified in place by the different solvers.
#'
#'
#' @author João Macalós
#'
#' @keywords internal
#'
.sfcr_make_scenario_matrix <- function(baseline, scenario, periods) {

  steady <- utils::tail(attributes(baseline)$matrix, n = 1)

  m <- steady[rep(seq_len(nrow(steady)), periods), ]

  scenario_eqs <- purrr::map(scenario, function(x) .eq_as_tb(x[[1]]))

  scenario_names <- purrr::map(scenario_eqs, function(x) x$lhs)
  scenario_exprs <- purrr::map(scenario_eqs, function(x) purrr::map(x$rhs, function(y) parse(text = y)))

  scenario_start <- purrr::map(scenario, function(x) x[[2]])
  scenario_end <- purrr::map(scenario, function(x) x[[3]])


  for (scenario in seq_len(vctrs::vec_size(scenario_eqs))) {
    scenario_nms <- scenario_names[[scenario]]
    scenario_xprs <- scenario_exprs[[scenario]]

    for (var in seq_along(scenario_nms)) {
      m[scenario_start[[scenario]]:scenario_end[[scenario]], scenario_nms[[var]]] <- eval(scenario_xprs[[var]])
    }
  }


  return(m)
}

#' Extend a baseline matrix
#'
#' This function is called if a scenario is to be created that just
#' continues with the baseline specification. It is useful to create
#' a benchmark model to compare new scenarios.
#'
#' @param baseline A baseline model
#' @param periods The total number of periods to run the model
#'
#' @author João Macalós
#'
#' @keywords internal
#'
.extend_baseline_matrix <- function(baseline, periods) {
  steady <- utils::tail(attributes(baseline)$matrix, n = 1)
  m <- steady[rep(seq_len(nrow(steady)), periods), ]
}

.abort_wrong_shock_var <- function(wrong_var) {

  if (length(wrong_var) == 1) {
    rlang::abort(message = paste0("Shocked variable `", wrong_var, "` is not included in the external variables of the model. Please check your shocks and try again."))
  } else {
    rlang::abort(message = paste0("Shocked variables `", paste0(wrong_var, collapse = ", "), "` are not present in the external variables of the model. Please check your shocks and try again."))
  }

}


#' Add scenarios to a \code{sfcr} model.
#'
#' @param baseline A model generated with the \code{sfcr_baseline()} function.
#' @param scenario Either a shock created with \code{sfcr_shock()}, a list of shocks,
#' or \code{NULL}. If \code{scenario = NULL}, the model will just extend the baseline
#' model.
#'
#' @inheritParams sfcr_baseline
#'
#' @details Add scenario(s) to a model generated with \code{sfcr_baseline()} functions.
#'
#' This function inherits the block structure from the steady state model. See
#' \code{\link{sfcr_baseline}} for further details on the algorithms.
#'
#' @seealso \code{\link{sfcr_baseline}}
#'
#' @example inst/examples/example_sfcr_scenario.R
#'
#' @export
#'
#' @author João Macalós, \email{joaomacalos@@gmail.com}
#'
sfcr_scenario <- function(baseline, scenario, periods, max_iter = 350, tol = 1e-10, method = "Broyden", ...) {

  match.arg(method, c("Gauss", "Newton", "Broyden"))

  # Check inheritance

  if (inherits(scenario, "sfcr_shock")) {
    scenario <- list(scenario)
  }

  # Load calls
  eqs <- attr(baseline, "calls")

  # Check that all shocks are created with sfcr_shock

  if (!is.null(scenario)) {
    check_all_shocks <- purrr::map_lgl(scenario, ~inherits(.x, "sfcr_shock"))

    if (mean(check_all_shocks) < 1) rlang::abort("Please use `sfcr_shock()` to create shocks.")

    # Check if variables in the shock are valid
    ends_names <- eqs$lhs
    all_names <- colnames(baseline)
    exgs_names <- all_names[which(!(all_names %in% ends_names))]

    all_shock_vars <- unlist(purrr::map(scenario, ~.eq_as_tb(.x$variables)$lhs))
    check_valid_vars <- purrr::map_lgl(all_shock_vars, ~{.x %in% exgs_names})

    if (mean(check_valid_vars) < 1) {
      wrong_var <- all_shock_vars[!check_valid_vars]
      .abort_wrong_shock_var(wrong_var)
    }
  }


  # If scenario is NULL, extend baseline model
  if (is.null(scenario)) {
    m <- .extend_baseline_matrix(baseline, periods)
  } else {
    m <- .sfcr_make_scenario_matrix(baseline, scenario, periods)
  }

  if (method == "Gauss") {
    s1 <- .sfcr_gauss_seidel(m, eqs, periods, max_iter, tol)
  } else if (method == "Newton") {
    s1 <- .sfcr_newton(m, eqs, periods, max_iter, tol, ...)
  } else {
    s1 <- .sfcr_broyden(m, eqs, periods, max_iter, tol)
  }


  s2 <- tibble::tibble(data.frame(s1)) %>%
    dplyr::mutate(period = dplyr::row_number()) %>%
    dplyr::select(-tidyselect::contains('block')) %>%
    dplyr::select(.data$period, tidyselect::everything())
    #dplyr::mutate(dplyr::across(-c(.data$period), ~round(.x, digits = 4)))

  #attr(s2, "matrix") <- s1
  #attr(s2, "calls") <- eqs

  #class(s2) <- c("sfcr", "tbl_df", "tbl", "data.frame")

  ext <- attr(baseline, "external")

  x <- new_sfcr_tbl(s2, s1, eqs, ext)

  return(x)
}
