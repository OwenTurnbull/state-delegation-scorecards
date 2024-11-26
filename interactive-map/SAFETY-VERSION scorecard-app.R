# Setup
library(shiny)
library(ggplot2)
library(plotly)
library(sf)
library(dplyr)
library(tigris)
library(DBI)
library(usmap)

################################################################################
# Pull in data for the app
################################################################################
#Import and cleanse the map data
#should eventually remove the full path name from this
us_states_geojson <- st_read("/Users/owenturnbull/src/state-delegation-scorecards/us-states.json")
us_states_geojson$NAME <- toupper(trimws(us_states_geojson$NAME))

# Database setup and query to get representative data
con <- dbConnect(SQLite(), "state-delegation-scorecards.db")
query <- "SELECT state, display_name, party_affiliation, district FROM 'house_member_bios.tbl'"

#This is just base data of member info; doesn't include bill passage, etc. data yet
members_data <- dbGetQuery(con, query)
members_data$state <- toupper(trimws(members_data$state)) #capitalize state names, so as to ensure it matches w/ the geoJSON

#other important queries should go here; in theory it would be nice to have the
#shiny app automatically pull from the DB, but this is likely not going to happen
#since it would require a lot of time that I don't have







################################################################################
# Create the shiny app
################################################################################
library(shiny)
library(leaflet)
library(dplyr)

  # Define UI
ui <- fluidPage(
  titlePanel("US House of Representatives Members"),
  # Resize the map
  leafletOutput("us_map", width = "100%", height = "800px"),  # Set height and width
  verbatimTextOutput("hover_info")
)
  
# Define server logic
server <- function(input, output, session) {
  
  # Create the map using GeoJSON data
  output$us_map <- renderLeaflet({
    leaflet() %>%
      addTiles() %>%
      addPolygons(
        data = us_states_geojson,  # Use the GeoJSON data for state boundaries
        fillColor = "lightblue",
        weight = 1,
        color = "white",
        opacity = 0.5,
        dashArray = "3",
        fillOpacity = 0.7,
        highlight = highlightOptions(weight = 3, color = "blue", fillOpacity = 0.7),
        label = ~NAME,  # Label state name when hovered
        layerId = ~NAME  # Set unique ID for each state (state name)
      )
  })
  
  # Function to display member data when clicking on a state
  observeEvent(input$us_map_shape_click, {
    state_name <- input$us_map_shape_click$id
    
    # Filter the members data for the clicked state
    members_in_state <- members_data %>% filter(state == state_name)
    
    # Generate HTML content for the state popups
    if (nrow(members_in_state) == 0) {
      content <- paste0("<h4>State: ", state_name, "</h4><br>No members found for this state.")
    } else {
      members_list <- paste0(
        "<h4>State: ", state_name, "</h4><br><b>Members of Congress:</b>",
        "<div style='max-height: 200px; overflow-y: scroll; padding-right: 10px;'>",  # Makes popup scrollable
        "<ul>",
        paste0(
          lapply(1:nrow(members_in_state), function(i) {
            paste0("<li>", members_in_state$display_name[i], " (", members_in_state$party_affiliation[i], ", District ", members_in_state$district[i], ")</li>")
          }),
          collapse = ""
        ),
        "</ul></div>"
      )
      content <- members_list
    }
    
    # Add the popup directly
    leafletProxy("us_map") %>%
      clearPopups() %>%
      addPopups(
        lng = input$us_map_shape_click$lng,
        lat = input$us_map_shape_click$lat,
        popup = content,  # Pass the HTML string content
        layerId = state_name,  # Use state name as the layerId to uniquely identify the popup
        options = popupOptions(maxWidth = 400)  # Control popup size
      )
  })
}



shinyApp(ui = ui, server = server)