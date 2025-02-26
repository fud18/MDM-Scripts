#!/bin/bash

# ===================================================================================
# Add to the start of any script that needs to make an API call 
# ===================================================================================

# Define the Access Token for authentication with Mosyle API
accessToken="%accessToken%"
bearer_token="%custom_bearer_token_1%\
%custom_bearer_token_2%\
%custom_bearer_token_3%\
%custom_bearer_token_4%\
%custom_bearer_token_5%\
%custom_bearer_token_6%"

# ===================================================================================
# Add to the curl command 
# ===================================================================================

--header "accessToken: $accessToken" \
--header "Authorization: Bearer $bearer_token" \

# End of script
