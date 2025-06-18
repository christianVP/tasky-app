# using existing tasky app
# this :4 version contains the exercise file
FROM cvp01/tasky:4
# copy the dummy key file
COPY dummy-key /app/dummy-key
