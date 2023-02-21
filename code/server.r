server <- function(input,output, session){
  #Reactive list variable 
  values <- reactiveValues(masterFrame = NULL,numReadings = NULL)
  #Upload Project File
  upload <- observeEvent(eventExpr = input$inputFile,
                         handlerExpr = {
                           # Declaring variables
                           req(input$inputFile)
                           pathlengths <- c(unlist(strsplit(input$pathlengths,",")))
                           molStateVal <<- input$molState
                           wavelengthVal <<- as.numeric(input$wavelength)
                           helix <<- trimws(strsplit(input$helixInput,",")[[1]],which="both")
                           blank <<- as.numeric(input$blankSample)
                           if (molStateVal == "Heteroduplex") {
                             molStateVal <<- "Heteroduplex.2State"
                           } else if (molStateVal == "Homoduplex") {
                             molStateVal <<- "Homoduplex.2State"
                           }else{
                             molStateVal <<- "Monomolecular.2State"
                           }
                           removeUI(
                             selector = "div:has(> #helixInput)"
                           )
                           removeUI(
                             selector = "div:has(> #molState)"
                           )
                           fileName <- input$inputFile$datapath
                           cd <- read.csv(file = fileName,header = FALSE)
                           df <- cd %>% select_if(~ !any(is.na(.)))
                           # Creating temporary frame to store sample data
                           columns <- c("Sample", "Pathlength", "Temperature", "Absorbance")
                           tempFrame <- data.frame(matrix(nrow = 0, ncol = 4))
                           colnames(tempFrame) <- columns
                           readings <- ncol(df)
                           # Loop that appends sample data 
                           p <- 1
                           for (x in 2:readings) {
                             col <- df[x]
                             sample <- rep(c(counter),times = nrow(df[x]))
                             pathlength <- rep(c(as.numeric(pathlengths[p])),times = nrow(df[x]))
                             col <- df[x]
                             t <- data.frame(sample,pathlength,df[1],df[x])
                             names(t) <- names(tempFrame)
                             tempFrame <- rbind(tempFrame, t)
                             p <- p + 1
                             counter <<- counter + 1
                           }
                           values$numReadings <- counter - 1
                           values$masterFrame <- rbind(values$masterFrame, tempFrame)
                           myConnecter <<- connecter(df = values$masterFrame,
                                                     NucAcid = helix,
                                                     Mmodel = molStateVal,
                                                     blank = blank)
                           myConnecter$constructObject()
                           calculations <<- myConnecter$gatherVantData()
                           vals <<- reactiveValues(
                             keeprows = rep(TRUE, nrow(calculations)))
                         }
  )
  #Outputs the post-processed data frame
  output$Table <- renderTable({
    return(values$masterFrame)})
  
  #Hides "Analysis" and "Results tabs until file successfully uploads
  observeEvent(
    eventExpr = is.null(values$numReadings),
    handlerExpr = {
      hideTab(inputId = "navbar",target = "Analysis")
      hideTab(inputId = "navbar",target = "Results")
    }
  )
  
  
  #Creates n tabPanels for the "Analysis" tabPanel
  observe({
    req(values$numReadings)
    lapply(start:values$numReadings,function(i){
      if (i != blank) {
        data = values$masterFrame[values$masterFrame$Sample == i,]
        n = myConnecter$getFirstDerivativeMax(i)
        bounds = myConnecter$getSliderBounds(i,n)
        xmin = round(min(data$Temperature),4)
        xmax = round(max(data$Temperature),4)
        #output elements
        plotBoth = paste0("plotBoth",i)
        plotBestFit = paste0("plotBestFit",i)
        plotFit = paste0("plotFit",i)
        plotName = paste0("plot",i)
        plotSlider <- paste0("plotSlider",i)
        plotDerivative = paste0("plotDerivative",i)
        #Check box  and tab Panel variables
        firstDerivative = paste0("firstDerivative",i)
        bestFit = paste0("bestFit",i)
        tabName = paste("Sample",i,sep = " ")
        appendTab(inputId = "tabs",
                  tab = tabPanel(
                    tabName,
                    fluidPage(
                      sidebarLayout(
                        sidebarPanel(
                          #side-panel code
                          h2("Features"),
                          checkboxInput(inputId = bestFit,label = "Best Fit"),
                          checkboxInput(inputId = firstDerivative,label = "First Derivative"),
                          conditionalPanel(
                            condition = glue("{xmin} == {bounds[[1]][1]}"),
                            p("Warning: Lower bound exceeds minimum x-value of data. Positioning lower-end bar as the minimum value of the data")
                          ),
                          conditionalPanel(
                            condition = glue("{xmax} == {bounds[[2]][1]}"),
                            p("Warning: Upper bound exceeds maximum x-value of data. Positioning uupper-end bar as the maximum value of the data",color="Red")
                          )
                        ),mainPanel(
                          #main-panel code
                          conditionalPanel(
                            condition = glue("!input.{firstDerivative} && !input.{bestFit}"),
                            plotOutput(plotName)
                          ),
                          conditionalPanel(
                            condition = glue("input.{firstDerivative} && !input.{bestFit}"),
                            plotOutput(plotDerivative)
                          ),
                          conditionalPanel(
                            condition = glue("input.{bestFit} && !input.{firstDerivative}"),
                            plotOutput(plotBestFit)
                          ),
                          conditionalPanel(
                            condition = glue("input.{firstDerivative} && input.{bestFit}"),
                            plotOutput(plotBoth)
                          ),
                          sliderInput(plotSlider,
                                      glue("Plot{i}: Range of values"),
                                      min = xmin,
                                      max = xmax,
                                      value = c(bounds[[1]][1],bounds[[2]][1]),
                                      round = TRUE,
                                      step = .10,
                                      width = "85%")
                        )
                      )
                    )
                  ))
      }
    })
    start <<- values$numReadings + 1
    showTab(inputId = "navbar",target = "Analysis")
    showTab(inputId = "navbar",target = "Results")
  })
  
  #Dynamically creates a renderPlot object of each absorbance readings
  observe({
    req(input$inputFile)
    for (i in 1:values$numReadings) {
      if (i != blank) {
        local({
          myI <- i 
          plotDerivative = paste0("plotDerivative",myI)
          plotBestFit = paste0("plotBestFit",myI)
          plotBoth = paste0("plotBoth",myI)
          plotName = paste0("plot",myI)
          plotSlider = paste0("plotSlider",myI)
          #plot containing raw data
          output[[plotName]] <- renderPlot({
            myConnecter$constructRawPlot(myI) +
              geom_vline(xintercept = input[[plotSlider]][1]) +
              geom_vline(xintercept = input[[plotSlider]][2])
          })
          #plot containing first derivative with raw data
          output[[plotDerivative]] <- renderPlot({
            myConnecter$constructFirstDerivative(myI) +
              geom_vline(xintercept = input[[plotSlider]][1]) +
              geom_vline(xintercept = input[[plotSlider]][2])
          })
          #plot containing best fit with raw data
          output[[plotBestFit]] <- renderPlot({
            myConnecter$constructBestFit(myI) + 
              geom_vline(xintercept = input[[plotSlider]][1]) +
              geom_vline(xintercept = input[[plotSlider]][2])
          })
          #plot containing best, first derivative, and raw data
          output[[plotBoth]] <- renderPlot({
            myConnecter$constructBoth(myI) + 
              geom_vline(xintercept = input[[plotSlider]][1]) +
              geom_vline(xintercept = input[[plotSlider]][2])
          })
        })
      }
    }
  })
  
  #code that plots a van't hoff plot
  output$vantplots <- renderPlot({
    #Plot the kept and excluded points as two seperate data sets
    keep    <- calculations[ vals$keeprows, , drop = FALSE]
    exclude <- calculations[!vals$keeprows, , drop = FALSE]
    
    ggplot(keep, aes(x = invT, y = lnCt )) + geom_point() +
      geom_smooth(method = lm, fullrange = TRUE, color = "black") +
      geom_point(data = exclude, shape = 21, fill = NA, color = "black", alpha = 0.25)
    
  }, res = 100)
  
  # Toggle points that are clicked
  observeEvent(input$vantClick, {
    res <- nearPoints(calculations, input$vantClick, allRows = TRUE)
    
    vals$keeprows <- xor(vals$keeprows, res$selected_)
  })
  
  # Toggle points that are brushed, when button is clicked
  observeEvent(input$exclude_toggle, {
    res <- brushedPoints(calculations, input$vantBrush, allRows = TRUE)
    
    vals$keeprows <- xor(vals$keeprows, res$selected_)
  })
  
  # Reset all points
  observeEvent(input$exclude_reset, {
    vals$keeprows <- rep(TRUE, nrow(calculations))
  })
  
  #Code that outputs the results table
  
  output$resulttable <- renderTable({
    data <-myConnecter$fitData()
    return(data)
  })
  output$summarytable <- renderTable({
    data <-myConnecter$summaryData1()
    return(data)
  })
  output$summarytable2 <- renderTable({
    data <-myConnecter$summaryData2()
    return(data)
  })
  output$error <- renderTable({
    data <-myConnecter$error()
    return(data)
  })
  output$downloadReport <- downloadHandler(
    filename = function(){paste(input$dataset, '.pdf', sep = '')},
    
    content = function(file){
      cairo_pdf(filename = file, onefile = T,width = 18, height = 10, pointsize = 12, family = "sans", bg = "transparent",
                antialias = "subpixel",fallback_resolution = 300)
      caluclations <- myConnecter$gatherVantData()
      InverseTemp <- caluclations$invT
      LnConcentraion <- caluclations$lnCt
      plot(LnConcentraion,InverseTemp)
      dev.off()
    },
    contentType = "application/pdf"
  )
  #save the data tables
  output$downloadExcelSheet <- downloadHandler(
    filename = function() {
      paste(input$saveFile, '.xlsx', sep='')
    },
    content = function(file) {
      # write workbook and first sheet
      write.xlsx(myConnecter$summaryData1(), file, sheetName = "table1", append = FALSE)
      
      write.xlsx(myConnecter$summaryData2(), file, 
                 sheetName = "table2", append = TRUE)
      write.xlsx(myConnecter$error(), file, 
                 sheetName = "error", append = TRUE)
    }
  )
}
