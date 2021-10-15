
---
  categories:
  - ""
- ""
date: "2017-10-31T22:26:09-05:00"
description:
  draft: false
image: inflation.jpeg
keywords: ""
slug: me
title:Inflation and CPI analysis  
---
  
  1. We scrape the FRED website and pull all of the CPI components into a vector.
```{r, scape CPI data}
library(rvest)
url <- "https://fredaccount.stlouisfed.org/public/datalist/843"

tables <- url %>% 
  read_html() %>% 
  html_nodes(css="table")

cpi <- map(tables, . %>% 
             html_table(fill=TRUE)%>% 
             janitor::clean_names()) 

cpi_id = cpi[[2]]$series_id

```

2. Once we have a vector of components, you can then pass it to `tidyquant::tq_get(get = "economic.data", from =  "2000-01-01")` to get all data since January 1, 2000
```{r, get all data since January 1, 2000}
cpi_data <- tidyquant::tq_get(cpi_id, get = "economic.data", from =  "2000-01-01")
```


3. Since the data you download is an index with various starting dates, we need to calculate the yearly, or 12-month change. To do this we need to use the `lag` function, and specifically, `year_change = value/lag(value, 12) - 1`; this means that we are comparing the current month's value with that 12 months ago lag(value, 12).
```{r, calculate year change}
cpi_data_clean <- cpi_data %>% pivot_wider(id_cols=1:3, 
               names_from="symbol", 
               values_from = "price")

#Make date the index to make mutate_all work
cpi_data_clean1 <- cpi_data_clean %>% 
     remove_rownames() %>%
     column_to_rownames(var = 'date')

#Define Function
Funk <- function(x, na.rm = FALSE) (x/lag(x, 12) - 1)

#Apply functions to all columns into new dataset
cpi_changes <- cpi_data_clean1 %>%  mutate_all(
  Funk
)

```

Below we format the graph

4. We order components so the higher the yearly change, the earlier does that component appear.
5. We also make sure that the **All Items** CPI (CPIAUCSL) appears first.
6. We then add a `geom_smooth()` for each component to get a sense of the overall trend.
7  Finally, we colour the points according to whether yearly change was positive or negative. 

```{r, format the graph, fig.width=15, fig.height=12}
# Make date back as first column for pivot_longer
cpi_changes <- cbind("Date" = rownames(cpi_changes), cpi_changes)

cpi_changes_graph <- cpi_changes %>% 
  pivot_longer(cols=2:50, 
               names_to="Component", 
               values_to = "YoY")

cpi_changes_graph <- cpi_changes_graph %>% mutate(
  Neg = (YoY<=0)
)

cpi_changes_graph$Date <- as.Date(cpi_changes_graph$Date, "%Y-%m-%d")

# Get our order of components by max descending (excl. All Items)
cpi_order <- cpi_changes_graph %>%
  filter(Date>="2016-01-01") %>%
  filter(Component != "CPIAUCSL") %>% 
  group_by(Component) %>% 
  summarise(max_YoY = max(YoY,na.rm=TRUE)) %>% 
  arrange(-max_YoY)

# Put the all items at the start (append)
order = c(cpi_order$Component)
order = append("CPIAUCSL", order)
order

cpi_changes_graph %>%
  filter(Date>="2016-01-01") %>% 
  group_by(Component) %>% 
  mutate(
    max_cpi = max(YoY)
  )
  
# Graph
cpi_changes_graph %>%
  filter(Date>="2016-01-01") %>% 
  ggplot(aes(Date, YoY)) + 
  geom_point(size=1, aes(colour = Neg)) +
  geom_smooth(se=F, colour="grey") +
  facet_wrap(~factor(Component, levels = order),scales="free")+
  scale_y_continuous(labels = scales::percent)+
  scale_x_date(breaks = as.Date(c("2016-01-01", "2018-01-01","2020-01-01")), labels=c("2016", "2018", "2020"),
               minor_breaks = as.Date(c("2016-01-01", "2018-01-01",
                                        "2020-01-01")))+
  theme_bw()+
  theme(legend.title = element_blank(),legend.position = "none",
        axis.text.x = element_text(size=5, colour = "black"), 
    axis.text.y = element_text(size=5, colour = "black"),
    plot.title = element_text(size=14, face= "bold", colour= "black"),
    plot.subtitle = element_text(size=10, colour= "black"),
    axis.title.x = element_text(size=10, colour = "black"),    
    axis.title.y = element_text(size=10, colour = "black"))+
  
  labs(title="Yearly change of US CPI (All Items) and its components", 
       subtitle = "Year on year change being positive or negative
Jan 2016 to Aug 2021", 
       x="Year", 
       y="YoY % Change")

                     
                     
```
