# counts2pca.shinyapp
# A R/shiny tool to plot pca from raw-count data
# from a Nucleomics Core MS-Excel RNASeq count file

library("shiny")
library("shinyBS")
library("openxlsx")
library("DT")
library("RColorBrewer")
library("PCAtools")

# you may uncomment the next line to allow large input files
options(shiny.maxRequestSize=1000*1024^2)
# the following test checks if we are running on shinnyapps.io to limit file size dynamically
# ref: https://stackoverflow.com/questions/31423144/how-to-know-if-the-app-is-running-at-local-or-on-server-r-shiny/31425801#31425801
#if ( Sys.getenv('SHINY_PORT') == "" ) { options(shiny.maxRequestSize=1000*1024^2) }

app.name <- "counts2pca"
script.version <- "beta"

# Define UI for application that draws a histogram
ui <- fluidPage(
  HTML('<style type="text/css">
    .row-fluid { width: 20%; }
       .well { background-color: #99CCFF; }
       .shiny-html-output { font-size: 14px; line-height: 15px; }
       </style>'),
  # Application header
  headerPanel("Create a PCA plot from RNASeq raw-counts"),

  # Application title
  titlePanel(
    windowTitle = "RNASeq PCA plot",
    tags$a(href="https://corefacilities.vib.be/nc", target="_blank",
           img(src='logo.png', align = "right", width="150", height="58.5", alt="VIB Nucleomics Core"))
  ),

  # Sidebar with input
  sidebarLayout(
    # show file import and molecule filters
    sidebarPanel(
      tags$h5(paste(app.name, " version: ", script.version, sep="")),
      downloadButton("downloadData", label = "Download test data"),
      tags$br(),
      tags$a(href="license.pdf", target="_blank", "usage licence"),
      tags$br(),
      tags$a(href="javascript:history.go(0)", tags$i("reset page content"), alt="Reset page"),
      tags$hr(),
      tipify(fileInput('file1', 'Choose RNASeq XLSX File', accept='.xlsx'),
             "the Data is a MS-Excel file provided by the Nucleomics Core, with worksheet#2 reporting gene expression (count), you may produce a compatible file based on the test data provided here."),
      tags$h4("Edit settings & click ", tags$em("Plot")),
      actionButton(inputId='goButton', "Plot", style='padding:4px; font-weight: bold; font-size:150%'),
      textInput('title', "Plot Title:", value="PCA plot"),
      selectInput("format", "Output format (png or pdf):", c("png", "pdf"), selected="png"),
      textInput('outfile', "name for output File:", value="my_pca"),
      downloadButton('downloadPlot', 'Download Plot'),
      tipify(downloadButton('downloadMM', 'Download M&M'),"Download a text including the names and versions of all packages used in this webtool")
    ),

    # Show a plot of the generated distribution
    mainPanel(
      plotOutput('pca.plot', width = "100%"),
      br(),
      textOutput('data.cnt'),
      br(),
      div(DT::dataTableOutput("data.table"), style = "font-size: 75%; width: 75%")
    )
  )

  # end UI block
  )

# Define server logic required to draw a histogram
server <- function(input, output) {

  output$downloadData <- downloadHandler(
    filename <- function() { paste("expXXXX-RNAseqCounts", "xlsx", sep=".") },
    content <- function(file) { file.copy("www/expXXXX-RNAseqCounts.xlsx", file) }
  )

  output$downloadGroupings <- downloadHandler(
    filename <- function() { paste("sample_groups.txt", "txt", sep=".") },
    content <- function(file) { file.copy("www/sample_groups.txt", file) }
  )

  count.data <- reactive({
    inFile <- input$file1

    if (is.null(inFile)) return(NULL)

    # load data from excel file (raw counts tab = 1)
    dat <- read.xlsx(inFile$datapath, sheet=1)

    # keep only data columns (remove last columns including "Chromosome")
    chromosome.col <- which(colnames(dat)==as.vector("Chromosome"))
    
    # reorder columns to be genename, ensemblID, [data-columns]
    count.data <- dat[,c(3:(chromosome.col-1))]

    # kick end part of samples names @bla@bla
    # colnames(count.data) <- sub("@.*", "", colnames(count.data))
    # one@two@S23@GTACTGAT@AGCTAGCT
    # the following variables can be selected by the user
    mergechar <- "_"
    first.to.merge <- 1
    last.to.merge <- 3
    colnames(count.data) <- paste0(
      unlist(
        strsplit(colnames(count.data), "@")
        )[first.to.merge:last.to.merge], 
      collapse=mergechar)
    
    # return data as 'count.data()'
    count.data
  })

  sample.groups <- reactive({
    inFile <- input$file2
    
    if (is.null(inFile)) return(NULL)
    
    # read signature ID list
    sample.groups <- read.table(col.names = inFile$datapath, 
                                sep="\t", 
                                col.names = c("sampleID", "group"),
                                header=FALSE)
    sample.groups
  })
  
  output$data.cnt <- reactive({
    if (is.null(count.data())) return("Waiting for data!")

    paste("Rows in the imported data: ", nrow(count.data()))
  })

  data <- eventReactive({input$goButton | input$obs}, {
    # do nothing in absence of data
    if (is.null(count.data())) return(NULL)
  
    count.data <- as.data.frame(count.data())

    # return data
    data
    })

  output$data.table = DT::renderDataTable({
    if (is.null(count.data())) return(NULL)
    count.data()
  })

  compute.pca <- reactive({
    if (is.null(count.data())) return(NULL)
    
  })
  
  output$pca.plot <- renderPlot({
    if (is.null(count.data())) return(NULL)
    # the PCA plotting code comes here
    # the PCA is sent to the plotting area of the UI
  })

  output$downloadPlot <- downloadHandler(
    filename =  function() {
      paste(input$outfile, input$format, sep=".")
    },
    # content is a function with argument file. content writes the plot to file
    content = function(file) {
      # save the plot to file
      # this may require replotting but with a file name in the command
    })

  output$downloadMM <- downloadHandler(
    filename = function() {
      paste(input$outfile, "_session_info.txt", sep="")
    },
    content = function(file) {
      sink(file, append=TRUE)
      cat(paste("Thanks for using our tool", app.name, script.version, "\n", sep=" "))
      cat ("This tool generates a PCA , bla bla")
      cat (" bla bla bla")
      cat("\nYou can contact The Nucleomics Core at nucleomics@vib.be for any question\n")
      cat(paste("This data was generated on ", format(Sys.time(), "%a %b %d %H:%M:%S %Y"), "\n",sep=" "))
      cat("\nThe R packages used in the tools are listed next:\n")
      print(capture.output(sessionInfo()))
      sink()
    }
  )

  # end server block
  }

# Run the application
shinyApp(ui = ui, server = server)
