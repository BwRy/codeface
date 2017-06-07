#! /usr/bin/env Rscript

## This file is part of Codeface. Codeface is free software: you can
## redistribute it and/or modify it under the terms of the GNU General Public
## License as published by the Free Software Foundation, version 2.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##
## Copyright 2017 by Wolfgang Mauerer <wolfgang.mauerer@oth-regensburg.de>
## All Rights Reserved.

s <- suppressPackageStartupMessages
s(library(ggplot2))
s(library(lubridate))
s(library(dplyr))

source("query.r")
source("utils.r")
source("config.r")
source("dependency_analysis.r")
source("quality_analysis.r")

get.correlation.data <- function(cycles, i, quality.file, quality.type, do.subset=TRUE) {
    if (!file.exists(quality.file)) {
        return(NULL)
    }
    artifacts.dat <- read.csv(quality.file)

    if (do.subset) {
        corr.elements <- gen.correlation.columns(quality.type)
        artifacts.dat <- artifacts.dat[, corr.elements$names]
        colnames(artifacts.dat) <- corr.elements$labels
    }

    if (nrow(artifacts.dat) == 0) {
        return(NULL)
    }

    return(artifacts.dat)
}

compute.correlation.data <- function(conf, i, cycles, quality.file, quality.type) {
    artifacts.subset <- get.correlation.data(cycles, i, quality.file, quality.type)
    if (is.null(artifacts.subset)) {
        return(NULL)
    }

    cycle <- cycles[i, ]
    corr.mat <- cor(artifacts.subset, use="pairwise.complete.obs",
                    method="spearman")
    corr.test <- cor.mtest(artifacts.subset) ## Note: can be NULL

    ## Compute labels for the correlated quantities (A:B to indicate correlation
    ## between A and B)
    corr.combinations <- expand.grid(colnames(corr.mat), rownames(corr.mat))
    corr.combinations <- str_c(corr.combinations$Var1, ":", corr.combinations$Var2)
    corr.combinations <- matrix(corr.combinations, nrow=nrow(corr.mat), ncol=ncol(corr.mat))

    return(data.frame(date=cycle$date.end, range=i,
                      combination=corr.combinations[upper.tri(corr.combinations)],
                      value=corr.mat[upper.tri(corr.combinations)]))
}

make.title <- function(conf, motif.type) {
    return(str_c(conf$description, " (window: ", conf$windowSize, " months, motif: ",
                 motif.type, ", comm: ", conf$communicationType, ")"))
}

dispatch.all <- function(conf, resdir) {
    motif.type <- list("triangle", "square")[[1]]
    cycles <- get.cycles(conf)

    if (is.null(conf$windowSize)) {
        conf$windowSize <- 3
    }

    ## Compute correlation values time series and plot the result
    res <- lapply(1:nrow(cycles), function(i) {
        range.resdir <- file.path(resdir, gen.range.path(i, cycles[i,]$cycle))
        quality.file <- file.path(range.resdir, "quality_analysis", motif.type,
                                  conf$communicationType, "quality_data.csv")

        logdevinfo(str_c("Analysing quality file ", quality.file), logger="conway")
        res <- compute.correlation.data(conf, i, cycles, quality.file, conf$qualityType)
    })

    corr.dat <- do.call(rbind, res)
    plot.file <- file.path(resdir, str_c("correlations_ts_", motif.type, "_",
                                        conf$communicationType, ".pdf"))
    logdevinfo(str_c("Saving plot to ", plot.file), logger="conway")

    corr.dat$date <- as.Date(corr.dat$date)
    corr.label <- "Correlated\nQuantities"
    g <- ggplot(corr.dat, aes(x=date, y=value, colour=combination, shape=combination)) +
        geom_point() + geom_line() +  scale_x_date("Date", date_labels="%m-%Y") + ylab("Correlation") +
        ggtitle(make.title(conf, motif.type)) + scale_colour_discrete(corr.label) +
        scale_shape_discrete(corr.label) + theme_bw()
    ggsave(plot.file, g, width=7, height=3)


    ## ###############################################################
    ## Compute a time series with absolute data counts for the previous correlation computations
    res <- lapply(1:nrow(cycles), function(i) {
        range.resdir <- file.path(resdir, gen.range.path(i, cycles[i,]$cycle))
        quality.file <- file.path(range.resdir, "quality_analysis", motif.type,
                                  conf$communicationType, "quality_data.csv")

        logdevinfo(str_c("Analysing quality file ", quality.file), logger="conway")
        res <- get.correlation.data(cycles, i, quality.file, conf$qualityType, do.subset=FALSE)
        if (is.null(res)) {
            return(NULL)
        }

        res$date <- cycles[i,]$date.end
        res$range <- i
        return(res)
    })
    res <- do.call(rbind, res)

    plot.file <- file.path(resdir, str_c("abs_ts_", motif.type, "_",
                                        conf$communicationType, ".pdf"))

    labels <- c(motif.count = "Motifs", motif.anti.count = "Anti-Motifs")
    corr.dat$date <- as.Date(corr.dat$date)
    if (conf$communicationType=="mail") {
        res <- res[,c("corrective", "motif.count", "motif.anti.count", "dev.count", "date", "range")]
        res$date <- as.Date(res$date)
        res.molten <- melt(res, measure.vars=c("motif.count", "motif.anti.count"))

        g <- ggplot(res.molten, aes(x=dev.count, y=value)) + geom_point(size=0.5) +
            facet_grid(variable~date, labeller=labeller(variable=labels)) +
            scale_x_sqrt("# Devs contributing to artifact [sqrt]") +
            scale_y_sqrt("Count [sqrt]") + geom_smooth(method=lm) + theme_bw() +
            ggtitle(make.title(conf, motif.type))
        logdevinfo(str_c("Saving plot to ", plot.file), logger="conway")
        ggsave(plot.file, g, width=8, height=5)
    }
    else if (conf$communicationType=="jira") {
        ## TODO: Provide the plot for jira
    }

    ## ###########################################################
    ## Prepare a global "timeseries" plot of the null model tests
    res <- do.call(rbind, lapply(1:nrow(cycles), function(i) {
        range.resdir <- file.path(resdir, gen.range.path(i, cycles[i,]$cycle))
        motif.file <- file.path(range.resdir, "motif_analysis", motif.type,
                                conf$communicationType, "raw_motif_results.txt")

        logdevinfo(str_c("Analysing motif file ", motif.file), logger="conway")
        if (!file.exists(motif.file)) {
            return(NULL)
        }
        null.model.dat <- read.table(motif.file, header=TRUE)
        null.model.dat$date <- cycles[i,]$date.end
        null.model.dat$range <- i

        return(null.model.dat)
    }))

    res$date <- as.Date(res$date)
    labels <- c(negative = "Anti-Motif", positive = "Motif", ratio = "Ratio")
    g <- ggplot(data=res, aes(x=count)) +
        geom_point(aes(x=empirical.count), y=0, color="red", size=2.5) +
        geom_density(aes(x=count, y=..scaled..), alpha=.2, fill="#AAD4FF") +
        facet_wrap(count.type~date, nrow=3, scales="free_x", labeller=labeller(count.type=labels)) +
        xlab("Count or Ratio") + ylab("Density [a.u.]") +
        ggtitle(make.title(conf, motif.type)) + theme_bw()

    plot.file <- file.path(resdir, str_c("motif_ts_", motif.type, "_",
                                         conf$communicationType, ".pdf"))
    logdevinfo(str_c("Saving plot to ", plot.file), logger="conway")
    ggsave(plot.file, g, width=9, height=6)

    ## #####################################################
    ## Plot a time series with absolute empirical motif counts
    plot.file <- file.path(resdir, str_c("motif_ts_abs_", motif.type, "_",
                                         conf$communicationType, ".pdf"))
    g <- ggplot(res, aes(x=as.Date(date), y=empirical.count)) + geom_point() + geom_line() +
        facet_grid(count.type~., scales="free_y", labeller=labeller(count.type=labels)) +
        scale_x_date("Date", date_labels="%m-%Y") +
        ylab("Count or Ratio") + theme_bw() + ggtitle(make.title(conf, motif.type))

    logdevinfo(str_c("Saving plot to ", plot.file), logger="conway")
    ggsave(plot.file, g, width=7, height=4)
}

config.script.run({
    conf <- config.from.args(positional.args=list("resdir"), require.project=TRUE)
    dispatch.all(conf, conf$resdir)
})
