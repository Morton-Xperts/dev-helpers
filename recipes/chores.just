#/!/usr/bin/env just

# Run the iOS app
prettify path=".":
    @echo "Running prettier..."
    prettier --write "{{path}}"

lint path=".":
    @echo "Linting..."
    eslint "{{path}}" --fix

test:
    @echo "Running tests..."
    jest
