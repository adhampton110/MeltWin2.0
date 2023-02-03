Contains working MeltWin2.0 code.
The purpose of this application is to easily and consistently fit data to obtain thermodynamic parameters. This uses the MeltR library to do all calculations. The goal is to add a graphical user interface to make our application work closer to how MeltWin, MeltR's predecessor, does. This means adding an easy to use graphical user interface to it.

To run our code you need to download R and RStudio. First go to this website, https://cran.r-project.org/ , and follow the instructions for your machine to install R. Next follow this link to download RStudio: https://posit.co/download/rstudio-desktop/ . Scroll down to the bottom and find the RStudio download link needed for your machine and click the link to download it. 
Next you will need a few packages to run the code. Open RStudio and in the console at the bottom type this: install.packages(c('MeltR', 'shiny', 'dplyr', 'ggplot2', 'glue', 'methods'))
Then download our code from the git repository and open the files in RStudio. Once they are open you can hit Run App in the top right corner of the console to run the app. 
