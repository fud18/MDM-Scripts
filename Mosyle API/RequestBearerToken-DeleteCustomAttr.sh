#!/bin/bash

# ===================================================================================
# This script authenticates with the Mosyle API, retrieves a Bearer token, 
# splits the token into six parts, deletes device attributes with each part, 
# and finally deletes the stored full Bearer token variable in Mosyle.
#
# Steps:
# 1. Authenticate using API credentials and retrieve the Bearer token.
# 2. Extract and split the token into six equal parts.
# 3. Delete six custom device attributes in Mosyle, each storing a token part.
# 4. Delete the full Bearer token variable in Mosyle.
# ===================================================================================

# Define the Access Token for authentication with Mosyle API
accessToken="<ACCESS TOKEN>"

# Step 1: Send login request and capture the full response, including headers
response=$(curl --include --location 'https://businessapi.mosyle.com/v1/login' \
--header "accessToken: $accessToken" \
--header 'Content-Type: application/json' \
--data-raw '{
    "email" : "<EMAIL>",
    "password" : "<PASSWORD>"
}')

# Step 2: Extract only the Bearer token from the response headers
bearer_token=$(echo "$response" | grep -i "Authorization: Bearer" | sed "s/Authorization: Bearer //I" | tr -d "\r")

# Calculate the length of the Bearer token
token_length=${#bearer_token}

# Determine the size of each split part (divide into six equal pieces)
part_size=$((token_length / 6))

# Extract six parts of the Bearer token
bearer_token_1=${bearer_token:0:part_size}
bearer_token_2=${bearer_token:part_size:part_size}
bearer_token_3=${bearer_token:$((part_size * 2)):part_size}
bearer_token_4=${bearer_token:$((part_size * 3)):part_size}
bearer_token_5=${bearer_token:$((part_size * 4)):part_size}
bearer_token_6=${bearer_token:$((part_size * 5))}

# Combine all six parts back into the full Bearer token
full_bearer_token="${bearer_token_1}${bearer_token_2}${bearer_token_3}${bearer_token_4}${bearer_token_5}${bearer_token_6}"

# Step 3: Delete six device attributes, each storing one part of the Bearer token
for i in {1..6}; do
    curl --location 'https://businessapi.mosyle.com/v1/devices' \
    --header 'Content-Type: application/json' \
    --header "accessToken: $accessToken" \
    --header "Authorization: Bearer $full_bearer_token" \
    --data "{
         \"operation\": \"delete_custom_device_attribute\",
         \"os\": \"mac\",
         \"unique_id\": \"custom_new_custom_bearer_token_$i\"
    }"
done

# Step 4: Delete the full Bearer token stored as a Mosyle custom variable
curl --location 'https://businessapi.mosyle.com/v1/devices' \
--header 'Content-Type: application/json' \
--header "accessToken: $accessToken" \
--header "Authorization: Bearer $full_bearer_token" \
--data "{
     \"operation\": \"delete_custom_device_attribute\",
     \"os\": \"mac\",
     \"unique_id\": \"new_custom_cda\"
}"

# End of script
