
project_downsampled_inds_scale <- function(x, destruction_level, drop_groups = c('Papuan', 'Russian'), context = context_info, pca_rest = NULL, ret.pca_rest = F) {
  drop_ind <- which(context$Group_Name %in% drop_groups)
  
  ## get data for "dropped inds"
  geno_matrix_drop_ind <- x[drop_ind,] %>% shoot_holes(destruction_level)
  dim(geno_matrix_drop_ind)
  # print(geno_matrix_drop_ind[1:2, 1:10])
  context_info_drop_ind <- context %>% dplyr::filter(Group_Name %in% drop_groups)
  context_info_drop_ind$projected <- 'projected'
  
  ## get data for rest
  geno_matrix_rest <- x[-drop_ind,]
  dim(geno_matrix_rest)
  context_info_rest <- context %>% dplyr::filter(!Group_Name %in% drop_groups)
  context_info_rest$projected <- 'pca'
  
  ## do pca for inds that are not downsampled
  if (is.null(pca_rest)) {
    pca_rest <- prcomp(geno_matrix_rest[, colSums(geno_matrix_rest) > 0], scale. = T)
    ## allow the function to just return the pca for non-downsampled inds, which is static
    if (ret.pca_rest) return(pca_rest)
  }
  
  for (ind in 1:nrow(geno_matrix_drop_ind)) {
    cat('projecting', ind, '\n')
    # print(dim(geno_matrix_drop_ind))
    keep_sites <- !is.na(geno_matrix_drop_ind[ind,]) & colSums(geno_matrix_rest) > 0
    keep_sites_scale <- !is.na(geno_matrix_drop_ind[ind,colSums(geno_matrix_rest) > 0])
    # print(length(keep_sites))
    # print(pca_rest$scale)
    # print(length(pca_rest$scale))
    pca_drop_ind <- scale(matrix(geno_matrix_drop_ind[ind, keep_sites], nrow = 1),
                          pca_rest$center[keep_sites_scale],
                          pca_rest$scale[keep_sites_scale]) %*% pca_rest$rotation[keep_sites_scale, ]
    # print(pca_drop_ind[,1:5])
    pca_drop_ind <- pca_drop_ind * length(keep_sites) / sum(keep_sites)
    # print(pca_drop_ind[,1:5])
    pca_rest$x <- rbind(pca_rest$x, pca_drop_ind)
    context_info_rest <- rbind(context_info_rest, context_info_drop_ind[ind,])
  }
  
  ## clean up results
  pnf_tidy_drop_ind <- tidy_pca_output(pca_rest, context_info_rest)
  pnf_tidy_drop_ind <- pnf_tidy_drop_ind %>% dplyr::mutate(downsample = destruction_level)
  pnf_tidy_drop_ind
}


project_downsampled_inds <- function(x, destruction_level, drop_groups = c('Papuan', 'Russian'), context = context_info, pca_rest = NULL, ret.pca_rest = F) {
  drop_ind <- which(context$Group_Name %in% drop_groups)
  
  ## get data for "dropped inds"
  geno_matrix_drop_ind <- x[drop_ind,] %>% shoot_holes(destruction_level)
  dim(geno_matrix_drop_ind)
  # print(geno_matrix_drop_ind[1:2, 1:10])
  context_info_drop_ind <- context %>% dplyr::filter(Group_Name %in% drop_groups)
  context_info_drop_ind$projected <- 'projected'
  
  ## get data for rest
  geno_matrix_rest <- x[-drop_ind,]
  dim(geno_matrix_rest)
  context_info_rest <- context %>% dplyr::filter(!Group_Name %in% drop_groups)
  context_info_rest$projected <- 'pca'
  
  ## do pca for inds that are not downsampled
  if (is.null(pca_rest)) {
    pca_rest <- prcomp(geno_matrix_rest)
    ## allow the function to just return the pca for non-downsampled inds, which is static
    if (ret.pca_rest) return(pca_rest)
  }
  
  cat('projecting: ')
  for (ind in 1:nrow(geno_matrix_drop_ind)) {
    cat(' ', ind)
    keep_sites <- !is.na(geno_matrix_drop_ind[ind,])
    pca_drop_ind <- scale(matrix(geno_matrix_drop_ind[ind, keep_sites], nrow = 1),
                          pca_rest$center[keep_sites],
                          pca_rest$scale) %*% pca_rest$rotation[keep_sites, ]
    # print(pca_drop_ind[,1:5])
    pca_drop_ind <- pca_drop_ind * length(keep_sites) / sum(keep_sites)
    # print(pca_drop_ind[,1:5])
    pca_rest$x <- rbind(pca_rest$x, pca_drop_ind)
    context_info_rest <- rbind(context_info_rest, context_info_drop_ind[ind,])
  }
  cat(' done.\n')
  
  ## clean up results
  pnf_tidy_drop_ind <- tidy_pca_output(pca_rest, context_info_rest)
  pnf_tidy_drop_ind <- pnf_tidy_drop_ind %>% dplyr::mutate(downsample = destruction_level)
  pnf_tidy_drop_ind
}

explore_filling_method <- function(x, f, destruction_level, ...) {
  x %>% shoot_holes_column_wise(destruction_level) %>% f(...) %>%
    prcomp() %>% tidy_pca_output() %>% plot_tidy_pca_simple()
}

shoot_holes <- function(x, prop) {
  nr_cells <- prod(dim(x))
  holes <- sample(seq_len(nr_cells), size = round(prop * nr_cells))
  x[holes] <- NA
  return(x)
}

shoot_holes_column_wise <- function(x, prop) {
  nr_holes_per_column <- round((prop * prod(dim(x)))/ncol(x))
  apply(x, 2, function(y) {
    holes <- sample(seq_along(y), size = nr_holes_per_column)
    y[holes] <- NA
    y
  })
}

tidy_pca_output <- function(x, context = context_info) {
  pnf_tidy_obs <- x$x %>%
    tibble::as_tibble() %>%
    dplyr::bind_cols(context)

  ## rotate to give it all the same orientation
  j_pc1 <- pnf_tidy_obs %>% dplyr::filter(Group_Name == 'Japanese') %>% dplyr::select(PC1)
  m_pc1 <- pnf_tidy_obs %>% dplyr::filter(Group_Name == 'Mbuti') %>% dplyr::select(PC1)
  f_pc1 <- pnf_tidy_obs %>% dplyr::filter(Group_Name == 'French') %>% dplyr::select(PC1)
  if (nrow(m_pc1) < 1) { 
    if (0 > f_pc1[1,]) pnf_tidy_obs <- pnf_tidy_obs %>% dplyr::mutate(PC1 = -PC1)
  } else {
    if (m_pc1[1,] < j_pc1[1,]) pnf_tidy_obs <- pnf_tidy_obs %>% dplyr::mutate(PC1 = -PC1)
  }
  
  ## rotate to give it all the same orientation
  f_pc2 <- pnf_tidy_obs %>% dplyr::filter(Group_Name == 'French') %>% dplyr::select(PC2)
  m_pc2 <- pnf_tidy_obs %>% dplyr::filter(Group_Name == 'Mbuti') %>% dplyr::select(PC2)
  if (nrow(m_pc1) < 1) { 
    if (0 > f_pc2[1,]) pnf_tidy_obs <- pnf_tidy_obs %>% dplyr::mutate(PC2 = -PC2)
  } else {
    if (m_pc2[1,] > f_pc2[1,]) pnf_tidy_obs <- pnf_tidy_obs %>% dplyr::mutate(PC2 = -PC2)
  }
  
  pnf_tidy_obs
}
# explore_filling_method(geno_matrix, missMethods::impute_mean, 0.2)

#####

## use.labels can be all or projected

plot_tidy_pca_simple <- function(x, text_geom = geom_text, use.labels = 'none', ...) {suppressWarnings({
  if (!"iter" %in% colnames(x)) {
    x$iter <- NA
  }
  p <- ggplot() + 
    geom_point(
      data = x,
      mapping = aes(x = PC1, y = PC2, colour = Makro_Region, frame = iter),
      size = 3
    ) +
    NULL
  if ("downsample" %in% colnames(x)) {
    p <- p + geom_text(
      data = x %>% dplyr::mutate(PC1 = min(PC1), PC2 = min(PC2)) %>% dplyr::group_by(iter) %>% dplyr::sample_n(1),
      mapping = aes(x = PC1, y = PC2, label = sprintf('Remove %g%%', downsample*100), frame = iter),
      size = 5,
      vjust = -1.2, hjust = -0.1
    )
  }
  if (use.labels == 'all') {
    p <- p + 
      text_geom(
        data = x,
        mapping = aes(x = PC1, y = PC2, label = Group_Name, frame = iter),
        size = 3,
        ...
      ) 
  }
  if (use.labels == 'projected') {
    p <- p + 
      text_geom(
        data = x %>% dplyr::filter(projected == 'projected'),
        mapping = aes(x = PC1, y = PC2, label = Group_Name, frame = iter),
        size = 3,
        ...
      ) 
  }
  if ('projected' %in% colnames(x)) {
    # cat('labeling projected samples')
    p <- p +
      geom_point(
        data = x %>% dplyr::filter(projected == 'projected'),
        mapping = aes(x = PC1, y = PC2, frame = iter),
        size = 1,
        color='red'
      )
  }
  p
})}

plot_tidy_pca_density <- function(x, text_geom = geom_text) {
  p0 <- plot_tidy_pca_simple(x, text_geom)
  xdens <- cowplot::axis_canvas(p0, axis = "x") +
    geom_density(
      data = x,
      aes(x = PC1, fill = Makro_Region),
      alpha = 0.7
    )
  ydens <- cowplot::axis_canvas(p0, axis = "y", coord_flip = TRUE) +
    geom_density(
      data = x,
      aes(x = PC2, fill = Makro_Region),
      alpha = 0.7
    ) +
    coord_flip()
  p1 <- cowplot::insert_xaxis_grob(p0, xdens, grid::unit(.2, "null"), position = "top")
  p2 <- cowplot::insert_yaxis_grob(p1, ydens, grid::unit(.2, "null"), position = "right")
  cowplot::ggdraw(p2)
}