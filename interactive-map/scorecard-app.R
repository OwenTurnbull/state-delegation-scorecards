################################################################################
# Set-up
################################################################################
library(shiny)
library(ggplot2)
library(plotly)
library(sf)
library(dplyr)
library(tigris)
library(DBI)
library(usmap)
library(htmltools)

# Database setup and query to get representative data
con <- dbConnect(SQLite(), "state-delegation-scorecards.db")


################################################################################
# Initialize data.frames
################################################################################

# Member biographies:
bio_query <- "SELECT bioguide_id, state, display_name, party_affiliation, district 
  FROM 'house_member_bios.tbl'"
member_bios <- dbGetQuery(con, bio_query)

# Number of bills sponsored:
sponsors_query <- "SELECT bill_number, bioguide_id, sponsor_status FROM 
  'bill_sponsors.tbl'"
bill_sponsors <- dbGetQuery(con, sponsors_query) %>%
  filter(sponsor_status == "S") %>%
  group_by(bioguide_id) %>%
  summarise(tot_sponsored = n()) %>%
  as.data.frame()

# Merge biographies and bills sponsored
members_data <- left_join(member_bios, bill_sponsors, by = join_by(bioguide_id))
members_data$state <- toupper(trimws(members_data$state))

################################################################################
# Additional fields and other transformations
################################################################################

##### Fields for state-level pop-up:

# Weighted count of bills (# of bills / # of members)
state_bill_counts <- members_data %>%
  group_by(state) %>%
  summarise(tot_bills = sum(tot_sponsored, na.rm = TRUE), 
            tot_members = n_distinct(bioguide_id)) %>%
  mutate(weighted_bills = round((tot_bills / tot_members), 1)) %>%
  as.data.frame()



##### Combine with US map .json file
us_states_geojson <- st_read("us-states.json")
us_states_geojson$NAME <- toupper(trimws(us_states_geojson$NAME))

# Merge state bill counts with GeoJSON data
us_states_geojson <- left_join(us_states_geojson, state_bill_counts, by = c("NAME" = "state"))



################################################################################
# Create the shiny app
################################################################################
library(shiny)
library(leaflet)
library(dplyr)

# Define UI
ui <- fluidPage(
  titlePanel("US House of Representatives Members"),
  
  # Add custom CSS for scroll-able popups
  tags$head(
    tags$style(HTML("
      .popup-content {
        max-height: 300px; /* Set the height limit for the popup */
        overflow-y: auto;  /* Allow vertical scrolling */
      }
    "))
  ),
  
  # Resize the map
  leafletOutput("us_map", width = "100%", height = "800px"),  
  verbatimTextOutput("hover_info")
)

# Define server logic
server <- function(input, output, session) {
  
  # Create the map using
  output$us_map <- renderLeaflet({
    
    # Define a continuous color scale based on the weighted bill count
    color_pal <- colorNumeric(
      palette = "YlGnBu",  # Color palette: Yellow-Green-Blue
      domain = us_states_geojson$weighted_bills  # Based on weighted bills (avg per member)
    )
    
    # Create HTML for state overview labels
    state_labels <- paste(
      "<strong>", us_states_geojson$NAME,
      "</strong><br>Bills per Member:", us_states_geojson$weighted_bills,
      "</strong><br>Total Bills Introduced:", us_states_geojson$tot_bills,
      "</strong><br>Total Members:", us_states_geojson$tot_members) %>%
      lapply(htmltools::HTML)
    
    # Generate the map
    leaflet() %>%
      addTiles() %>%
      addPolygons(
        data = us_states_geojson,  # Use the GeoJSON data for state boundaries
        fillColor = ~color_pal(weighted_bills),  # Color states by weighted bills (avg per member)
        weight = 1,
        color = "white",
        opacity = 0.5,
        dashArray = "3",
        fillOpacity = 0.7,
        highlight = highlightOptions(weight = 3, color = "blue", fillOpacity = 0.7),
        #label = ~state_hover_html()$hover_content[match(NAME, state_hover_html()$NAME)],
        label = state_labels,
        labelOptions = labelOptions(html = TRUE),
        layerId = ~NAME  # Set unique ID for each state (state name)
      ) %>%
      # Add the legend for the continuous scale
      addLegend(
        position = "bottomright",  # Position of the legend
        pal = color_pal,  # The color scale
        values = us_states_geojson$weighted_bills,  # The values used for the scale
        title = "Bills per Member",  # Title of the legend
        opacity = 1  # Set the opacity of the legend
      )
  })
  
  # Function to display member data when clicking on a state
  observeEvent(input$us_map_shape_click, {
    state_name <- input$us_map_shape_click$id
    
    # Filter the members data for the clicked state
    members_in_state <- members_data %>% filter(state == state_name)
    
    # Generate HTML content as a string
    if (nrow(members_in_state) == 0) {
      content <- paste0("<h4>State: ", state_name, "</h4><br>No members found for this state.")
    } 
    else {
      members_list <- paste0(
        "<h4>State: ", state_name, "</h4><br><b>Members of Congress:</b><ul>",
        paste0(
          lapply(1:nrow(members_in_state), function(i) {
            paste0("<li>", members_in_state$display_name[i], " (", members_in_state$party_affiliation[i], ", District ", members_in_state$district[i], ")</li>")
          }),
          collapse = ""
        ),
        "</ul>"
      )
      content <- paste0("<div class='popup-content'>", members_list, "</div>")
    }
    
    # Add the popup
    leafletProxy("us_map") %>%
      clearPopups() %>%
      addPopups(
        lng = input$us_map_shape_click$lng,  # Longitude of clicked point
        lat = input$us_map_shape_click$lat,  # Latitude of clicked point
        popup = content,  # Pass the HTML string content
        layerId = state_name,  # Use state name as the layerId to uniquely identify the popup
        options = popupOptions(maxWidth = 400)
      )
  })
}

shinyApp(ui = ui, server = server)