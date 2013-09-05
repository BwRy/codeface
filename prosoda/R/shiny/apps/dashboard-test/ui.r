## This file is part of prosoda.  prosoda is free software: you can
## redistribute it and/or modify it under the terms of the GNU General Public
## License as published by the Free Software Foundation, version 2.
##
## This program is distributed in the hope that it will be useful, but WITHOUT
## ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
## FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
## details.
##
## You should have received a copy of the GNU General Public License
## along with this program; if not, write to the Free Software
## Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
##
## Copyright 2013 by Siemens AG, Wolfgang Mauerer <wolfgang.mauerer@siemens.com>
## All Rights Reserved.

##
## Software Project Dashboard (ui.r) 
##
library(shinyGridster)
source('gridsterWidgetsExt.r')

shinyUI(bootstrapPage(

	tags$head(
	  
		## Adapt the styles as needed (some seem to be ignored)
		tags$link(rel = 'stylesheet', type = 'text/css', href = 'styles.css'),
		tags$script(src = "gridsterWidgetsExt.js"),
    tags$script(src = "jquery.cookie.js")
	),
  
	div(class = "container",
    div(class = "row",
	    breadcrumbOutput("quantarchBreadcrumb"),
# 		  #tags$div(textOutput("testid")),
 			div( class="span2", style = "padding: 10px 0px;",
            gridsterButton("gridsterActionMenu","addWidgetDialog") )
 			),
		div(class = "row",
			div(class = "span12",
				gridster(width = 250, height = 250))
			)
		)
	))
