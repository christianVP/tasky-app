# using existing tasky app
FROM cvp01/tasky:3

# copy the dummy key file
COPY dummy-key /app/dummy-key
