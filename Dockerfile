# using existing tasky app
FROM cvp01/tasky:4

# copy the dummy key file
COPY dummy-key /app/dummy-key

# Keep the container running with a dummy process - for testing
CMD ["tail", "-f", "/dev/null"]