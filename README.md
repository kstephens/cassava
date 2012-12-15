# Cassava

A command-line CSV tool.

## Installation

Add this line to your application's Gemfile:

    gem 'cassava'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install cassava

## Usage

    # Concat mulitple CSVs, while merging columns:
    $ cassava cat first.csv second.csv
    
    # Cut columns out of result; '-' is used to pipe results to next command:
    $ cassava cat first.csv second.csv - cut -c first_name,last_name
    
    # Format as ASCII table.
    $ cassava format first.csv
    
    # Select where.
    $ cassava cat *.csv - where last_name=Smith - format
    
    # Sort by a column:
    $ cassava cat *.csv - sort -by last_name,first_name - format

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
