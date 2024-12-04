# state-delegation-scorecards

Purpose:

This project aims to show a general breakdown of each state's House delegation and their effectiveness. This results in a Shiny app that allows users to see the number of bills introduced per house member for each state. Users can also see a full list of a state's House members by clicking on that state. Additional characteristics, such as a member's party, district, and count of sponsored bills, are also shown.

Use:
This project is broken into two distinct portions. The first is the script named scraping-and-APIs.qmd. This script is used to generate the data required to build the shiny app. The script also creates a local DB file that stores the extracted data. It's highly recommended that you use the DB file currently in the repository; the extraction script takes around an hour to run in full. However, using this script may be necessary for analyzing congressional sessions other than the 117th. 

The second script is located in the "app" folder and is used to build the Shiny app. This script calls the local DB object and builds the Shiny app off of the data gathered from it. Note that some issues may arise if you run through the extraction script manually. To avoid these issues, you may need to manually copy the new DB file into the app folder itself. A solution to this will be pushed out shortly.

Future Improvements:
As time allows, improvements to user operability will be made. This will include adding additional datapoints to the graph. Work is also being done to get the data working for Vermont.

Additional improvements include a restructuring of the project format for ease of use. This is not critical but will be pushed shortly.

Finally, in the mid-future, the scraping script will be re-formatted so that users can more easily specify the congressional session to extract from. This is easily possible in its current state, but could be improved. I will also be pushing out the local DB files of the extracted data for the 116th, 115th, and beyond. This will allow users to see historic representations of these data. The Shiny app will similarly be improved to allow users to specify this congress.