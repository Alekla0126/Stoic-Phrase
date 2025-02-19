#!/bin/bash
# A simple script that fetches and prints a stoic phrase in colorful text using lolcat

# Fetch the stoic quote using curl and parse the JSON with jq
quote=$(curl -s https://stoic-quotes.com/api/quote | jq -r '.text')

# Display the quote using lolcat for colorful output
echo "$quote" | lolcat

