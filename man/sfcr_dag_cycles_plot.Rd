% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/sfcr_plots.R
\name{sfcr_dag_cycles_plot}
\alias{sfcr_dag_cycles_plot}
\title{Plot the DAG with cycles information}
\usage{
sfcr_dag_cycles_plot(equations, title = NULL, size = 10)
}
\arguments{
\item{equations}{A \code{sfcr_set} containing all the equations of the model to be simulated. The equations
must be written with the R formula syntax, with the left-hand side separated from the right-hand side
by a twiddle \code{~}.}

\item{title}{Title of the plot.}

\item{size}{Size of the points.}
}
\description{
Plot the DAG with cycles information
}
\author{
João Macalós
}
