#' Perform blood and tissue-resident immune cell identification using Originator
#'
#' @param data Seurat onject (S4 or S5) containing cell types to query. The input data is the integrated data between query and reference data. Make sure cell types are annotated as "Query <celltype name>" and "Ref <celltype name>" in column "annotation_query_ref"
#' @param query_cell_typeGiven "Query <celltype name>" and "Ref <celltype name>" in an input Seurat object, specify query_cell_type as <celltype name>
#' @param plot (Default FALSE) If TRUE, generate relevant plots in the directory specify in output_dir argument
#' @param output_dir If plot = TRUE, output_dir needs to be specified.
#' @return dataframe (N x 2; N = number of query samples): Blood and tissue-resident immune cell identification result is stored in "origin_tb". Row names are query sample IDs.
#' @export
originator.bak <- function(data, query_cell_type, plot = FALSE, output_dir = NA, offset = -0.1) {

  '%!in%' <- function(x,y)!('%in%'(x,y))

  ########### Input handler
  ## Make sure data is in either Seurat V4 or Seurat V5
  if (typeof(data) %!in% c("S4", "S5")) {
    stop("ERROR: Input data is not in an applicable format (S4, S5)")
  }

  ## Make sure`annotation_query_ref` column in available
  if ("annotation_query_ref" %in% colnames(data@meta.data) == FALSE) {
    stop("ERROR: annotation_query_ref is missing in metadata. Make sure to follow the guideline by including Query <celltype> and Ref <celltype> in annotation_query_ref column")
  }

  ## Make sure the output directory is specified if plot = TRUE
  if (plot == TRUE) {
    if (is.na(output_dir)) {
      stop("ERROR: output_dir is missing. If plot == TRUE, output_dir needs to be specified.")
    }
  }

  ## Make sure both Query and Ref cell types are available
  data_meta <- data@meta.data
  data_meta$annotation_query_ref_tmp <- data_meta$annotation_query_ref

  data_meta <- tidyr::separate(data_meta, annotation_query_ref_tmp, sep = " ", c("source", "cell_type"))

  data@meta.data <- data_meta

  # Subset cell type of interest
  data_ct <- subset(data, subset = cell_type == query_cell_type)

  if (("Ref" %in% unique(data_ct$source)) & ("Query" %in% unique(data_ct$source)) == FALSE) {
    stop(paste0("ERROR: Only ", unlist(data_ct$source), " avaialable in the data. Make sure to have both Ref and Query."))
  }

  if(plot == TRUE) {
    print("#### Generate UMAP plot comparing cells from query and reference")
    pdf(file = file.path(output_dir, paste0(query_cell_type, "_UMAP_annotation_query_ref.pdf")), width = 15, height = 6)
    print(Seurat::DimPlot(data_ct, group.by = "annotation_query_ref", split.by = "source"))
    dev.off()
  }

  ########### Prepare colors
  my.break1 <- seq(0, 15)
  my.color1 <- grDevices::colorRampPalette(rev(RColorBrewer::brewer.pal(n = 7, name = "RdYlBu")))(length(my.break1))

  my.break2 <- seq(0, 20)
  my.color2 <- grDevices::colorRampPalette(rev(RColorBrewer::brewer.pal(n = 14, name = "RdYlBu")))(length(my.break1))

  my.break3 <- seq(0, 15)
  my.color3 <- grDevices::colorRampPalette(rev(RColorBrewer::brewer.pal(n = 4, name = "RdYlBu")))(length(my.break1))


  ########### Perform Blood and tissue-resident immune cell separation
  # Extract umap embedding 1-10
  print("#### Extract UMAP embeddings 1-10")

  data_subset_xy <- data_ct[["umap"]]@cell.embeddings
  data_subset_meta <- data_ct[[]]
  data_subset_meta <- data_subset_meta[, c("source", "annotation_query_ref")]
  data_subset_meta <- data_subset_meta[row.names(data_subset_meta), ]
  table(row.names(data_subset_meta) == row.names(data_subset_xy))
  data_subset_meta_2 <- cbind(data_subset_meta, data_subset_xy)

  # Extract cell type of interest
  ct <- query_cell_type
  temp1 <- data_subset_meta_2[grep(ct, data_subset_meta_2$annotation_query_ref), ]

  # Use only cells within range to avoid cluster error
  if (length(offset) == 1) {
    offset <- rep(offset, 4)
  } else if (length(offset) == 2) {
    offset <- c(offset[[1]], offset[[1]], offset[[2]], offset[[2]])
  } else if (length(offset) != 4) {
    stop("offset dimension should be 1, 2 or 4")
  }

  min_umap1 <- min(temp1$UMAP_1) + offset[[1]]
  max_umap1 <- max(temp1$UMAP_1) - offset[[2]]
  min_umap2 <- min(temp1$UMAP_2) + offset[[3]]
  max_umap2 <- max(temp1$UMAP_2) - offset[[4]]

  print(paste0("min_umap1: ", min_umap1))
  print(paste0("max_umap1: ", max_umap1))
  print(paste0("min_umap2: ", min_umap2))
  print(paste0("max_umap2: ", max_umap2))

  temp1 <- temp1[temp1$UMAP_1 > min_umap1 & temp1$UMAP_1 < max_umap1 & temp1$UMAP_2 > min_umap2 & temp1$UMAP_2 < max_umap2, ]

  ref_cid <- row.names(temp1[temp1$source == "Ref", ])
  query_cid <- row.names(temp1[temp1$source == "Query", ])

  temp2 <- as.matrix(temp1[, 3:12])
  print(dim(temp2))
  q <- temp2[query_cid, ]
  r <- temp2[ref_cid, ]
  dist <- sqrt(outer(rowSums(q^2), rowSums(r^2), "+") - 2 * tcrossprod(q, r))
  # dist <- matrix(0, nrow = length(query_cid), ncol = length(ref_cid))
  rownames(dist) <- query_cid
  colnames(dist) <- ref_cid
  # for (i in 1:nrow(q)) {
  #   for (j in 1:nrow(r)) {
  #     # Calculate Euclidean distance between vectors i from q and j from r
  #     d <- sqrt(sum((q[i, ] - r[j, ]) ^ 2))
  #     dist[i, j] <- d
  #   }
  # }
  # print(dist[1:5, 1:5])
  print(dim(dist))
  # stopifnot(F)
  # print(length(query_cid))
  # print(length(ref_cid))
  # temp3 <- as.matrix(dist(temp2))
  # temp4 <- temp3[query_cid, ref_cid]
  # print(dim(temp4))
  # print(temp4[1:5, 1:5])
  # stopifnot(F)
  temp4 <- dist

  # Perform clustering
  print("#### Perform clustering")
  km.res <- kmeans(temp4, 2, nstart = 25)
  km.res2 <- cbind(temp4, cluster = km.res$cluster)
  km.res3 <- km.res2[, "cluster", drop = F]
  km.res3 <- as.data.frame(km.res3)
  km.res3 <- km.res3[order(km.res3$cluster), , drop = F]
  km.res3$cluster <- as.factor(km.res3$cluster)
  temp4 <- temp4[row.names(km.res3), ]

  # Get median distance for each query
  temp4 <- as.data.frame(temp4)
  temp4$dist_median = matrixStats::rowMedians(as.matrix(temp4[,c(-1)]))
  temp5 <- temp4[, "dist_median", drop = F]

  if(plot == TRUE){
    # return(list("temp5" = temp5, "km.res3" = km.res3, color = my.color1, breaks = my.break1))
    print("#### Generate heatmaps of median distance plot between query and reference")
    pdf(file = file.path(output_dir, paste0(ct, "_UMAP_d10_query_ref_dist_median.pdf")), width = 4, height = 6)
    print(pheatmap::pheatmap(temp5, annotation_names_col = FALSE, annotation_names_row = FALSE, show_rownames = FALSE, show_colnames = FALSE, main = paste0(ct), annotation_row = km.res3, cluster_rows = FALSE, cluster_cols = FALSE, color = my.color1, breaks = my.break1))
    dev.off()

  }

  # Assign blood vs. tissue-resident immune cells
  # Cluster with a larger distance to the reference is assigned as tissue-resident immune cells
  # Cluster with a smaller distance to the reference is assigned as blood immune cells

  cluster1_rowMedians <- matrixStats::rowMedians(km.res$centers)[1]
  cluster2_rowMedians <- matrixStats::rowMedians(km.res$centers)[2]

  ##Assign tissue and blood origin based on distance calculated
  km.res3 <- as.data.frame(km.res3, drop = F)
  km.res3$origin_tb <- rep("Null", dim(km.res3)[1])

  if (cluster1_rowMedians > cluster2_rowMedians) {
    km.res3$origin_tb[km.res3$cluster == 1] <- "Tissue"
    km.res3$origin_tb[km.res3$cluster == 2] <- "Blood"
  }
  else if (cluster1_rowMedians < cluster2_rowMedians) {
    km.res3$origin_tb[km.res3$cluster == 1] <- "Blood"
    km.res3$origin_tb[km.res3$cluster == 2] <- "Tissue"
  }
  else if (cluster1_rowMedians == cluster2_rowMedians) {
    stop("ERROR: Two clusters have the same distance to the reference data. Cannot separate blood and tissue-resident immune cells.")
  }

  if (plot == TRUE) {
    saveRDS(km.res3, file.path(output_dir, paste0(ct, "_UMAP_d10_query_ref_dist.rds")))
  }
  return(km.res3)

}

originator <- function(data, query_cell_type, plot = FALSE, output_dir = NA, offset = -0.1) {

  '%!in%' <- function(x,y)!('%in%'(x,y))

  ########### Input handler
  ## Make sure data is in either Seurat V4 or Seurat V5
  if (typeof(data) %!in% c("S4", "S5")) {
    stop("ERROR: Input data is not in an applicable format (S4, S5)")
  }

  ## Make sure`annotation_query_ref` column in available
  if ("annotation_query_ref" %in% colnames(data@meta.data) == FALSE) {
    stop("ERROR: annotation_query_ref is missing in metadata. Make sure to follow the guideline by including Query <celltype> and Ref <celltype> in annotation_query_ref column")
  }

  ## Make sure the output directory is specified if plot = TRUE
  if (plot == TRUE) {
    if (is.na(output_dir)) {
      stop("ERROR: output_dir is missing. If plot == TRUE, output_dir needs to be specified.")
    }
  }

  ## Make sure both Query and Ref cell types are available
  data_meta <- data@meta.data
  data_meta$annotation_query_ref_tmp <- data_meta$annotation_query_ref

  data_meta <- tidyr::separate(data_meta, annotation_query_ref_tmp, sep = " ", c("source", "cell_type"))

  data@meta.data <- data_meta

  # Subset cell type of interest
  data_ct <- subset(data, subset = cell_type == query_cell_type)

  if (("Ref" %in% unique(data_ct$source)) & ("Query" %in% unique(data_ct$source)) == FALSE) {
    stop(paste0("ERROR: Only ", unlist(data_ct$source), " avaialable in the data. Make sure to have both Ref and Query."))
  }

  if(plot == TRUE) {
    print("#### Generate UMAP plot comparing cells from query and reference")
    pdf(file = file.path(output_dir, paste0(query_cell_type, "_UMAP_annotation_query_ref.pdf")), width = 15, height = 6)
    print(Seurat::DimPlot(data_ct, group.by = "annotation_query_ref", split.by = "source"))
    dev.off()
  }

  ########### Prepare colors
  my.break1 <- seq(0, 15)
  my.color1 <- grDevices::colorRampPalette(rev(RColorBrewer::brewer.pal(n = 7, name = "RdYlBu")))(length(my.break1))

  my.break2 <- seq(0, 20)
  my.color2 <- grDevices::colorRampPalette(rev(RColorBrewer::brewer.pal(n = 14, name = "RdYlBu")))(length(my.break1))

  my.break3 <- seq(0, 15)
  my.color3 <- grDevices::colorRampPalette(rev(RColorBrewer::brewer.pal(n = 4, name = "RdYlBu")))(length(my.break1))


  ########### Perform Blood and tissue-resident immune cell separation
  # Extract umap embedding 1-10
  print("#### Extract UMAP embeddings 1-10")
  
  embedding_based <- "umap"
  if(embedding_based == "umap"){
    #### original UMAP-based originator
    message(paste0("#### Using ", embedding_based, "-based Originator"))
    data_subset_xy <- data_ct[["umap"]]@cell.embeddings
  } else if (embedding_based == "pca"){
    #### PCA-version commented below
    message(paste0("#### Using ", embedding_based, "-based Originator"))
    data_subset_xy <- data_ct[["harmony"]]@cell.embeddings
  } else {
    stop("ERROR: Embeddings for originator can be either 'umap' of 'pca")
  }
  
  data_subset_meta <- data_ct[[]]
  data_subset_meta <- data_subset_meta[, c("source", "annotation_query_ref")]
  data_subset_meta <- data_subset_meta[row.names(data_subset_meta), ]
  table(row.names(data_subset_meta) == row.names(data_subset_xy))
  data_subset_meta_2 <- cbind(data_subset_meta, data_subset_xy)

  # Extract cell type of interest
  ct <- query_cell_type
  temp1 <- data_subset_meta_2[grep(ct, data_subset_meta_2$annotation_query_ref), ]

  # # Use only cells within range to avoid cluster error
  # if (length(offset) == 1) {
  #   offset <- rep(offset, 4)
  # } else if (length(offset) == 2) {
  #   offset <- c(offset[[1]], offset[[1]], offset[[2]], offset[[2]])
  # } else if (length(offset) != 4) {
  #   stop("offset dimension should be 1, 2 or 4")
  # }
  #
  # min_umap1 <- min(temp1$UMAP_1) + offset[[1]]
  # max_umap1 <- max(temp1$UMAP_1) - offset[[2]]
  # min_umap2 <- min(temp1$UMAP_2) + offset[[3]]
  # max_umap2 <- max(temp1$UMAP_2) - offset[[4]]
  #
  # print(paste0("min_umap1: ", min_umap1))
  # print(paste0("max_umap1: ", max_umap1))
  # print(paste0("min_umap2: ", min_umap2))
  # print(paste0("max_umap2: ", max_umap2))
  #
  # temp1 <- temp1[temp1$UMAP_1 > min_umap1 & temp1$UMAP_1 < max_umap1 & temp1$UMAP_2 > min_umap2 & temp1$UMAP_2 < max_umap2, ]

  ref_cid <- row.names(temp1[temp1$source == "Ref", ])
  query_cid <- row.names(temp1[temp1$source == "Query", ])

  temp2 <- as.matrix(temp1[, 3:12])
  print(dim(temp2))
  q <- temp2[query_cid, ]
  r <- temp2[ref_cid, ]
  dist <- sqrt(outer(rowSums(q^2), rowSums(r^2), "+") - 2 * tcrossprod(q, r))
  # dist <- matrix(0, nrow = length(query_cid), ncol = length(ref_cid))
  rownames(dist) <- query_cid
  colnames(dist) <- ref_cid
  # for (i in 1:nrow(q)) {
  #   for (j in 1:nrow(r)) {
  #     # Calculate Euclidean distance between vectors i from q and j from r
  #     d <- sqrt(sum((q[i, ] - r[j, ]) ^ 2))
  #     dist[i, j] <- d
  #   }
  # }
  # print(dist[1:5, 1:5])
  print(dim(dist))
  # stopifnot(F)
  # print(length(query_cid))
  # print(length(ref_cid))
  # temp3 <- as.matrix(dist(temp2))
  # temp4 <- temp3[query_cid, ref_cid]
  # print(dim(temp4))
  # print(temp4[1:5, 1:5])
  # stopifnot(F)
  temp4 <- dist

  # Perform clustering
  print("#### Perform clustering")
  km.res <- kmeans(temp4, 2, nstart = 25)
  km.res2 <- cbind(temp4, cluster = km.res$cluster)
  km.res3 <- km.res2[, "cluster", drop = F]
  km.res3 <- as.data.frame(km.res3)
  km.res3 <- km.res3[order(km.res3$cluster), , drop = F]
  km.res3$cluster <- as.factor(km.res3$cluster)
  temp4 <- temp4[row.names(km.res3), ]

  # Get median distance for each query
  temp4 <- as.data.frame(temp4)
  temp4$dist_median = matrixStats::rowMedians(as.matrix(temp4[,c(-1)]))
  temp5 <- temp4[, "dist_median", drop = F]

  if(plot == TRUE){
    # return(list("temp5" = temp5, "km.res3" = km.res3, color = my.color1, breaks = my.break1))
    print("#### Generate heatmaps of median distance plot between query and reference")
    pdf(file = file.path(output_dir, paste0(ct, "_UMAP_d10_query_ref_dist_median.pdf")), width = 4, height = 6)
    print(pheatmap::pheatmap(temp5, annotation_names_col = FALSE, annotation_names_row = FALSE, show_rownames = FALSE, show_colnames = FALSE, main = paste0(ct), annotation_row = km.res3, cluster_rows = FALSE, cluster_cols = FALSE, color = my.color1, breaks = my.break1))
    dev.off()

  }

  # Assign blood vs. tissue-resident immune cells
  # Cluster with a larger distance to the reference is assigned as tissue-resident immune cells
  # Cluster with a smaller distance to the reference is assigned as blood immune cells

  cluster1_rowMedians <- matrixStats::rowMedians(km.res$centers)[1]
  cluster2_rowMedians <- matrixStats::rowMedians(km.res$centers)[2]

  ##Assign tissue and blood origin based on distance calculated
  km.res3 <- as.data.frame(km.res3, drop = F)
  km.res3$origin_tb <- rep("Null", dim(km.res3)[1])

  if (cluster1_rowMedians > cluster2_rowMedians) {
    km.res3$origin_tb[km.res3$cluster == 1] <- "Tissue"
    km.res3$origin_tb[km.res3$cluster == 2] <- "Blood"
  } else if (cluster1_rowMedians < cluster2_rowMedians) {
    km.res3$origin_tb[km.res3$cluster == 1] <- "Blood"
    km.res3$origin_tb[km.res3$cluster == 2] <- "Tissue"
  } else if (cluster1_rowMedians == cluster2_rowMedians) {
    stop("ERROR: Two clusters have the same distance to the reference data. Cannot separate blood and tissue-resident immune cells.")
  }

  if (plot == TRUE) {
    saveRDS(km.res3, file.path(output_dir, paste0(ct, "_UMAP_d10_query_ref_dist.rds")))
  }
  return(km.res3)

}

source("./src/DataLoader.R")

Originator <- R6::R6Class(
  classname = "Originator",
  public = list(
    config = NULL,
    dataLoader = NULL,
    initialize = function(config) {
      self$config <- config
      self$dataLoader <- DataLoader$new(self$config)
    },
    run = originator
  )
)
