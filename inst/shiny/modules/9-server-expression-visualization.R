##-----------------Update The geneExpr panel----------------------------##
observe({
  if (input$nDegsp | input$pWGCNA_1) {
    updateTabsetPanel(session = session, inputId = 'mainMenu', selected = "epv")
  }
})


output$expr_groupby <- renderUI({
  colNames <- colnames(as.data.frame(dds()@colData))
  selectInput(
    inputId = "expr_groupby", label = "Group for summarise data:", width = "100%",
    choices = colNames[!colNames %in% c("samples", "sizeFactor", "replaceable")]
  )
})


output$expr_group <- renderUI({
  req(input$expr_groupby, dds())
  virtualSelectInput(
    inputId = "expr_group",  label = "Select group to plot:",
    choices = dds()@colData[, input$expr_groupby] %>% unique %>% as.character,
    selected = dds()@colData[, input$expr_groupby] %>% unique %>% as.character,
    multiple = TRUE, search = TRUE, width = "100%"
  )
  # 
  # selectInput(inputId = "expr_group", label = "Select group to plot:", 
  #             choices = dds()@colData[, input$expr_groupby] %>% unique %>% as.character,
  #             selected = dds()@colData[, input$expr_groupby] %>% unique %>% as.character, multiple = T, width = "100%")
})

output$expr_de_group <- renderUI({
  virtualSelectInput(
    inputId = "expr_de_group",  label = "Groups Of Differential Expressed Genes::",
    choices = dir("DEGs") %>% stringr::str_remove_all(".csv"),
    selected = dir("DEGs") %>% stringr::str_remove_all(".csv"),
    multiple = TRUE, search = TRUE, width = "100%"
  )
  # 
  # selectInput(
  #   inputId = "expr_de_group", label = "Groups Of Differential Expressed Genes:",
  #   choices = dir("DEGs") %>% stringr::str_remove_all(".csv"),
  #   selected = dir("DEGs") %>% stringr::str_remove_all(".csv"),
  #   width = "100%", multiple = T
  # )
})

observeEvent(input$get_DEGs,{
  updateSelectInput(
    session = session, inputId = "expr_de_group",
    choices = dir("DEGs") %>% stringr::str_remove_all(".csv")
  )
})

output$expr_plotType <- renderUI({
  if (input$data_use == "log2flc") {
    ch <- c("BarPlot", "DotPlot", "Heatmap")
  }else {
    ch <- c("BarPlot", "BoxPlot", "Heatmap")
  }
  prettyRadioButtons(
    inputId = "expr_plotType", label = "Plot type:",
    choices = c("BarPlot", "BoxPlot", "Heatmap"), icon = icon("check"),
    status = "info", animation = "jelly", inline = TRUE, width = "100%")
  # radioButtons("expr_plotType", "Plot type:", choices = c("BarPlot", "BoxPlot", "Heatmap"), inline = T, width = "100%")
})

observe({
  if (input$data_use == "log2flc") {
    updatePrettyRadioButtons(
      session = session, inputId = "expr_plotType", choices = c("BarPlot", "DotPlot", "Heatmap"), 
      inline = TRUE, prettyOptions = list(icon = icon("check"), status = "info", animation = "jelly", width = "100%")
    )
  }
})

##-----------------Plotting genes expression----------------------------##
Expr_plot <- eventReactive(input$plot_geneExpr,{
  
  if (grepl("\n", input$input_gene)) {
    genes <- strsplit(input$input_gene, "\n")[[1]] %>% unique
  }else if (grepl(",", input$input_gene)) {
    genes <- strsplit(input$input_gene, ",")[[1]] %>% unique
  }else {
    genes <- input$input_gene %>% unique
  }
  
  matched_genes <- genes[genes %in% rownames(trans_value())]
  if (length(matched_genes) != length(genes)) {
    sendSweetAlert(title = "warning", type = "warning", 
                   text = paste0("Can not find input genes: '", genes[!genes %in% matched_genes], "'", "please check your input!"))
  }
  
  if (input$data_use == "log2flc") {
    ResList <- load.REGs(input$expr_de_group)
    if (input$expr_plotType == "BarPlot" | input$expr_plotType == "DotPlot") {
      data <- lapply(names(ResList), function(x){
        df <- ResList[[x]][genes[genes %in% rownames(ResList[[x]])], c("padj", "log2FoldChange")]
        df$group <- x
        df$genes <- df %>% rownames
        return(df)
      }) %>% dplyr::bind_rows()

      data$padj[is.na(data$padj)] <- 1
      data <- tidyr::drop_na(data)
      data$padj <- -log10(data$padj)

      data$group <- factor(data$group, levels = input$expr_de_group)
      data$genes <- factor(data$genes, levels = genes[genes %in% data$genes])

      if (input$expr_plotType == "BarPlot") {
        if (input$Expr_split == TRUE) {
          p <- ggplot(data = data, aes(x = group, y = log2FoldChange, fill = group))+
            geom_bar(stat = "identity", position = "dodge")+
            facet_wrap(~genes, ncol = input$Expr_cols, scales = "free")+
            theme_bw()
        }else {
          if (length(data$genes %>% unique) == 1) {
            p <- ggplot(data = data, aes(x = group, y = log2FoldChange, fill = group))
          }else {
            p <- ggplot(data = data, aes(x = genes, y = log2FoldChange, fill = group))
          }
          p <- p + geom_bar(stat = "identity", position = "dodge")+
            theme_classic()
        }
      }else if (input$expr_plotType == "DotPlot") {
        p <- ggplot(data = data, aes(x = group, y = genes))+
          geom_point(aes(size = padj, col = log2FoldChange))+
          scale_color_gradient2(low = "blue", mid = "white", high = "red")+
          labs(col = "Log2 FoldChange", size = "-Log10 Padj")+
          theme_classic()
      }

      p <- p + theme(axis.text.x = element_text(angle = 45, hjust = 1))

      if (nchar(input$exprs_ggText) != 0) {
        add_funcs <- strsplit(input$exprs_ggText, "\\+")[[1]]
        p <- p + lapply(add_funcs, function(x){
          eval(parse(text = x))
        })
      }
      return(p)
    }else {
      lfc_mat <- lapply(names(ResList), function(x){
        df <- data.frame(row.names = rownames(ResList[[x]]), lfc = ResList[[x]][, "log2FoldChange"])
        colnames(df) <- x
        return(df)
      }) %>% dplyr::bind_cols()
      rownames(lfc_mat) <- rownames(ResList[[1]])
      data <- lfc_mat[genes[genes %in% rownames(lfc_mat)], names(ResList)]
      color = colorRampPalette(strsplit(input$exprsh_color, ",")[[1]])(100)
      pheatmap::pheatmap(data, col=color,
               cluster_col=F, cluster_row=input$cluster_row,
               scale = 'none', show_rownames = T,
               fontsize = input$exprsh_fontsize,
               show_colnames = input$exprsh_colname,
               breaks=seq(input$Expr_break[1], input$Expr_break[2], (input$Expr_break[2] - input$Expr_break[1])/100),
               treeheight_row = input$exprsh_treeheight_row,
               angle_col = input$exprsh_angle %>% as.integer)
      # if (input$expr_plotType == "Heatmap") {
      #   data <- lfc_mat[rownames(lfc_mat) %in% genes, ]
      #   color = colorRampPalette(strsplit(input$exprsh_color, ",")[[1]])(100)
      #   pheatmap(data, col=color,
      #            cluster_col=F, cluster_row=input$cluster_row,
      #            scale = 'none', show_rownames = T,
      #            fontsize = input$exprsh_fontsize,
      #            show_colnames = input$exprsh_colname,
      #            breaks=seq(input$Expr_break[1], input$Expr_break[2], (input$Expr_break[2] - input$Expr_break[1])/100),
      #            treeheight_row = input$exprsh_treeheight_row,
      #            angle_col = input$exprsh_angle %>% as.integer)
      # }else {
      #   pca <- prcomp(t(lfc_mat),scale = FALSE)
      #   pca.var <- pca$sdev^2
      #   pca.var.per <- round(pca.var/sum(pca.var)*100,1)
      #   pca.data <- data.frame(Groups=rownames(pca$x),X=pca$x[,1],Y=pca$x[,2])
      #
      #   p <- ggplot(data = pca.data,aes(x=X,y=Y,col=Groups))+
      #     geom_point()+
      #     xlab(paste("PC1 - ",pca.var.per[1],"%",sep = ""))+
      #     ylab(paste("PC2 - ",pca.var.per[2],"%",sep = ""))+
      #     theme_classic()
      #
      #   if (nchar(input$exprs_ggText != 0)) {
      #     add_funcs <- strsplit(input$exprs_ggText, "\\+")[[1]]
      #     p <- p + lapply(add_funcs, function(x){
      #       eval(parse(text = x))
      #     })
      #   }
      #   return(p)
      # }
    }
  }else {
    if (input$data_use == "rel_value") {
      data <- log2(norm_value() + 1) %>% as.data.frame()
      # data <- counts(dds(), normalized=TRUE) %>% as.data.frame()
      # data <- log2(data + 1)
      # if (input$batch_methods != 'NULL') {
      #   data <- remove.Batch(expr.data = data, designTable = subset(dds()@colData, select = -sizeFactor),
      #                        key_words = input$batch_col, design = "condition", method = input$batch_methods)
      # }
    }else if(input$data_use == "trans_value"){
      data <- SummarizedExperiment::assay(trans_value()) %>% as.data.frame()
    }else if(input$data_use == "norm_value"){
      data <- norm_value() %>% as.data.frame()
      # data <- counts(dds(), normalized=TRUE) %>% as.data.frame()
      # if (input$batch_methods != 'NULL') {
      #   data <- remove.Batch(expr.data = data, designTable = subset(dds()@colData, select = -sizeFactor),
      #                        key_words = input$batch_col, design = "condition", method = input$batch_methods)
      # }
    }

    # sampleTable <- as.data.frame(colData(dds()))[dds()$condition %in% input$expr_group, ]
    # rownames(sampleTable) <- sampleTable$samples
    # colNames <- sampleTable$samples
    sampleTable <- subset_Tab(dds(), vars = input$expr_groupby, selected = input$expr_group)

    Sub_data <- data[genes[genes %in% rownames(data)], sampleTable$samples] %>% as.matrix
    if (dim(Sub_data)[1] == 0) {
      return(NULL)
      # stop("No genes can match to expression data, please check your input, or this genes were filtered out beacause they are low expression genes.")
    }

    Mel_data <- Sub_data %>% reshape2::melt()
    colnames(Mel_data) <- c("genes", "samples", "expr_value")
    Mel_data["Groups"] = sampleTable[Mel_data$samples, input$expr_groupby]
    Sum_data <- Rmisc::summarySE(Mel_data, measurevar = "expr_value", groupvars=c("Groups", "genes"), conf.interval = 0.95)
    Sum_data$Groups <- factor(Sum_data$Groups, levels = input$expr_group)
    Sum_data$genes <- factor(Sum_data$genes, levels = genes[genes %in% Sum_data$genes])

    for (i in 1:dim(Sum_data)[1]) {
      if (Sum_data[i, "expr_value"] < 0) {
        Sum_data[i, c("sd", "se", "ci")] <- Sum_data[i, c("sd", "se", "ci")] * -1
      }
    }

    if (input$expr_plotType=="BarPlot") {
      dodge <- position_dodge(width = 1)

      if (isTRUE(input$Expr_split)) {
        p <- ggplot(data=Sum_data, aes(x=Groups, y=expr_value, fill=Groups))+
          facet_wrap(~genes, ncol = input$Expr_cols, scales = "free")
      }else {
        p <- ggplot(data=Sum_data, aes(x=genes, y=expr_value, fill=Groups))
      }

      if (input$Expr_error == "se") {
        p <- p + geom_errorbar(aes(ymin=expr_value - expr_value * 0.1, ymax=expr_value+se), position=dodge, width=0.5, lwd = input$Expr_error_lwd)
      }else if(input$Expr_error == "sd"){
        p <- p + geom_errorbar(aes(ymin=expr_value - expr_value * 0.1, ymax=expr_value+sd), position=dodge, width=0.5, lwd = input$Expr_error_lwd)
      }else {
        p <- p + geom_errorbar(aes(ymin=expr_value - expr_value * 0.1, ymax=expr_value+ci), position=dodge, width=0.5, lwd = input$Expr_error_lwd)
      }

      p <- p + geom_bar(stat = 'identity', position=dodge)+
        ylab('Normalized expression values')+
        theme_bw()+
        theme(axis.text.x = element_text(angle = 45, hjust = 1))

      if (nchar(input$exprs_ggText) != 0) {
        add_funcs <- strsplit(input$exprs_ggText, "\\+")[[1]]
        p <- p + lapply(add_funcs, function(x){
          eval(parse(text = x))
        })
      }
      return(p)
    }else if (input$expr_plotType=="BoxPlot") {
      if (isTRUE(input$Expr_split)) {
        p <- ggplot(data=Mel_data, aes(x=Groups, y=expr_value, fill=Groups))+
          geom_boxplot()+
          ylab('Normalized expression values')+
          theme_bw()+
          facet_wrap(~genes, ncol = input$Expr_cols, scales = "free")+
          theme(axis.text.x = element_text(angle = 45, hjust = 1))
      }else {
        p <- ggplot(data=Mel_data, aes(x=genes, y=expr_value, fill=Groups))+
          geom_boxplot()+
          ylab('Normalized expression values')+
          theme_bw()
      }

      if (nchar(input$exprs_ggText) != 0) {
        add_funcs <- strsplit(input$exprs_ggText, "\\+")[[1]]
        p <- p + lapply(add_funcs, function(x){
          eval(parse(text = x))
        })
      }
      return(p)
    }else {
      annotation_col = data.frame(condition = factor(sampleTable$condition, levels = sampleTable$condition %>% unique))
      rownames(annotation_col) = sampleTable$samples
      # color = colorRampPalette(c("navy", "white", "red"))(50)
      color = colorRampPalette(strsplit(input$exprsh_color, ",")[[1]])(100)
      if (isTRUE(input$exprsh_colanno)) {
        annotation_col <- annotation_col
      }else {
        annotation_col <- NA
      }
      pheatmap::pheatmap(Sub_data, col=color,
                         cluster_col=F, cluster_row=input$cluster_row,
                         scale = input$exprsh_scale, show_rownames = T,
                         fontsize = input$exprsh_fontsize,
                         show_colnames = input$exprsh_colname,
                         breaks=seq(input$Expr_break[1], input$Expr_break[2], (input$Expr_break[2] - input$Expr_break[1])/100),
                         annotation_col=annotation_col,
                         treeheight_row = input$exprsh_treeheight_row,
                         angle_col = input$exprsh_angle %>% as.integer)
    }
  }
})

output$geneExpr_plot <- renderPlot({
  Expr_plot()
})

output$epv_plotUI <- renderUI({
  withSpinner(plotOutput("geneExpr_plot", width = paste0(input$epv_plot_width, "%"), height = paste0(input$epv_plot_height, "px")))
})

output$geneExpr_Pdf <- downloadHandler(
  filename = function()  {paste0("Genes_expression_plots",".pdf")},
  content = function(file) {
    p <- Expr_plot()
    ggsave(file, p, width = input$geneExpr_width, height = input$geneExpr_height)
  }
)
