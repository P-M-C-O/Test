#!/bin/bash
SERIES_URLa="https://thetvdb.com/series/"
SERIES_URLb="/seasons/official/"
SERIES_BASE_DIR="/media/Data/Series/ShowsLib/"
SERIES_DIR=$1
SERIES_NAME=""
SERIES_YEAR=""
SEASON=""
SEASON_PAGE=""
EPISODE_LIST=""
EPISODE_LIST_SEASON=""
DATE_LIST=""
DATE_LIST_SEASON=""
DIRS=""
RSS_FILE=""
RSS_FILE_NAME=""



: <<COMMENT

get_season_page_table() {
  SEASON_PAGE=$(wget -qO - "$SERIES_URLa""$SERIES_NAME""-""$SERIES_YEAR""$SERIES_URLb""$SEASON")
  if [ $? -eq 8 ]; then
    SEASON_PAGE=$(wget -qO - "$SERIES_URLa""$SERIES_NAME""$SERIES_URLb""$SEASON")
    if [ $? -eq 8 ]; then
      SEASON_PAGE=""
	  fi
  fi
  if [ ! -z "$SEASON_PAGE" ]; then
    #Clean the page and leave only the episodes table (10000 lines just to be sure)
    SEASON_PAGE=$(echo "$SEASON_PAGE" | grep "<tbody>" -A 10000)
    SEASON_PAGE=$(echo "$SEASON_PAGE" | grep "</tbody>" -B 10000)
  fi
}



create_episode_files () {
  # Remove '/' from the directory name
  SERIES_DIR=${SERIES_DIR//$'/'/}


  # Buid TheTVDB complient serie's name and year
  SERIES_NAME=${SERIES_DIR// /-}
  SERIES_NAME=${SERIES_NAME/-(*[0-9])}
  SERIES_YEAR=${SERIES_DIR##*(}
  SERIES_YEAR=${SERIES_YEAR/)}


  # If some episodes have already been downloaded, start from last season downloaded
  SEASON=$(find "$SERIES_DIR"* | tail -1 | grep -E "S[0-9]{2}E[0-9]{2,3}" -o)
  if [ ! -z "$SEASON" ]; then
    SEASON=${SEASON:1:2}
    SEASON=${SEASON#0}
  else
    SEASON=1
  fi


  # Create a list of episodes and dates for all episodes that are missing
  EPISODE_LIST=""
  DATE_LIST=""
  while [ $SEASON -gt 0 ]
  do
    get_season_page_table
    if [ ! -z "$SEASON_PAGE" ]; then
      # Create a clean episode list
      EPISODE_LIST_SEASON=$(echo "$SEASON_PAGE" | grep -E "<td>S[0-9]{2}E[0-9]{2,3}</td>" -o | grep -E "S[0-9]{2}E[0-9]{2,3}" -o)
      EPISODE_LIST="$EPISODE_LIST""$EPISODE_LIST_SEASON"$'\n'
    
      # Create a clean episodes date list
      DATE_LIST_SEASON=$(echo "$SEASON_PAGE" | grep -E "<div>[A-Z][a-z]{2,8}? [0-9]{1,2}?, [0-9]{4}</div>" -o | grep -E "[A-Z][a-z]{2,8}? [0-9]{1,2}?, [0-9]{4}" -o)
      DATE_LIST="$DATE_LIST""$DATE_LIST_SEASON"$'\n'
      
      SEASON=$(($SEASON+1))
    else
      SEASON=0
    fi
  done


  #Convert lists to Array (for date need to replace " " by "-")
  EPISODE_LIST=($EPISODE_LIST)
  
  DATE_LIST=${DATE_LIST// /-}
  DATE_LIST=($DATE_LIST)


  # Create episode files. Ignore files that already exist
  for ((i=0; i<${#EPISODE_LIST[@]}; i++)); do
    EPISODE_FILE=$SERIES_DIR"/"$SERIES_DIR" "${EPISODE_LIST[$i]}".strm"
    if [ ! -f "$EPISODE_FILE" ]; then
      # Create episode if air date is in the past
      if [ $(date -I) \> $(date -d "${DATE_LIST[$i]//-/ }" -I) ]; then
        if [[ "${EPISODE_LIST[$i]}" != *"SPECIAL"* ]]; then
          truncate -s 1 "$EPISODE_FILE"
          touch -d "${DATE_LIST[$i]//-/ }" "$EPISODE_FILE"
          echo $SERIES_DIR ${EPISODE_LIST[$i]} : ${DATE_LIST[$i]//-/ }
        fi
      fi
    fi
  done
}



cd "$SERIES_BASE_DIR"

if [ $# -eq 0 ]; then
  DIRS=$(ls -p | grep /)
  DIRS=${DIRS// /@}
  for f in $DIRS; do
    SERIES_DIR=${f//@/ }
    echo ---------------------------------------------------------------
    echo -- ${SERIES_DIR/$'/'}
    echo
    create_episode_files
  done
else
  create_episode_files
fi


COMMENT





create_rss_file()
{
  Channel=$1
  Items=("${!2}")


  RSS_FILE='<?xml version="1.0" encoding="UTF-8" ?>'$'\n''<rss version="2.0">'$'\n'$'\n'"<channel>"$'\n'

  IFS='<' Channel=($Channel)
  
  RSS_FILE=$RSS_FILE"  <title>"${Channel[0]}"</title>"$'\n'
  RSS_FILE=$RSS_FILE"  <link>"${Channel[1]}"</link>"$'\n'
  RSS_FILE=$RSS_FILE"  <description>"${Channel[2]}"</description>"$'\n'

  # Create episode files. Ignore files that already exist
  for item in "${Items[@]}"; do
    IFS="<" item=($item)

    RSS_FILE=$RSS_FILE"  <item>"$'\n'
    RSS_FILE=$RSS_FILE"    <title>"${item[0]}"</title>"$'\n'
    RSS_FILE=$RSS_FILE"    <link>"${item[1]}"</link>"$'\n'
    RSS_FILE=$RSS_FILE"    <description>"${item[2]}"</description>"$'\n'
    RSS_FILE=$RSS_FILE"    <pubDate>"${item[3]}"</pubDate>"$'\n'
    RSS_FILE=$RSS_FILE"  </item>"$'\n'
  done

  RSS_FILE=$RSS_FILE"</channel>"$'\n'$'\n'"</rss>"

  echo "$RSS_FILE"
}



parse_page()
{
  Page=$1
  Article_Start_HTML=$2
  Article_End_HTML=$3
  Titles=""
  Links=""
  Descrs=""
  Dates=""
  
  
  # Clean the page all the way to the News articles start
  Page=$(echo "$Page" | grep "$Article_Start_HTML" -A 10000)
  Page=$(echo "$Page" | grep "$Article_Start_HTML" -B 10000)

  # Get Titles for all articles and clean them
  Titles=$(echo "$Page" | grep -E '<h2 class="heading body">' | grep -E ">.*?" -o)
  Titles=${Titles//<\/h2>/}
  Titles=${Titles//>/}
  Titles="${Titles//$'\n'/<}"
  IFS="<" Titles=($Titles)
    
  Links=$(echo "$Page" | grep -E 'class="permalink">' | grep -P '"https.*?"' -o )
  Links=${Links//\"/}
  Links="${Links//$'\n'/<}"
  IFS="<" Links=($Links)
    
  Descrs=$(echo "$Page" | grep -E '<p class="description">' | grep -E ">.*?" -o)
  Descrs=${Descrs//<\/p>/}
  Descrs=${Descrs//>/}
  Descrs="${Descrs//$'\n'/<}"
  IFS="<" Descrs=($Descrs)

  Dates=$(echo "$Page" | grep -E '<span class="meta-item pubDateTime" data-time=' | grep -E '"[0-9]{1,2}? [A-Z][a-z]{2} [0-9]{4}"' -o)
  Dates=${Dates//\"/}
  Dates=${Dates//$'\n'/<}
  IFS="<" Dates=($Dates)

  for ((i=0; i<${#Titles[@]}; i++)); do
    ITEMS[$i]=${Titles[$i]}"<"${Links[$i]}"<"${Descrs[$i]}"<"${Dates[$i]}
#echo $i
#echo "${ITEMS[$i]}"
  done
  
#echo "$Titles"
#echo
#echo "$Links"
#echo
#echo "$Descrs"
#echo
#echo "$Dates"
}


CHANNEL="W3Schools Home Page<https://www.w3schools.com<Free web building tutorials"
ITEMS=("RSS Tutorial<https://www.w3schools.com/xml/xml_rss.asp<New RSS tutorial on W3Schools" "XML Tutorial<https://www.w3schools.com/xml<New XML tutorial on W3Schools" "HTML tutorial<https://www.w3schools.com/xml<New HTML tutorial on W3Schools")

NEWS_PAGE_URL="https://www.channel4.com/news/uk"
ARTICLE_START_HTML='<div class="content with-image">'
ARTICLE_END_HTML='<footer class="receptacle site-footer">'

NEWS_PAGE=$(wget -qO - "$NEWS_PAGE_URL")

parse_page "$NEWS_PAGE" "$ARTICLE_START_HTML" "$ARTICLE_END_HTML"

create_rss_file "$CHANNEL" ITEMS[@]

















