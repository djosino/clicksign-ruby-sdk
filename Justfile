default: test

test:
    bundle exec rspec

format:
    bundle exec rubocop -A

format-check:
    bundle exec rubocop
