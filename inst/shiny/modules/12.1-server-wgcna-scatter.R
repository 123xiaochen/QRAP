

output$trait <- renderUI({
  pickerInput(
    inputId = "trait", label = "Select interested trait:",
    choices = colnames(traitDataTab()), selected = colnames(traitDataTab())[1],
    multiple = F, width = "100%", options = list(`live-search` = TRUE, size = 5)
  )
})

output$wgcna_scatter_module <- renderUI({
  pickerInput(
    inputId = "wgcna_scatter_module", label = "Select interested module:",
    choices = moduleColors() %>% unique, selected = (moduleColors() %>% unique)[1],
    multiple = F, width = "100%", options = list(`live-search` = TRUE, size = 5)
  )
})

verboseScatter <- eventReactive(input$plot_wgcna_scatter, {
  trait_condition = as.data.frame(traitDataTab()[, input$trait])
  names(trait_condition) = input$trait

  MEs0 = WGCNA::moduleEigengenes(datExpr(), moduleColors())$eigengenes
  MEs = WGCNA::orderMEs(MEs0)

  modNames = substring(names(MEs), 3)

  nSamples <- dim(datExpr())[1]
  geneModuleMembership = as.data.frame(cor(datExpr(), MEs, use = "p"))
  MMPvalue = as.data.frame(WGCNA::corPvalueStudent( as.matrix(geneModuleMembership), nSamples))

  names(geneModuleMembership) = paste("MM", modNames, sep="");
  names(MMPvalue) = paste("p.MM", modNames, sep="");

  geneTraitSignificance = as.data.frame(WGCNA::cor(datExpr(), trait_condition, use = "p"));
  GSPvalue = as.data.frame(WGCNA::corPvalueStudent(as.matrix(geneTraitSignificance), nSamples));

  names(geneTraitSignificance) = paste("GS.", names(trait_condition), sep="");
  names(GSPvalue) = paste("p.GS.", names(trait_condition), sep="");

  module = input$wgcna_scatter_module
  column = match(module, modNames);
  moduleGenes = moduleColors() == module;

  if (input$WGCNA_scatter_method=='verboseScatterplot (WGCNA function)') {
    par(mar=c(5,5,5,5))
    WGCNA::verboseScatterplot(abs(geneModuleMembership[moduleGenes, column]),
                       abs(geneTraitSignificance[moduleGenes, 1]),
                       xlab = paste("Module Membership in", module, "module"),
                       ylab = paste("Gene significance for ", input$trait),
                       main = paste("Module membership vs. gene significance\n"),
                       cex = input$wgcna_scatter_cex, cex.main = input$wgcna_scatter_main,
                       cex.lab = input$wgcna_scatter_lab, cex.axis = input$wgcna_scatter_axis, col = module)
  }else {
    x = abs(geneModuleMembership[moduleGenes, column])
    y = abs(geneTraitSignificance[moduleGenes, 1])
    corFnc = "cor"
    corOptions = "use = 'p'"
    displayAsZero = 1e-05
    corLabel = corFnc
    main = paste("Module membership vs. gene significance\n")

    x = as.numeric(as.character(x))
    y = as.numeric(as.character(y))
    corExpr = parse(text = paste(corFnc, "(x, y ", WGCNA::prepComma(corOptions), ")"))

    cor = signif(eval(corExpr), 2)
    if (is.finite(cor))
      if (abs(cor) < displayAsZero)
        cor = 0
    corp = signif(WGCNA::corPvalueStudent(cor, sum(is.finite(x) & is.finite(y))), 2)

    if (is.finite(corp) && corp < 10^(-200)) {
      corp = "<1e-200"
    }else{
      corp = paste("=", corp, sep = "")
    }
    if (!is.na(corLabel)) {
      mainX = paste(main, " ", corLabel, "=", cor, if (is.finite(cor)) {WGCNA::spaste(", p", corp)} else {""}, sep = "")
    }else {
      mainX = main
    }

    if (grepl("white", module)) {
      pch <- 1
      cols <- "black"
    }else {
      pch <- 16
      cols <- module
    }
    p <- ggplot()+
      geom_point(aes(x = x, y = y), color = cols, size = input$wgcna_scatter_size, alpha = input$wgcna_scatter_alpha, pch = pch)+
      labs(x = paste("Module Membership in", module, "module"),
           y = paste("Gene significance for", input$trait), title = mainX)+
      theme_bw()+
      theme(plot.title = element_text(hjust = 0.5), text = element_text(size = input$wgcna_scatter_fontsize))
    
    if (nchar(input$wgcna_scatter_ggText) != 0) {
      add_funcs <- strsplit(input$wgcna_scatter_ggText, "\\+")[[1]]
      p <- p + lapply(add_funcs, function(x){
        eval(parse(text = x))
      })
    }
    return(p)
  }
})

output$verboseScatter <- renderPlot({
  verboseScatter()
})

output$render_wgcna_scatter_height <- renderUI({
  if (input$WGCNA_scatter_method=='verboseScatterplot (WGCNA function)') {
    sliderInput("wgcna_scatter_height", "Figure Height (px):", min = 200, max = 1000, value = 542, step = 2, width = "100%")
  }else {
    sliderInput("wgcna_scatter_height", "Figure Height (px):", min = 200, max = 1000, value = 512, step = 2, width = "100%")
  }
})

output$verboseScatterUI <- renderUI({
  req(input$wgcna_scatter_width, input$wgcna_scatter_height)
  withSpinner(plotOutput("verboseScatter", width = paste0(input$wgcna_scatter_width, "%"), height = paste0(input$wgcna_scatter_height, "px")))
})

output$verboseScatter_Pdf <- downloadHandler(
  filename = function()  {paste0("WGCNA_GS-MM-verboseScatterplot",".pdf")},
  content = function(file) {
    
    trait_condition = as.data.frame(traitDataTab()[, input$trait])
    names(trait_condition) = input$trait

    MEs0 = WGCNA::moduleEigengenes(datExpr(), moduleColors())$eigengenes
    MEs = WGCNA::orderMEs(MEs0)

    modNames = substring(names(MEs), 3)

    nSamples <- dim(datExpr())[1]
    geneModuleMembership = as.data.frame(WGCNA::cor(datExpr(), MEs, use = "p"))
    MMPvalue = as.data.frame(WGCNA::corPvalueStudent( as.matrix(geneModuleMembership), nSamples))

    names(geneModuleMembership) = paste("MM", modNames, sep="");
    names(MMPvalue) = paste("p.MM", modNames, sep="");

    geneTraitSignificance = as.data.frame(WGCNA::cor(datExpr(), trait_condition, use = "p"));
    GSPvalue = as.data.frame(WGCNA::corPvalueStudent(as.matrix(geneTraitSignificance), nSamples));

    names(geneTraitSignificance) = paste("GS.", names(trait_condition), sep="");
    names(GSPvalue) = paste("p.GS.", names(trait_condition), sep="");

    module = input$wgcna_scatter_module
    column = match(module, modNames);
    moduleGenes = moduleColors() == module;

    if (input$WGCNA_scatter_method=='verboseScatterplot (WGCNA function)') {
      pdf(file, width = input$verboseScatter_width, height = input$verboseScatter_height)
      par(mar=c(5,5,5,5))
      WGCNA::verboseScatterplot(abs(geneModuleMembership[moduleGenes, column]),
                         abs(geneTraitSignificance[moduleGenes, 1]),
                         xlab = paste("Module Membership in", module, "module"),
                         ylab = paste("Gene significance for ", input$trait),
                         main = paste("Module membership vs. gene significance\n"),
                         cex = input$wgcna_scatter_cex, cex.main = input$wgcna_scatter_main,
                         cex.lab = input$wgcna_scatter_lab, cex.axis = input$wgcna_scatter_axis, col = module)
      dev.off()
    }else {
      x = abs(geneModuleMembership[moduleGenes, column])
      y = abs(geneTraitSignificance[moduleGenes, 1])
      corFnc = "cor"
      corOptions = "use = 'p'"
      displayAsZero = 1e-05
      corLabel = corFnc
      main = paste("Module membership vs. gene significance\n")

      x = as.numeric(as.character(x))
      y = as.numeric(as.character(y))
      corExpr = parse(text = paste(corFnc, "(x, y ", WGCNA::prepComma(corOptions), ")"))

      cor = signif(eval(corExpr), 2)
      if (is.finite(cor))
        if (abs(cor) < displayAsZero)
          cor = 0
      corp = signif(WGCNA::corPvalueStudent(cor, sum(is.finite(x) & is.finite(y))), 2)

      if (is.finite(corp) && corp < 10^(-200)) {
        corp = "<1e-200"
      }else{
        corp = paste("=", corp, sep = "")
      }
      if (!is.na(corLabel)) {
        mainX = paste(main, " ", corLabel, "=", cor, if (is.finite(cor)) {WGCNA::spaste(", p", corp)} else {""}, sep = "")
      }else {
        mainX = main
      }

      if (grepl("white", module)) {
        pch <- 1
        cols <- "black"
      }else {
        pch <- 16
        cols <- module
      }
      p <- ggplot()+
        geom_point(aes(x = x, y = y), color = cols, size = input$wgcna_scatter_size, alpha = input$wgcna_scatter_alpha, pch = pch)+
        labs(x = paste("Module Membership in", module, "module"),
             y = paste("Gene significance for", input$trait), title = mainX)+
        theme_bw()+
        theme(plot.title = element_text(hjust = 0.5), text = element_text(size = input$wgcna_scatter_fontsize))
      
      if (nchar(input$wgcna_scatter_ggText) != 0) {
        add_funcs <- strsplit(input$wgcna_scatter_ggText, "\\+")[[1]]
        p <- p + lapply(add_funcs, function(x){
          eval(parse(text = x))
        })
      }
      ggsave(file, plot = p, width = input$verboseScatter_width, height = input$verboseScatter_height, limitsize = F)
    }
  }
)

