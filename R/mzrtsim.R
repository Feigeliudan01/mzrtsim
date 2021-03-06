#' Generate simulated count data with batch effects for npeaks
#'
#' @param npeaks Number of peaks to simulate
#' @param ncomp percentage of compounds
#' @param ncond Number of conditions to simulate
#' @param ncpeaks percentage of peaks influenced by conditions
#' @param nbatch Number of batches to simulate
#' @param nbpeaks percentage of peaks influenced by batchs
#' @param npercond Number of samples per condition to simulate
#' @param nperbatch Number of samples per batch to simulate
#' @param shape shape for Weibull distribution of sample mean
#' @param scale scale for Weibull distribution of sample mean
#' @param shapersd shape for Weibull distribution of sample rsd
#' @param scalersd scale for Weibull distribution of sample rsd
#' @param batchtype type of batch. 'm' means monotonic, 'b' means block, 'r' means random error, 'mb' means mixed mode of monotonic and block, default 'mb'
#' @param seed Random seed for reproducibility
#' @details the numbers of batch columns should be the same with the condition columns.
#' @return list with rtmz data matrix, row index of peaks influenced by conditions, row index of peaks influenced by batchs, column index of conditions, column of batchs, raw condition matrix, raw batch matrix, peak mean across the samples, peak rsd across the samples
#' @seealso \code{\link{simmzrt}}
#' @export
#' @examples
#' sim <- mzrtsim()
mzrtsim <- function(npeaks = 1000, ncomp = 0.1, ncond = 2,
    ncpeaks = 0.1, nbatch = 3, nbpeaks = 0.1, npercond = 10,
    nperbatch = c(8, 5, 7), shape = 2, scale = 3, shapersd = 1,
    scalersd = 0.18, batchtype = 'mb', seed = 42) {
    set.seed(seed)
    batch <- rep(1:nbatch, nperbatch)
    condition <- rep(1:ncond, npercond)
    # check the col numbers
    if (length(batch) != length(condition)) {
        stop("Try to use the same numbers for both batch and condition columns")
    }
    ncol <- length(batch)
    # change the column order
    batch <- batch[sample(ncol)]
    condition <- condition[sample(ncol)]
    # generate the colname
    bc <- paste0("C", condition, "B", batch, "_", c(1:ncol))
    # get the compounds numbers
    ncomp <- npeaks * ncomp
    # get the matrix
    matrix <- matrix(0, nrow = ncomp, ncol = ncol)
    colnames(matrix) <- bc

    # generate the base peaks
    samplem <- 10^(stats::rweibull(ncomp, shape = shape,
        scale = scale))
    # generate the rsd for base peaks
    samplersd <- stats::rweibull(ncomp, shape = shapersd,
        scale = scalersd)

    for (i in 1:ncomp) {
        samplei <- abs(stats::rnorm(ncol, mean = samplem[i],
            sd = samplem[i] * samplersd[i]))
        matrix[i, ] <- samplei
    }

    # get the multi-peaks
    nmpeaks <- npeaks - ncomp
    indexm <- sample(1:ncomp, nmpeaks, replace = T)
    change <- exp(stats::rnorm(nmpeaks))
    mpeaks <- matrix[indexm, ] * change

    # get the matrix
    matrix0 <- matrix <- rbind(matrix, mpeaks)

    # get the numbers of signal and batch peaks
    ncpeaks <- npeaks * ncpeaks
    nbpeaks <- npeaks * nbpeaks
    # simulation of condition
    index <- sample(1:npeaks, ncpeaks)
    matrixc <- matrix[index, ]
    changec <- NULL
    for (i in 1:ncond) {
        colindex <- condition == i
        change <- exp(stats::rnorm(ncpeaks))
        matrixc[, colindex] <- matrixc[, colindex] * change
        changec <- cbind(changec, change)
    }
    matrix[index, ] <- matrixc
    # simulation of batch
    indexb <- sample(1:npeaks, nbpeaks)
    matrixb <- matrix[indexb, ]
    matrixb0 <- matrix0[indexb, ]
    changeb <- changem <- changer <-  NULL
    # check batch mode
    if(!grepl('m|b|r',batchtype)){
            stop("Batch type should be 'm', 'r' and/or 'b'")
    }
    # generate random batch effect
    if(grepl('r',batchtype)){
            for (i in 1:nrow(matrixb)){
                    change <- abs(stats::rnorm(ncol(matrixb)))
                    matrixb[i,] <- matrixb[i,]*change
                    matrixb0[i,] <- matrixb0[i,]*change
                    changer <- change
            }
    }
    # generate increasing/decreasing batch effect
    if(grepl('m',batchtype)){
            for (i in 1:nrow(matrixb)){
                    changet <- seq(1,ncol(matrixb),length.out = ncol(matrixb)) * exp(stats::rnorm(1))
                    change <- if (sample(c(T,F),1)) changet else rev(changet)
                    matrixb[i,] <- matrixb[i,]*change
                    matrixb0[i,] <- matrixb0[i,]*change
                    changem <- rbind(changem,change)
            }
    }
    # generate block batch effect
    if(grepl('b',batchtype)){
    for (i in 1:nbatch) {
        colindex <- batch == i
        change <- exp(stats::rnorm(nbpeaks))
        matrixb[, colindex] <- matrixb[, colindex] * change
        matrixb0[, colindex] <- matrixb0[, colindex] *
                        change
        changeb <- cbind(changeb, change)
        }
    }


    matrix[indexb, ] <- matrixb
    # get peaks mean across the samples
    means <- apply(matrix, 1, mean)
    # get peaks rsd across the samples
    sds <- apply(matrix, 1, stats::sd)
    rsds <- sds/means
    # add row names
    rownames(matrix) <- paste0("P", c(1:npeaks))
    rownames(matrixc) <- paste0("P", index)
    rownames(matrixb0) <- paste0("P", indexb)

    return(list(data = matrix, conp = index, batchp = indexb,
        con = condition, batch = batch, cmatrix = matrixc,
        changec = changec, bmatrix = matrixb0, changeb = changeb, changer = changer, changem = changem,
        matrix = matrix0, compmatrix = matrix[1:ncomp,
            ], mean = means, rsd = rsds))
}

#' Simulation from data by sample mean and rsd from Empirical Cumulative Distribution or Bootstrap sampling
#'
#' @param data matrix with row peaks and column samples
#' @param type 'e' means simulation from data by sample mean and rsd from Empirical Cumulative Distribution; 'f' means simulation from data by sample mean and rsd from Bootstrap sampling
#' @param npeaks Number of peaks to simulate
#' @param ncomp percentage of compounds
#' @param ncond Number of conditions to simulate
#' @param ncpeaks percentage of peaks influenced by conditions
#' @param nbatch Number of batches to simulate
#' @param nbpeaks percentage of peaks influenced by batchs
#' @param npercond Number of samples per condition to simulate
#' @param nperbatch Number of samples per batch to simulate
#' @param batchtype type of batch. 'm' means monotonic, 'b' means block, 'r' means random error, 'mb' means mixed mode of monotonic and block, default 'mb'
#' @param seed Random seed for reproducibility
#' @details the numbers of batch columns should be the same with the condition columns.
#' @return list with rtmz data matrix, row index of peaks influenced by conditions, row index of peaks influenced by batchs, column index of conditions, column of batchs, raw condition matrix, raw batch matrix, peak mean across the samples, peak rsd across the samples
#' @seealso \code{\link{mzrtsim}}
#' @export
#' @examples
#' \dontrun{
#' library(enviGCMS)
#' data(list)
#' sim <- simmzrt(list$data)
#' }
simmzrt <- function(data, type = "e", npeaks = 1000, ncomp = 0.1,
    ncond = 2, ncpeaks = 0.1, nbatch = 3, nbpeaks = 0.1,
    npercond = 10, nperbatch = c(8, 5, 7), batchtype = 'mb', seed = 42) {
    set.seed(seed)
    batch <- rep(1:nbatch, nperbatch)
    condition <- rep(1:ncond, npercond)
    # check the col numbers
    if (length(batch) != length(condition)) {
        stop("Try to use the same numbers for both batch and condition columns")
    }

    ncol <- length(batch)
    # change the column order
    batch <- batch[sample(ncol)]
    condition <- condition[sample(ncol)]
    # generate the colname
    bc <- paste0("C", condition, "B", batch)
    # get the compounds numbers
    ncomp <- npeaks * ncomp
    # get the matrix
    matrix <- matrix(0, nrow = ncomp, ncol = ncol)
    colnames(matrix) <- bc
    # get the mean, sd, and rsd from the data
    datamean <- apply(data, 1, mean)
    datasd <- apply(data, 1, stats::sd)
    datarsd <- datasd/datamean
    if (type == "e") {
        # generate the distribution from mean and rsd
        pdfmean <- stats::ecdf(datamean)
        pdfrsd <- stats::ecdf(datarsd)
        # simulate the sample mean and rsd from ecdf
        simmean <- as.numeric(stats::quantile(pdfmean,
            stats::runif(ncomp)))
        simrsd <- as.numeric(stats::quantile(pdfrsd, stats::runif(ncomp)))
    } else if (type == "b") {
        # simulate the sample mean and rsd from bootstrap
        simmean <- sample(datamean, ncomp, replace = T)
        simrsd <- sample(datarsd, ncomp, replace = T)
    } else {
        stop("type should be 'e' or 'b'")
    }

    # simulate the data
    for (i in 1:ncomp) {
        samplei <- abs(stats::rnorm(ncol, mean = simmean[i],
            sd = simmean[i] * simrsd[i]))
        matrix[i, ] <- samplei
    }

    # get the multi-peaks
    nmpeaks <- npeaks - ncomp
    indexm <- sample(1:ncomp, nmpeaks, replace = T)
    change <- exp(stats::rnorm(nmpeaks))
    mpeaks <- matrix[indexm, ] * change

    # get the matrix
    matrix0 <- matrix <- rbind(matrix, mpeaks)

    # get the numbers of signal and batch peaks
    ncpeaks <- npeaks * ncpeaks
    nbpeaks <- npeaks * nbpeaks
    # simulation of condition
    index <- sample(1:npeaks, ncpeaks)
    matrixc <- matrix[index, ]
    changec <- NULL
    for (i in 1:ncond) {
        colindex <- condition == i
        change <- exp(stats::rnorm(ncpeaks))
        matrixc[, colindex] <- matrixc[, colindex] * change
        changec <- cbind(changec, change)
    }
    matrix[index, ] <- matrixc
    # simulation of batch
    indexb <- sample(1:npeaks, nbpeaks)
    matrixb <- matrix[indexb, ]
    matrixb0 <- matrix0[indexb, ]
    changeb <- changem <- changer <-  NULL
    # check batch mode
    if(!grepl('m|b|r',batchtype)){
            stop("Batch type should be 'm', 'r' and/or 'b'")
    }
    # generate random batch effect
    if(grepl('r',batchtype)){
            for (i in 1:nrow(matrixb)){
                    change <- abs(stats::rnorm(ncol(matrixb)))
                    matrixb[i,] <- matrixb[i,]*change
                    matrixb0[i,] <- matrixb0[i,]*change
                    changer <- change
            }
    }
    # generate increasing/decreasing batch effect
    if(grepl('m',batchtype)){
            for (i in 1:nrow(matrixb)){
                    changet <- seq(1,ncol(matrixb),length.out = ncol(matrixb)) * exp(stats::rnorm(1))
                    change <- if (sample(c(T,F),1)) changet else rev(changet)
                    matrixb[i,] <- matrixb[i,]*change
                    matrixb0[i,] <- matrixb0[i,]*change
                    changem <- rbind(changem,change)
            }
    }
    # generate block batch effect
    if(grepl('b',batchtype)){
            for (i in 1:nbatch) {
                    colindex <- batch == i
                    change <- exp(stats::rnorm(nbpeaks))
                    matrixb[, colindex] <- matrixb[, colindex] * change
                    matrixb0[, colindex] <- matrixb0[, colindex] *
                            change
                    changeb <- cbind(changeb, change)
            }
    }
    matrix[indexb, ] <- matrixb
    # get peaks mean across the samples
    means <- apply(matrix, 1, mean)
    # get peaks rsd across the samples
    sds <- apply(matrix, 1, stats::sd)
    rsds <- sds/means
    # add row names
    rownames(matrix) <- paste0("P", c(1:npeaks))
    rownames(matrixc) <- paste0("P", index)
    rownames(matrixb0) <- paste0("P", indexb)
    return(list(data = matrix, conp = index, batchp = indexb,
        con = condition, batch = batch, cmatrix = matrixc,
        changec = changec, bmatrix = matrixb0, changeb = changeb,changer = changer, changem = changem,
        matrix = matrix0, compmatrix = matrix[1:ncomp,
            ], mean = means, rsd = rsds))
}
#' Save the simulated data as csv files
#' @param sim list from `mzrtsim` or `simmzrt`
#' @param name file name
#' @seealso \code{\link{mzrtsim}},\code{\link{simmzrt}}
#' @export
simdata <- function(sim, name = "sim") {
    # for metaboanalyst
    data <- rbind.data.frame(sim$con, sim$data)
    filename1 <- paste0(name, "raw.csv")
    utils::write.csv(data, file = filename1)
    # for all
    filename2 <- paste0(name, "raw2.csv")
    data2 <- rbind.data.frame(Label = sim$con, sim$data)
    colnames(data2) <- c(1:ncol(data2))

    utils::write.csv(t(data2), file = filename2)
    # for biological influnced peaks
    filename3 <- paste0(name, "con.csv")
    data3 <- rbind.data.frame(sim$con, sim$batch, sim$cmatrix)
    utils::write.csv(data3, file = filename3)
    # for batch influnced peaks
    filename4 <- paste0(name, "bat.csv")
    data4 <- rbind.data.frame(sim$con, sim$batch, sim$bmatrix)
    utils::write.csv(data4, file = filename4)
    # for batch matrix
    filename5 <- paste0(name, "batchmatrix.csv")
    data5 <- rbind.data.frame(sim$con,sim$batch, sim$matrix)
    utils::write.csv(data5, file = filename5)
    # for compounds
    filename6 <- paste0(name, "comp.csv")
    data6 <- rbind.data.frame(sim$con, sim$batch, sim$compmatrix)
    utils::write.csv(data6, file = filename6)
    # for compounds folds change
    filename7 <- paste0(name, "compchange.csv")
    utils::write.csv(sim$changec, file = filename7)
    # for batch folds change
    filename8 <- paste0(name, "blockbatchange.csv")
    utils::write.csv(sim$changeb, file = filename8)
    # for monotonic change
    filename9 <- paste0(name, "monobatchange.csv")
    utils::write.csv(sim$changem, file = filename9)
}
